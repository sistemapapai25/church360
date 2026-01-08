DO $$
DECLARE
  p record;
BEGIN
  IF to_regclass('public.course_lesson') IS NOT NULL THEN
    ALTER TABLE public.course_lesson ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Permitir atualização para usuários autenticados" ON public.course_lesson;
    DROP POLICY IF EXISTS "Permitir exclusão para usuários autenticados" ON public.course_lesson;
    DROP POLICY IF EXISTS "Permitir inserção para usuários autenticados" ON public.course_lesson;

    FOR p IN
      SELECT schemaname, tablename, policyname
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'course_lesson'
        AND cmd IN ('INSERT', 'UPDATE', 'DELETE')
        AND (
          COALESCE(qual, '') ~* '^\s*true\s*$'
          OR COALESCE(with_check, '') ~* '^\s*true\s*$'
        )
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', p.policyname, p.schemaname, p.tablename);
    END LOOP;
  END IF;
END $$;

DO $$
DECLARE
  p record;
  v_has_utm boolean;
  v_has_ual boolean;
  v_ual_has_tenant boolean;
BEGIN
  IF to_regclass('public.notifications') IS NOT NULL THEN
    ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Sistema pode criar notificações" ON public.notifications;

    FOR p IN
      SELECT schemaname, tablename, policyname
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'notifications'
        AND cmd IN ('INSERT', 'UPDATE', 'DELETE')
        AND (
          COALESCE(qual, '') ~* '^\s*true\s*$'
          OR COALESCE(with_check, '') ~* '^\s*true\s*$'
        )
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', p.policyname, p.schemaname, p.tablename);
    END LOOP;

    DROP POLICY IF EXISTS tenant_select_notifications ON public.notifications;
    DROP POLICY IF EXISTS tenant_insert_notifications_self ON public.notifications;
    DROP POLICY IF EXISTS tenant_update_notifications_self ON public.notifications;
    DROP POLICY IF EXISTS tenant_delete_notifications_self ON public.notifications;

    SELECT (to_regclass('public.user_tenant_membership') IS NOT NULL) INTO v_has_utm;
    SELECT (to_regclass('public.user_access_level') IS NOT NULL) INTO v_has_ual;
    SELECT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'user_access_level'
        AND column_name = 'tenant_id'
    ) INTO v_ual_has_tenant;

    IF v_has_utm THEN
      EXECUTE $ddl$
        CREATE POLICY tenant_select_notifications
        ON public.notifications
        FOR SELECT
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND user_id = auth.uid()
          AND EXISTS (
            SELECT 1
            FROM public.user_tenant_membership utm
            WHERE utm.user_id = auth.uid()
              AND utm.tenant_id = tenant_id
              AND utm.is_active = true
          )
        );
      $ddl$;

      EXECUTE $ddl$
        CREATE POLICY tenant_insert_notifications_self
        ON public.notifications
        FOR INSERT
        TO authenticated
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND user_id = auth.uid()
          AND EXISTS (
            SELECT 1
            FROM public.user_tenant_membership utm
            WHERE utm.user_id = auth.uid()
              AND utm.tenant_id = tenant_id
              AND utm.is_active = true
          )
        );
      $ddl$;

      EXECUTE $ddl$
        CREATE POLICY tenant_update_notifications_self
        ON public.notifications
        FOR UPDATE
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND user_id = auth.uid()
          AND EXISTS (
            SELECT 1
            FROM public.user_tenant_membership utm
            WHERE utm.user_id = auth.uid()
              AND utm.tenant_id = tenant_id
              AND utm.is_active = true
          )
        )
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND user_id = auth.uid()
          AND EXISTS (
            SELECT 1
            FROM public.user_tenant_membership utm
            WHERE utm.user_id = auth.uid()
              AND utm.tenant_id = tenant_id
              AND utm.is_active = true
          )
        );
      $ddl$;

      EXECUTE $ddl$
        CREATE POLICY tenant_delete_notifications_self
        ON public.notifications
        FOR DELETE
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND user_id = auth.uid()
          AND EXISTS (
            SELECT 1
            FROM public.user_tenant_membership utm
            WHERE utm.user_id = auth.uid()
              AND utm.tenant_id = tenant_id
              AND utm.is_active = true
          )
        );
      $ddl$;
    ELSIF v_has_ual AND v_ual_has_tenant THEN
      EXECUTE $ddl$
        CREATE POLICY tenant_select_notifications
        ON public.notifications
        FOR SELECT
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND user_id = auth.uid()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = tenant_id
          )
        );
      $ddl$;

      EXECUTE $ddl$
        CREATE POLICY tenant_insert_notifications_self
        ON public.notifications
        FOR INSERT
        TO authenticated
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND user_id = auth.uid()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = tenant_id
          )
        );
      $ddl$;

      EXECUTE $ddl$
        CREATE POLICY tenant_update_notifications_self
        ON public.notifications
        FOR UPDATE
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND user_id = auth.uid()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = tenant_id
          )
        )
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND user_id = auth.uid()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = tenant_id
          )
        );
      $ddl$;

      EXECUTE $ddl$
        CREATE POLICY tenant_delete_notifications_self
        ON public.notifications
        FOR DELETE
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND user_id = auth.uid()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = tenant_id
          )
        );
      $ddl$;
    ELSE
      CREATE POLICY tenant_select_notifications
      ON public.notifications
      FOR SELECT
      TO authenticated
      USING (
        tenant_id = public.current_tenant_id()
        AND user_id = auth.uid()
      );

      CREATE POLICY tenant_insert_notifications_self
      ON public.notifications
      FOR INSERT
      TO authenticated
      WITH CHECK (
        tenant_id = public.current_tenant_id()
        AND user_id = auth.uid()
      );

      CREATE POLICY tenant_update_notifications_self
      ON public.notifications
      FOR UPDATE
      TO authenticated
      USING (
        tenant_id = public.current_tenant_id()
        AND user_id = auth.uid()
      )
      WITH CHECK (
        tenant_id = public.current_tenant_id()
        AND user_id = auth.uid()
      );

      CREATE POLICY tenant_delete_notifications_self
      ON public.notifications
      FOR DELETE
      TO authenticated
      USING (
        tenant_id = public.current_tenant_id()
        AND user_id = auth.uid()
      );
    END IF;
  END IF;
