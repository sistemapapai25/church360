DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_account'
  ) THEN
    EXECUTE $sql$
      CREATE OR REPLACE FUNCTION public.current_tenant_id()
      RETURNS uuid
      LANGUAGE sql
      STABLE
      SECURITY DEFINER
      SET search_path TO ''
      SET row_security TO off
      AS $f$
        SELECT COALESCE(
          (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'tenant_id')::uuid,
          (current_setting('request.jwt.claims', true)::jsonb -> 'user_metadata' ->> 'tenant_id')::uuid,
          (SELECT ua.tenant_id FROM public.user_account ua WHERE ua.id = auth.uid() LIMIT 1)
        )
      $f$;
    $sql$;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_account'
  ) THEN
    ALTER TABLE public.user_account ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS tenant_select_user_account ON public.user_account;
    DROP POLICY IF EXISTS tenant_modify_user_account ON public.user_account;
    DROP POLICY IF EXISTS user_account_select_tenant ON public.user_account;
    DROP POLICY IF EXISTS user_account_insert_own ON public.user_account;
    DROP POLICY IF EXISTS user_account_update_own ON public.user_account;

    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'user_account' AND column_name = 'tenant_id'
    ) THEN
      CREATE POLICY user_account_select_tenant
      ON public.user_account
      FOR SELECT
      TO authenticated
      USING (
        id = auth.uid()
        OR tenant_id = public.current_tenant_id()
      );
    ELSE
      CREATE POLICY user_account_select_tenant
      ON public.user_account
      FOR SELECT
      TO authenticated
      USING (true);
    END IF;

    CREATE POLICY user_account_insert_own
    ON public.user_account
    FOR INSERT
    TO authenticated
    WITH CHECK (id = auth.uid());

    CREATE POLICY user_account_update_own
    ON public.user_account
    FOR UPDATE
    TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_access_level'
  ) THEN
    ALTER TABLE public.user_access_level ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Users can view all access levels" ON public.user_access_level;
    DROP POLICY IF EXISTS "Users can create access levels" ON public.user_access_level;
    DROP POLICY IF EXISTS "Only admins can create access levels" ON public.user_access_level;
    DROP POLICY IF EXISTS "Only admins can update access levels" ON public.user_access_level;
    DROP POLICY IF EXISTS "Only admins can delete access levels" ON public.user_access_level;
    DROP POLICY IF EXISTS user_access_level_select ON public.user_access_level;
    DROP POLICY IF EXISTS user_access_level_insert_self_visitor ON public.user_access_level;

    CREATE POLICY user_access_level_select
    ON public.user_access_level
    FOR SELECT
    TO authenticated
    USING (true);

    CREATE POLICY user_access_level_insert_self_visitor
    ON public.user_access_level
    FOR INSERT
    TO authenticated
    WITH CHECK (
      user_id = auth.uid()
      AND access_level = 'visitor'
      AND access_level_number = 0
    );
  END IF;
END $$;

