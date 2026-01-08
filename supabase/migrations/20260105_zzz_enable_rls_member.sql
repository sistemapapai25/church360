DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'member'
  ) THEN
    ALTER TABLE public.member ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS member_select_admin ON public.member;
    DROP POLICY IF EXISTS member_insert_admin ON public.member;
    DROP POLICY IF EXISTS member_update_admin ON public.member;
    DROP POLICY IF EXISTS member_delete_admin ON public.member;

    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'member' AND column_name = 'tenant_id'
    ) THEN
      CREATE POLICY member_select_admin
      ON public.member
      FOR SELECT
      TO authenticated
      USING (
        tenant_id = public.current_tenant_id()
        AND EXISTS (
          SELECT 1
          FROM public.user_access_level ual
          WHERE ual.user_id = auth.uid()
            AND ual.tenant_id = public.current_tenant_id()
            AND ual.access_level_number >= 5
        )
      );

      CREATE POLICY member_insert_admin
      ON public.member
      FOR INSERT
      TO authenticated
      WITH CHECK (
        tenant_id = public.current_tenant_id()
        AND EXISTS (
          SELECT 1
          FROM public.user_access_level ual
          WHERE ual.user_id = auth.uid()
            AND ual.tenant_id = public.current_tenant_id()
            AND ual.access_level_number >= 5
        )
      );

      CREATE POLICY member_update_admin
      ON public.member
      FOR UPDATE
      TO authenticated
      USING (
        tenant_id = public.current_tenant_id()
        AND EXISTS (
          SELECT 1
          FROM public.user_access_level ual
          WHERE ual.user_id = auth.uid()
            AND ual.tenant_id = public.current_tenant_id()
            AND ual.access_level_number >= 5
        )
      )
      WITH CHECK (tenant_id = public.current_tenant_id());

      CREATE POLICY member_delete_admin
      ON public.member
      FOR DELETE
      TO authenticated
      USING (
        tenant_id = public.current_tenant_id()
        AND EXISTS (
          SELECT 1
          FROM public.user_access_level ual
          WHERE ual.user_id = auth.uid()
            AND ual.tenant_id = public.current_tenant_id()
            AND ual.access_level_number >= 5
        )
      );
    ELSE
      CREATE POLICY member_select_admin
      ON public.member
      FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1
          FROM public.user_access_level ual
          WHERE ual.user_id = auth.uid()
            AND ual.tenant_id = public.current_tenant_id()
            AND ual.access_level_number >= 5
        )
      );

      CREATE POLICY member_insert_admin
      ON public.member
      FOR INSERT
      TO authenticated
      WITH CHECK (
        EXISTS (
          SELECT 1
          FROM public.user_access_level ual
          WHERE ual.user_id = auth.uid()
            AND ual.tenant_id = public.current_tenant_id()
            AND ual.access_level_number >= 5
        )
      );

      CREATE POLICY member_update_admin
      ON public.member
      FOR UPDATE
      TO authenticated
      USING (
        EXISTS (
          SELECT 1
          FROM public.user_access_level ual
          WHERE ual.user_id = auth.uid()
            AND ual.tenant_id = public.current_tenant_id()
            AND ual.access_level_number >= 5
        )
      )
      WITH CHECK (true);

      CREATE POLICY member_delete_admin
      ON public.member
      FOR DELETE
      TO authenticated
      USING (
        EXISTS (
          SELECT 1
          FROM public.user_access_level ual
          WHERE ual.user_id = auth.uid()
            AND ual.tenant_id = public.current_tenant_id()
            AND ual.access_level_number >= 5
        )
      );
    END IF;
  END IF;
END $$;