END $$;

DO $$
DECLARE
  p record;
  v_has_check_user_permission boolean;
BEGIN
  IF to_regclass('public.permission_audit_log') IS NOT NULL THEN
    ALTER TABLE public.permission_audit_log ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Sistema pode inserir logs" ON public.permission_audit_log;

    FOR p IN
      SELECT schemaname, tablename, policyname
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'permission_audit_log'
        AND cmd = 'INSERT'
        AND (
          COALESCE(qual, '') ~* '^\s*true\s*$'
          OR COALESCE(with_check, '') ~* '^\s*true\s*$'
        )
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', p.policyname, p.schemaname, p.tablename);
    END LOOP;

    DROP POLICY IF EXISTS permission_audit_log_select_manage_permissions ON public.permission_audit_log;
    DROP POLICY IF EXISTS permission_audit_log_insert_manage_permissions ON public.permission_audit_log;

    SELECT EXISTS (
      SELECT 1
      FROM pg_proc pr
      JOIN pg_namespace ns ON ns.oid = pr.pronamespace
      WHERE ns.nspname = 'public'
        AND pr.proname = 'check_user_permission'
    ) INTO v_has_check_user_permission;

    IF v_has_check_user_permission THEN
      EXECUTE $ddl$
        CREATE POLICY permission_audit_log_select_manage_permissions
        ON public.permission_audit_log
        FOR SELECT
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND public.check_user_permission(auth.uid(), 'settings.manage_permissions')
        );
      $ddl$;

      EXECUTE $ddl$
        CREATE POLICY permission_audit_log_insert_manage_permissions
        ON public.permission_audit_log
        FOR INSERT
        TO authenticated
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND performed_by = auth.uid()
          AND public.check_user_permission(auth.uid(), 'settings.manage_permissions')
        );
      $ddl$;
    ELSE
      CREATE POLICY permission_audit_log_select_manage_permissions
      ON public.permission_audit_log
      FOR SELECT
      TO authenticated
      USING (false);

      CREATE POLICY permission_audit_log_insert_manage_permissions
      ON public.permission_audit_log
      FOR INSERT
      TO authenticated
      WITH CHECK (false);
    END IF;
  END IF;
