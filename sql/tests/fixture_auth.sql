-- Datos sintéticos, ejecutados SOLO en PostgreSQL efímero de CI.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
GRANT USAGE ON SCHEMA auth TO anon, authenticated;
GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated;

CREATE TABLE public.usuarios(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 name text NOT NULL, email text UNIQUE NOT NULL,
 pwd_hash text NOT NULL, role text NOT NULL DEFAULT 'viewer',
 active boolean NOT NULL DEFAULT true, created date DEFAULT CURRENT_DATE,
 auth_user_id uuid
);
CREATE TABLE public.empleados(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 codigo text UNIQUE NOT NULL,
 nombres text NOT NULL, apellidos text NOT NULL,
 dni text, email text, profesion text, especialidad text,
 cargo text, area text, estado text,
 tipo_contrato text, fecha_fin_contrato date
);
CREATE TABLE public.proyectos (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 codigo text NOT NULL, nombre text NOT NULL
);
CREATE TABLE public.asignaciones(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 proyecto_id bigint NOT NULL REFERENCES public.proyectos(id),
 empleado_id bigint NOT NULL REFERENCES public.empleados(id),
 puesto text, fecha_ini date, fecha_fin date
);
CREATE TABLE public.maestras(tabla text PRIMARY KEY, valores jsonb NOT NULL DEFAULT '[]');

INSERT INTO public.usuarios(name,email,pwd_hash,role,active,auth_user_id) VALUES
('Admin Test','admin@example.invalid','legacy-only','admin',true,'11111111-1111-4111-8111-111111111111'),
('Viewer Test','viewer@example.invalid','legacy-only','viewer',true,'22222222-2222-4222-8222-222222222222'),
('Disabled','disabled@example.invalid','legacy-only','viewer',false,'33333333-3333-4333-8333-333333333333');
INSERT INTO public.empleados(codigo,nombres,apellidos,dni,tipo_contrato,fecha_fin_contrato)
 VALUES ('TEST-01','Ejemplo','Ficticio','00000000','Indefinido',NULL);
INSERT INTO public.proyectos(codigo,nombre) VALUES ('TEST-P','Proyecto ficticio');
INSERT INTO public.asignaciones(proyecto_id,empleado_id,puesto,fecha_ini,fecha_fin)
VALUES (1,1,'Inspector','2026-01-01',NULL);
INSERT INTO public.maestras(tabla,valores) VALUES ('tiposContrato','["Indefinido","Plazo Fijo"]');

ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.empleados ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.proyectos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asignaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maestras ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.usuarios,public.empleados,public.proyectos,public.asignaciones,public.maestras TO anon, authenticated;
CREATE POLICY sigral_allow_all ON public.usuarios FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY sigral_allow_all ON public.empleados FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY sigral_allow_all ON public.proyectos FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY sigral_allow_all ON public.asignaciones FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY sigral_allow_all ON public.maestras FOR ALL TO anon USING (true) WITH CHECK (true);
