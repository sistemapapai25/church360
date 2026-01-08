DO $$
BEGIN
  -- user_account
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='user_account') THEN
    ALTER TABLE public.user_account ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_user_account_tenant_id ON public.user_account(tenant_id);
  END IF;

  -- group
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='group') THEN
    ALTER TABLE public."group" ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_group_tenant_id ON public."group"(tenant_id);
    UPDATE public."group" g
    SET tenant_id = COALESCE(c.tenant_id, ua.tenant_id)
    FROM public.campus c
    LEFT JOIN public.user_account ua ON ua.id = g.created_by
    WHERE g.campus_id = c.id AND g.tenant_id IS NULL;
  END IF;

  -- group_meeting
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='group_meeting') THEN
    ALTER TABLE public.group_meeting ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_group_meeting_tenant_id ON public.group_meeting(tenant_id);
    UPDATE public.group_meeting gm
    SET tenant_id = g.tenant_id
    FROM public."group" g
    WHERE gm.group_id = g.id AND gm.tenant_id IS NULL;
  END IF;

  -- group_attendance
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='group_attendance') THEN
    ALTER TABLE public.group_attendance ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_group_attendance_tenant_id ON public.group_attendance(tenant_id);
    UPDATE public.group_attendance ga
    SET tenant_id = gm.tenant_id
    FROM public.group_meeting gm
    WHERE ga.meeting_id = gm.id AND ga.tenant_id IS NULL;
  END IF;

  -- visitor
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='visitor') THEN
    ALTER TABLE public.visitor ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_visitor_tenant_id ON public.visitor(tenant_id);
    UPDATE public.visitor v
    SET tenant_id = COALESCE(gm.tenant_id, ua.tenant_id)
    FROM public.group_meeting gm
    LEFT JOIN public.user_account ua ON ua.id = v.created_by
    WHERE v.meeting_id = gm.id AND v.tenant_id IS NULL;
  END IF;

  -- group_visitor
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='group_visitor') THEN
    ALTER TABLE public.group_visitor ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_group_visitor_tenant_id ON public.group_visitor(tenant_id);
    UPDATE public.group_visitor gv
    SET tenant_id = COALESCE(gm.tenant_id, ua.tenant_id)
    FROM public.group_meeting gm
    LEFT JOIN public.user_account ua ON ua.id = gv.created_by
    WHERE gv.meeting_id = gm.id AND gv.tenant_id IS NULL;
  END IF;

  -- event
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='event') THEN
    ALTER TABLE public.event ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_event_tenant_id ON public.event(tenant_id);
    UPDATE public.event e
    SET tenant_id = COALESCE(c.tenant_id, ua.tenant_id)
    FROM public.campus c
    LEFT JOIN public.user_account ua ON ua.id = e.created_by
    WHERE e.campus_id = c.id AND e.tenant_id IS NULL;
  END IF;

  -- event_registration
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='event_registration') THEN
    ALTER TABLE public.event_registration ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_event_registration_tenant_id ON public.event_registration(tenant_id);
    UPDATE public.event_registration er
    SET tenant_id = e.tenant_id
    FROM public.event e
    WHERE er.event_id = e.id AND er.tenant_id IS NULL;
  END IF;

  -- contribution
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='contribution') THEN
    ALTER TABLE public.contribution ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_contribution_tenant_id ON public.contribution(tenant_id);
    UPDATE public.contribution c
    SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE c.user_id = ua.id AND c.tenant_id IS NULL;
  END IF;

  -- financial_goal
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='financial_goal') THEN
    ALTER TABLE public.financial_goal ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_financial_goal_tenant_id ON public.financial_goal(tenant_id);
    UPDATE public.financial_goal fg
    SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE fg.created_by = ua.id AND fg.tenant_id IS NULL;
  END IF;

  -- expense
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='expense') THEN
    ALTER TABLE public.expense ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_expense_tenant_id ON public.expense(tenant_id);
    UPDATE public.expense ex
    SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE ex.created_by = ua.id AND ex.tenant_id IS NULL;
  END IF;

  -- tag (opcional, somente se desejar segmentar por tenant)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='tag') THEN
    ALTER TABLE public.tag ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_tag_tenant_id ON public.tag(tenant_id);
    -- Backfill não aplicado por ausência de created_by no schema base; manter null até futura migração
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='quick_news') THEN
    ALTER TABLE public.quick_news ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_quick_news_tenant_id ON public.quick_news(tenant_id);
    UPDATE public.quick_news qn
    SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE qn.created_by = ua.id AND qn.tenant_id IS NULL;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='prayer_requests') THEN
    ALTER TABLE public.prayer_requests ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_prayer_requests_tenant_id ON public.prayer_requests(tenant_id);
    UPDATE public.prayer_requests pr
    SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE pr.author_id = ua.id AND pr.tenant_id IS NULL;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='prayer_request_prayers') THEN
    ALTER TABLE public.prayer_request_prayers ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_prayer_request_prayers_tenant_id ON public.prayer_request_prayers(tenant_id);
    UPDATE public.prayer_request_prayers prp
    SET tenant_id = pr.tenant_id
    FROM public.prayer_requests pr
    WHERE prp.prayer_request_id = pr.id AND prp.tenant_id IS NULL;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='prayer_request_testimonies') THEN
    ALTER TABLE public.prayer_request_testimonies ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_prayer_request_testimonies_tenant_id ON public.prayer_request_testimonies(tenant_id);
    UPDATE public.prayer_request_testimonies prt
    SET tenant_id = pr.tenant_id
    FROM public.prayer_requests pr
    WHERE prt.prayer_request_id = pr.id AND prt.tenant_id IS NULL;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='worship_service') THEN
    ALTER TABLE public.worship_service ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_worship_service_tenant_id ON public.worship_service(tenant_id);
    UPDATE public.worship_service ws
    SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE ws.created_by = ua.id AND ws.tenant_id IS NULL;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='worship_attendance') THEN
    ALTER TABLE public.worship_attendance ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_worship_attendance_tenant_id ON public.worship_attendance(tenant_id);
    UPDATE public.worship_attendance wa
    SET tenant_id = ws.tenant_id
    FROM public.worship_service ws
    WHERE wa.worship_service_id = ws.id AND wa.tenant_id IS NULL;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='reading_plan') THEN
    ALTER TABLE public.reading_plan ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_reading_plan_tenant_id ON public.reading_plan(tenant_id);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='reading_plan_progress') THEN
    ALTER TABLE public.reading_plan_progress ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_reading_plan_progress_tenant_id ON public.reading_plan_progress(tenant_id);
    DO $inner$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='reading_plan_progress' AND column_name='member_id'
      ) THEN
        ALTER TABLE public.reading_plan_progress DROP CONSTRAINT IF EXISTS reading_plan_progress_member_id_fkey;
        ALTER TABLE public.reading_plan_progress RENAME COLUMN member_id TO user_id;
        ALTER TABLE public.reading_plan_progress ADD CONSTRAINT reading_plan_progress_user_id_fkey 
          FOREIGN KEY (user_id) REFERENCES public.user_account(id) ON DELETE CASCADE;
      END IF;
    END $inner$;
    UPDATE public.reading_plan_progress rpp
    SET tenant_id = rp.tenant_id
    FROM public.reading_plan rp
    WHERE rpp.plan_id = rp.id AND rpp.tenant_id IS NULL;
  END IF;