END $$;

DO $$
DECLARE
  p record;
  v_has_utm boolean;
  v_has_ual boolean;
  v_ual_has_tenant boolean;
BEGIN
  IF to_regclass('public.study_participants') IS NOT NULL THEN
    ALTER TABLE public.study_participants ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Authenticated users can manage study participants" ON public.study_participants;
    DROP POLICY IF EXISTS "Permitir INSERT via trigger" ON public.study_participants;

    FOR p IN
      SELECT schemaname, tablename, policyname
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'study_participants'
        AND cmd IN ('INSERT', 'UPDATE', 'DELETE')
        AND (
          COALESCE(qual, '') ~* '^\s*true\s*$'
          OR COALESCE(with_check, '') ~* '^\s*true\s*$'
        )
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', p.policyname, p.schemaname, p.tablename);
    END LOOP;

    DROP POLICY IF EXISTS study_participants_select_group_members ON public.study_participants;
    DROP POLICY IF EXISTS study_participants_insert_self_public ON public.study_participants;
    DROP POLICY IF EXISTS study_participants_insert_leader ON public.study_participants;
    DROP POLICY IF EXISTS study_participants_update_leader ON public.study_participants;
    DROP POLICY IF EXISTS study_participants_update_self ON public.study_participants;
    DROP POLICY IF EXISTS study_participants_delete_self ON public.study_participants;

    SELECT (to_regclass('public.user_tenant_membership') IS NOT NULL) INTO v_has_utm;
    SELECT (to_regclass('public.user_access_level') IS NOT NULL) INTO v_has_ual;
    SELECT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'user_access_level'
        AND column_name = 'tenant_id'
    ) INTO v_ual_has_tenant;

    IF v_has_utm THEN
      EXECUTE $ddl$
        CREATE POLICY study_participants_select_group_members
        ON public.study_participants
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
          )
          AND EXISTS (
            SELECT 1
            FROM public.study_participants sp
            WHERE sp.study_group_id = study_participants.study_group_id
              AND sp.user_id = auth.uid()
              AND sp.tenant_id = study_participants.tenant_id
              AND sp.is_active = true
          )
        );
      $ddl$;
    ELSIF v_has_ual AND v_ual_has_tenant THEN
      EXECUTE $ddl$
        CREATE POLICY study_participants_select_group_members
        ON public.study_participants
        FOR SELECT
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = tenant_id
          )
          AND EXISTS (
            SELECT 1
            FROM public.study_participants sp
            WHERE sp.study_group_id = study_participants.study_group_id
              AND sp.user_id = auth.uid()
              AND sp.tenant_id = study_participants.tenant_id
              AND sp.is_active = true
          )
        );
      $ddl$;
    ELSE
      CREATE POLICY study_participants_select_group_members
      ON public.study_participants
      FOR SELECT
      TO authenticated
      USING (
        tenant_id = public.current_tenant_id()
        AND EXISTS (
          SELECT 1
          FROM public.study_participants sp
          WHERE sp.study_group_id = study_participants.study_group_id
            AND sp.user_id = auth.uid()
            AND sp.tenant_id = study_participants.tenant_id
            AND sp.is_active = true
        )
      );
    END IF;

    CREATE POLICY study_participants_insert_self_public
    ON public.study_participants
    FOR INSERT
    TO authenticated
    WITH CHECK (
      tenant_id = public.current_tenant_id()
      AND user_id = auth.uid()
      AND EXISTS (
        SELECT 1
        FROM public.study_groups sg
        WHERE sg.id = study_group_id
          AND sg.tenant_id = tenant_id
          AND sg.is_public = true
      )
    );

    CREATE POLICY study_participants_insert_leader
    ON public.study_participants
    FOR INSERT
    TO authenticated
    WITH CHECK (
      tenant_id = public.current_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.study_participants sp
        WHERE sp.study_group_id = study_group_id
          AND sp.user_id = auth.uid()
          AND sp.tenant_id = tenant_id
          AND sp.is_active = true
          AND sp.role IN ('leader', 'co_leader')
      )
    );

    CREATE POLICY study_participants_update_leader
    ON public.study_participants
    FOR UPDATE
    TO authenticated
    USING (
      tenant_id = public.current_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.study_participants sp
        WHERE sp.study_group_id = study_participants.study_group_id
          AND sp.user_id = auth.uid()
          AND sp.tenant_id = study_participants.tenant_id
          AND sp.is_active = true
          AND sp.role IN ('leader', 'co_leader')
      )
    )
    WITH CHECK (
      tenant_id = public.current_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.study_participants sp
        WHERE sp.study_group_id = study_participants.study_group_id
          AND sp.user_id = auth.uid()
          AND sp.tenant_id = study_participants.tenant_id
          AND sp.is_active = true
          AND sp.role IN ('leader', 'co_leader')
      )
    );

    CREATE POLICY study_participants_update_self
    ON public.study_participants
    FOR UPDATE
    TO authenticated
    USING (
      tenant_id = public.current_tenant_id()
      AND user_id = auth.uid()
    )
    WITH CHECK (
      tenant_id = public.current_tenant_id()
      AND user_id = auth.uid()
    );

    CREATE POLICY study_participants_delete_self
    ON public.study_participants
    FOR DELETE
    TO authenticated
    USING (
      tenant_id = public.current_tenant_id()
      AND user_id = auth.uid()
    );
  END IF;
