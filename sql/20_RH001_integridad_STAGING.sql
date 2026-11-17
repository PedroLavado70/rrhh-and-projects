-- RH-001 — aplicar en STAGING únicamente, después de revisar preflight.
-- Evita guardar fecha de vencimiento en contratos indefinidos.
BEGIN;
DO $$
BEGIN
  IF EXISTS(
    SELECT 1 FROM public.empleados
    WHERE lower(trim(coalesce(tipo_contrato,'')))='indefinido'
      AND fecha_fin_contrato IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'RH-001: existen contratos indefinidos con fecha de fin. Conciliar antes de agregar restricción.';
  END IF;
END $$;
ALTER TABLE public.empleados DROP CONSTRAINT IF EXISTS empleados_indefinidos_sin_vencimiento;
ALTER TABLE public.empleados
  ADD CONSTRAINT empleados_indefinidos_sin_vencimiento
  CHECK (lower(trim(coalesce(tipo_contrato,''))) <> 'indefinido' OR fecha_fin_contrato IS NULL);
COMMIT;

-- Solo si la prevalidación de duplicados por DNI arroja cero:
-- CREATE UNIQUE INDEX IF NOT EXISTS sigral_empleados_dni_unico
-- ON public.empleados ((trim(dni))) WHERE dni IS NOT NULL AND trim(dni)<>'';
-- No eliminar ni fusionar trabajadores automáticamente para satisfacer este índice.
