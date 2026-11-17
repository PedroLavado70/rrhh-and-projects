-- SIGRAL RRHH | PREPRODUCCIÓN — migración manual, NO ejecutar sin respaldo.
-- Requiere PostgreSQL 15+ / Supabase. Ejecutar con rol propietario desde SQL Editor.
-- NO contiene contraseñas ni inserta usuarios ficticios.
-- PASOS PREVIOS: 1) Backup. 2) Crear cuentas en Supabase Auth, confirmar email.
-- 3) Vincular cada public.usuarios.auth_user_id al UUID de auth.users.
-- 4) Auditar accesos y probar en un proyecto de staging.
-- 5) Solo entonces ejecutar la sección de corte transaccional.
-- ¡NO ejecutar esta migración en producción antes de migrar TODOS los usuarios activos!

BEGIN;

ALTER TABLE public.usuarios ADD COLUMN IF NOT EXISTS auth_user_id uuid;
CREATE UNIQUE INDEX IF NOT EXISTS sigral_usuarios_auth_user_id_uidx ON public.usuarios(auth_user_id)
  WHERE auth_user_id IS NOT NULL;

DO $$
BEGIN
  IF EXISTS(SELECT 1 FROM public.usuarios WHERE active IS TRUE AND auth_user_id IS NULL) THEN
    RAISE EXCEPTION 'MIGRACION DETENIDA: hay usuarios activos sin auth_user_id. Vincule Supabase Auth primero.';
  END IF;
  IF EXISTS(SELECT 1 FROM public.usuarios WHERE active IS TRUE AND role NOT IN ('admin','viewer')) THEN
    RAISE EXCEPTION 'MIGRACION DETENIDA: hay roles diferentes de admin/viewer; revisar antes del corte.';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE active IS TRUE AND role='admin' AND auth_user_id IS NOT NULL) THEN
    RAISE EXCEPTION 'MIGRACION DETENIDA: no existe administrador activo vinculado.';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.sigral_is_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT EXISTS(
    SELECT 1 FROM public.usuarios u
     WHERE u.auth_user_id=auth.uid() AND u.active IS TRUE AND u.role='admin'
  );
$$;
REVOKE ALL ON FUNCTION public.sigral_is_admin() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sigral_is_admin() TO authenticated;

CREATE OR REPLACE FUNCTION public.sigral_is_active()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT EXISTS(
    SELECT 1 FROM public.usuarios u
     WHERE u.auth_user_id=auth.uid() AND u.active IS TRUE AND u.role IN ('admin','viewer')
  );
$$;
REVOKE ALL ON FUNCTION public.sigral_is_active() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sigral_is_active() TO authenticated;