END $$;

DO $$
DECLARE
  p record;
  v_has_utm boolean;
  v_has_ual boolean;
  v_ual_has_tenant boolean;
BEGIN
  IF to_regclass('public.ministry') IS NOT NULL THEN
    ALTER TABLE public.ministry ENABLE ROW LEVEL SECURITY;

    FOR p IN
      SELECT schemaname, tablename, policyname
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'ministry'
        AND cmd IN ('INSERT', 'UPDATE', 'DELETE')
        AND (
          COALESCE(qual, '') ~* '^\s*true\s*$'
          OR COALESCE(with_check, '') ~* '^\s*true\s*$'
        )
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', p.policyname, p.schemaname, p.tablename);
    END LOOP;

    DROP POLICY IF EXISTS tenant_select_ministry ON public.ministry;
    DROP POLICY IF EXISTS tenant_modify_ministry ON public.ministry;

    SELECT (to_regclass('public.user_tenant_membership') IS NOT NULL) INTO v_has_utm;
    SELECT (to_regclass('public.user_access_level') IS NOT NULL) INTO v_has_ual;
    SELECT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'user_access_level'
        AND column_name = 'tenant_id'
    ) INTO v_ual_has_tenant;

    IF v_has_utm THEN
      EXECUTE $ddl$
        CREATE POLICY tenant_select_ministry
        ON public.ministry
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
          )
        );
      $ddl$;

      EXECUTE $ddl$
        CREATE POLICY tenant_modify_ministry
        ON public.ministry
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
        CREATE POLICY tenant_select_ministry
        ON public.ministry
        FOR SELECT
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = public.current_tenant_id()
              AND ual.access_level_number >= 1
          )
        );
      $ddl$;

      EXECUTE $ddl$
        CREATE POLICY tenant_modify_ministry
        ON public.ministry
        FOR ALL
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = public.current_tenant_id()
              AND ual.access_level_number >= 4
          )
        )
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = public.current_tenant_id()
              AND ual.access_level_number >= 4
          )
        );
      $ddl$;
    ELSE
      EXECUTE $ddl$
        CREATE POLICY tenant_select_ministry
        ON public.ministry
        FOR SELECT
        TO authenticated
        USING (tenant_id = public.current_tenant_id());
      $ddl$;

      EXECUTE $ddl$
        CREATE POLICY tenant_modify_ministry
        ON public.ministry
        FOR ALL
        TO authenticated
        USING (tenant_id = public.current_tenant_id())
        WITH CHECK (tenant_id = public.current_tenant_id());
      $ddl$;
    END IF;
  END IF;
