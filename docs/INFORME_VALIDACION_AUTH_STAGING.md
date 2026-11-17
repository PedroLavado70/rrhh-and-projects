# SIGRAL RRHH — Informe de validación de migración a Supabase Auth

**Fecha de preparación:** 16/11/2026 (Perú)  
**Rama:** `security/supabase-auth-staging`  
**Pull Request:** [#2](https://github.com/PedroLavado70/rrhh-and-projects/pull/2) — permanece en borrador  
**Destino:** preproducción, **sin cambios autorizados en producción**

## 1. Verificaciones satisfactorias

### A. JavaScript (GitHub Actions)
- Validación sintáctica de los dos scripts internos del HTML.
- RH-001: al elegir indefinido se limpia y bloquea la fecha de vencimiento.
- Plazo fijo: fecha de vencimiento obligatoria.
- Otros tipos de contrato: no se fuerzan indebidamente fechas de vencimiento.
- Lectura de `historial` e `historial_contratos` sin pérdida.
- Simulación de Supabase Auth: admin, contraseña incorrecta, usuario sin perfil y error al cargar datos.
- Bloqueo de acceso desde Netlify deploy-preview mientras use la URL de Supabase real.
- Importador web heredado deshabilitado, porque no es atómico ni idempotente.

### B. PostgreSQL 17 temporal en GitHub Actions
- Ejecución completa del script `sql/10_corte_auth_rls_STAGING.sql` contra cinco tablas ficticias que comienzan con políticas `sigral_allow_all`.
- Ejecución de las restricciones RH-001 y del índice natural de asignaciones.
- Acceso `anon` denegado a empleados, usuarios y RPC de directorio.
- Acceso del administrador a datos y directorio.
- Acceso de `viewer` restringido al directorio sin DNI, salario ni histórico; sin escritura de proyectos.
- Usuario desactivado sin acceso a proyectos ni directorio.
- Protección de columna `pwd_hash` contra lectura desde el navegador.
- Rechazo de vencimiento en contrato indefinido.
- Rechazo de asignación natural duplicada.

**Evidencia:** [GitHub Actions — PostgreSQL RLS, ejecución 19](https://github.com/PedroLavado70/rrhh-and-projects/actions/runs/44001153419) (resultado: success); [GitHub Actions — static checks, ejecución 45](https://github.com/PedroLavado70/rrhh-and-projects/actions/runs/44001153374) (resultado: success).

## 2. Contraste de solo lectura de producción

Proyecto: `BD_rrhh_control` (referencia `amhkybyuwrolursgsicb`).

| Control | Estado verificado |
|---|---:|
| Empleados | 58 |
| Proyectos | 71 |
| Asignaciones | 75 |
| Perfiles en tabla usuarios | 2 |
| Cuentas existentes en Supabase Auth | 0 |
| Políticas `sigral_allow_all` de acceso `anon` | 5 |
| Contratos indefinidos con vencimiento erróneo | 0 |
| DNI duplicados | 0 |

`main/index.html` conserva el blob SHA `937fdc7d94cba933acaf13dc8a975a1ef85a883a`. No se han ejecutado migraciones, cambios de permisos ni importaciones sobre producción.

## 3. Límites de estas pruebas

- **No existe aún una rama o proyecto Supabase staging independiente con el esquema y usuarios reales de ensayo.** Las pruebas SQL fueron en PostgreSQL 17 efímero y las pruebas Auth con objetos simulados, no son una demostración de login real.
- No se han creado cuentas Auth ni vinculado `auth_user_id` para los dos perfiles del sistema; hacerlo en producción cambiaría datos y exige aprobación posterior.
- La importación Excel → Supabase no está habilitada; falta el ejecutor transaccional y la resolución funcional de eventos y asignaciones pendientes.
- Las cinco políticas públicas reales siguen activas hasta que se apruebe el corte de seguridad. Se trata de una exposición real que debe mitigarse en el menor plazo compatible con la continuidad del negocio.

## 4. Secuencia para ensayo real sin afectar producción

1. Crear un entorno Supabase de staging independiente **previa aceptación de cualquier coste**; no usar el proyecto PL&Co.-Costos ni ejecutar migraciones en `BD_rrhh_control`.
2. Crear estructura y registros ficticios o copia anonimizada; nunca copiar contraseñas heredadas al repositorio.
3. Crear dos usuarios de prueba en Supabase Authentication (admin y viewer); ejecutar `sql/05_preparar_perfiles_auth_STAGING.sql` y vincular los UUID reales.
4. Aplicar `sql/10_corte_auth_rls_STAGING.sql`, `sql/20_RH001_integridad_STAGING.sql`, `sql/25_asignaciones_idempotentes_STAGING.sql` solo en staging.
5. Configurar Netlify Deploy Preview con la URL de staging, repetir login real, cese, reingreso, contratos y permisos por rol; verificar en el navegador y SQL.
6. Probar respaldo y restauración, resolver 98 decisiones/95 asignaciones, y completar motor de importación atómico antes de plantear producción.
7. Solicitar autorización explícita para la ventana de cambio de producción, con respaldo y rollback.

**Conclusión:** la fase de validación automatizada de autenticación, políticas y restricciones está aprobada; el ensayo real en Supabase Auth/Netlify y el corte de producción permanecen pendientes. No declarar la aplicación terminada hasta superarlos.
