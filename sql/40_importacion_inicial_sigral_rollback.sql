-- SIGRAL RRHH | Importación inicial conservadora desde tablas del Excel.
-- Esta plantilla NO contiene datos personales: __SOURCE_BASE64__ se sustituye en ejecución.
-- DRY RUN por defecto; para aplicar cambiar exclusivamente ROLLBACK por COMMIT.
-- El origen es la copia tabular integrada anteriormente en el visor HTML privado
-- (no contiene fórmulas originales del libro Excel).
BEGIN;
SELECT pg_advisory_xact_lock(23012,20261117);
CREATE TEMP TABLE sigral_fuente_tmp(j jsonb) ON COMMIT DROP;
INSERT INTO sigral_fuente_tmp(j)
VALUES (convert_from(decode('__SOURCE_BASE64__','base64'),'UTF8')::jsonb);

DO $pre$
DECLARE n integer;
BEGIN
 SELECT jsonb_array_length(j->'Personal'->'items') INTO n FROM sigral_fuente_tmp;
 IF n<>84 THEN RAISE EXCEPTION 'Inesperado: % personas',n; END IF;
 SELECT jsonb_array_length(j->'Proyectos'->'items') INTO n FROM sigral_fuente_tmp;
 IF n<>44 THEN RAISE EXCEPTION 'Inesperado: % proyectos',n; END IF;
 SELECT jsonb_array_length(j->'Asignaciones'->'items') INTO n FROM sigral_fuente_tmp;
 IF n<>95 THEN RAISE EXCEPTION 'Inesperado: % asignaciones',n; END IF;
 SELECT jsonb_array_length(j->'Contratos'->'items') INTO n FROM sigral_fuente_tmp;
 IF n<>88 THEN RAISE EXCEPTION 'Inesperado: % contratos',n; END IF;
 IF (SELECT count(*) FROM public.empleados)<>58
 OR (SELECT count(*) FROM public.proyectos)<>71
 OR (SELECT count(*) FROM public.asignaciones)<>75
 THEN RAISE EXCEPTION 'La base se modificó desde el preflight'; END IF;
 IF EXISTS (SELECT 1 FROM public.empleados e WHERE e.codigo LIKE 'EX-%' AND e.dni IS NULL)
 THEN RAISE EXCEPTION 'Códigos EX- sin DNI: revisar riesgo de colisión'; END IF;
END $pre$;

-- Respaldo del estado ANTERIOR, dentro de la misma transacción.
INSERT INTO sigral_private.respaldos_preimportacion
(etiqueta,empleados,proyectos,asignaciones)
SELECT 'SIGRAL_ORIGINAL_58_71_75_20261117',
 (SELECT COALESCE(jsonb_agg(to_jsonb(e)),'[]'::jsonb) FROM public.empleados e),
 (SELECT COALESCE(jsonb_agg(to_jsonb(p)),'[]'::jsonb) FROM public.proyectos p),
 (SELECT COALESCE(jsonb_agg(to_jsonb(a)),'[]'::jsonb) FROM public.asignaciones a)
ON CONFLICT (etiqueta) DO NOTHING;

-- Evidencia de todos los datos importados (4 tablas originales).
INSERT INTO sigral_private.excel_import_archivo(nombre_fuente,datos_fuente,huella_fuente)
SELECT '0_Personal_SIGRAL_r0.xlsx - copia de tablas HTML',j,md5(j::text) FROM sigral_fuente_tmp
ON CONFLICT (huella_fuente) DO NOTHING;

-- No se modifica ni se sustituye ningún empleado ya identificado por DNI.
WITH items AS (
 SELECT x FROM sigral_fuente_tmp,LATERAL jsonb_array_elements(j->'Personal'->'items') x
)
INSERT INTO public.empleados(codigo,dni,apellidos,nombres,cargo,area,fecha_ingreso,fecha_fin_contrato,estado,observaciones)
SELECT 'EX-'||(x->>0),x->>0,
 trim(split_part(regexp_replace(x->>1,'[[:space:]]+',' ','g'),' ',1)||' '||
      split_part(regexp_replace(x->>1,'[[:space:]]+',' ','g'),' ',2)),
 trim(regexp_replace(regexp_replace(x->>1,'[[:space:]]+',' ','g'),'^[^ ]+ [^ ]+ *','')),
 x->>2,x->>3,to_date(x->>4,'DD/MM/YYYY'),
 CASE WHEN x->>5='' THEN NULL ELSE to_date(x->>5,'DD/MM/YYYY') END,
 CASE WHEN x->>10='ACTIVO' THEN 'Activo' ELSE 'Cesado' END,
 'Importado de tabla Excel. Estado original: '||(x->>10)||
 '. Apellidos y nombres originales: '||(x->>1)
FROM items
WHERE NOT EXISTS(SELECT 1 FROM public.empleados e WHERE trim(e.dni)=trim(x->>0))
ON CONFLICT DO NOTHING;

