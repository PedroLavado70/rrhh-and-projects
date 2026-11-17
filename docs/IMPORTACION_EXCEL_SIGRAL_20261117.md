# SIGRAL RRHH — Carga inicial del Excel a Supabase (17-11-2026)

## Confirmación de producción
La importación se ejecutó sobre el proyecto `BD_rrhh_control`, usando una transacción SQL. Antes de ejecutar se realizó una prueba idéntica con `ROLLBACK` y se comprobó que el estado esperado era consistente.

| Concepto | Antes | Ahora | Altas |
|---|---:|---:|---:|
| Empleados | 58 | 97 | 39 |
| Proyectos | 71 | 104 | 33 |
| Asignaciones | 75 | 170 | 95 |
| Historiales de contratos con referencia al Excel | 0 | 88 | 88 |

El conjunto importado comprende 84 personas, 44 proyectos, 95 asignaciones y 88 eventos contractuales del origen. Los 45 empleados y 11 proyectos con coincidencia existente **no fueron sobrescritos** en sus campos principales. Los 88 eventos contractuales de origen se anexaron al historial sin sustituir el historial anterior.

## Evidencia y restauración
- La copia tabular exacta usada para el proceso quedó archivada en `sigral_private.excel_import_archivo`.
- Se guardó una copia del estado previo de las tablas de empleados, proyectos y asignaciones en `sigral_private.respaldos_preimportacion`.
- Las tablas están en un esquema privado, no expuesto al navegador ni a los roles `anon`/`authenticated`.
- Los controles posteriores registraron: 0 DNI duplicados, 0 códigos duplicados de proyectos, 0 referencias de asignación duplicadas, 0 asignaciones sin empleado o proyecto. Los 84 DNI, 44 proyectos y 95 referencias del origen están presentes.

## Transformaciones necesarias para el esquema web
- Identificación de empleados mediante DNI y proyectos mediante código; el importador no vuelve a insertar las coincidencias.
- Los empleados nuevos reciben un código provisional `EX-<DNI>`, editable en la web.
- El Excel combina apellidos y nombres en una columna; para nuevas altas se separaron los dos primeros términos como apellidos y el resto como nombres. El texto original completo quedó en observaciones para corrección manual.
- `ACTIVO` se representa como `Activo`; `RENUNCIA` y `TÉRMINO DE CONTRATO` se representan como `Cesado`, conservando el estado exacto de origen en las observaciones.
- `ACTIVO` para proyectos se representa como `En curso`; el original se conserva en la descripción.
- La dedicación `1`, `0.5` y `0.1` del Excel corresponde a 100 %, 50 % y 10 % en la aplicación.
- Para los proyectos sin fechas de inicio/fin, esos campos permanecen vacíos. La aplicación se adaptó para permitir su edición sin obligar a inventar fechas.
- El original importado es la **copia estructurada de cuatro hojas incorporada al visor privado** en una conversación anterior, no el archivo XLSX con sus fórmulas, formatos o validaciones. Los datos tabulares exactos están preservados.

## Uso a partir de ahora
La base oficial del sistema es **Supabase**. Ingresar con Supabase Auth en `https://sigralrrhh.netlify.app/`, actualizar directamente empleados, contratos, proyectos y asignaciones, y comprobar resultados en el dashboard. No debe repetirse la importación original.

Para respaldos Excel locales: utilizar Chrome/Edge, pulsar «Vincular carpeta Excel», aceptar el permiso de carpeta y realizar modificaciones; el navegador guardará el Excel maestro y una copia fechada tras cada operación confirmada. Los respaldos son exportaciones, no una vía de sincronización bidireccional; si se editan directamente no cambian Supabase.

## Aún pendiente de verificación presencial
Comprobar en navegador del administrador: edición de un proyecto importado sin fechas, creación/cierre de asignación, renovación contractual y escritura en carpeta Windows. Las pruebas de integridad SQL **no reemplazan** esas pruebas de interfaz.