END $$;
DO $$
BEGIN
  -- agent_config: tornar multi-tenant
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='agent_config') THEN
    ALTER TABLE public.agent_config ADD COLUMN IF NOT EXISTS tenant_id uuid;
    DO $inner$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conrelid = 'public.agent_config'::regclass 
          AND contype = 'p' 
          AND conname = 'agent_config_pkey'
      ) THEN
        ALTER TABLE public.agent_config DROP CONSTRAINT agent_config_pkey;
      END IF;
    END $inner$;
    DO $inner$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conrelid = 'public.agent_config'::regclass 
          AND conname = 'agent_config_tenant_key_unique'
      ) THEN
        ALTER TABLE public.agent_config ADD CONSTRAINT agent_config_tenant_key_unique UNIQUE (tenant_id, key);
      END IF;
    END $inner$;
    INSERT INTO public.agent_config (
      tenant_id, key, assistant_id, name, created_at, updated_at, display_name, subtitle, avatar_url, theme_color, show_on_home, show_on_dashboard, show_floating_button, floating_route, allowed_access_levels
    )
    SELECT t.id, ac.key, ac.assistant_id, ac.name, ac.created_at, ac.updated_at, ac.display_name, ac.subtitle, ac.avatar_url, ac.theme_color, ac.show_on_home, ac.show_on_dashboard, ac.show_floating_button, ac.floating_route, ac.allowed_access_levels
    FROM public.tenant t
    CROSS JOIN public.agent_config ac
    WHERE ac.tenant_id IS NULL
    ON CONFLICT DO NOTHING;
    DELETE FROM public.agent_config WHERE tenant_id IS NULL;
    ALTER TABLE public.agent_config
      ADD CONSTRAINT agent_config_tenant_fk FOREIGN KEY (tenant_id) REFERENCES public.tenant(id) ON DELETE CASCADE;
    ALTER TABLE public.agent_config
      ALTER COLUMN tenant_id SET NOT NULL;
    CREATE INDEX IF NOT EXISTS idx_agent_config_tenant_id ON public.agent_config(tenant_id);
  END IF;

  -- message_template
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='message_template') THEN
    ALTER TABLE public.message_template ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_message_template_tenant_id ON public.message_template(tenant_id);
    UPDATE public.message_template mt
    SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE mt.created_by = ua.auth_user_id AND mt.tenant_id IS NULL;
  END IF;

  -- dispatch_rule
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='dispatch_rule') THEN
    ALTER TABLE public.dispatch_rule ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_dispatch_rule_tenant_id ON public.dispatch_rule(tenant_id);
    UPDATE public.dispatch_rule dr
    SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE dr.created_by = ua.auth_user_id AND dr.tenant_id IS NULL;
  END IF;

  -- dispatch_job
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='dispatch_job') THEN
    ALTER TABLE public.dispatch_job ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_dispatch_job_tenant_id ON public.dispatch_job(tenant_id);
    UPDATE public.dispatch_job dj
    SET tenant_id = dr.tenant_id
    FROM public.dispatch_rule dr
    WHERE dj.rule_id = dr.id AND dj.tenant_id IS NULL;
  END IF;

  -- dispatch_log
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='dispatch_log') THEN
    ALTER TABLE public.dispatch_log ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_dispatch_log_tenant_id ON public.dispatch_log(tenant_id);
    UPDATE public.dispatch_log dl
    SET tenant_id = dj.tenant_id
    FROM public.dispatch_job dj
    WHERE dl.job_id = dj.id AND dl.tenant_id IS NULL;
  END IF;

  -- whatsapp_relatorios_automaticos (auto-scheduler)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='whatsapp_relatorios_automaticos') THEN
    ALTER TABLE public.whatsapp_relatorios_automaticos ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_whatsapp_relatorios_automaticos_tenant_id ON public.whatsapp_relatorios_automaticos(tenant_id);
    UPDATE public.whatsapp_relatorios_automaticos wra
    SET tenant_id = dr.tenant_id
    FROM public.dispatch_rule dr
    WHERE wra.dispatch_rule_id = dr.id AND wra.tenant_id IS NULL;
  END IF;

  -- study_groups
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='study_groups') THEN
    ALTER TABLE public.study_groups ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_study_groups_tenant_id ON public.study_groups(tenant_id);
    UPDATE public.study_groups sg
    SET tenant_id = ua.tenant_id
    FROM public.user_account ua
    WHERE ua.id = sg.created_by AND sg.tenant_id IS NULL;
  END IF;

  -- study_lessons
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='study_lessons') THEN
    ALTER TABLE public.study_lessons ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_study_lessons_tenant_id ON public.study_lessons(tenant_id);
    UPDATE public.study_lessons sl
    SET tenant_id = sg.tenant_id
    FROM public.study_groups sg
    WHERE sl.study_group_id = sg.id AND sl.tenant_id IS NULL;
  END IF;

  -- study_participants
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='study_participants') THEN
    ALTER TABLE public.study_participants ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_study_participants_tenant_id ON public.study_participants(tenant_id);
    UPDATE public.study_participants sp
    SET tenant_id = sg.tenant_id
    FROM public.study_groups sg
    WHERE sp.study_group_id = sg.id AND sp.tenant_id IS NULL;
  END IF;

  -- study_attendance
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='study_attendance') THEN
    ALTER TABLE public.study_attendance ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_study_attendance_tenant_id ON public.study_attendance(tenant_id);
    UPDATE public.study_attendance sa
    SET tenant_id = sl.tenant_id
    FROM public.study_lessons sl
    WHERE sa.study_lesson_id = sl.id AND sa.tenant_id IS NULL;
  END IF;

  -- study_comments
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='study_comments') THEN
    ALTER TABLE public.study_comments ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_study_comments_tenant_id ON public.study_comments(tenant_id);
    UPDATE public.study_comments sc
    SET tenant_id = sl.tenant_id
    FROM public.study_lessons sl
    WHERE sc.study_lesson_id = sl.id AND sc.tenant_id IS NULL;
  END IF;

  -- study_resources
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='study_resources') THEN
    ALTER TABLE public.study_resources ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_study_resources_tenant_id ON public.study_resources(tenant_id);
    UPDATE public.study_resources sr
    SET tenant_id = sg.tenant_id
    FROM public.study_groups sg
    WHERE sr.study_group_id = sg.id AND sr.tenant_id IS NULL;
  END IF;
END $$;
