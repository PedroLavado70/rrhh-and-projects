# SIGRAL RRHH — Corte de autenticación y datos (STAGING)

**Estado**: Cambios propuestos, no desplegados ni ejecutados sobre Supabase.

## Riesgo confirmado
El HTML anterior incluía contraseñas comparadas desde el navegador y un SQL de ejemplo con políticas `allow_all`. La *existencia real* de dichas políticas en tu Supabase debe comprobarse con `sql/00_preflight_lectura.sql` (no asumir que el ejemplo SQL fue ejecutado).

## Orden de ejecución sin interrupción de producción
1. Respaldar tablas, políticas, esquema y cuentas Auth actuales. Usar un proyecto Supabase de **staging** clonado.
2. Ejecutar `sql/00_preflight_lectura.sql` en staging y revisar permisos, roles, conflictos y datos contractuales. Conservar resultados.
3. Crear o invitar en **Supabase Authentication** a cada usuario de prueba y confirmar su acceso. Evitar compartir contraseñas por chat o incluirlas en código.
4. Vincular `public.usuarios.auth_user_id` al UUID de cada `auth.users.id`, mediante SQL administrado. La migración añade la columna pero se detiene si algún usuario activo carece de vinculación. Se debe crear la columna antes de vincular (primera instrucción SQL; en staging).
5. Ejecutar `sql/10_corte_auth_rls_STAGING.sql` solo en staging, luego publicar la rama en un sitio Netlify de previsualización; configurar el mismo Supabase staging.
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