END $$;

DO $$
DECLARE
  p record;
  v_has_utm boolean;
  v_has_ual boolean;
  v_ual_has_tenant boolean;
BEGIN
  IF to_regclass('public.ministry_member') IS NOT NULL THEN
    ALTER TABLE public.ministry_member ENABLE ROW LEVEL SECURITY;

    FOR p IN
      SELECT schemaname, tablename, policyname
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'ministry_member'
        AND cmd IN ('INSERT', 'UPDATE', 'DELETE')
        AND (
          COALESCE(qual, '') ~* '^\s*true\s*$'
          OR COALESCE(with_check, '') ~* '^\s*true\s*$'
        )
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', p.policyname, p.schemaname, p.tablename);
    END LOOP;

    DROP POLICY IF EXISTS tenant_select_ministry_member ON public.ministry_member;
    DROP POLICY IF EXISTS tenant_modify_ministry_member ON public.ministry_member;

    SELECT (to_regclass('public.user_tenant_membership') IS NOT NULL) INTO v_has_utm;
    SELECT (to_regclass('public.user_access_level') IS NOT NULL) INTO v_has_ual;
    SELECT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'user_access_level'
        AND column_name = 'tenant_id'
    ) INTO v_ual_has_tenant;

    IF v_has_utm THEN
      EXECUTE $ddl$
        CREATE POLICY tenant_select_ministry_member
        ON public.ministry_member
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
          )
        );
      $ddl$;

      EXECUTE $ddl$
        CREATE POLICY tenant_modify_ministry_member
        ON public.ministry_member
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
        CREATE POLICY tenant_select_ministry_member
        ON public.ministry_member
        FOR SELECT
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = public.current_tenant_id()
              AND ual.access_level_number >= 1
          )
        );
      $ddl$;

      EXECUTE $ddl$
        CREATE POLICY tenant_modify_ministry_member
        ON public.ministry_member
        FOR ALL
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = public.current_tenant_id()
              AND ual.access_level_number >= 4
          )
        )
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = public.current_tenant_id()
              AND ual.access_level_number >= 4
          )
        );
      $ddl$;
    ELSE
      EXECUTE $ddl$
        CREATE POLICY tenant_select_ministry_member
        ON public.ministry_member
        FOR SELECT
        TO authenticated
        USING (tenant_id = public.current_tenant_id());
      $ddl$;

      EXECUTE $ddl$
        CREATE POLICY tenant_modify_ministry_member
        ON public.ministry_member
        FOR ALL
        TO authenticated
        USING (tenant_id = public.current_tenant_id())
        WITH CHECK (tenant_id = public.current_tenant_id());
      $ddl$;
    END IF;
  END IF;
END $$;

DO $$
DECLARE
  p record;
  v_has_utm boolean;
  v_has_ual boolean;
  v_ual_has_tenant boolean;
