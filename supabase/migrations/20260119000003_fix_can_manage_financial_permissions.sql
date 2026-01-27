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
  v_has_check_permission boolean;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN false;
  END IF;

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

  IF v_tenant_id IS NOT NULL THEN
    PERFORM set_config('app.tenant_id', v_tenant_id::text, true);
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'check_user_permission'
  ) INTO v_has_check_permission;

  IF v_has_check_permission THEN
    BEGIN
      IF public.check_user_permission(p_user_id, 'financial.view')
        OR public.check_user_permission(p_user_id, 'financial.view_reports')
        OR public.check_user_permission(p_user_id, 'financial.create_contribution')
        OR public.check_user_permission(p_user_id, 'financial.create_expense')
        OR public.check_user_permission(p_user_id, 'financial.manage_goals')
        OR public.check_user_permission(p_user_id, 'financial.edit')
        OR public.check_user_permission(p_user_id, 'financial.delete')
        OR public.check_user_permission(p_user_id, 'financial.approve')
        OR public.check_user_permission(p_user_id, 'financial.manage_lancamentos')
        OR public.check_user_permission(p_user_id, 'financial.manage_categories')
        OR public.check_user_permission(p_user_id, 'financial.manage_beneficiaries')
        OR public.check_user_permission(p_user_id, 'financial.manage_accounts')
        OR public.check_user_permission(p_user_id, 'financial.import_extrato')
        OR public.check_user_permission(p_user_id, 'financial.manage_cultos')
        OR public.check_user_permission(p_user_id, 'financial.manage_desafios')
        OR public.check_user_permission(p_user_id, 'financial.manage_mensagens')
      THEN
        RETURN true;
      END IF;
    EXCEPTION
      WHEN undefined_function THEN
        NULL;
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
