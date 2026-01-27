DO $$
DECLARE
  v_has_jwt_tenant boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'jwt_tenant_id'
  ) INTO v_has_jwt_tenant;

  IF v_has_jwt_tenant THEN
    EXECUTE $sql$
      CREATE OR REPLACE FUNCTION public.current_tenant_id()
      RETURNS uuid
      LANGUAGE sql
      STABLE
      SECURITY DEFINER
      SET search_path TO ''
      AS $f$
        SELECT COALESCE(
          public.jwt_tenant_id(),
          (SELECT ua.tenant_id FROM public.user_account ua WHERE ua.auth_user_id = auth.uid() LIMIT 1),
          (SELECT ua.tenant_id FROM public.user_account ua WHERE ua.id = auth.uid() LIMIT 1)
        )
      $f$;
    $sql$;
  ELSE
    EXECUTE $sql$
      CREATE OR REPLACE FUNCTION public.current_tenant_id()
      RETURNS uuid
      LANGUAGE sql
      STABLE
      SECURITY DEFINER
      SET search_path TO ''
      AS $f$
        SELECT COALESCE(
          (SELECT ua.tenant_id FROM public.user_account ua WHERE ua.auth_user_id = auth.uid() LIMIT 1),
          (SELECT ua.tenant_id FROM public.user_account ua WHERE ua.id = auth.uid() LIMIT 1)
        )
      $f$;
    $sql$;
  END IF;
END $$;
