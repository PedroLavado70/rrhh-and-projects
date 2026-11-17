-- SIGRAL: preparación no destructiva para staging.
-- Requiere ejecutar desde SQL Editor como propietario del esquema.
ALTER TABLE public.usuarios ADD COLUMN IF NOT EXISTS auth_user_id uuid;
CREATE UNIQUE INDEX IF NOT EXISTS sigral_usuarios_auth_user_id_uidx
  ON public.usuarios(auth_user_id) WHERE auth_user_id IS NOT NULL;
-- Mostrar perfiles que aún necesitan vincularse con Supabase Authentication.
SELECT id,email,role,active,auth_user_id
  FROM public.usuarios WHERE active IS TRUE AND auth_user_id IS NULL
  ORDER BY email;
-- Vincular perfiles usando IDs reales obtenidos de Authentication > Users.
-- Ejemplo: UPDATE public.usuarios SET auth_user_id = '<UUID REAL>' WHERE email = '<EMAIL REAL>';
-- No copiar UUID ni credenciales en el repositorio.
