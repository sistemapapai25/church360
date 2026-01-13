DO $$
DECLARE
  v_has_utm boolean;
  v_has_ual boolean;
  v_ual_has_tenant boolean;
BEGIN
  SELECT (to_regclass('public.user_tenant_membership') IS NOT NULL) INTO v_has_utm;
  SELECT (to_regclass('public.user_access_level') IS NOT NULL) INTO v_has_ual;
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'user_access_level'
      AND column_name = 'tenant_id'
  ) INTO v_ual_has_tenant;

  IF to_regclass('public.integration_settings') IS NOT NULL THEN
    ALTER TABLE public.integration_settings ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS tenant_select_integration_settings ON public.integration_settings;
    DROP POLICY IF EXISTS tenant_modify_integration_settings ON public.integration_settings;

    IF v_has_utm THEN
      EXECUTE $ddl$
        CREATE POLICY tenant_select_integration_settings
        ON public.integration_settings
        FOR SELECT
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_tenant_membership utm
            WHERE utm.user_id = auth.uid()
              AND utm.tenant_id = tenant_id
              AND utm.is_active = true
              AND utm.access_level_number >= 4
          )
        );

        CREATE POLICY tenant_modify_integration_settings
        ON public.integration_settings
        FOR ALL
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_tenant_membership utm
            WHERE utm.user_id = auth.uid()
              AND utm.tenant_id = tenant_id
              AND utm.is_active = true
              AND utm.access_level_number >= 4
          )
        )
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_tenant_membership utm
            WHERE utm.user_id = auth.uid()
              AND utm.tenant_id = tenant_id
              AND utm.is_active = true
              AND utm.access_level_number >= 4
          )
        );
      $ddl$;
    ELSIF v_has_ual AND v_ual_has_tenant THEN
      EXECUTE $ddl$
        CREATE POLICY tenant_select_integration_settings
        ON public.integration_settings
        FOR SELECT
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = tenant_id
              AND ual.access_level_number >= 4
          )
        );

        CREATE POLICY tenant_modify_integration_settings
        ON public.integration_settings
        FOR ALL
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = tenant_id
              AND ual.access_level_number >= 4
          )
        )
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = tenant_id
              AND ual.access_level_number >= 4
          )
        );
      $ddl$;
    ELSE
      EXECUTE $ddl$
        CREATE POLICY tenant_select_integration_settings
        ON public.integration_settings
        FOR SELECT
        TO authenticated
        USING (false);

        CREATE POLICY tenant_modify_integration_settings
        ON public.integration_settings
        FOR ALL
        TO authenticated
        USING (false)
        WITH CHECK (false);
      $ddl$;
    END IF;
  END IF;

  IF to_regclass('public.message_template') IS NOT NULL THEN
    ALTER TABLE public.message_template ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS tenant_select_message_template ON public.message_template;
    DROP POLICY IF EXISTS tenant_modify_message_template ON public.message_template;

    IF v_has_utm THEN
      EXECUTE $ddl$
        CREATE POLICY tenant_select_message_template
        ON public.message_template
        FOR SELECT
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_tenant_membership utm
            WHERE utm.user_id = auth.uid()
              AND utm.tenant_id = tenant_id
              AND utm.is_active = true
              AND utm.access_level_number >= 4
          )
        );

        CREATE POLICY tenant_modify_message_template
        ON public.message_template
        FOR ALL
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_tenant_membership utm
            WHERE utm.user_id = auth.uid()
              AND utm.tenant_id = tenant_id
              AND utm.is_active = true
              AND utm.access_level_number >= 4
          )
        )
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_tenant_membership utm
            WHERE utm.user_id = auth.uid()
              AND utm.tenant_id = tenant_id
              AND utm.is_active = true
              AND utm.access_level_number >= 4
          )
        );
      $ddl$;
    ELSIF v_has_ual AND v_ual_has_tenant THEN
      EXECUTE $ddl$
        CREATE POLICY tenant_select_message_template
        ON public.message_template
        FOR SELECT
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = tenant_id
              AND ual.access_level_number >= 4
          )
        );

        CREATE POLICY tenant_modify_message_template
        ON public.message_template
        FOR ALL
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = tenant_id
              AND ual.access_level_number >= 4
          )
        )
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = tenant_id
              AND ual.access_level_number >= 4
          )
        );
      $ddl$;
    ELSE
      EXECUTE $ddl$
        CREATE POLICY tenant_select_message_template
        ON public.message_template
        FOR SELECT
        TO authenticated
        USING (false);

        CREATE POLICY tenant_modify_message_template
        ON public.message_template
        FOR ALL
        TO authenticated
        USING (false)
        WITH CHECK (false);
      $ddl$;
    END IF;
  END IF;

  IF to_regclass('public.dispatch_rule') IS NOT NULL THEN
    ALTER TABLE public.dispatch_rule ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS tenant_select_dispatch_rule ON public.dispatch_rule;
    DROP POLICY IF EXISTS tenant_modify_dispatch_rule ON public.dispatch_rule;

    IF v_has_utm THEN
      EXECUTE $ddl$
        CREATE POLICY tenant_select_dispatch_rule
        ON public.dispatch_rule
        FOR SELECT
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_tenant_membership utm
            WHERE utm.user_id = auth.uid()
              AND utm.tenant_id = tenant_id
              AND utm.is_active = true
              AND utm.access_level_number >= 4
          )
        );

        CREATE POLICY tenant_modify_dispatch_rule
        ON public.dispatch_rule
        FOR ALL
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_tenant_membership utm
            WHERE utm.user_id = auth.uid()
              AND utm.tenant_id = tenant_id
              AND utm.is_active = true
              AND utm.access_level_number >= 4
          )
        )
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_tenant_membership utm
            WHERE utm.user_id = auth.uid()
              AND utm.tenant_id = tenant_id
              AND utm.is_active = true
              AND utm.access_level_number >= 4
          )
        );
      $ddl$;
    ELSIF v_has_ual AND v_ual_has_tenant THEN
      EXECUTE $ddl$
        CREATE POLICY tenant_select_dispatch_rule
        ON public.dispatch_rule
        FOR SELECT
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = tenant_id
              AND ual.access_level_number >= 4
          )
        );

        CREATE POLICY tenant_modify_dispatch_rule
        ON public.dispatch_rule
        FOR ALL
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = tenant_id
              AND ual.access_level_number >= 4
          )
        )
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = tenant_id
              AND ual.access_level_number >= 4
          )
        );
      $ddl$;
    ELSE
      EXECUTE $ddl$
        CREATE POLICY tenant_select_dispatch_rule
        ON public.dispatch_rule
        FOR SELECT
        TO authenticated
        USING (false);

        CREATE POLICY tenant_modify_dispatch_rule
        ON public.dispatch_rule
        FOR ALL
        TO authenticated
        USING (false)
        WITH CHECK (false);
      $ddl$;
    END IF;
  END IF;

  IF to_regclass('public.dispatch_job') IS NOT NULL THEN
    ALTER TABLE public.dispatch_job ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS dispatch_job_insert_all ON public.dispatch_job;
    DROP POLICY IF EXISTS tenant_select_dispatch_job ON public.dispatch_job;
    DROP POLICY IF EXISTS tenant_modify_dispatch_job ON public.dispatch_job;

    IF v_has_utm THEN
      EXECUTE $ddl$
        CREATE POLICY tenant_select_dispatch_job
        ON public.dispatch_job
        FOR SELECT
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_tenant_membership utm
            WHERE utm.user_id = auth.uid()
              AND utm.tenant_id = tenant_id
              AND utm.is_active = true
              AND utm.access_level_number >= 4
          )
        );

        CREATE POLICY tenant_modify_dispatch_job
        ON public.dispatch_job
        FOR ALL
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_tenant_membership utm
            WHERE utm.user_id = auth.uid()
              AND utm.tenant_id = tenant_id
              AND utm.is_active = true
              AND utm.access_level_number >= 4
          )
        )
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_tenant_membership utm
            WHERE utm.user_id = auth.uid()
              AND utm.tenant_id = tenant_id
              AND utm.is_active = true
              AND utm.access_level_number >= 4
          )
        );
      $ddl$;
    ELSIF v_has_ual AND v_ual_has_tenant THEN
      EXECUTE $ddl$
        CREATE POLICY tenant_select_dispatch_job
        ON public.dispatch_job
        FOR SELECT
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = tenant_id
              AND ual.access_level_number >= 4
          )
        );

        CREATE POLICY tenant_modify_dispatch_job
        ON public.dispatch_job
        FOR ALL
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = tenant_id
              AND ual.access_level_number >= 4
          )
        )
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = tenant_id
              AND ual.access_level_number >= 4
          )
        );
      $ddl$;
    ELSE
      EXECUTE $ddl$
        CREATE POLICY tenant_select_dispatch_job
        ON public.dispatch_job
        FOR SELECT
        TO authenticated
        USING (false);

        CREATE POLICY tenant_modify_dispatch_job
        ON public.dispatch_job
        FOR ALL
        TO authenticated
        USING (false)
        WITH CHECK (false);
      $ddl$;
    END IF;
  END IF;

  IF to_regclass('public.whatsapp_relatorios_automaticos') IS NOT NULL THEN
    ALTER TABLE public.whatsapp_relatorios_automaticos ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS tenant_select_whatsapp_relatorios_automaticos ON public.whatsapp_relatorios_automaticos;
    DROP POLICY IF EXISTS tenant_modify_whatsapp_relatorios_automaticos ON public.whatsapp_relatorios_automaticos;

    IF v_has_utm THEN
      EXECUTE $ddl$
        CREATE POLICY tenant_select_whatsapp_relatorios_automaticos
        ON public.whatsapp_relatorios_automaticos
        FOR SELECT
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_tenant_membership utm
            WHERE utm.user_id = auth.uid()
              AND utm.tenant_id = tenant_id
              AND utm.is_active = true
              AND utm.access_level_number >= 4
          )
        );

        CREATE POLICY tenant_modify_whatsapp_relatorios_automaticos
        ON public.whatsapp_relatorios_automaticos
        FOR ALL
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_tenant_membership utm
            WHERE utm.user_id = auth.uid()
              AND utm.tenant_id = tenant_id
              AND utm.is_active = true
              AND utm.access_level_number >= 4
          )
        )
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_tenant_membership utm
            WHERE utm.user_id = auth.uid()
              AND utm.tenant_id = tenant_id
              AND utm.is_active = true
              AND utm.access_level_number >= 4
          )
        );
      $ddl$;
    ELSIF v_has_ual AND v_ual_has_tenant THEN
      EXECUTE $ddl$
        CREATE POLICY tenant_select_whatsapp_relatorios_automaticos
        ON public.whatsapp_relatorios_automaticos
        FOR SELECT
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = tenant_id
              AND ual.access_level_number >= 4
          )
        );

        CREATE POLICY tenant_modify_whatsapp_relatorios_automaticos
        ON public.whatsapp_relatorios_automaticos
        FOR ALL
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = tenant_id
              AND ual.access_level_number >= 4
          )
        )
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = tenant_id
              AND ual.access_level_number >= 4
          )
        );
      $ddl$;
    ELSE
      EXECUTE $ddl$
        CREATE POLICY tenant_select_whatsapp_relatorios_automaticos
        ON public.whatsapp_relatorios_automaticos
        FOR SELECT
        TO authenticated
        USING (false);

        CREATE POLICY tenant_modify_whatsapp_relatorios_automaticos
        ON public.whatsapp_relatorios_automaticos
        FOR ALL
        TO authenticated
        USING (false)
        WITH CHECK (false);
      $ddl$;
    END IF;
  END IF;
END $$;

