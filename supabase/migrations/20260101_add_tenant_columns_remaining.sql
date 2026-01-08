DO $$
BEGIN
  -- visitor_visit
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='visitor_visit') THEN
    ALTER TABLE public.visitor_visit ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.visitor_visit ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.visitor_visit vv
      SET tenant_id = v.tenant_id
    FROM public.visitor v
    WHERE vv.visitor_id = v.id AND vv.tenant_id IS NULL;
    ALTER TABLE public.visitor_visit ALTER COLUMN tenant_id SET NOT NULL;
    CREATE INDEX IF NOT EXISTS idx_visitor_visit_tenant_id ON public.visitor_visit(tenant_id);
  END IF;

  -- visitor_followup
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='visitor_followup') THEN
    ALTER TABLE public.visitor_followup ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.visitor_followup ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.visitor_followup vf
      SET tenant_id = v.tenant_id
    FROM public.visitor v
    WHERE vf.visitor_id = v.id AND vf.tenant_id IS NULL;
    ALTER TABLE public.visitor_followup ALTER COLUMN tenant_id SET NOT NULL;
    CREATE INDEX IF NOT EXISTS idx_visitor_followup_tenant_id ON public.visitor_followup(tenant_id);
  END IF;

  -- kids_authorized_guardian
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='kids_authorized_guardian') THEN
    ALTER TABLE public.kids_authorized_guardian ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.kids_authorized_guardian ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.kids_authorized_guardian kag
      SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE kag.child_id = ua.id AND kag.tenant_id IS NULL;
    ALTER TABLE public.kids_authorized_guardian ALTER COLUMN tenant_id SET NOT NULL;
    CREATE INDEX IF NOT EXISTS idx_kids_authorized_guardian_tenant_id ON public.kids_authorized_guardian(tenant_id);
  END IF;

  -- kids_checkin_token
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='kids_checkin_token') THEN
    ALTER TABLE public.kids_checkin_token ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.kids_checkin_token ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.kids_checkin_token kct
      SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE kct.child_id = ua.id AND kct.tenant_id IS NULL;
    ALTER TABLE public.kids_checkin_token ALTER COLUMN tenant_id SET NOT NULL;
    CREATE INDEX IF NOT EXISTS idx_kids_checkin_token_tenant_id ON public.kids_checkin_token(tenant_id);
  END IF;

  -- kids_attendance
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='kids_attendance') THEN
    ALTER TABLE public.kids_attendance ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.kids_attendance ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    DO $inner$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='worship_service' AND column_name='tenant_id'
      ) THEN
        UPDATE public.kids_attendance ka
          SET tenant_id = ws.tenant_id
        FROM public.worship_service ws
        WHERE ka.worship_service_id = ws.id AND ka.tenant_id IS NULL;
      ELSE
        UPDATE public.kids_attendance ka
          SET tenant_id = ua.tenant_id
        FROM public.worship_service ws
        JOIN public.user_account ua ON ws.created_by = ua.id
        WHERE ka.worship_service_id = ws.id AND ka.tenant_id IS NULL;
      END IF;
    END $inner$;
    ALTER TABLE public.kids_attendance ALTER COLUMN tenant_id SET NOT NULL;
    CREATE INDEX IF NOT EXISTS idx_kids_attendance_tenant_id ON public.kids_attendance(tenant_id);
  END IF;

  -- support_material
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='support_material') THEN
    ALTER TABLE public.support_material ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.support_material ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.support_material sm
      SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE sm.created_by = ua.id AND sm.tenant_id IS NULL;
    ALTER TABLE public.support_material ALTER COLUMN tenant_id SET NOT NULL;
    CREATE INDEX IF NOT EXISTS idx_support_material_tenant_id ON public.support_material(tenant_id);
  END IF;

  -- support_material_module
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='support_material_module') THEN
    ALTER TABLE public.support_material_module ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.support_material_module ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.support_material_module smm
      SET tenant_id = sm.tenant_id
    FROM public.support_material sm
    WHERE smm.material_id = sm.id AND smm.tenant_id IS NULL;
    ALTER TABLE public.support_material_module ALTER COLUMN tenant_id SET NOT NULL;
    CREATE INDEX IF NOT EXISTS idx_support_material_module_tenant_id ON public.support_material_module(tenant_id);
  END IF;

  -- support_material_link
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='support_material_link') THEN
    ALTER TABLE public.support_material_link ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.support_material_link ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.support_material_link sml
      SET tenant_id = sm.tenant_id
    FROM public.support_material sm
    WHERE sml.material_id = sm.id AND sml.tenant_id IS NULL;
    ALTER TABLE public.support_material_link ALTER COLUMN tenant_id SET NOT NULL;
    CREATE INDEX IF NOT EXISTS idx_support_material_link_tenant_id ON public.support_material_link(tenant_id);
  END IF;

  -- ministry
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='ministry') THEN
    ALTER TABLE public.ministry ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.ministry ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.ministry m
      SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE m.created_by = ua.id AND m.tenant_id IS NULL;
    UPDATE public.ministry m
      SET tenant_id = ua.tenant_id
    FROM public.ministry_member mm
    JOIN public.user_account ua ON ua.id = mm.user_id
    WHERE mm.ministry_id = m.id AND m.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.ministry WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.ministry ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_ministry_tenant_id ON public.ministry(tenant_id);
  END IF;

  -- ministry_member
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='ministry_member') THEN
    ALTER TABLE public.ministry_member ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.ministry_member ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.ministry_member mm
      SET tenant_id = m.tenant_id
    FROM public.ministry m
    WHERE mm.ministry_id = m.id AND mm.tenant_id IS NULL;
    ALTER TABLE public.ministry_member ALTER COLUMN tenant_id SET NOT NULL;
    CREATE INDEX IF NOT EXISTS idx_ministry_member_tenant_id ON public.ministry_member(tenant_id);
  END IF;

  -- ministry_schedule
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='ministry_schedule') THEN
    ALTER TABLE public.ministry_schedule ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.ministry_schedule ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.ministry_schedule ms
      SET tenant_id = COALESCE(e.tenant_id, m.tenant_id)
    FROM public.event e, public.ministry m
    WHERE ms.event_id = e.id AND ms.ministry_id = m.id AND ms.tenant_id IS NULL;
    ALTER TABLE public.ministry_schedule ALTER COLUMN tenant_id SET NOT NULL;
    CREATE INDEX IF NOT EXISTS idx_ministry_schedule_tenant_id ON public.ministry_schedule(tenant_id);
  END IF;

  -- ministry_function (catalog)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='ministry_function') THEN
    ALTER TABLE public.ministry_function ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.ministry_function ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    -- replicate existing global functions for each tenant if tenant_id is NULL
    INSERT INTO public.ministry_function (id, name, code, description, requires_skill, is_active, created_at, tenant_id)
    SELECT gen_random_uuid(), mf.name, mf.code, mf.description, mf.requires_skill, COALESCE(mf.is_active, true), mf.created_at, t.id
    FROM public.ministry_function mf
    CROSS JOIN public.tenant t
    WHERE mf.tenant_id IS NULL
    ON CONFLICT DO NOTHING;
    CREATE INDEX IF NOT EXISTS idx_ministry_function_tenant_id ON public.ministry_function(tenant_id);
  END IF;

  -- member_function (link)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='member_function') THEN
    ALTER TABLE public.member_function ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.member_function ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.member_function mf
      SET tenant_id = m.tenant_id
    FROM public.ministry m
    WHERE mf.ministry_id = m.id AND mf.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.member_function WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.member_function ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_member_function_tenant_id ON public.member_function(tenant_id);
  END IF;

  -- bible_bookmark
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='bible_bookmark') THEN
    ALTER TABLE public.bible_bookmark ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.bible_bookmark ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.bible_bookmark bb
      SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE bb.user_id = ua.id AND bb.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.bible_bookmark WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.bible_bookmark ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_bible_bookmark_tenant_id ON public.bible_bookmark(tenant_id);
  END IF;

  -- contribution_info
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='contribution_info') THEN
    ALTER TABLE public.contribution_info ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.contribution_info ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.contribution_info ci
      SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
    WHERE ci.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.contribution_info WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.contribution_info ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_contribution_info_tenant_id ON public.contribution_info(tenant_id);
  END IF;

  -- notifications
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='notifications') THEN
    ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.notifications ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.notifications n
      SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE n.user_id = ua.id AND n.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.notifications WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.notifications ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_notifications_tenant_id ON public.notifications(tenant_id);
  END IF;

  -- notification_preferences
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='notification_preferences') THEN
    ALTER TABLE public.notification_preferences ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.notification_preferences ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.notification_preferences np
      SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE np.user_id = ua.id AND np.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.notification_preferences WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.notification_preferences ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_notification_preferences_tenant_id ON public.notification_preferences(tenant_id);
  END IF;

  -- fcm_tokens
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='fcm_tokens') THEN
    ALTER TABLE public.fcm_tokens ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.fcm_tokens ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.fcm_tokens ft
      SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE ft.user_id = ua.id AND ft.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.fcm_tokens WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.fcm_tokens ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_fcm_tokens_tenant_id ON public.fcm_tokens(tenant_id);
  END IF;

  -- roles
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='roles') THEN
    ALTER TABLE public.roles ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.roles ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.roles r
      SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE r.created_by = ua.id AND r.tenant_id IS NULL;
    -- fallback: replicate global roles to each tenant if still NULL
    INSERT INTO public.roles (id, name, description, parent_role_id, hierarchy_level, allows_context, is_active, created_by, created_at, updated_at, tenant_id)
    SELECT gen_random_uuid(), r.name, r.description, r.parent_role_id, r.hierarchy_level, r.allows_context, COALESCE(r.is_active, true), NULL, r.created_at, r.updated_at, t.id
    FROM public.roles r
    CROSS JOIN public.tenant t
    WHERE r.tenant_id IS NULL
    ON CONFLICT DO NOTHING;
    CREATE INDEX IF NOT EXISTS idx_roles_tenant_id ON public.roles(tenant_id);
  END IF;

  -- role_contexts
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='role_contexts') THEN
    ALTER TABLE public.role_contexts ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.role_contexts ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.role_contexts rc
      SET tenant_id = r.tenant_id
    FROM public.roles r
    WHERE rc.role_id = r.id AND rc.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.role_contexts WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.role_contexts ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_role_contexts_tenant_id ON public.role_contexts(tenant_id);
  END IF;

  -- role_permissions
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='role_permissions') THEN
    ALTER TABLE public.role_permissions ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.role_permissions ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.role_permissions rp
      SET tenant_id = r.tenant_id
    FROM public.roles r
    WHERE rp.role_id = r.id AND rp.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.role_permissions WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.role_permissions ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_role_permissions_tenant_id ON public.role_permissions(tenant_id);
  END IF;

  -- user_custom_permissions
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='user_custom_permissions') THEN
    ALTER TABLE public.user_custom_permissions ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.user_custom_permissions ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.user_custom_permissions ucp
      SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE ucp.user_id = ua.id AND ucp.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.user_custom_permissions WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.user_custom_permissions ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_user_custom_permissions_tenant_id ON public.user_custom_permissions(tenant_id);
  END IF;

  -- relacionamentos_familiares
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='relacionamentos_familiares') THEN
    ALTER TABLE public.relacionamentos_familiares ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.relacionamentos_familiares ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.relacionamentos_familiares rf
      SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE rf.membro_id = ua.id AND rf.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.relacionamentos_familiares WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.relacionamentos_familiares ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_relacionamentos_familiares_tenant_id ON public.relacionamentos_familiares(tenant_id);
  END IF;

  -- church_info
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='church_info') THEN
    ALTER TABLE public.church_info ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.church_info ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.church_info ci
      SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
    WHERE ci.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.church_info WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.church_info ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_church_info_tenant_id ON public.church_info(tenant_id);
  END IF;

  -- access_level_history
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='access_level_history') THEN
    ALTER TABLE public.access_level_history ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.access_level_history ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.access_level_history alh
      SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE alh.user_id = ua.id AND alh.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.access_level_history WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.access_level_history ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_access_level_history_tenant_id ON public.access_level_history(tenant_id);
  END IF;

  -- user_access_level
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='user_access_level') THEN
    ALTER TABLE public.user_access_level ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.user_access_level ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.user_access_level ual
      SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE ual.user_id = ua.id AND ual.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.user_access_level WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.user_access_level ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_user_access_level_tenant_id ON public.user_access_level(tenant_id);
  END IF;

  -- dashboard_widget
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='dashboard_widget') THEN
    ALTER TABLE public.dashboard_widget ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.dashboard_widget ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.dashboard_widget dw
      SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
    WHERE dw.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.dashboard_widget WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.dashboard_widget ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_dashboard_widget_tenant_id ON public.dashboard_widget(tenant_id);
  END IF;

  -- study_groups
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='study_groups') THEN
    ALTER TABLE public.study_groups ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.study_groups ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.study_groups sg
      SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE sg.created_by = ua.id AND sg.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.study_groups WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.study_groups ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_study_groups_tenant_id ON public.study_groups(tenant_id);
  END IF;

  -- study_lessons
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='study_lessons') THEN
    ALTER TABLE public.study_lessons ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.study_lessons ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.study_lessons sl
      SET tenant_id = sg.tenant_id
    FROM public.study_groups sg
    WHERE sl.study_group_id = sg.id AND sl.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.study_lessons WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.study_lessons ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_study_lessons_tenant_id ON public.study_lessons(tenant_id);
  END IF;

  -- study_participants
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='study_participants') THEN
    ALTER TABLE public.study_participants ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.study_participants ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.study_participants sp
      SET tenant_id = COALESCE(sg.tenant_id, ua.tenant_id)
    FROM public.study_groups sg, public.user_account ua
    WHERE sp.study_group_id = sg.id AND ua.id = sp.user_id AND sp.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.study_participants WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.study_participants ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_study_participants_tenant_id ON public.study_participants(tenant_id);
  END IF;

  -- testimonies
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='testimonies') THEN
    ALTER TABLE public.testimonies ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.testimonies ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.testimonies t
      SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE t.author_id = ua.id AND t.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.testimonies WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.testimonies ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_testimonies_tenant_id ON public.testimonies(tenant_id);
  END IF;

  -- prayer_requests
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='prayer_requests') THEN
    ALTER TABLE public.prayer_requests ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.prayer_requests ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.prayer_requests pr
      SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE pr.author_id = ua.id AND pr.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.prayer_requests WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.prayer_requests ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_prayer_requests_tenant_id ON public.prayer_requests(tenant_id);
  END IF;

  -- prayer_request_prayers
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='prayer_request_prayers') THEN
    ALTER TABLE public.prayer_request_prayers ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.prayer_request_prayers ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.prayer_request_prayers prp
      SET tenant_id = pr.tenant_id
    FROM public.prayer_requests pr
    WHERE prp.prayer_request_id = pr.id AND prp.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.prayer_request_prayers WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.prayer_request_prayers ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_prayer_request_prayers_tenant_id ON public.prayer_request_prayers(tenant_id);
  END IF;

  -- expense
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='expense') THEN
    ALTER TABLE public.expense ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.expense ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.expense e
      SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE e.created_by = ua.id AND e.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.expense WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.expense ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_expense_tenant_id ON public.expense(tenant_id);
  END IF;

  -- financial_goal
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='financial_goal') THEN
    ALTER TABLE public.financial_goal ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.financial_goal ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.financial_goal fg
      SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE fg.created_by = ua.id AND fg.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.financial_goal WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.financial_goal ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_financial_goal_tenant_id ON public.financial_goal(tenant_id);
  END IF;

  -- fund
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='fund') THEN
    ALTER TABLE public.fund ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.fund ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.fund f
      SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
    WHERE f.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.fund WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.fund ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_fund_tenant_id ON public.fund(tenant_id);
  END IF;

  -- permissions
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='permissions') THEN
    ALTER TABLE public.permissions ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.permissions ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.permissions p
      SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
    WHERE p.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.permissions WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.permissions ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_permissions_tenant_id ON public.permissions(tenant_id);
  END IF;

  -- user_roles
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='user_roles') THEN
    ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.user_roles ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.user_roles ur
      SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE ur.user_id = ua.id AND ur.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.user_roles WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.user_roles ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_user_roles_tenant_id ON public.user_roles(tenant_id);
  END IF;

  -- permission_audit_log
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='permission_audit_log') THEN
    ALTER TABLE public.permission_audit_log ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.permission_audit_log ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.permission_audit_log pal
      SET tenant_id = COALESCE(
        (SELECT ua_performer.tenant_id FROM public.user_account ua_performer WHERE ua_performer.id = pal.performed_by),
        (SELECT ua_user.tenant_id FROM public.user_account ua_user WHERE ua_user.id = pal.user_id),
        (SELECT id FROM public.tenant LIMIT 1)
      )
    WHERE pal.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.permission_audit_log WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.permission_audit_log ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_permission_audit_log_tenant_id ON public.permission_audit_log(tenant_id);
  END IF;

  -- custom_report
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='custom_report') THEN
    ALTER TABLE public.custom_report ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.custom_report ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.custom_report cr
      SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
    WHERE cr.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.custom_report WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.custom_report ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_custom_report_tenant_id ON public.custom_report(tenant_id);
  END IF;

  -- custom_report_permission
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='custom_report_permission') THEN
    ALTER TABLE public.custom_report_permission ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.custom_report_permission ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.custom_report_permission crp
      SET tenant_id = cr.tenant_id
    FROM public.custom_report cr
    WHERE crp.report_id = cr.id AND crp.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.custom_report_permission WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.custom_report_permission ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_custom_report_permission_tenant_id ON public.custom_report_permission(tenant_id);
  END IF;

  -- worship_attendance
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='worship_attendance') THEN
    ALTER TABLE public.worship_attendance ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.worship_attendance ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.worship_attendance wa
      SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE wa.user_id = ua.id AND wa.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.worship_attendance WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.worship_attendance ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_worship_attendance_tenant_id ON public.worship_attendance(tenant_id);
  END IF;

  -- step
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='step') THEN
    ALTER TABLE public.step ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.step ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.step s
      SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
    WHERE s.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.step WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.step ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_step_tenant_id ON public.step(tenant_id);
  END IF;

  -- Optional/unknown tables: add tenant_id if they exist (safe guards)
  -- community_post_likes
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='community_post_likes') THEN
    ALTER TABLE public.community_post_likes ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.community_post_likes ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.community_post_likes cpl
      SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE cpl.user_id = ua.id AND cpl.tenant_id IS NULL;
    CREATE INDEX IF NOT EXISTS idx_community_post_likes_tenant_id ON public.community_post_likes(tenant_id);
  END IF;

  -- agent_config
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='agent_config') THEN
    ALTER TABLE public.agent_config ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.agent_config ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.agent_config ac
      SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
    WHERE ac.tenant_id IS NULL;
    CREATE INDEX IF NOT EXISTS idx_agent_config_tenant_id ON public.agent_config(tenant_id);
  END IF;

  -- dispatch_rule
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='dispatch_rule') THEN
    ALTER TABLE public.dispatch_rule ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.dispatch_rule ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.dispatch_rule dr
      SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
    WHERE dr.tenant_id IS NULL;
    CREATE INDEX IF NOT EXISTS idx_dispatch_rule_tenant_id ON public.dispatch_rule(tenant_id);
  END IF;

  -- dispatch_job
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='dispatch_job') THEN
    ALTER TABLE public.dispatch_job ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.dispatch_job ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.dispatch_job dj
      SET tenant_id = dr.tenant_id
    FROM public.dispatch_rule dr
    WHERE dj.rule_id = dr.id AND dj.tenant_id IS NULL;
    CREATE INDEX IF NOT EXISTS idx_dispatch_job_tenant_id ON public.dispatch_job(tenant_id);
  END IF;

  -- dispatch_log
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='dispatch_log') THEN
    ALTER TABLE public.dispatch_log ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.dispatch_log ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.dispatch_log dl
      SET tenant_id = COALESCE(
        (SELECT dj.tenant_id FROM public.dispatch_job dj WHERE dj.id = dl.job_id),
        (SELECT id FROM public.tenant LIMIT 1)
      )
    WHERE dl.tenant_id IS NULL;
    CREATE INDEX IF NOT EXISTS idx_dispatch_log_tenant_id ON public.dispatch_log(tenant_id);
  END IF;

  -- integration_settings
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='integration_settings') THEN
    ALTER TABLE public.integration_settings ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.integration_settings ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.integration_settings ins
      SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
    WHERE ins.tenant_id IS NULL;
    CREATE INDEX IF NOT EXISTS idx_integration_settings_tenant_id ON public.integration_settings(tenant_id);
  END IF;

  -- message_template
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='message_template') THEN
    ALTER TABLE public.message_template ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.message_template ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.message_template mt
      SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
    WHERE mt.tenant_id IS NULL;
    CREATE INDEX IF NOT EXISTS idx_message_template_tenant_id ON public.message_template(tenant_id);
  END IF;

  -- user_account_sync_log
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='user_account_sync_log') THEN
    ALTER TABLE public.user_account_sync_log ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.user_account_sync_log ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.user_account_sync_log uasl
      SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
    WHERE uasl.tenant_id IS NULL;
    CREATE INDEX IF NOT EXISTS idx_user_account_sync_log_tenant_id ON public.user_account_sync_log(tenant_id);
  END IF;

  -- user_followup
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='user_followup') THEN
    ALTER TABLE public.user_followup ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.user_followup ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.user_followup uf
      SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE uf.user_id = ua.id AND uf.tenant_id IS NULL;
    CREATE INDEX IF NOT EXISTS idx_user_followup_tenant_id ON public.user_followup(tenant_id);
  END IF;

  -- user_visit
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='user_visit') THEN
    ALTER TABLE public.user_visit ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.user_visit ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.user_visit uv
      SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE uv.user_id = ua.id AND uv.tenant_id IS NULL;
    CREATE INDEX IF NOT EXISTS idx_user_visit_tenant_id ON public.user_visit(tenant_id);
  END IF;

  -- whatsapp_relatorios_automaticos
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='whatsapp_relatorios_automaticos') THEN
    ALTER TABLE public.whatsapp_relatorios_automaticos ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.whatsapp_relatorios_automaticos ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.whatsapp_relatorios_automaticos wra
      SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
    WHERE wra.tenant_id IS NULL;
    CREATE INDEX IF NOT EXISTS idx_whatsapp_relatorios_automaticos_tenant_id ON public.whatsapp_relatorios_automaticos(tenant_id);
  END IF;

  -- event_type (if table exists separately)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='event_type') THEN
    ALTER TABLE public.event_type ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.event_type ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.event_type et
      SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
    WHERE et.tenant_id IS NULL;
    CREATE INDEX IF NOT EXISTS idx_event_type_tenant_id ON public.event_type(tenant_id);
  END IF;

  -- church_schedule
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='church_schedule') THEN
    ALTER TABLE public.church_schedule ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.church_schedule ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.church_schedule cs
      SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
    WHERE cs.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.church_schedule WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.church_schedule ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_church_schedule_tenant_id ON public.church_schedule(tenant_id);
  END IF;

  -- devotionals
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='devotionals') THEN
    ALTER TABLE public.devotionals ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.devotionals ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.devotionals d
      SET tenant_id = (SELECT ua.tenant_id FROM public.user_account ua WHERE ua.id = d.author_id)
    WHERE d.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.devotionals WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.devotionals ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_devotionals_tenant_id ON public.devotionals(tenant_id);
  END IF;

  -- devotional_readings
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='devotional_readings') THEN
    ALTER TABLE public.devotional_readings ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.devotional_readings ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.devotional_readings dr
      SET tenant_id = d.tenant_id
    FROM public.devotionals d
    WHERE dr.devotional_id = d.id AND dr.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.devotional_readings WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.devotional_readings ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_devotional_readings_tenant_id ON public.devotional_readings(tenant_id);
  END IF;

  -- dispatch_webhook
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='dispatch_webhook') THEN
    ALTER TABLE public.dispatch_webhook ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.dispatch_webhook ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    DO $inner$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='dispatch_webhook' AND column_name='job_id'
      ) THEN
        UPDATE public.dispatch_webhook dw
          SET tenant_id = (SELECT dj.tenant_id FROM public.dispatch_job dj WHERE dj.id = dw.job_id)
        WHERE dw.tenant_id IS NULL;
      ELSIF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='dispatch_webhook' AND column_name='rule_id'
      ) THEN
        UPDATE public.dispatch_webhook dw
          SET tenant_id = (SELECT dr.tenant_id FROM public.dispatch_rule dr WHERE dr.id = dw.rule_id)
        WHERE dw.tenant_id IS NULL;
      ELSE
        UPDATE public.dispatch_webhook dw
          SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
        WHERE dw.tenant_id IS NULL;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM public.dispatch_webhook WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.dispatch_webhook ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_dispatch_webhook_tenant_id ON public.dispatch_webhook(tenant_id);
  END IF;

  -- member_step
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='member_step') THEN
    ALTER TABLE public.member_step ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.member_step ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    DO $inner$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='member_step' AND column_name='member_id'
      ) THEN
        UPDATE public.member_step ms
          SET tenant_id = (SELECT ua.tenant_id FROM public.user_account ua WHERE ua.id = ms.member_id)
        WHERE ms.tenant_id IS NULL;
      ELSIF EXISTS (
        SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='member_step' AND column_name='user_id'
      ) THEN
        UPDATE public.member_step ms
          SET tenant_id = (SELECT ua.tenant_id FROM public.user_account ua WHERE ua.id = ms.user_id)
        WHERE ms.tenant_id IS NULL;
      ELSE
        UPDATE public.member_step ms
          SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
        WHERE ms.tenant_id IS NULL;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM public.member_step WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.member_step ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_member_step_tenant_id ON public.member_step(tenant_id);
  END IF;

  -- member_tag
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='member_tag') THEN
    ALTER TABLE public.member_tag ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.member_tag ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    DO $inner$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='member_tag' AND column_name='member_id'
      ) THEN
        UPDATE public.member_tag mt
          SET tenant_id = (SELECT ua.tenant_id FROM public.user_account ua WHERE ua.id = mt.member_id)
        WHERE mt.tenant_id IS NULL;
      ELSIF EXISTS (
        SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='member_tag' AND column_name='user_id'
      ) THEN
        UPDATE public.member_tag mt
          SET tenant_id = (SELECT ua.tenant_id FROM public.user_account ua WHERE ua.id = mt.user_id)
        WHERE mt.tenant_id IS NULL;
      ELSE
        UPDATE public.member_tag mt
          SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
        WHERE mt.tenant_id IS NULL;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM public.member_tag WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.member_tag ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_member_tag_tenant_id ON public.member_tag(tenant_id);
  END IF;

  -- prayer_request_testimonies
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='prayer_request_testimonies') THEN
    ALTER TABLE public.prayer_request_testimonies ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.prayer_request_testimonies ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    DO $inner$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='prayer_request_testimonies' AND column_name='testimony_id'
      ) THEN
        UPDATE public.prayer_request_testimonies prt
          SET tenant_id = COALESCE(
            (SELECT pr.tenant_id FROM public.prayer_requests pr WHERE pr.id = prt.prayer_request_id),
            (SELECT t.tenant_id FROM public.testimonies t WHERE t.id = prt.testimony_id),
            (SELECT id FROM public.tenant LIMIT 1)
          )
        WHERE prt.tenant_id IS NULL;
      ELSIF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='prayer_request_testimonies' AND column_name='testimony'
      ) THEN
        UPDATE public.prayer_request_testimonies prt
          SET tenant_id = COALESCE(
            (SELECT pr.tenant_id FROM public.prayer_requests pr WHERE pr.id = prt.prayer_request_id),
            (SELECT t.tenant_id FROM public.testimonies t WHERE t.id = prt.testimony::uuid),
            (SELECT id FROM public.tenant LIMIT 1)
          )
        WHERE prt.tenant_id IS NULL;
      ELSE
        UPDATE public.prayer_request_testimonies prt
          SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
        WHERE prt.tenant_id IS NULL;
      END IF;
    END $inner$;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.prayer_request_testimonies WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.prayer_request_testimonies ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_prayer_request_testimonies_tenant_id ON public.prayer_request_testimonies(tenant_id);
  END IF;

  -- quick_news
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='quick_news') THEN
    ALTER TABLE public.quick_news ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.quick_news ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    DO $inner$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='quick_news' AND column_name='created_by'
      ) THEN
        UPDATE public.quick_news qn
          SET tenant_id = (SELECT ua.tenant_id FROM public.user_account ua WHERE ua.id = qn.created_by)
        WHERE qn.tenant_id IS NULL;
      ELSE
        UPDATE public.quick_news qn
          SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
        WHERE qn.tenant_id IS NULL;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM public.quick_news WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.quick_news ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_quick_news_tenant_id ON public.quick_news(tenant_id);
  END IF;

  -- study_attendance
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='study_attendance') THEN
    ALTER TABLE public.study_attendance ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.study_attendance ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    DO $inner$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='study_lessons' AND column_name='tenant_id'
      ) THEN
        UPDATE public.study_attendance sa
          SET tenant_id = (SELECT sl.tenant_id FROM public.study_lessons sl WHERE sl.id = sa.study_lesson_id)
        WHERE sa.tenant_id IS NULL;
      ELSE
        UPDATE public.study_attendance sa
          SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
        WHERE sa.tenant_id IS NULL;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM public.study_attendance WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.study_attendance ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_study_attendance_tenant_id ON public.study_attendance(tenant_id);
  END IF;

  -- study_comments
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='study_comments') THEN
    ALTER TABLE public.study_comments ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.study_comments ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    DO $inner$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='study_lessons' AND column_name='tenant_id'
      ) THEN
        UPDATE public.study_comments sc
          SET tenant_id = (SELECT sl.tenant_id FROM public.study_lessons sl WHERE sl.id = sc.study_lesson_id)
        WHERE sc.tenant_id IS NULL;
      ELSE
        UPDATE public.study_comments sc
          SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
        WHERE sc.tenant_id IS NULL;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM public.study_comments WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.study_comments ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_study_comments_tenant_id ON public.study_comments(tenant_id);
  END IF;

  -- study_resources
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='study_resources') THEN
    ALTER TABLE public.study_resources ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.study_resources ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.study_resources sr
      SET tenant_id = (SELECT sg.tenant_id FROM public.study_groups sg WHERE sg.id = sr.study_group_id)
    WHERE sr.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.study_resources WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.study_resources ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_study_resources_tenant_id ON public.study_resources(tenant_id);
  END IF;

  -- tag
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='tag') THEN
    ALTER TABLE public.tag ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.tag ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
    UPDATE public.tag t
      SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
    WHERE t.tenant_id IS NULL;
    DO $inner$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM public.tag WHERE tenant_id IS NULL) THEN
        ALTER TABLE public.tag ALTER COLUMN tenant_id SET NOT NULL;
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_tag_tenant_id ON public.tag(tenant_id);
  END IF;
END $$;
DROP VIEW IF EXISTS public.v_dispatch_jobs_pending;
CREATE VIEW public.v_dispatch_jobs_pending AS
SELECT dj.*
FROM public.dispatch_job dj
WHERE dj.status::text = 'pending'
  AND dj.tenant_id = public.current_tenant_id();
ALTER VIEW public.v_dispatch_jobs_pending SET (security_invoker = true);
DROP VIEW IF EXISTS public.v_dispatch_rules_active;
CREATE VIEW public.v_dispatch_rules_active AS
SELECT dr.*
FROM public.dispatch_rule dr
WHERE dr.active = true
  AND dr.tenant_id = public.current_tenant_id();
ALTER VIEW public.v_dispatch_rules_active SET (security_invoker = true);
