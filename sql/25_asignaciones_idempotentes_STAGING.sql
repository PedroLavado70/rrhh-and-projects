-- SIGRAL: índice de idempotencia para asignaciones (STAGING solamente).
-- Requiere primero revisar las 95 asignaciones históricas y posibles duplicados.
-- No ejecutar sin comprobar que no existen duplicados legítimos por la misma clave.
DO $$
BEGIN
  IF EXISTS(
    SELECT 1 FROM public.asignaciones
    GROUP BY proyecto_id,empleado_id,lower(trim(coalesce(puesto,''))),fecha_ini,fecha_fin
    HAVING count(*)>1
  ) THEN
    RAISE EXCEPTION 'Asignaciones duplicadas: resolver antes de crear índice';
  END IF;
END $$;
-- PostgreSQL 15+: NULLS NOT DISTINCT evita duplicados cuando fecha_fin es NULL.
CREATE UNIQUE INDEX IF NOT EXISTS sigral_asignacion_natural_unica
 ON public.asignaciones(proyecto_id,empleado_id,(lower(trim(coalesce(puesto,'')))),fecha_ini,fecha_fin)
 NULLS NOT DISTINCT;