BEGIN
  IF to_regclass('public.ministry_schedule') IS NOT NULL THEN
    ALTER TABLE public.ministry_schedule ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Permitir atualização de escalas para usuários autenticados" ON public.ministry_schedule;
    DROP POLICY IF EXISTS "Permitir exclusão de escalas para usuários autenticados" ON public.ministry_schedule;

    FOR p IN
      SELECT schemaname, tablename, policyname
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'ministry_schedule'
        AND cmd IN ('INSERT', 'UPDATE', 'DELETE')
        AND (
          COALESCE(qual, '') ~* '^\s*true\s*$'
          OR COALESCE(with_check, '') ~* '^\s*true\s*$'
        )
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', p.policyname, p.schemaname, p.tablename);
    END LOOP;

    DROP POLICY IF EXISTS tenant_select_ministry_schedule ON public.ministry_schedule;
    DROP POLICY IF EXISTS tenant_modify_ministry_schedule ON public.ministry_schedule;

    SELECT (to_regclass('public.user_tenant_membership') IS NOT NULL) INTO v_has_utm;
    SELECT (to_regclass('public.user_access_level') IS NOT NULL) INTO v_has_ual;
    SELECT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'user_access_level'
        AND column_name = 'tenant_id'
    ) INTO v_ual_has_tenant;

    IF v_has_utm THEN
      EXECUTE $ddl$
        CREATE POLICY tenant_select_ministry_schedule
        ON public.ministry_schedule
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
          )
        );
      $ddl$;

      EXECUTE $ddl$
        CREATE POLICY tenant_modify_ministry_schedule
        ON public.ministry_schedule
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
        CREATE POLICY tenant_select_ministry_schedule
        ON public.ministry_schedule
        FOR SELECT
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = public.current_tenant_id()
              AND ual.access_level_number >= 1
          )
        );
      $ddl$;

      EXECUTE $ddl$
        CREATE POLICY tenant_modify_ministry_schedule
        ON public.ministry_schedule
        FOR ALL
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = public.current_tenant_id()
              AND ual.access_level_number >= 4
          )
        )
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = public.current_tenant_id()
              AND ual.access_level_number >= 4
          )
        );
      $ddl$;
    ELSE
      EXECUTE $ddl$
        CREATE POLICY tenant_select_ministry_schedule
        ON public.ministry_schedule
        FOR SELECT
        TO authenticated
        USING (tenant_id = public.current_tenant_id());
      $ddl$;

      EXECUTE $ddl$
        CREATE POLICY tenant_modify_ministry_schedule
        ON public.ministry_schedule
        FOR ALL
        TO authenticated
        USING (tenant_id = public.current_tenant_id())
        WITH CHECK (tenant_id = public.current_tenant_id());
      $ddl$;
    END IF;
  END IF;
END $$;

DO $$
DECLARE
  p record;
  v_has_utm boolean;
  v_has_ual boolean;
  v_ual_has_tenant boolean;
BEGIN
  IF to_regclass('public.home_banner') IS NOT NULL THEN
    ALTER TABLE public.home_banner ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Usuários autenticados podem inserir banners" ON public.home_banner;
    DROP POLICY IF EXISTS "Usuários autenticados podem atualizar banners" ON public.home_banner;
    DROP POLICY IF EXISTS "Usuários autenticados podem deletar banners" ON public.home_banner;

    FOR p IN
      SELECT schemaname, tablename, policyname
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'home_banner'
        AND cmd IN ('INSERT', 'UPDATE', 'DELETE')
        AND (
          COALESCE(qual, '') ~* '^\s*true\s*$'
          OR COALESCE(with_check, '') ~* '^\s*true\s*$'
        )
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', p.policyname, p.schemaname, p.tablename);
    END LOOP;

    DROP POLICY IF EXISTS tenant_select_home_banner ON public.home_banner;
    DROP POLICY IF EXISTS tenant_modify_home_banner ON public.home_banner;

    SELECT (to_regclass('public.user_tenant_membership') IS NOT NULL) INTO v_has_utm;
    SELECT (to_regclass('public.user_access_level') IS NOT NULL) INTO v_has_ual;
    SELECT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'user_access_level'
        AND column_name = 'tenant_id'
    ) INTO v_ual_has_tenant;

    IF v_has_utm THEN
      EXECUTE $ddl$
        CREATE POLICY tenant_select_home_banner
        ON public.home_banner
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
          )
        );
      $ddl$;

      EXECUTE $ddl$
        CREATE POLICY tenant_modify_home_banner
        ON public.home_banner
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
        CREATE POLICY tenant_select_home_banner
        ON public.home_banner
        FOR SELECT
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = public.current_tenant_id()
              AND ual.access_level_number >= 1
          )
        );
      $ddl$;

      EXECUTE $ddl$
        CREATE POLICY tenant_modify_home_banner
        ON public.home_banner
        FOR ALL
        TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = public.current_tenant_id()
              AND ual.access_level_number >= 4
          )
        )
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = public.current_tenant_id()
              AND ual.access_level_number >= 4
          )
        );
      $ddl$;
    ELSE
      EXECUTE $ddl$
        CREATE POLICY tenant_select_home_banner
        ON public.home_banner
        FOR SELECT
        TO authenticated
        USING (tenant_id = public.current_tenant_id());
      $ddl$;

      EXECUTE $ddl$
        CREATE POLICY tenant_modify_home_banner
        ON public.home_banner
        FOR ALL
        TO authenticated
        USING (tenant_id = public.current_tenant_id())
        WITH CHECK (tenant_id = public.current_tenant_id());
      $ddl$;
    END IF;
  END IF;
