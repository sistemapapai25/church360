DO $$
DECLARE
  func_signature text;
BEGIN
  FOR func_signature IN
    SELECT format('%I.%I(%s)', n.nspname, p.proname, pg_get_function_identity_arguments(p.oid))
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'update_worship_attendance_count'
      AND n.nspname = 'public'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path TO %L', func_signature, '');
  END LOOP;
END $$;
