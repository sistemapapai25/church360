DO $$
DECLARE
  target_funcs text[] := ARRAY[
    'can_access_dashboard',
    'update_updated_at_column',
    'get_user_effective_permissions',
    'get_user_reading_streak',
    'access_level_to_number',
    'check_user_permission'
  ];
  func_name text;
  func_signature text;
BEGIN
  FOREACH func_name IN ARRAY target_funcs
  LOOP
    FOR func_signature IN
      SELECT format('%I.%I(%s)', n.nspname, p.proname, pg_get_function_identity_arguments(p.oid))
      FROM pg_proc p
      JOIN pg_namespace n ON p.pronamespace = n.oid
      WHERE p.proname = func_name
        AND n.nspname = 'public'
    LOOP
      EXECUTE format('ALTER FUNCTION %s SET search_path TO %L', func_signature, '');
    END LOOP;
  END LOOP;
END $$;