END $$;

DO $$
DECLARE
  v_member_has_tenant boolean;
  v_ual_has_tenant boolean;
BEGIN
  IF to_regclass('public.member') IS NOT NULL THEN
    ALTER TABLE public.member ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS member_update_admin ON public.member;

    SELECT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'member'
        AND column_name = 'tenant_id'
    ) INTO v_member_has_tenant;

    SELECT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'user_access_level'
        AND column_name = 'tenant_id'
    ) INTO v_ual_has_tenant;

    IF v_member_has_tenant AND v_ual_has_tenant THEN
      EXECUTE $ddl$
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
      $ddl$;
    ELSIF v_member_has_tenant THEN
      EXECUTE $ddl$
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
              AND ual.access_level_number >= 5
          )
        )
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.access_level_number >= 5
          )
        );
      $ddl$;
    ELSIF v_ual_has_tenant THEN
      EXECUTE $ddl$
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
        WITH CHECK (
          EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.tenant_id = public.current_tenant_id()
              AND ual.access_level_number >= 5
          )
        );
      $ddl$;
    ELSE
      EXECUTE $ddl$
        CREATE POLICY member_update_admin
        ON public.member
        FOR UPDATE
        TO authenticated
        USING (
          EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.access_level_number >= 5
          )
        )
        WITH CHECK (
          EXISTS (
            SELECT 1
            FROM public.user_access_level ual
            WHERE ual.user_id = auth.uid()
              AND ual.access_level_number >= 5
          )
        );
      $ddl$;
    END IF;
  END IF;
END $$;

DO $$
DECLARE
  p record;
BEGIN
  IF to_regclass('public.dispatch_job') IS NOT NULL THEN
    ALTER TABLE public.dispatch_job ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS dispatch_job_insert_all ON public.dispatch_job;

    FOR p IN
      SELECT schemaname, tablename, policyname
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'dispatch_job'
        AND cmd IN ('INSERT', 'UPDATE', 'DELETE')
        AND (
          COALESCE(qual, '') ~* '^\s*true\s*$'
          OR COALESCE(with_check, '') ~* '^\s*true\s*$'
        )
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', p.policyname, p.schemaname, p.tablename);
    END LOOP;
  END IF;
END $$;

DO $$
DECLARE
  p record;
BEGIN
  IF to_regclass('public.dispatch_log') IS NOT NULL THEN
    ALTER TABLE public.dispatch_log ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS dispatch_log_insert_all ON public.dispatch_log;

    FOR p IN
      SELECT schemaname, tablename, policyname
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'dispatch_log'
        AND cmd IN ('INSERT', 'UPDATE', 'DELETE')
        AND (
          COALESCE(qual, '') ~* '^\s*true\s*$'
          OR COALESCE(with_check, '') ~* '^\s*true\s*$'
        )
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', p.policyname, p.schemaname, p.tablename);
    END LOOP;

    DROP POLICY IF EXISTS tenant_select_dispatch_log ON public.dispatch_log;
    DROP POLICY IF EXISTS tenant_modify_dispatch_log ON public.dispatch_log;

    CREATE POLICY tenant_select_dispatch_log
    ON public.dispatch_log
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

    CREATE POLICY tenant_modify_dispatch_log
    ON public.dispatch_log
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
  END IF;
END $$;

DO $$
DECLARE
  p record;
