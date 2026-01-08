    DO $$
    BEGIN
      -- Helper: ensure function exists
      PERFORM 1 FROM pg_proc WHERE proname = 'current_tenant_id';
      -- visitor_visit
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='visitor_visit' AND column_name='tenant_id'
      ) THEN
        ALTER TABLE public.visitor_visit ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS tenant_select_visitor_visit ON public.visitor_visit;
        CREATE POLICY tenant_select_visitor_visit ON public.visitor_visit FOR SELECT USING (tenant_id = public.current_tenant_id());
        DROP POLICY IF EXISTS tenant_modify_visitor_visit ON public.visitor_visit;
        CREATE POLICY tenant_modify_visitor_visit ON public.visitor_visit FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
        CREATE INDEX IF NOT EXISTS idx_visitor_visit_tenant_id ON public.visitor_visit(tenant_id);
      END IF;

      -- visitor_followup
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='visitor_followup' AND column_name='tenant_id'
      ) THEN
        ALTER TABLE public.visitor_followup ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS tenant_select_visitor_followup ON public.visitor_followup;
        CREATE POLICY tenant_select_visitor_followup ON public.visitor_followup FOR SELECT USING (tenant_id = public.current_tenant_id());
        DROP POLICY IF EXISTS tenant_modify_visitor_followup ON public.visitor_followup;
        CREATE POLICY tenant_modify_visitor_followup ON public.visitor_followup FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
        CREATE INDEX IF NOT EXISTS idx_visitor_followup_tenant_id ON public.visitor_followup(tenant_id);
      END IF;

      -- kids_authorized_guardian
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='kids_authorized_guardian' AND column_name='tenant_id'
      ) THEN
        ALTER TABLE public.kids_authorized_guardian ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS tenant_select_kids_authorized_guardian ON public.kids_authorized_guardian;
        CREATE POLICY tenant_select_kids_authorized_guardian ON public.kids_authorized_guardian FOR SELECT USING (tenant_id = public.current_tenant_id());
        DROP POLICY IF EXISTS tenant_modify_kids_authorized_guardian ON public.kids_authorized_guardian;
        CREATE POLICY tenant_modify_kids_authorized_guardian ON public.kids_authorized_guardian FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
        CREATE INDEX IF NOT EXISTS idx_kids_authorized_guardian_tenant_id ON public.kids_authorized_guardian(tenant_id);
      END IF;

      -- kids_checkin_token
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='kids_checkin_token' AND column_name='tenant_id'
      ) THEN
        ALTER TABLE public.kids_checkin_token ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS tenant_select_kids_checkin_token ON public.kids_checkin_token;
        CREATE POLICY tenant_select_kids_checkin_token ON public.kids_checkin_token FOR SELECT USING (tenant_id = public.current_tenant_id());
        DROP POLICY IF EXISTS tenant_modify_kids_checkin_token ON public.kids_checkin_token;
        CREATE POLICY tenant_modify_kids_checkin_token ON public.kids_checkin_token FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
        CREATE INDEX IF NOT EXISTS idx_kids_checkin_token_tenant_id ON public.kids_checkin_token(tenant_id);
      END IF;

      -- kids_attendance
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='kids_attendance' AND column_name='tenant_id'
      ) THEN
        ALTER TABLE public.kids_attendance ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS tenant_select_kids_attendance ON public.kids_attendance;
        CREATE POLICY tenant_select_kids_attendance ON public.kids_attendance FOR SELECT USING (tenant_id = public.current_tenant_id());
        DROP POLICY IF EXISTS tenant_modify_kids_attendance ON public.kids_attendance;
        CREATE POLICY tenant_modify_kids_attendance ON public.kids_attendance FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
        CREATE INDEX IF NOT EXISTS idx_kids_attendance_tenant_id ON public.kids_attendance(tenant_id);
      END IF;

      -- support_material
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='support_material' AND column_name='tenant_id'
      ) THEN
        ALTER TABLE public.support_material ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS tenant_select_support_material ON public.support_material;
        CREATE POLICY tenant_select_support_material ON public.support_material FOR SELECT USING (tenant_id = public.current_tenant_id());
        DROP POLICY IF EXISTS tenant_modify_support_material ON public.support_material;
        CREATE POLICY tenant_modify_support_material ON public.support_material FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
        CREATE INDEX IF NOT EXISTS idx_support_material_tenant_id ON public.support_material(tenant_id);
      END IF;

      -- support_material_module
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='support_material_module' AND column_name='tenant_id'
      ) THEN
        ALTER TABLE public.support_material_module ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS tenant_select_support_material_module ON public.support_material_module;
        CREATE POLICY tenant_select_support_material_module ON public.support_material_module FOR SELECT USING (tenant_id = public.current_tenant_id());
        DROP POLICY IF EXISTS tenant_modify_support_material_module ON public.support_material_module;
        CREATE POLICY tenant_modify_support_material_module ON public.support_material_module FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
        CREATE INDEX IF NOT EXISTS idx_support_material_module_tenant_id ON public.support_material_module(tenant_id);
      END IF;

      -- support_material_link
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='support_material_link' AND column_name='tenant_id'
      ) THEN
        ALTER TABLE public.support_material_link ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS tenant_select_support_material_link ON public.support_material_link;
        CREATE POLICY tenant_select_support_material_link ON public.support_material_link FOR SELECT USING (tenant_id = public.current_tenant_id());
        DROP POLICY IF EXISTS tenant_modify_support_material_link ON public.support_material_link;
        CREATE POLICY tenant_modify_support_material_link ON public.support_material_link FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
        CREATE INDEX IF NOT EXISTS idx_support_material_link_tenant_id ON public.support_material_link(tenant_id);
      END IF;

      -- ministry
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='ministry' AND column_name='tenant_id'
      ) THEN
        ALTER TABLE public.ministry ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS tenant_select_ministry ON public.ministry;
        CREATE POLICY tenant_select_ministry ON public.ministry FOR SELECT USING (tenant_id = public.current_tenant_id());
        DROP POLICY IF EXISTS tenant_modify_ministry ON public.ministry;
        CREATE POLICY tenant_modify_ministry ON public.ministry FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
        CREATE INDEX IF NOT EXISTS idx_ministry_tenant_id ON public.ministry(tenant_id);
      END IF;

      -- ministry_member
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='ministry_member' AND column_name='tenant_id'
      ) THEN
        ALTER TABLE public.ministry_member ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS tenant_select_ministry_member ON public.ministry_member;
        CREATE POLICY tenant_select_ministry_member ON public.ministry_member FOR SELECT USING (tenant_id = public.current_tenant_id());
        DROP POLICY IF EXISTS tenant_modify_ministry_member ON public.ministry_member;
        CREATE POLICY tenant_modify_ministry_member ON public.ministry_member FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
        CREATE INDEX IF NOT EXISTS idx_ministry_member_tenant_id ON public.ministry_member(tenant_id);
      END IF;

      -- ministry_schedule
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='ministry_schedule' AND column_name='tenant_id'
      ) THEN
        ALTER TABLE public.ministry_schedule ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS tenant_select_ministry_schedule ON public.ministry_schedule;
        CREATE POLICY tenant_select_ministry_schedule ON public.ministry_schedule FOR SELECT USING (tenant_id = public.current_tenant_id());
        DROP POLICY IF EXISTS tenant_modify_ministry_schedule ON public.ministry_schedule;
        CREATE POLICY tenant_modify_ministry_schedule ON public.ministry_schedule FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
        CREATE INDEX IF NOT EXISTS idx_ministry_schedule_tenant_id ON public.ministry_schedule(tenant_id);
      END IF;

      -- ministry_function
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='ministry_function' AND column_name='tenant_id'
      ) THEN
        ALTER TABLE public.ministry_function ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS tenant_select_ministry_function ON public.ministry_function;
        CREATE POLICY tenant_select_ministry_function ON public.ministry_function FOR SELECT USING (tenant_id = public.current_tenant_id());
        DROP POLICY IF EXISTS tenant_modify_ministry_function ON public.ministry_function;
        CREATE POLICY tenant_modify_ministry_function ON public.ministry_function FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
        CREATE INDEX IF NOT EXISTS idx_ministry_function_tenant_id ON public.ministry_function(tenant_id);
      END IF;

      -- member_function
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='member_function' AND column_name='tenant_id'
      ) THEN
        ALTER TABLE public.member_function ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS tenant_select_member_function ON public.member_function;
        CREATE POLICY tenant_select_member_function ON public.member_function FOR SELECT USING (tenant_id = public.current_tenant_id());
        DROP POLICY IF EXISTS tenant_modify_member_function ON public.member_function;
        CREATE POLICY tenant_modify_member_function ON public.member_function FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
        CREATE INDEX IF NOT EXISTS idx_member_function_tenant_id ON public.member_function(tenant_id);
      END IF;

      -- bible_bookmark
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='bible_bookmark' AND column_name='tenant_id'
      ) THEN
        ALTER TABLE public.bible_bookmark ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS tenant_select_bible_bookmark ON public.bible_bookmark;
        CREATE POLICY tenant_select_bible_bookmark ON public.bible_bookmark FOR SELECT USING (tenant_id = public.current_tenant_id());
        DROP POLICY IF EXISTS tenant_modify_bible_bookmark ON public.bible_bookmark;
        CREATE POLICY tenant_modify_bible_bookmark ON public.bible_bookmark FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
        CREATE INDEX IF NOT EXISTS idx_bible_bookmark_tenant_id ON public.bible_bookmark(tenant_id);
      END IF;

      -- notifications
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='notifications' AND column_name='tenant_id'
      ) THEN
        ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS tenant_select_notifications ON public.notifications;
        CREATE POLICY tenant_select_notifications ON public.notifications FOR SELECT USING (tenant_id = public.current_tenant_id());
        DROP POLICY IF EXISTS tenant_modify_notifications ON public.notifications;
        CREATE POLICY tenant_modify_notifications ON public.notifications FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
        CREATE INDEX IF NOT EXISTS idx_notifications_tenant_id ON public.notifications(tenant_id);
      END IF;

      -- notification_preferences
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='notification_preferences' AND column_name='tenant_id'
      ) THEN
        ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS tenant_select_notification_preferences ON public.notification_preferences;
        CREATE POLICY tenant_select_notification_preferences ON public.notification_preferences FOR SELECT USING (tenant_id = public.current_tenant_id());
        DROP POLICY IF EXISTS tenant_modify_notification_preferences ON public.notification_preferences;
        CREATE POLICY tenant_modify_notification_preferences ON public.notification_preferences FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
        CREATE INDEX IF NOT EXISTS idx_notification_preferences_tenant_id ON public.notification_preferences(tenant_id);
      END IF;

      -- fcm_tokens
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='fcm_tokens' AND column_name='tenant_id'
      ) THEN
        ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS tenant_select_fcm_tokens ON public.fcm_tokens;
        CREATE POLICY tenant_select_fcm_tokens ON public.fcm_tokens FOR SELECT USING (tenant_id = public.current_tenant_id());
        DROP POLICY IF EXISTS tenant_modify_fcm_tokens ON public.fcm_tokens;
        CREATE POLICY tenant_modify_fcm_tokens ON public.fcm_tokens FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
        CREATE INDEX IF NOT EXISTS idx_fcm_tokens_tenant_id ON public.fcm_tokens(tenant_id);
      END IF;

      -- roles
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='roles' AND column_name='tenant_id'
      ) THEN
        ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS tenant_select_roles ON public.roles;
        CREATE POLICY tenant_select_roles ON public.roles FOR SELECT USING (tenant_id = public.current_tenant_id());
        DROP POLICY IF EXISTS tenant_modify_roles ON public.roles;
        CREATE POLICY tenant_modify_roles ON public.roles FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
        CREATE INDEX IF NOT EXISTS idx_roles_tenant_id ON public.roles(tenant_id);
      END IF;

      -- role_contexts
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='role_contexts' AND column_name='tenant_id'
      ) THEN
        ALTER TABLE public.role_contexts ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS tenant_select_role_contexts ON public.role_contexts;
        CREATE POLICY tenant_select_role_contexts ON public.role_contexts FOR SELECT USING (tenant_id = public.current_tenant_id());
        DROP POLICY IF EXISTS tenant_modify_role_contexts ON public.role_contexts;
        CREATE POLICY tenant_modify_role_contexts ON public.role_contexts FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
        CREATE INDEX IF NOT EXISTS idx_role_contexts_tenant_id ON public.role_contexts(tenant_id);
      END IF;

      -- role_permissions
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='role_permissions' AND column_name='tenant_id'
      ) THEN
        ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS tenant_select_role_permissions ON public.role_permissions;
        CREATE POLICY tenant_select_role_permissions ON public.role_permissions FOR SELECT USING (tenant_id = public.current_tenant_id());
        DROP POLICY IF EXISTS tenant_modify_role_permissions ON public.role_permissions;
        CREATE POLICY tenant_modify_role_permissions ON public.role_permissions FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
        CREATE INDEX IF NOT EXISTS idx_role_permissions_tenant_id ON public.role_permissions(tenant_id);
      END IF;

      -- user_custom_permissions
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='user_custom_permissions' AND column_name='tenant_id'
      ) THEN
        ALTER TABLE public.user_custom_permissions ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS tenant_select_user_custom_permissions ON public.user_custom_permissions;
        CREATE POLICY tenant_select_user_custom_permissions ON public.user_custom_permissions FOR SELECT USING (tenant_id = public.current_tenant_id());
        DROP POLICY IF EXISTS tenant_modify_user_custom_permissions ON public.user_custom_permissions;
        CREATE POLICY tenant_modify_user_custom_permissions ON public.user_custom_permissions FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
        CREATE INDEX IF NOT EXISTS idx_user_custom_permissions_tenant_id ON public.user_custom_permissions(tenant_id);
      END IF;

      -- relacionamentos_familiares
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='relacionamentos_familiares' AND column_name='tenant_id'
      ) THEN
        ALTER TABLE public.relacionamentos_familiares ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS tenant_select_relacionamentos_familiares ON public.relacionamentos_familiares;
        CREATE POLICY tenant_select_relacionamentos_familiares ON public.relacionamentos_familiares FOR SELECT USING (tenant_id = public.current_tenant_id());
        DROP POLICY IF EXISTS tenant_modify_relacionamentos_familiares ON public.relacionamentos_familiares;
        CREATE POLICY tenant_modify_relacionamentos_familiares ON public.relacionamentos_familiares FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
        CREATE INDEX IF NOT EXISTS idx_relacionamentos_familiares_tenant_id ON public.relacionamentos_familiares(tenant_id);
      END IF;
    END $$;

  CREATE OR REPLACE FUNCTION public.current_tenant_id()
  RETURNS uuid
  LANGUAGE SQL
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $$
    SELECT COALESCE(
      NULLIF(current_setting('app.tenant_id', true), '')::uuid,
      (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'tenant_id')::uuid,
      (current_setting('request.jwt.claims', true)::jsonb -> 'user_metadata' ->> 'tenant_id')::uuid,
      (
        SELECT ua.tenant_id
        FROM public.user_account ua
        WHERE ua.auth_user_id = auth.uid()
        LIMIT 1
      )
    )
  $$;

  CREATE OR REPLACE FUNCTION public.set_tenant_id_default()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $$
  BEGIN
    IF NEW.tenant_id IS NULL THEN
      NEW.tenant_id := public.current_tenant_id();
    END IF;
    RETURN NEW;
  END;
  $$;

  DO $$
  BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='ministry') THEN
      DROP TRIGGER IF EXISTS trg_ministry_set_tenant ON public.ministry;
      CREATE TRIGGER trg_ministry_set_tenant
        BEFORE INSERT OR UPDATE ON public.ministry
        FOR EACH ROW EXECUTE FUNCTION public.set_tenant_id_default();
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='notifications') THEN
      DROP TRIGGER IF EXISTS trg_notifications_set_tenant ON public.notifications;
      CREATE TRIGGER trg_notifications_set_tenant
        BEFORE INSERT OR UPDATE ON public.notifications
        FOR EACH ROW EXECUTE FUNCTION public.set_tenant_id_default();
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='notification_preferences') THEN
      DROP TRIGGER IF EXISTS trg_notification_preferences_set_tenant ON public.notification_preferences;
      CREATE TRIGGER trg_notification_preferences_set_tenant
        BEFORE INSERT OR UPDATE ON public.notification_preferences
        FOR EACH ROW EXECUTE FUNCTION public.set_tenant_id_default();
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='roles') THEN
      DROP TRIGGER IF EXISTS trg_roles_set_tenant ON public.roles;
      CREATE TRIGGER trg_roles_set_tenant
        BEFORE INSERT OR UPDATE ON public.roles
        FOR EACH ROW EXECUTE FUNCTION public.set_tenant_id_default();
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='contribution_info') THEN
      DROP TRIGGER IF EXISTS trg_contribution_info_set_tenant ON public.contribution_info;
      CREATE TRIGGER trg_contribution_info_set_tenant
        BEFORE INSERT OR UPDATE ON public.contribution_info
        FOR EACH ROW EXECUTE FUNCTION public.set_tenant_id_default();
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='role_contexts') THEN
      DROP TRIGGER IF EXISTS trg_role_contexts_set_tenant ON public.role_contexts;
      CREATE TRIGGER trg_role_contexts_set_tenant
        BEFORE INSERT OR UPDATE ON public.role_contexts
        FOR EACH ROW EXECUTE FUNCTION public.set_tenant_id_default();
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='role_permissions') THEN
      DROP TRIGGER IF EXISTS trg_role_permissions_set_tenant ON public.role_permissions;
      CREATE TRIGGER trg_role_permissions_set_tenant
        BEFORE INSERT OR UPDATE ON public.role_permissions
        FOR EACH ROW EXECUTE FUNCTION public.set_tenant_id_default();
    END IF;
  END $$;

  CREATE OR REPLACE FUNCTION public.get_unread_notifications_count(target_user_id UUID)
  RETURNS BIGINT 
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  BEGIN
    RETURN (
      SELECT COUNT(*)
      FROM public.notifications n
      WHERE n.user_id = target_user_id
        AND n.status != 'read'
        AND n.tenant_id = public.current_tenant_id()
    );
  END;
  $function$;

  CREATE OR REPLACE FUNCTION public.mark_all_notifications_as_read(target_user_id UUID)
  RETURNS VOID 
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  BEGIN
    UPDATE public.notifications n
    SET status = 'read', read_at = NOW()
    WHERE n.user_id = target_user_id
      AND n.status != 'read'
      AND n.tenant_id = public.current_tenant_id();
  END;
  $function$;

  DO $$
  BEGIN
    ALTER TABLE public.user_account ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_user_account ON public.user_account;
    CREATE POLICY tenant_select_user_account ON public.user_account FOR SELECT USING (auth.uid() = auth_user_id);
    DROP POLICY IF EXISTS tenant_modify_user_account ON public.user_account;
    CREATE POLICY tenant_modify_user_account ON public.user_account FOR ALL USING (auth.uid() = auth_user_id) WITH CHECK (auth.uid() = auth_user_id);
  END $$;

  DO $$
  BEGIN
    IF EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema='public' AND table_name='contribution_info' AND column_name='tenant_id'
    ) THEN
      ALTER TABLE public.contribution_info ENABLE ROW LEVEL SECURITY;
      DROP POLICY IF EXISTS tenant_select_contribution_info ON public.contribution_info;
      CREATE POLICY tenant_select_contribution_info ON public.contribution_info FOR SELECT USING (tenant_id = public.current_tenant_id());
      DROP POLICY IF EXISTS tenant_modify_contribution_info ON public.contribution_info;
      CREATE POLICY tenant_modify_contribution_info ON public.contribution_info FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
      CREATE INDEX IF NOT EXISTS idx_contribution_info_tenant_id ON public.contribution_info(tenant_id);
    END IF;
  END $$;
