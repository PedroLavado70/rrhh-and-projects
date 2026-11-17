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
  -- Para la primera etapa de uso individual se exige vinculación del administrador.
  -- Los perfiles viewer sin Auth permanecerán sin acceso, sin modificar ni borrar registros.
  IF EXISTS(SELECT 1 FROM public.usuarios WHERE active IS TRUE AND role='admin' AND auth_user_id IS NULL) THEN
    RAISE EXCEPTION 'MIGRACION DETENIDA: el administrador activo no está vinculado a Supabase Auth.';
  END IF;
  IF EXISTS(SELECT 1 FROM public.usuarios WHERE active IS TRUE AND role NOT IN ('admin','viewer')) THEN
    RAISE EXCEPTION 'MIGRACION DETENIDA: hay roles diferentes de admin/viewer; revisar antes del corte.';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE active IS TRUE AND role='admin' AND auth_user_id IS NOT NULL) THEN
    RAISE EXCEPTION 'MIGRACION DETENIDA: no existe administrador activo vinculado.';
  END IF;
END $$;

-- Las funciones con privilegios elevados viven en un esquema NO expuesto por la API.
CREATE SCHEMA IF NOT EXISTS sigral_private;
REVOKE ALL ON SCHEMA sigral_private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA sigral_private TO authenticated;

CREATE OR REPLACE FUNCTION sigral_private.is_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.usuarios u
    WHERE u.auth_user_id = auth.uid()
      AND u.active IS TRUE AND u.role='admin'
  );
$$;
REVOKE ALL ON FUNCTION sigral_private.is_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION sigral_private.is_admin() TO authenticated;

CREATE OR REPLACE FUNCTION sigral_private.is_active()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.usuarios u
    WHERE u.auth_user_id = auth.uid()
      AND u.active IS TRUE AND u.role IN ('admin','viewer')
  );
$$;
REVOKE ALL ON FUNCTION sigral_private.is_active() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION sigral_private.is_active() TO authenticated;

