# SIGRAL RRHH — Corte de autenticación y datos (STAGING)

**Estado**: Cambios propuestos, no desplegados ni ejecutados sobre Supabase.

## Riesgo confirmado
El HTML anterior incluía contraseñas comparadas desde el navegador y un SQL de ejemplo con políticas `allow_all`. La auditoría de solo lectura del proyecto real `BD_rrhh_control` confirmó cinco políticas activas `sigral_allow_all` para `anon` en empleados, proyectos, asignaciones, usuarios y maestras. No se cambió ninguna política ni registro de producción.

## Orden de ejecución sin interrupción de producción
1. Respaldar tablas, políticas, esquema y cuentas Auth actuales. Usar un proyecto Supabase de **staging** aislado. No hay una rama Supabase de ensayo creada en este momento y la creación puede tener coste; no asumir que la previsualización Netlify es un entorno aislado.
2. Ejecutar `sql/00_preflight_lectura.sql` en staging y revisar permisos, roles, conflictos y datos contractuales. Conservar resultados.
3. Crear o invitar en **Supabase Authentication** a cada usuario de prueba y confirmar su acceso. Evitar compartir contraseñas por chat o incluirlas en código.
4. Vincular `public.usuarios.auth_user_id` al UUID de cada `auth.users.id`, mediante SQL administrado. La migración añade la columna pero se detiene si algún usuario activo carece de vinculación. Se debe crear la columna antes de vincular (primera instrucción SQL; en staging).
5. Ejecutar `sql/10_corte_auth_rls_STAGING.sql` solo en staging, después de verificar las cinco políticas esperadas y sus funciones `sigral_private`, luego publicar la rama en un sitio Netlify de previsualización; configurar el mismo Supabase staging.
6. Verificar dos usuarios: **admin** (CRUD de empleados, contratos, proyectos, asignaciones) y **viewer** (solo directorio sin datos personales, proyectos y asignaciones; sin acciones de escritura). Verificar que `anon` reciba denegaciones.
7. Probar que un `Indefinido` tenga `fecha_fin_contrato=NULL`, y que cese se registre separadamente. No ejecutar un cambio masivo de datos.
8. Resolver compatibilidad de demás roles reales si los hay, y pruebas de importación transaccional antes del corte definitivo.
9. Programar despliegue y migración de producción solamente con respaldo, ventana, aprobación y verificación de acceso de cada usuario.

## Operaciones deliberadamente deshabilitadas
- Alta de usuarios desde navegador: debe crearse en Supabase Auth y vincularse a `usuarios.auth_user_id` con permisos administrativos.
- Importación masiva directa desde navegador: no transaccional, puede duplicar asignaciones y sobrescribir contratos históricos.
- Conexión a la base real desde el entorno de previsualización.

## Observaciones de seguridad
- La clave pública `anon` de Supabase puede estar en el cliente; la seguridad reside en Auth y RLS, nunca en ocultar esa clave.
- La función `listar_empleados_directorio` expone solamente columnas laborales no sensibles para usuarios activos.
- La interfaz puede mostrar una selección de datos menor que los permisos RLS; ambas capas deben verificar roles.
- El proyecto no está listo para producción hasta demostrar autenticación, permisos, migración de usuarios y aceptación funcional en staging.

## Evidencia de validación automatizada
- GitHub Actions `SIGRAL static safety checks`: JavaScript sintáctico, RH-001, lectura del historial, pruebas simuladas de inicio de sesión, denegación al usuario sin perfil y bloqueo de vista previa contra el proyecto real.
- GitHub Actions `SIGRAL PostgreSQL RLS staging verification`: PostgreSQL 17 en contenedor efímero, sin información de trabajadores reales. Verifica el SQL de corte de políticas, denegación de `anon`, privilegios de administrador, restricción de lectura y escritura del viewer, bloqueo de usuarios inactivos, RH-001 y duplicados.
- Los scripts y las pruebas están en `scripts/`, `sql/tests/` y `.github/workflows/`.
- **Alcance**: pruebas reproducibles en memoria/CI y consultas de solo lectura sobre el proyecto real. **No son pruebas de acceso a un proyecto Supabase staging con usuarios Auth reales ni una certificación de despliegue.**

## Hallazgos reales, sin datos personales
- Proyecto `BD_rrhh_control` (ref `amhkybyuwrolursgsicb`).
- 58 empleados, 71 proyectos, 75 asignaciones, 2 perfiles usuarios y 9 registros maestros.
- Cuentas de `auth.users`: cero. Perfiles activos no vinculados todavía a Auth: dos.
- Contratos indefinidos con vencimiento incorrecto: cero; DNIs duplicados: cero.
- La base actual utiliza un índice único de DNI y otro por `ref_excel` de asignaciones; deben conservarse.
- El sistema sigue expuesto por las políticas de `anon` hasta su corte planificado. No interpretar el estado de staging como protección de producción.

## Criterios de aceptación antes de autorizar producción
- Copia de seguridad y prueba de restauración.
- Dos usuarios Auth reales creados y vinculados en staging, con roles admin y viewer.
- Carga completa de tablas en staging; login/logout/cambio de contraseña probados en navegador.
- Confirmar que el frontend del deploy preview no use la URL del Supabase real.
- Importador transaccional implementado y las 98 decisiones/95 asignaciones funcionalmente verificadas (no habilitar el importador masivo anterior).
- Pruebas RLS y de integridad en Supabase staging, además de CI con PostgreSQL.
- Aprobación de ventana de despliegue y rollback comprobado.
