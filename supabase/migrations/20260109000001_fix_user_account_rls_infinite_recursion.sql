DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_account'
  )
  AND EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'user_account' AND column_name = 'tenant_id'
  ) THEN
    EXECUTE $sql$
      CREATE OR REPLACE FUNCTION public.is_elevated_current_user()
      RETURNS boolean
      LANGUAGE plpgsql
      STABLE
      SECURITY DEFINER
      SET search_path TO ''
      SET row_security TO off
      AS $f$
      DECLARE
        uid uuid;
        tid uuid;
        v_role_global text;
        v_has_auth_user_id boolean;
        v_has_role_global boolean;
        v_has_user_access_level boolean;
        v_ual_has_tenant_id boolean;
        v_ual_has_access_level_number boolean;
        v_has_user_roles boolean;
        v_has_has_role_fn boolean;
        v_has_is_admin_or_pastor_fn boolean;
      BEGIN
        uid := auth.uid();
        IF uid IS NULL THEN
          RETURN false;
        END IF;

        tid := public.jwt_tenant_id();
        IF tid IS NULL THEN
          RETURN false;
        END IF;

        SELECT EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'user_account' AND column_name = 'auth_user_id'
        ) INTO v_has_auth_user_id;

        SELECT EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'user_account' AND column_name = 'role_global'
        ) INTO v_has_role_global;

        IF v_has_role_global THEN
          IF v_has_auth_user_id THEN
            SELECT me.role_global
            INTO v_role_global
            FROM public.user_account me
            WHERE me.tenant_id = tid
              AND (me.id = uid OR me.auth_user_id = uid)
            LIMIT 1;
          ELSE
            SELECT me.role_global
            INTO v_role_global
            FROM public.user_account me
            WHERE me.tenant_id = tid
              AND me.id = uid
            LIMIT 1;
          END IF;

          IF v_role_global IN ('owner', 'admin', 'leader') THEN
            RETURN true;
          END IF;
        END IF;

        SELECT EXISTS (
          SELECT 1 FROM information_schema.tables
          WHERE table_schema = 'public' AND table_name = 'user_access_level'
        ) INTO v_has_user_access_level;

        IF v_has_user_access_level THEN
          SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'user_access_level' AND column_name = 'tenant_id'
          ) INTO v_ual_has_tenant_id;

          SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'user_access_level' AND column_name = 'access_level_number'
          ) INTO v_ual_has_access_level_number;

          IF v_ual_has_access_level_number THEN
            IF v_ual_has_tenant_id THEN
              IF EXISTS (
                SELECT 1
                FROM public.user_access_level ual
                WHERE ual.user_id = uid
                  AND ual.tenant_id = tid
                  AND ual.access_level_number >= 5
              ) THEN
                RETURN true;
              END IF;
            ELSE
              IF EXISTS (
                SELECT 1
                FROM public.user_access_level ual
                WHERE ual.user_id = uid
                  AND ual.access_level_number >= 5
              ) THEN
                RETURN true;
              END IF;
            END IF;
          END IF;
        END IF;

        SELECT EXISTS (
          SELECT 1 FROM information_schema.tables
          WHERE table_schema = 'public' AND table_name = 'user_roles'
        ) INTO v_has_user_roles;

        IF v_has_user_roles THEN
          SELECT EXISTS (
            SELECT 1
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public' AND p.proname = 'has_role'
          ) INTO v_has_has_role_fn;

          SELECT EXISTS (
            SELECT 1
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public' AND p.proname = 'is_admin_or_pastor'
          ) INTO v_has_is_admin_or_pastor_fn;

          IF v_has_is_admin_or_pastor_fn THEN
            IF public.is_admin_or_pastor(uid) THEN
              RETURN true;
            END IF;
          END IF;

          IF v_has_has_role_fn THEN
            IF public.has_role(uid, 'admin')
              OR public.has_role(uid, 'pastor')
              OR public.has_role(uid, 'lider')
            THEN
              RETURN true;
            END IF;
          END IF;
        END IF;

        RETURN false;
      END
      $f$;
    $sql$;
  END IF;
END $$;

DO $$
DECLARE
  v_has_user_account boolean;
  v_has_tenant_id boolean;
  v_has_auth_user_id boolean;
  v_self_condition text;
  v_select_condition text;
  v_manage_condition text;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_account'
  ) INTO v_has_user_account;

  IF NOT v_has_user_account THEN
    RETURN;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'user_account' AND column_name = 'tenant_id'
  ) INTO v_has_tenant_id;

  IF NOT v_has_tenant_id THEN
    RETURN;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'user_account' AND column_name = 'auth_user_id'
  ) INTO v_has_auth_user_id;

  v_self_condition := 'id = auth.uid()';
  IF v_has_auth_user_id THEN
    v_self_condition := v_self_condition || ' OR auth_user_id = auth.uid()';
  END IF;

  v_select_condition := 'tenant_id = public.jwt_tenant_id() AND (' || v_self_condition || ' OR public.is_elevated_current_user())';
  v_manage_condition := 'tenant_id = public.jwt_tenant_id() AND (' || v_self_condition || ' OR public.is_elevated_current_user())';

  ALTER TABLE public.user_account ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS tenant_select_user_account ON public.user_account;
  DROP POLICY IF EXISTS tenant_modify_user_account ON public.user_account;
  DROP POLICY IF EXISTS user_account_insert_own ON public.user_account;
  DROP POLICY IF EXISTS user_account_update_own ON public.user_account;
  DROP POLICY IF EXISTS authenticated_can_update_members ON public.user_account;

  DROP POLICY IF EXISTS user_account_select_tenant ON public.user_account;
  DROP POLICY IF EXISTS user_account_insert_tenant ON public.user_account;
  DROP POLICY IF EXISTS user_account_update_tenant ON public.user_account;
  DROP POLICY IF EXISTS user_account_delete_tenant ON public.user_account;

  EXECUTE format(
    $sql$
    CREATE POLICY user_account_select_tenant
    ON public.user_account
    FOR SELECT
    TO authenticated
    USING (%s)
    $sql$,
    v_select_condition
  );

  EXECUTE format(
    $sql$
    CREATE POLICY user_account_insert_tenant
    ON public.user_account
    FOR INSERT
    TO authenticated
    WITH CHECK (%s)
    $sql$,
    v_manage_condition
  );

  EXECUTE format(
    $sql$
    CREATE POLICY user_account_update_tenant
    ON public.user_account
    FOR UPDATE
    TO authenticated
    USING (%s)
    WITH CHECK (%s)
    $sql$,
    v_manage_condition,
    v_manage_condition
  );

  EXECUTE format(
    $sql$
    CREATE POLICY user_account_delete_tenant
    ON public.user_account
    FOR DELETE
    TO authenticated
    USING (%s)
    $sql$,
    v_manage_condition
  );
END $$;