-- Función interna privilegiada: devuelve únicamente atributos laborales permitidos.
CREATE OR REPLACE FUNCTION sigral_private.empleados_directorio()
RETURNS TABLE (
  id bigint, codigo text, nombres text, apellidos text,
  profesion text, especialidad text, cargo text, area text, estado text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF NOT sigral_private.is_active() THEN
    RAISE EXCEPTION 'Acceso denegado al directorio';
  END IF;
  RETURN QUERY SELECT e.id,e.codigo,e.nombres,e.apellidos,e.profesion,
    e.especialidad,e.cargo,e.area,e.estado
    FROM public.empleados e ORDER BY e.apellidos,e.nombres;
END $$;
REVOKE ALL ON FUNCTION sigral_private.empleados_directorio() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION sigral_private.empleados_directorio() TO authenticated;

-- RPC público sin elevación de privilegios: delega a función interna auditada.
CREATE OR REPLACE FUNCTION public.listar_empleados_directorio()
RETURNS TABLE (
  id bigint, codigo text, nombres text, apellidos text,
  profesion text, especialidad text, cargo text, area text, estado text
)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
  SELECT * FROM sigral_private.empleados_directorio();
$$;
REVOKE ALL ON FUNCTION public.listar_empleados_directorio() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.listar_empleados_directorio() TO authenticated;

ALTER TABLE public.empleados ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.proyectos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asignaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maestras ENABLE ROW LEVEL SECURITY;

-- Precondición: exactamente una política heredada por tabla, sin políticas desconocidas.
-- Nunca borrar indiscriminadamente políticas que no han sido auditadas.
DO $$
DECLARE v_count int;
BEGIN
  SELECT count(*) INTO v_count FROM pg_policies
  WHERE schemaname='public'
    AND tablename IN ('empleados','proyectos','asignaciones','usuarios','maestras')
    AND policyname='sigral_allow_all'
    AND cmd='ALL' AND roles::text LIKE '%anon%';
  IF v_count <> 5 THEN
    RAISE EXCEPTION 'CORTE CANCELADO: se esperaban cinco políticas sigral_allow_all (anon), hay %',v_count;
  END IF;
  IF EXISTS(
    SELECT 1 FROM pg_policies
    WHERE schemaname='public'
      AND tablename IN ('empleados','proyectos','asignaciones','usuarios','maestras')
      AND policyname<>'sigral_allow_all'
  ) THEN
    RAISE EXCEPTION 'CORTE CANCELADO: existen otras políticas. Requiere auditoría.';
  END IF;
END $$;
DROP POLICY sigral_allow_all ON public.empleados;
DROP POLICY sigral_allow_all ON public.proyectos;
DROP POLICY sigral_allow_all ON public.asignaciones;
DROP POLICY sigral_allow_all ON public.usuarios;
DROP POLICY sigral_allow_all ON public.maestras;

REVOKE ALL ON public.empleados,public.proyectos,public.asignaciones,public.usuarios,public.maestras
  FROM PUBLIC,anon,authenticated;

-- Los administradores gestionan datos personales; los viewers usan RPC de directorio.
GRANT SELECT,INSERT,UPDATE,DELETE ON public.empleados TO authenticated;
CREATE POLICY empleados_admin_select ON public.empleados FOR SELECT TO authenticated
  USING (sigral_private.is_admin());
CREATE POLICY empleados_admin_insert ON public.empleados FOR INSERT TO authenticated
  WITH CHECK (sigral_private.is_admin());
CREATE POLICY empleados_admin_update ON public.empleados FOR UPDATE TO authenticated
  USING (sigral_private.is_admin()) WITH CHECK (sigral_private.is_admin());
CREATE POLICY empleados_admin_delete ON public.empleados FOR DELETE TO authenticated
  USING (sigral_private.is_admin());

GRANT SELECT,INSERT,UPDATE,DELETE ON public.proyectos TO authenticated;
CREATE POLICY proyectos_read ON public.proyectos FOR SELECT TO authenticated
  USING (sigral_private.is_active());
CREATE POLICY proyectos_insert ON public.proyectos FOR INSERT TO authenticated
  WITH CHECK (sigral_private.is_admin());
CREATE POLICY proyectos_update ON public.proyectos FOR UPDATE TO authenticated
  USING (sigral_private.is_admin()) WITH CHECK (sigral_private.is_admin());
CREATE POLICY proyectos_delete ON public.proyectos FOR DELETE TO authenticated
  USING (sigral_private.is_admin());

GRANT SELECT,INSERT,UPDATE,DELETE ON public.asignaciones TO authenticated;
CREATE POLICY asignaciones_read ON public.asignaciones FOR SELECT TO authenticated
  USING (sigral_private.is_active());
CREATE POLICY asignaciones_insert ON public.asignaciones FOR INSERT TO authenticated
  WITH CHECK (sigral_private.is_admin());
CREATE POLICY asignaciones_update ON public.asignaciones FOR UPDATE TO authenticated
  USING (sigral_private.is_admin()) WITH CHECK (sigral_private.is_admin());
CREATE POLICY asignaciones_delete ON public.asignaciones FOR DELETE TO authenticated
  USING (sigral_private.is_admin());

-- Proteger pwd_hash incluso de perfiles autenticados. Solo metadatos de perfil.
GRANT SELECT (id,name,email,role,active,created,auth_user_id) ON public.usuarios TO authenticated;
GRANT UPDATE (name,role,active) ON public.usuarios TO authenticated;
CREATE POLICY usuarios_read ON public.usuarios FOR SELECT TO authenticated
  USING (sigral_private.is_admin() OR (auth_user_id=auth.uid() AND active IS TRUE));
CREATE POLICY usuarios_update_admin ON public.usuarios FOR UPDATE TO authenticated
  USING (sigral_private.is_admin()) WITH CHECK (sigral_private.is_admin());

GRANT SELECT,INSERT,UPDATE,DELETE ON public.maestras TO authenticated;
CREATE POLICY maestras_read ON public.maestras FOR SELECT TO authenticated
  USING (sigral_private.is_active());
CREATE POLICY maestras_insert ON public.maestras FOR INSERT TO authenticated
  WITH CHECK (sigral_private.is_admin());
CREATE POLICY maestras_update ON public.maestras FOR UPDATE TO authenticated
  USING (sigral_private.is_admin()) WITH CHECK (sigral_private.is_admin());
CREATE POLICY maestras_delete ON public.maestras FOR DELETE TO authenticated
  USING (sigral_private.is_admin());

-- RH-001: prohibir vencimiento en indefinidos; revisar registros existentes
-- antes de activar esta restricción (consultar preflight).
-- ALTER TABLE public.empleados ADD CONSTRAINT empleados_indefinido_sin_vencimiento
-- CHECK (tipo_contrato IS DISTINCT FROM 'Indefinido' OR fecha_fin_contrato IS NULL);

COMMIT;
