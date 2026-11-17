# SIGRAL RRHH — Implementación sobre la aplicación original

## Funciones implementadas en el repositorio original

### Gestión diaria
- Edición de empleados, proyectos y asignaciones usando formularios originales.
- Contrato **indefinido**: su vencimiento siempre es `NULL`; se bloquea el campo de fecha final.
- Cese y recontratación: eventos diferentes del vencimiento; el historial se conserva.
- **Cerrar proyecto** conserva el proyecto y sus asignaciones; ya no ejecuta un borrado de registros relacionados.
- **Finalizar asignación** registra el fin con fecha actual, sin borrar el recurso histórico.
- Duplicados de DNI y de asignación detectados antes de guardar; los índices SQL complementan esta lógica.

### Dashboard y alertas
- Módulo `scripts/operational-dashboard.js` integrado en `index.html`.
- Proyectos que terminan en 60 días o ya vencidos pero no cerrados.
- Contratos de personal activo que vencen en 60 días, excluyendo los indefinidos.
- Asignaciones activas que terminan en 30 días, candidatas a reasignación.
- No reemplaza los cuadros gerenciales preexistentes.

### Exportación automática a Excel en una carpeta Windows
- El usuario administrador pulsa `📁 Vincular carpeta Excel` en la barra superior.
- Chrome/Edge solicita permiso de lectura/escritura para la carpeta escogida.
- Después de una operación **confirmada por Supabase**, genera:
  - `SIGRAL_RRHH/01_BASE_MAESTRA/SIGRAL_RRHH_Actual.xlsx`
  - `SIGRAL_RRHH/02_RESPALDOS/SIGRAL_<fecha-hora>_<operación>.xlsx`
- Cada libro contiene hojas `Empleados`, `Proyectos`, `Asignaciones`, `Control`.
- Los historiales JSON se exportan como texto, sin eliminarse. La carpeta no se envía a Netlify.
- Si la autorización de carpeta se pierde o falla la escritura, aparece un error; la operación confirmada en Supabase no se revierte automáticamente.
- Los archivos Excel son **exportaciones y respaldos**, no una segunda fuente editable y sincronizada en ambos sentidos. Si se modifica el Excel manualmente, el cambio no se reimporta automáticamente.

## Estado de seguridad y puesta en servicio

**Versión integrada en el Pull Request #2 (rama `security/supabase-auth-staging`)**, sin fusión a `main`.

- Las pruebas CI de JavaScript, login simulado, respaldo Excel, alertas y PostgreSQL RLS se ejecutan con GitHub Actions.
- Supabase real `BD_rrhh_control` conserva 58 empleados, 71 proyectos, 75 asignaciones, dos perfiles y cero cuentas de Supabase Auth.
- Las cinco políticas `sigral_allow_all` del rol anónimo **siguen activas en producción**; son un problema de seguridad y no deben usarse para seguir cargando información personal sin autenticación.
- La importación masiva antigua está deshabilitada deliberadamente. No está implementado todavía el importador transaccional que reconcilie el Excel completo con la BD.
- Netlify deploy-preview bloquea el login si apunta a la BD de producción.

## Bloqueantes verificables para la versión operativa
1. Crear una cuenta **Supabase Auth** de administrador, vincularla al perfil autorizado y probarla en un entorno de ensayo.
2. Ejecutar migración RLS y tests con ese entorno; cortar las políticas anónimas en una ventana autorizada.
3. Aplicar las decisiones de conciliación histórica y la carga inicial Excel mediante un proceso transaccional con respaldo y comprobaciones de versión.
4. Ensayar el flujo completo en navegador (crear, editar, reasignar, cesar, recontratar, respaldar y recuperar).
5. Fusionar y desplegar en `sigralrrhh.netlify.app`.

**No declarar la aplicación lista para uso real diario hasta completar estos pasos.**