BEGIN
  IF to_regclass('public.dispatch_webhook') IS NOT NULL THEN
    ALTER TABLE public.dispatch_webhook ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS dw_insert ON public.dispatch_webhook;

    FOR p IN
      SELECT schemaname, tablename, policyname
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'dispatch_webhook'
        AND cmd IN ('INSERT', 'UPDATE', 'DELETE')
        AND (
          COALESCE(qual, '') ~* '^\s*true\s*$'
          OR COALESCE(with_check, '') ~* '^\s*true\s*$'
        )
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', p.policyname, p.schemaname, p.tablename);
    END LOOP;

    DROP POLICY IF EXISTS tenant_select_dispatch_webhook ON public.dispatch_webhook;
    DROP POLICY IF EXISTS tenant_modify_dispatch_webhook ON public.dispatch_webhook;

    CREATE POLICY tenant_select_dispatch_webhook
    ON public.dispatch_webhook
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

    CREATE POLICY tenant_modify_dispatch_webhook
    ON public.dispatch_webhook
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
  END IF;
END $$;

DO $$
DECLARE
  p record;
BEGIN
  IF to_regclass('public.expense') IS NOT NULL THEN
    ALTER TABLE public.expense ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Usuários autenticados podem ver despesas" ON public.expense;
    DROP POLICY IF EXISTS "Usuários autenticados podem inserir despesas" ON public.expense;
    DROP POLICY IF EXISTS "Usuários autenticados podem atualizar despesas" ON public.expense;
    DROP POLICY IF EXISTS "Usuários autenticados podem deletar despesas" ON public.expense;

    FOR p IN
      SELECT schemaname, tablename, policyname
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'expense'
        AND cmd IN ('INSERT', 'UPDATE', 'DELETE')
        AND (
          COALESCE(qual, '') ~* '^\s*true\s*$'
          OR COALESCE(with_check, '') ~* '^\s*true\s*$'
        )
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', p.policyname, p.schemaname, p.tablename);
    END LOOP;

    DROP POLICY IF EXISTS tenant_select_expense ON public.expense;
    DROP POLICY IF EXISTS tenant_modify_expense ON public.expense;
    DROP POLICY IF EXISTS tenant_insert_expense ON public.expense;
    DROP POLICY IF EXISTS tenant_update_expense ON public.expense;
    DROP POLICY IF EXISTS tenant_delete_expense ON public.expense;

    CREATE POLICY tenant_select_expense
    ON public.expense
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

    CREATE POLICY tenant_insert_expense
    ON public.expense
    FOR INSERT
    TO authenticated
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

    CREATE POLICY tenant_update_expense
    ON public.expense
    FOR UPDATE
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

    CREATE POLICY tenant_delete_expense
    ON public.expense
    FOR DELETE
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
  END IF;
END $$;

DO $$
DECLARE
  p record;
BEGIN
  IF to_regclass('public.financial_goal') IS NOT NULL THEN
    ALTER TABLE public.financial_goal ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Usuários autenticados podem inserir metas" ON public.financial_goal;
    DROP POLICY IF EXISTS "Usuários autenticados podem atualizar metas" ON public.financial_goal;
    DROP POLICY IF EXISTS "Usuários autenticados podem deletar metas" ON public.financial_goal;

    FOR p IN
      SELECT schemaname, tablename, policyname
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'financial_goal'
        AND cmd IN ('INSERT', 'UPDATE', 'DELETE')
        AND (
          COALESCE(qual, '') ~* '^\s*true\s*$'
          OR COALESCE(with_check, '') ~* '^\s*true\s*$'
        )
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', p.policyname, p.schemaname, p.tablename);
    END LOOP;

    DROP POLICY IF EXISTS tenant_select_financial_goal ON public.financial_goal;
    DROP POLICY IF EXISTS tenant_modify_financial_goal ON public.financial_goal;
    DROP POLICY IF EXISTS tenant_insert_financial_goal ON public.financial_goal;
    DROP POLICY IF EXISTS tenant_update_financial_goal ON public.financial_goal;
    DROP POLICY IF EXISTS tenant_delete_financial_goal ON public.financial_goal;

    CREATE POLICY tenant_select_financial_goal
    ON public.financial_goal
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

    CREATE POLICY tenant_insert_financial_goal
    ON public.financial_goal
    FOR INSERT
    TO authenticated
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

    CREATE POLICY tenant_update_financial_goal
    ON public.financial_goal
    FOR UPDATE
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

    CREATE POLICY tenant_delete_financial_goal
    ON public.financial_goal
    FOR DELETE
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
  END IF;
END $$;