-- Directorio sin DNI, salario, datos de contacto ni historial contractual.
CREATE OR REPLACE FUNCTION public.listar_empleados_directorio()
RETURNS TABLE (
  id bigint, codigo text, nombres text, apellidos text,
  profesion text, especialidad text, cargo text, area text, estado text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF NOT public.sigral_is_active() THEN
    RAISE EXCEPTION 'Sin permiso para consultar directorio';
  END IF;
  RETURN QUERY SELECT e.id,e.codigo,e.nombres,e.apellidos,e.profesion,
    e.especialidad,e.cargo,e.area,e.estado FROM public.empleados e ORDER BY e.apellidos,e.nombres;
END $$;
REVOKE ALL ON FUNCTION public.listar_empleados_directorio() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.listar_empleados_directorio() TO authenticated;

ALTER TABLE public.empleados ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.proyectos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asignaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maestras ENABLE ROW LEVEL SECURITY;

-- IMPORTANTE: sustituye TODAS las políticas antiguas, incluidas "allow_all".
-- Revisar políticas ajenas a SIGRAL en el preflight y NO ejecutar si hay integraciones externas.
DO $$
DECLARE p record;
BEGIN
 FOR p IN SELECT schemaname,tablename,policyname FROM pg_policies
   WHERE schemaname='public' AND tablename IN ('empleados','proyectos','asignaciones','usuarios','maestras')
 LOOP
   EXECUTE format('DROP POLICY %I ON public.%I',p.policyname,p.tablename);
 END LOOP;
END $$;

REVOKE ALL ON public.empleados,public.proyectos,public.asignaciones,public.usuarios,public.maestras
  FROM PUBLIC,anon,authenticated;

-- Los administradores gestionan datos personales; los viewers usan RPC de directorio.
GRANT SELECT,INSERT,UPDATE,DELETE ON public.empleados TO authenticated;
CREATE POLICY empleados_admin_select ON public.empleados FOR SELECT TO authenticated
  USING (public.sigral_is_admin());
CREATE POLICY empleados_admin_insert ON public.empleados FOR INSERT TO authenticated
  WITH CHECK (public.sigral_is_admin());
CREATE POLICY empleados_admin_update ON public.empleados FOR UPDATE TO authenticated
  USING (public.sigral_is_admin()) WITH CHECK (public.sigral_is_admin());
CREATE POLICY empleados_admin_delete ON public.empleados FOR DELETE TO authenticated
  USING (public.sigral_is_admin());

GRANT SELECT,INSERT,UPDATE,DELETE ON public.proyectos TO authenticated;
CREATE POLICY proyectos_read ON public.proyectos FOR SELECT TO authenticated
  USING (public.sigral_is_active());
CREATE POLICY proyectos_insert ON public.proyectos FOR INSERT TO authenticated
  WITH CHECK (public.sigral_is_admin());
CREATE POLICY proyectos_update ON public.proyectos FOR UPDATE TO authenticated
  USING (public.sigral_is_admin()) WITH CHECK (public.sigral_is_admin());
CREATE POLICY proyectos_delete ON public.proyectos FOR DELETE TO authenticated
  USING (public.sigral_is_admin());

GRANT SELECT,INSERT,UPDATE,DELETE ON public.asignaciones TO authenticated;
CREATE POLICY asignaciones_read ON public.asignaciones FOR SELECT TO authenticated
  USING (public.sigral_is_active());
CREATE POLICY asignaciones_insert ON public.asignaciones FOR INSERT TO authenticated
  WITH CHECK (public.sigral_is_admin());
CREATE POLICY asignaciones_update ON public.asignaciones FOR UPDATE TO authenticated
  USING (public.sigral_is_admin()) WITH CHECK (public.sigral_is_admin());
CREATE POLICY asignaciones_delete ON public.asignaciones FOR DELETE TO authenticated
  USING (public.sigral_is_admin());

-- Proteger pwd_hash incluso de perfiles autenticados. Solo metadatos de perfil.
GRANT SELECT (id,name,email,role,active,created,auth_user_id) ON public.usuarios TO authenticated;
GRANT UPDATE (name,role,active) ON public.usuarios TO authenticated;
CREATE POLICY usuarios_read ON public.usuarios FOR SELECT TO authenticated
  USING (public.sigral_is_admin() OR (auth_user_id=auth.uid() AND active IS TRUE));
CREATE POLICY usuarios_update_admin ON public.usuarios FOR UPDATE TO authenticated
  USING (public.sigral_is_admin()) WITH CHECK (public.sigral_is_admin());

GRANT SELECT,INSERT,UPDATE,DELETE ON public.maestras TO authenticated;
CREATE POLICY maestras_read ON public.maestras FOR SELECT TO authenticated
  USING (public.sigral_is_active());
CREATE POLICY maestras_insert ON public.maestras FOR INSERT TO authenticated
  WITH CHECK (public.sigral_is_admin());
CREATE POLICY maestras_update ON public.maestras FOR UPDATE TO authenticated
  USING (public.sigral_is_admin()) WITH CHECK (public.sigral_is_admin());
CREATE POLICY maestras_delete ON public.maestras FOR DELETE TO authenticated
  USING (public.sigral_is_admin());

-- RH-001: prohibir vencimiento en indefinidos; revisar registros existentes
-- antes de activar esta restricción (consultar preflight).
-- ALTER TABLE public.empleados ADD CONSTRAINT empleados_indefinido_sin_vencimiento
-- CHECK (tipo_contrato IS DISTINCT FROM 'Indefinido' OR fecha_fin_contrato IS NULL);

COMMIT;