-- Los proyectos presentes se conservan; no se les sustituyen datos ni fechas.
WITH items AS (
 SELECT x FROM sigral_fuente_tmp,LATERAL jsonb_array_elements(j->'Proyectos'->'items') x
)
INSERT INTO public.proyectos(codigo,nombre,gerente,estado,descripcion)
SELECT x->>0,x->>2,x->>3,'En curso',
 'Importado de tabla Excel. Estado original: '||(x->>4)||
 '. Proyecto padre: '||(x->>1)||'. Nivel: '||(x->>9)
FROM items
WHERE NOT EXISTS (
 SELECT 1 FROM public.proyectos p WHERE upper(trim(p.codigo))=upper(trim(x->>0))
)
ON CONFLICT DO NOTHING;

-- Incorpora los 88 contratos históricos como eventos de Excel sin alterar
-- las fechas ni el estado actual de personas existentes.
WITH contracts AS (
 SELECT x->>1 dni,
  jsonb_agg(jsonb_build_object(
   'ref_excel',x->>0,'tipo',x->>4,
   'fecha_ingreso_contrato',to_date(x->>6,'DD/MM/YYYY'),
   'fecha_fin_contrato',CASE WHEN x->>7='' THEN NULL ELSE to_date(x->>7,'DD/MM/YYYY') END,
   'fecha_cese',CASE WHEN x->>10='' THEN NULL ELSE to_date(x->>10,'DD/MM/YYYY') END,
   'puesto',x->>5,'estado_excel',x->>13,
   'motivo_cierre',x->>9,'observaciones',x->>14,
   'fuente','0_Personal_SIGRAL_r0.xlsx'
  ) ORDER BY x->>0) history
 FROM sigral_fuente_tmp,
 LATERAL jsonb_array_elements(j->'Contratos'->'items') x
 GROUP BY x->>1
)
UPDATE public.empleados e
SET historial_contratos=COALESCE(e.historial_contratos,'[]'::jsonb)||c.history
FROM contracts c
WHERE trim(e.dni)=trim(c.dni)
AND NOT EXISTS (
 SELECT 1 FROM jsonb_array_elements(COALESCE(e.historial_contratos,'[]'::jsonb)) z
 WHERE z->>'ref_excel'=c.history->0->>'ref_excel'
);

-- Todas las asignaciones se relacionan por DNI y código de proyecto.
-- La dedicación en Excel es fracción (1, 0.5, 0.1); el sistema usa % (100, 50, 10).
WITH items AS (
 SELECT x FROM sigral_fuente_tmp,
 LATERAL jsonb_array_elements(j->'Asignaciones'->'items') x
)
INSERT INTO public.asignaciones(ref_excel,empleado_id,proyecto_id,puesto,pct,fecha_ini,fecha_fin,obs)
SELECT x->>0,e.id,p.id,
 COALESCE(e.cargo,''),
 GREATEST(1,LEAST(100,ROUND((x->>9)::numeric*100)::integer)),
 to_date(x->>10,'DD/MM/YYYY'),
 CASE WHEN x->>13<>'' THEN to_date(x->>13,'DD/MM/YYYY')
      WHEN x->>11<>'' THEN to_date(x->>11,'DD/MM/YYYY')
      ELSE NULL END,
 'Excel: '||(x->>0)||'; contrato: '||(x->>12)||
 '; estado original: '||(x->>16)||
 '; hasta planificada: '||(x->>11)
FROM items
JOIN public.empleados e ON trim(e.dni)=trim(x->>1)
JOIN public.proyectos p ON upper(trim(p.codigo))=upper(trim(x->>4))
WHERE NOT EXISTS (
 SELECT 1 FROM public.asignaciones a
 WHERE a.ref_excel=x->>0
 OR (a.empleado_id=e.id AND a.proyecto_id=p.id
     AND a.fecha_ini=to_date(x->>10,'DD/MM/YYYY'))
)
ON CONFLICT DO NOTHING;

DO $post$
DECLARE n integer;
BEGIN
 SELECT count(*) INTO n FROM public.empleados;
 IF n<>97 THEN RAISE EXCEPTION 'Empleados esperados 97, recibidos %',n; END IF;
 SELECT count(*) INTO n FROM public.proyectos;
 IF n<>104 THEN RAISE EXCEPTION 'Proyectos esperados 104, recibidos %',n; END IF;
 SELECT count(*) INTO n FROM public.asignaciones;
 IF n<>170 THEN RAISE EXCEPTION 'Asignaciones esperadas 170, recibidas %',n; END IF;
 IF (SELECT count(*) FROM public.empleados e
 CROSS JOIN LATERAL jsonb_array_elements(COALESCE(e.historial_contratos,'[]'::jsonb)) h
 WHERE h->>'fuente'='0_Personal_SIGRAL_r0.xlsx')<>88
 THEN RAISE EXCEPTION 'Cantidad de contratos históricos distinta de 88'; END IF;
END $post$;

SELECT (SELECT count(*) FROM public.empleados) empleados,
       (SELECT count(*) FROM public.proyectos) proyectos,
       (SELECT count(*) FROM public.asignaciones) asignaciones,
       (SELECT count(*) FROM sigral_private.excel_import_archivo) archivos_fuente,
       (SELECT count(*) FROM sigral_private.respaldos_preimportacion) respaldos_preimportacion;
ROLLBACK;
