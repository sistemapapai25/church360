DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_account'
  ) THEN
    EXECUTE $sql$
      CREATE OR REPLACE FUNCTION public.jwt_tenant_id()
      RETURNS uuid
      LANGUAGE sql
      STABLE
      SECURITY DEFINER
      SET search_path TO ''
      SET row_security TO off
      AS $f$
        SELECT COALESCE(
          NULLIF(current_setting('app.tenant_id', true), '')::uuid,
          NULLIF((current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'tenant_id')::text, '')::uuid,
          NULLIF((current_setting('request.jwt.claims', true)::jsonb -> 'user_metadata' ->> 'tenant_id')::text, '')::uuid,
          NULLIF((current_setting('request.headers', true)::jsonb ->> 'x-tenant-id')::text, '')::uuid
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
  )
  AND EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'user_account' AND column_name = 'tenant_id'
  ) THEN
    ALTER TABLE public.user_account ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS user_account_insert_own ON public.user_account;
    CREATE POLICY user_account_insert_own
    ON public.user_account
    FOR INSERT
    TO authenticated
    WITH CHECK (
      id = auth.uid()
      AND tenant_id = public.jwt_tenant_id()
    );

    DROP POLICY IF EXISTS user_account_update_own ON public.user_account;
    CREATE POLICY user_account_update_own
    ON public.user_account
    FOR UPDATE
    TO authenticated
    USING (
      id = auth.uid()
      AND tenant_id = public.jwt_tenant_id()
    )
    WITH CHECK (
      id = auth.uid()
      AND tenant_id = public.jwt_tenant_id()
    );
  END IF;
END $$;

