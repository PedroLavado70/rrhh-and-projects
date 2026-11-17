-- Paso FINAL, posterior al corte a Supabase Auth, únicamente con respaldo y aprobación.
-- Ejecutar primero en staging después de que todos los usuarios hayan probado acceso.
-- Este cambio es destructivo: elimina el almacenamiento heredado de contraseñas.
BEGIN;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.usuarios
             WHERE active IS TRUE AND auth_user_id IS NULL)
  THEN
    RAISE EXCEPTION 'No se puede retirar pwd_hash: existen perfiles activos sin Auth';
  END IF;
END $$;
ALTER TABLE public.usuarios DROP COLUMN IF EXISTS pwd_hash;
COMMIT;
-- Recomendar rotación de cualquier contraseña heredada, especialmente si se reutiliza.
