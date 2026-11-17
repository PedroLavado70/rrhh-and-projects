-- SIGRAL | Consultas de preflight de SOLO LECTURA.
-- Ejecutar en Supabase SQL Editor antes de cualquier migración.
SELECT tablename,policyname,roles,cmd,qual,with_check
  FROM pg_policies WHERE schemaname='public'
    AND tablename IN ('empleados','proyectos','asignaciones','usuarios','maestras')
  ORDER BY tablename,policyname;

SELECT column_name,data_type,is_nullable
 FROM information_schema.columns
 WHERE table_schema='public' AND table_name='usuarios'
 ORDER BY ordinal_position;

SELECT COUNT(*) AS usuarios_activos FROM public.usuarios WHERE active IS TRUE;
SELECT role,COUNT(*) AS total FROM public.usuarios GROUP BY role ORDER BY role;
SELECT COUNT(*) AS contratos_indefinidos_con_fin
 FROM public.empleados
 WHERE lower(trim(tipo_contrato))='indefinido' AND fecha_fin_contrato IS NOT NULL;
SELECT COUNT(*) AS empleados_dni_duplicados FROM (
 SELECT dni FROM public.empleados
 WHERE dni IS NOT NULL AND trim(dni)<>''
 GROUP BY dni HAVING COUNT(*)>1
) x;
SELECT COUNT(*) AS asignaciones_duplicadas_exactas FROM (
 SELECT proyecto_id,empleado_id,puesto,fecha_ini,fecha_fin,COUNT(*)
 FROM public.asignaciones
 GROUP BY 1,2,3,4,5 HAVING COUNT(*)>1
) x;
