DO $$
DECLARE
  v_has_user_account boolean;
  v_has_tenant_id boolean;
  v_has_auth_user_id boolean;
  v_has_role_global boolean;
  v_has_has_role_fn boolean;
  v_has_is_admin_or_pastor_fn boolean;
  v_self_condition text;
  v_admin_condition text;
  v_can_manage_condition text;
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

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'user_account' AND column_name = 'role_global'
  ) INTO v_has_role_global;

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

  v_self_condition := 'id = auth.uid()';
  IF v_has_auth_user_id THEN
    v_self_condition := v_self_condition || ' OR auth_user_id = auth.uid()';
  END IF;

  v_admin_condition := 'false';
  IF v_has_role_global THEN
    IF v_has_auth_user_id THEN
      v_admin_condition := v_admin_condition || E' OR EXISTS (\n'
        || E'  SELECT 1 FROM public.user_account me\n'
        || E'  WHERE (me.id = auth.uid() OR me.auth_user_id = auth.uid())\n'
        || E'    AND me.tenant_id = public.jwt_tenant_id()\n'
        || E'    AND me.role_global IN (''owner'', ''admin'', ''leader'')\n'
        || E')';
    ELSE
    v_admin_condition := v_admin_condition || E' OR EXISTS (\n'
      || E'  SELECT 1 FROM public.user_account me\n'
      || E'  WHERE me.id = auth.uid()\n'
      || E'    AND me.tenant_id = public.jwt_tenant_id()\n'
      || E'    AND me.role_global IN (''owner'', ''admin'', ''leader'')\n'
      || E')';
    END IF;
  END IF;

  IF v_has_is_admin_or_pastor_fn THEN
    v_admin_condition := v_admin_condition || ' OR public.is_admin_or_pastor(auth.uid())';
  END IF;

  IF v_has_has_role_fn THEN
    v_admin_condition := v_admin_condition
      || ' OR public.has_role(auth.uid(), ''admin'')'
      || ' OR public.has_role(auth.uid(), ''pastor'')'
      || ' OR public.has_role(auth.uid(), ''lider'')';
  END IF;

  v_can_manage_condition := '(' || v_self_condition || ' OR (' || v_admin_condition || '))';

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
    USING (
      tenant_id = public.jwt_tenant_id()
      AND %s
    )
    $sql$,
    v_can_manage_condition
  );

  EXECUTE format(
    $sql$
    CREATE POLICY user_account_insert_tenant
    ON public.user_account
    FOR INSERT
    TO authenticated
    WITH CHECK (
      tenant_id = public.jwt_tenant_id()
      AND %s
    )
    $sql$,
    v_can_manage_condition
  );

  EXECUTE format(
    $sql$
    CREATE POLICY user_account_update_tenant
    ON public.user_account
    FOR UPDATE
    TO authenticated
    USING (
      tenant_id = public.jwt_tenant_id()
      AND %s
    )
    WITH CHECK (
      tenant_id = public.jwt_tenant_id()
      AND %s
    )
    $sql$,
    v_can_manage_condition,
    v_can_manage_condition
  );

  EXECUTE format(
    $sql$
    CREATE POLICY user_account_delete_tenant
    ON public.user_account
    FOR DELETE
    TO authenticated
    USING (
      tenant_id = public.jwt_tenant_id()
      AND %s
    )
    $sql$,
    v_can_manage_condition
  );
END $$;
