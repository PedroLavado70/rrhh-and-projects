-- Pruebas de autorización con SQL y datos exclusivamente ficticios.
DO $$
BEGIN
 IF (SELECT count(*) FROM pg_policies WHERE schemaname='public'
     AND policyname='sigral_allow_all')<>0 THEN
   RAISE EXCEPTION 'Políticas de acceso público todavía activas';
 END IF;
END $$;
SET ROLE anon;
DO $$
BEGIN
 BEGIN
   PERFORM count(*) FROM public.empleados;
   RAISE EXCEPTION 'FAIL: anon pudo leer empleados';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
   PERFORM count(*) FROM public.usuarios;
   RAISE EXCEPTION 'FAIL: anon pudo leer usuarios';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
   PERFORM count(*) FROM public.listar_empleados_directorio();
   RAISE EXCEPTION 'FAIL: anon pudo invocar directorio';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
DO $$
BEGIN
 IF (SELECT count(*) FROM public.empleados)<>1 THEN
   RAISE EXCEPTION 'El admin no puede consultar empleados';
 END IF;
 IF (SELECT count(*) FROM public.usuarios)<>3 THEN
   RAISE EXCEPTION 'El admin no puede consultar perfiles';
 END IF;
 IF (SELECT count(*) FROM public.listar_empleados_directorio())<>1 THEN
   RAISE EXCEPTION 'El admin no puede consultar directorio';
 END IF;
 BEGIN
   PERFORM pwd_hash FROM public.usuarios;
   RAISE EXCEPTION 'FAIL: admin pudo leer pwd_hash';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
DO $$
BEGIN
 IF (SELECT count(*) FROM public.empleados)<>0 THEN
   RAISE EXCEPTION 'FAIL: viewer puede leer empleados privados';
 END IF;
 IF (SELECT count(*) FROM public.proyectos)<>1 THEN
   RAISE EXCEPTION 'Viewer no puede leer proyectos';
 END IF;
 IF (SELECT count(*) FROM public.listar_empleados_directorio())<>1 THEN
   RAISE EXCEPTION 'Viewer no puede consultar directorio seguro';
 END IF;
 IF (SELECT count(*) FROM public.usuarios)<>1 THEN
   RAISE EXCEPTION 'Viewer puede ver otros perfiles';
 END IF;
END $$;
RESET ROLE;
-- Un visor no puede escribir aunque tenga permiso de lectura.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
DO $check_viewer$
DECLARE affected bigint;
BEGIN
  UPDATE public.proyectos SET nombre='Escritura no autorizada' WHERE id=1;
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 0 THEN
    RAISE EXCEPTION 'FAIL: viewer modificó proyecto';
  END IF;
END $check_viewer$;
RESET ROLE;

-- Integridad de contratos y asignaciones: deben fallar cambios inválidos.
DO $check_integrity$
BEGIN
  BEGIN
    UPDATE public.empleados SET fecha_fin_contrato='2026-12-31' WHERE codigo='TEST-01';
    RAISE EXCEPTION 'FAIL: un indefinido aceptó vencimiento';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO public.asignaciones(proyecto_id,empleado_id,puesto,fecha_ini,fecha_fin)
    VALUES (1,1,'Inspector','2026-01-01',NULL);
    RAISE EXCEPTION 'FAIL: asignación duplicada fue aceptada';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
END $check_integrity$;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false);
DO $
DECLARE denied boolean := false;
BEGIN
 IF (SELECT count(*) FROM public.proyectos)<>0 THEN
   RAISE EXCEPTION 'FAIL: usuario desactivado accede a proyectos';
 END IF;
 BEGIN
   PERFORM count(*) FROM public.listar_empleados_directorio();
 EXCEPTION WHEN raise_exception THEN
   denied := true;
 END;
 IF NOT denied THEN
   RAISE EXCEPTION 'FAIL: usuario desactivado accede al directorio';
 END IF;
END $;
RESET ROLE;
