CREATE OR REPLACE FUNCTION public.can_manage_financial(p_user_id uuid, p_tenant_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_allowed boolean;
  v_tenant_id uuid;
  v_has_user_access_level_tenant_id boolean;
BEGIN
  v_tenant_id := p_tenant_id;
  IF v_tenant_id IS NULL THEN
    BEGIN
      v_tenant_id := public.current_tenant_id();
    EXCEPTION
      WHEN undefined_function THEN
        v_tenant_id := NULL;
      WHEN OTHERS THEN
        v_tenant_id := NULL;
    END;
  END IF;

  IF to_regclass('public.user_tenant_membership') IS NOT NULL AND v_tenant_id IS NOT NULL THEN
    EXECUTE
      'SELECT EXISTS (
         SELECT 1
         FROM public.user_tenant_membership utm
         WHERE utm.user_id = $1
           AND utm.tenant_id = $2
           AND utm.is_active = true
           AND utm.access_level_number >= 4
       )'
    INTO v_allowed
    USING p_user_id, v_tenant_id;
    RETURN COALESCE(v_allowed, false);
  END IF;

  IF to_regclass('public.user_access_level') IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'user_access_level'
        AND column_name = 'tenant_id'
    ) INTO v_has_user_access_level_tenant_id;

    IF v_has_user_access_level_tenant_id AND v_tenant_id IS NOT NULL THEN
      EXECUTE
        'SELECT EXISTS (
           SELECT 1
           FROM public.user_access_level ual
           WHERE ual.user_id = $1
             AND ual.tenant_id = $2
             AND ual.access_level_number >= 4
         )'
      INTO v_allowed
      USING p_user_id, v_tenant_id;
      RETURN COALESCE(v_allowed, false);
    END IF;

    EXECUTE
      'SELECT EXISTS (
         SELECT 1
         FROM public.user_access_level ual
         WHERE ual.user_id = $1
           AND ual.access_level_number >= 4
       )'
    INTO v_allowed
    USING p_user_id;
    RETURN COALESCE(v_allowed, false);
  END IF;

  RETURN false;
END;
$function$;
