CREATE OR REPLACE FUNCTION public.current_tenant_id()
RETURNS uuid
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
  SELECT ua.tenant_id
  FROM public.user_account ua
  WHERE ua.auth_user_id = auth.uid()
  LIMIT 1
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='user_account' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.user_account ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_user_account ON public.user_account;
    CREATE POLICY tenant_select_user_account ON public.user_account FOR SELECT USING (auth.uid() = auth_user_id);
    DROP POLICY IF EXISTS tenant_modify_user_account ON public.user_account;
    CREATE POLICY tenant_modify_user_account ON public.user_account FOR ALL USING (auth.uid() = auth_user_id) WITH CHECK (auth.uid() = auth_user_id);
    CREATE INDEX IF NOT EXISTS idx_user_account_tenant_id ON public.user_account(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='quick_news' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.quick_news ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_quick_news ON public.quick_news;
    CREATE POLICY tenant_select_quick_news ON public.quick_news FOR SELECT USING (
      tenant_id = public.current_tenant_id() AND is_active = true AND (expires_at IS NULL OR expires_at > NOW())
    );
    DROP POLICY IF EXISTS tenant_modify_quick_news ON public.quick_news;
    CREATE POLICY tenant_modify_quick_news ON public.quick_news FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_quick_news_tenant_id ON public.quick_news(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='prayer_requests' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.prayer_requests ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Todos podem ver pedidos públicos" ON public.prayer_requests;
    CREATE POLICY "Todos podem ver pedidos públicos" ON public.prayer_requests FOR SELECT USING (
      privacy = 'public' AND tenant_id = public.current_tenant_id()
    );
    DROP POLICY IF EXISTS "Membros podem ver pedidos members_only" ON public.prayer_requests;
    CREATE POLICY "Membros podem ver pedidos members_only" ON public.prayer_requests FOR SELECT USING (
      privacy = 'members_only' AND tenant_id = public.current_tenant_id()
      AND EXISTS (
        SELECT 1 FROM public.user_access_level
        WHERE user_id = auth.uid() AND access_level_number >= 2
      )
    );
    DROP POLICY IF EXISTS "Líderes podem ver pedidos leaders_only" ON public.prayer_requests;
    CREATE POLICY "Líderes podem ver pedidos leaders_only" ON public.prayer_requests FOR SELECT USING (
      privacy = 'leaders_only' AND tenant_id = public.current_tenant_id()
      AND EXISTS (
        SELECT 1 FROM public.user_access_level
        WHERE user_id = auth.uid() AND access_level_number >= 3
      )
    );
    DROP POLICY IF EXISTS "Autor pode ver seus pedidos" ON public.prayer_requests;
    CREATE POLICY "Autor pode ver seus pedidos" ON public.prayer_requests FOR SELECT USING (
      author_id = auth.uid() AND tenant_id = public.current_tenant_id()
    );
    DROP POLICY IF EXISTS "Usuários podem criar pedidos" ON public.prayer_requests;
    CREATE POLICY "Usuários podem criar pedidos" ON public.prayer_requests FOR INSERT WITH CHECK (
      author_id = auth.uid() AND tenant_id = public.current_tenant_id()
    );
    DROP POLICY IF EXISTS "Autor pode atualizar seus pedidos" ON public.prayer_requests;
    CREATE POLICY "Autor pode atualizar seus pedidos" ON public.prayer_requests FOR UPDATE USING (
      author_id = auth.uid() AND tenant_id = public.current_tenant_id()
    ) WITH CHECK (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS "Autor pode deletar seus pedidos" ON public.prayer_requests;
    CREATE POLICY "Autor pode deletar seus pedidos" ON public.prayer_requests FOR DELETE USING (
      author_id = auth.uid() AND tenant_id = public.current_tenant_id()
    );
    CREATE INDEX IF NOT EXISTS idx_prayer_requests_tenant_id ON public.prayer_requests(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='prayer_request_prayers' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.prayer_request_prayers ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Usuários podem ver orações" ON public.prayer_request_prayers;
    CREATE POLICY "Usuários podem ver orações" ON public.prayer_request_prayers FOR SELECT USING (
      EXISTS (
        SELECT 1 FROM public.prayer_requests pr
        WHERE pr.id = public.prayer_request_prayers.prayer_request_id
          AND pr.tenant_id = public.current_tenant_id()
      )
    );
    DROP POLICY IF EXISTS "Usuários podem criar orações" ON public.prayer_request_prayers;
    CREATE POLICY "Usuários podem criar orações" ON public.prayer_request_prayers FOR INSERT WITH CHECK (
      user_id = auth.uid() AND tenant_id = public.current_tenant_id()
    );
    DROP POLICY IF EXISTS "Usuário pode atualizar suas orações" ON public.prayer_request_prayers;
    CREATE POLICY "Usuário pode atualizar suas orações" ON public.prayer_request_prayers FOR UPDATE USING (
      user_id = auth.uid() AND tenant_id = public.current_tenant_id()
    ) WITH CHECK (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS "Usuário pode deletar suas orações" ON public.prayer_request_prayers;
    CREATE POLICY "Usuário pode deletar suas orações" ON public.prayer_request_prayers FOR DELETE USING (
      user_id = auth.uid() AND tenant_id = public.current_tenant_id()
    );
    CREATE INDEX IF NOT EXISTS idx_prayer_request_prayers_tenant_id ON public.prayer_request_prayers(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='prayer_request_testimonies' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.prayer_request_testimonies ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Usuários podem ver testemunhos" ON public.prayer_request_testimonies;
    CREATE POLICY "Usuários podem ver testemunhos" ON public.prayer_request_testimonies FOR SELECT USING (
      EXISTS (
        SELECT 1 FROM public.prayer_requests pr
        WHERE pr.id = public.prayer_request_testimonies.prayer_request_id
          AND pr.tenant_id = public.current_tenant_id()
      )
    );
    DROP POLICY IF EXISTS "Autor pode criar testemunho" ON public.prayer_request_testimonies;
    CREATE POLICY "Autor pode criar testemunho" ON public.prayer_request_testimonies FOR INSERT WITH CHECK (
      EXISTS (
        SELECT 1 FROM public.prayer_requests pr
        WHERE pr.id = public.prayer_request_testimonies.prayer_request_id
          AND pr.author_id = auth.uid()
          AND pr.tenant_id = public.current_tenant_id()
      )
    );
    DROP POLICY IF EXISTS "Autor pode atualizar testemunho" ON public.prayer_request_testimonies;
    CREATE POLICY "Autor pode atualizar testemunho" ON public.prayer_request_testimonies FOR UPDATE USING (
      EXISTS (
        SELECT 1 FROM public.prayer_requests pr
        WHERE pr.id = public.prayer_request_testimonies.prayer_request_id
          AND pr.author_id = auth.uid()
          AND pr.tenant_id = public.current_tenant_id()
      )
    ) WITH CHECK (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS "Autor pode deletar testemunho" ON public.prayer_request_testimonies;
    CREATE POLICY "Autor pode deletar testemunho" ON public.prayer_request_testimonies FOR DELETE USING (
      EXISTS (
        SELECT 1 FROM public.prayer_requests pr
        WHERE pr.id = public.prayer_request_testimonies.prayer_request_id
          AND pr.author_id = auth.uid()
          AND pr.tenant_id = public.current_tenant_id()
      )
    );
    CREATE INDEX IF NOT EXISTS idx_prayer_request_testimonies_tenant_id ON public.prayer_request_testimonies(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='worship_service' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.worship_service ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_worship_service ON public.worship_service;
    CREATE POLICY tenant_select_worship_service ON public.worship_service FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_worship_service ON public.worship_service;
    CREATE POLICY tenant_modify_worship_service ON public.worship_service FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_worship_service_tenant_id ON public.worship_service(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema='public' AND table_name='worship_attendance'
  ) THEN
    ALTER TABLE public.worship_attendance ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_worship_attendance ON public.worship_attendance;
    DROP POLICY IF EXISTS tenant_modify_worship_attendance ON public.worship_attendance;
    DO $inner$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='worship_service' AND column_name='tenant_id'
      ) THEN
        CREATE POLICY tenant_select_worship_attendance ON public.worship_attendance FOR SELECT USING (
          EXISTS (
            SELECT 1 FROM public.worship_service ws 
            WHERE ws.id = public.worship_attendance.worship_service_id
              AND ws.tenant_id = public.current_tenant_id()
          )
        );
        CREATE POLICY tenant_modify_worship_attendance ON public.worship_attendance FOR ALL USING (
          EXISTS (
            SELECT 1 FROM public.worship_service ws 
            WHERE ws.id = public.worship_attendance.worship_service_id
              AND ws.tenant_id = public.current_tenant_id()
          )
        ) WITH CHECK (
          EXISTS (
            SELECT 1 FROM public.worship_service ws 
            WHERE ws.id = public.worship_attendance.worship_service_id
              AND ws.tenant_id = public.current_tenant_id()
          )
        );
      ELSE
        CREATE POLICY tenant_select_worship_attendance ON public.worship_attendance FOR SELECT USING (
          EXISTS (
            SELECT 1 
            FROM public.worship_service ws 
            JOIN public.user_account ua ON ua.id = ws.created_by
            WHERE ws.id = public.worship_attendance.worship_service_id
              AND ua.tenant_id = public.current_tenant_id()
          )
        );
        CREATE POLICY tenant_modify_worship_attendance ON public.worship_attendance FOR ALL USING (
          EXISTS (
            SELECT 1 
            FROM public.worship_service ws 
            JOIN public.user_account ua ON ua.id = ws.created_by
            WHERE ws.id = public.worship_attendance.worship_service_id
              AND ua.tenant_id = public.current_tenant_id()
          )
        ) WITH CHECK (
          EXISTS (
            SELECT 1 
            FROM public.worship_service ws 
            JOIN public.user_account ua ON ua.id = ws.created_by
            WHERE ws.id = public.worship_attendance.worship_service_id
              AND ua.tenant_id = public.current_tenant_id()
          )
        );
      END IF;
    END $inner$;
    CREATE INDEX IF NOT EXISTS idx_worship_attendance_service_id ON public.worship_attendance(worship_service_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='reading_plan' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.reading_plan ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_reading_plan ON public.reading_plan;
    CREATE POLICY tenant_select_reading_plan ON public.reading_plan FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_reading_plan ON public.reading_plan;
    CREATE POLICY tenant_modify_reading_plan ON public.reading_plan FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_reading_plan_tenant_id ON public.reading_plan(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='reading_plan_progress' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.reading_plan_progress ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_reading_plan_progress ON public.reading_plan_progress;
    CREATE POLICY tenant_select_reading_plan_progress ON public.reading_plan_progress FOR SELECT USING (
      tenant_id = public.current_tenant_id()
    );
    DROP POLICY IF EXISTS tenant_modify_reading_plan_progress ON public.reading_plan_progress;
    CREATE POLICY tenant_modify_reading_plan_progress ON public.reading_plan_progress FOR ALL USING (
      tenant_id = public.current_tenant_id()
    ) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_reading_plan_progress_tenant_id ON public.reading_plan_progress(tenant_id);
  END IF;
END $$;
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='study_groups' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.study_groups ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Usuários podem ver grupos públicos ou seus grupos" ON public.study_groups;
    CREATE POLICY "Usuários podem ver grupos públicos ou seus grupos"
      ON public.study_groups
      FOR SELECT
      USING (
        public.study_groups.tenant_id = public.current_tenant_id() AND
        (
          is_public = true
          OR EXISTS (
            SELECT 1 FROM public.study_participants sp
            WHERE sp.study_group_id = public.study_groups.id
            AND sp.user_id = auth.uid()
            AND sp.is_active = true
          )
        )
      );
    CREATE INDEX IF NOT EXISTS idx_study_groups_tenant_id ON public.study_groups(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='study_lessons' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.study_lessons ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Participantes podem ver lições" ON public.study_lessons;
    CREATE POLICY "Participantes podem ver lições"
      ON public.study_lessons
      FOR SELECT
      USING (
        public.study_lessons.tenant_id = public.current_tenant_id() AND
        (
          (
            status = 'published' AND EXISTS (
              SELECT 1 FROM public.study_participants sp
              WHERE sp.study_group_id = public.study_lessons.study_group_id
              AND sp.user_id = auth.uid()
              AND sp.is_active = true
            )
          )
          OR EXISTS (
            SELECT 1 FROM public.study_participants sp
            WHERE sp.study_group_id = public.study_lessons.study_group_id
            AND sp.user_id = auth.uid()
            AND sp.role IN ('leader', 'co_leader')
            AND sp.is_active = true
          )
        )
      );
    CREATE INDEX IF NOT EXISTS idx_study_lessons_tenant_id ON public.study_lessons(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='study_participants' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.study_participants ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Participantes podem ver membros do grupo" ON public.study_participants;
    CREATE POLICY "Participantes podem ver membros do grupo"
      ON public.study_participants
      FOR SELECT
      USING (
        public.study_participants.tenant_id = public.current_tenant_id() AND
        EXISTS (
          SELECT 1 FROM public.study_participants sp
          WHERE sp.study_group_id = public.study_participants.study_group_id
          AND sp.user_id = auth.uid()
          AND sp.is_active = true
        )
      );
    CREATE INDEX IF NOT EXISTS idx_study_participants_tenant_id ON public.study_participants(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='study_attendance' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.study_attendance ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Participantes podem ver presença" ON public.study_attendance;
    CREATE POLICY "Participantes podem ver presença"
      ON public.study_attendance
      FOR SELECT
      USING (
        public.study_attendance.tenant_id = public.current_tenant_id() AND
        EXISTS (
          SELECT 1 FROM public.study_lessons sl
          JOIN public.study_participants sp ON sp.study_group_id = sl.study_group_id
          WHERE sl.id = public.study_attendance.study_lesson_id
          AND sp.user_id = auth.uid()
          AND sp.is_active = true
        )
      );
    CREATE INDEX IF NOT EXISTS idx_study_attendance_tenant_id ON public.study_attendance(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='study_comments' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.study_comments ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Participantes podem ver comentários" ON public.study_comments;
    CREATE POLICY "Participantes podem ver comentários"
      ON public.study_comments
      FOR SELECT
      USING (
        public.study_comments.tenant_id = public.current_tenant_id() AND
        EXISTS (
          SELECT 1 FROM public.study_lessons sl
          JOIN public.study_participants sp ON sp.study_group_id = sl.study_group_id
          WHERE sl.id = public.study_comments.study_lesson_id
          AND sp.user_id = auth.uid()
          AND sp.is_active = true
        )
      );
    CREATE INDEX IF NOT EXISTS idx_study_comments_tenant_id ON public.study_comments(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='study_resources' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.study_resources ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Participantes podem ver recursos" ON public.study_resources;
    CREATE POLICY "Participantes podem ver recursos"
      ON public.study_resources
      FOR SELECT
      USING (
        public.study_resources.tenant_id = public.current_tenant_id() AND
        EXISTS (
          SELECT 1 FROM public.study_participants sp
          WHERE sp.study_group_id = public.study_resources.study_group_id
          AND sp.user_id = auth.uid()
          AND sp.is_active = true
        )
      );
    CREATE INDEX IF NOT EXISTS idx_study_resources_tenant_id ON public.study_resources(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='agent_config' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.agent_config ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Enable read access for all users" ON public.agent_config;
    DROP POLICY IF EXISTS "Enable all access for authenticated users with role owner" ON public.agent_config;
    DROP POLICY IF EXISTS tenant_select_agent_config ON public.agent_config;
    CREATE POLICY tenant_select_agent_config ON public.agent_config FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_agent_config ON public.agent_config;
    CREATE POLICY tenant_modify_agent_config ON public.agent_config FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_agent_config_tenant_id ON public.agent_config(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='message_template' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.message_template ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_message_template ON public.message_template;
    CREATE POLICY tenant_select_message_template ON public.message_template FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_message_template ON public.message_template;
    CREATE POLICY tenant_modify_message_template ON public.message_template FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_message_template_tenant_id ON public.message_template(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='dispatch_rule' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.dispatch_rule ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_dispatch_rule ON public.dispatch_rule;
    CREATE POLICY tenant_select_dispatch_rule ON public.dispatch_rule FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_dispatch_rule ON public.dispatch_rule;
    CREATE POLICY tenant_modify_dispatch_rule ON public.dispatch_rule FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_dispatch_rule_tenant_id ON public.dispatch_rule(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='dispatch_job' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.dispatch_job ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_dispatch_job ON public.dispatch_job;
    CREATE POLICY tenant_select_dispatch_job ON public.dispatch_job FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_dispatch_job ON public.dispatch_job;
    CREATE POLICY tenant_modify_dispatch_job ON public.dispatch_job FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_dispatch_job_tenant_id ON public.dispatch_job(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='dispatch_log' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.dispatch_log ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_dispatch_log ON public.dispatch_log;
    CREATE POLICY tenant_select_dispatch_log ON public.dispatch_log FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_dispatch_log ON public.dispatch_log;
    CREATE POLICY tenant_modify_dispatch_log ON public.dispatch_log FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_dispatch_log_tenant_id ON public.dispatch_log(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='whatsapp_relatorios_automaticos' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.whatsapp_relatorios_automaticos ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_whatsapp_relatorios_automaticos ON public.whatsapp_relatorios_automaticos;
    CREATE POLICY tenant_select_whatsapp_relatorios_automaticos ON public.whatsapp_relatorios_automaticos FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_whatsapp_relatorios_automaticos ON public.whatsapp_relatorios_automaticos;
    CREATE POLICY tenant_modify_whatsapp_relatorios_automaticos ON public.whatsapp_relatorios_automaticos FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_whatsapp_relatorios_automaticos_tenant_id ON public.whatsapp_relatorios_automaticos(tenant_id);
  END IF;
END $$;
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='event' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.event ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_event ON public.event;
    CREATE POLICY tenant_select_event ON public.event FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_event ON public.event;
    CREATE POLICY tenant_modify_event ON public.event FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_event_tenant_id ON public.event(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema='public' AND table_name='event_registration'
  ) THEN
    ALTER TABLE public.event_registration ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_event_registration ON public.event_registration;
    CREATE POLICY tenant_select_event_registration ON public.event_registration FOR SELECT USING (
      EXISTS (SELECT 1 FROM public.event e WHERE e.id = event_registration.event_id AND e.tenant_id = public.current_tenant_id())
    );
    DROP POLICY IF EXISTS tenant_modify_event_registration ON public.event_registration;
    CREATE POLICY tenant_modify_event_registration ON public.event_registration FOR ALL USING (
      EXISTS (SELECT 1 FROM public.event e WHERE e.id = event_registration.event_id AND e.tenant_id = public.current_tenant_id())
    ) WITH CHECK (
      EXISTS (SELECT 1 FROM public.event e WHERE e.id = event_registration.event_id AND e.tenant_id = public.current_tenant_id())
    );
    CREATE INDEX IF NOT EXISTS idx_event_registration_event_id ON public.event_registration(event_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='group' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public."group" ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_group ON public."group";
    CREATE POLICY tenant_select_group ON public."group" FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_group ON public."group";
    CREATE POLICY tenant_modify_group ON public."group" FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_group_tenant_id ON public."group"(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema='public' AND table_name='group_member'
  ) THEN
    ALTER TABLE public.group_member ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_group_member ON public.group_member;
    CREATE POLICY tenant_select_group_member ON public.group_member FOR SELECT USING (
      EXISTS (SELECT 1 FROM public."group" g WHERE g.id = group_member.group_id AND g.tenant_id = public.current_tenant_id())
    );
    DROP POLICY IF EXISTS tenant_modify_group_member ON public.group_member;
    CREATE POLICY tenant_modify_group_member ON public.group_member FOR ALL USING (
      EXISTS (SELECT 1 FROM public."group" g WHERE g.id = group_member.group_id AND g.tenant_id = public.current_tenant_id())
    ) WITH CHECK (
      EXISTS (SELECT 1 FROM public."group" g WHERE g.id = group_member.group_id AND g.tenant_id = public.current_tenant_id())
    );
    CREATE INDEX IF NOT EXISTS idx_group_member_group_id ON public.group_member(group_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='group_meeting' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.group_meeting ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_group_meeting ON public.group_meeting;
    CREATE POLICY tenant_select_group_meeting ON public.group_meeting FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_group_meeting ON public.group_meeting;
    CREATE POLICY tenant_modify_group_meeting ON public.group_meeting FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_group_meeting_tenant_id ON public.group_meeting(tenant_id);
  ELSE
    IF EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema='public' AND table_name='group_meeting'
    ) THEN
      ALTER TABLE public.group_meeting ENABLE ROW LEVEL SECURITY;
      DROP POLICY IF EXISTS tenant_select_group_meeting ON public.group_meeting;
      CREATE POLICY tenant_select_group_meeting ON public.group_meeting FOR SELECT USING (
        EXISTS (SELECT 1 FROM public."group" g WHERE g.id = group_meeting.group_id AND g.tenant_id = public.current_tenant_id())
      );
      DROP POLICY IF EXISTS tenant_modify_group_meeting ON public.group_meeting;
      CREATE POLICY tenant_modify_group_meeting ON public.group_meeting FOR ALL USING (
        EXISTS (SELECT 1 FROM public."group" g WHERE g.id = group_meeting.group_id AND g.tenant_id = public.current_tenant_id())
      ) WITH CHECK (
        EXISTS (SELECT 1 FROM public."group" g WHERE g.id = group_meeting.group_id AND g.tenant_id = public.current_tenant_id())
      );
      CREATE INDEX IF NOT EXISTS idx_group_meeting_group_id ON public.group_meeting(group_id);
    END IF;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema='public' AND table_name='group_attendance'
  ) THEN
    ALTER TABLE public.group_attendance ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_group_attendance ON public.group_attendance;
    CREATE POLICY tenant_select_group_attendance ON public.group_attendance FOR SELECT USING (
      EXISTS (
        SELECT 1 
        FROM public.group_meeting gm 
        JOIN public."group" g ON g.id = gm.group_id
        WHERE gm.id = group_attendance.meeting_id
          AND g.tenant_id = public.current_tenant_id()
      )
    );
    DROP POLICY IF EXISTS tenant_modify_group_attendance ON public.group_attendance;
    CREATE POLICY tenant_modify_group_attendance ON public.group_attendance FOR ALL USING (
      EXISTS (
        SELECT 1 
        FROM public.group_meeting gm 
        JOIN public."group" g ON g.id = gm.group_id
        WHERE gm.id = group_attendance.meeting_id
          AND g.tenant_id = public.current_tenant_id()
      )
    ) WITH CHECK (
      EXISTS (
        SELECT 1 
        FROM public.group_meeting gm 
        JOIN public."group" g ON g.id = gm.group_id
        WHERE gm.id = group_attendance.meeting_id
          AND g.tenant_id = public.current_tenant_id()
      )
    );
    CREATE INDEX IF NOT EXISTS idx_group_attendance_meeting_id ON public.group_attendance(meeting_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='visitor' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.visitor ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_visitor ON public.visitor;
    CREATE POLICY tenant_select_visitor ON public.visitor FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_visitor ON public.visitor;
    CREATE POLICY tenant_modify_visitor ON public.visitor FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_visitor_tenant_id ON public.visitor(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='group_visitor' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.group_visitor ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_group_visitor ON public.group_visitor;
    CREATE POLICY tenant_select_group_visitor ON public.group_visitor FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_group_visitor ON public.group_visitor;
    CREATE POLICY tenant_modify_group_visitor ON public.group_visitor FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_group_visitor_tenant_id ON public.group_visitor(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='contribution' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.contribution ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_contribution ON public.contribution;
    CREATE POLICY tenant_select_contribution ON public.contribution FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_contribution ON public.contribution;
    CREATE POLICY tenant_modify_contribution ON public.contribution FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_contribution_tenant_id ON public.contribution(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='financial_goal' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.financial_goal ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_financial_goal ON public.financial_goal;
    CREATE POLICY tenant_select_financial_goal ON public.financial_goal FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_financial_goal ON public.financial_goal;
    CREATE POLICY tenant_modify_financial_goal ON public.financial_goal FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_financial_goal_tenant_id ON public.financial_goal(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='expense' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.expense ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_expense ON public.expense;
    CREATE POLICY tenant_select_expense ON public.expense FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_expense ON public.expense;
    CREATE POLICY tenant_modify_expense ON public.expense FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_expense_tenant_id ON public.expense(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='tag' AND column_name='tenant_id'
  ) THEN
    ALTER TABLE public.tag ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_tag ON public.tag;
    CREATE POLICY tenant_select_tag ON public.tag FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_tag ON public.tag;
    CREATE POLICY tenant_modify_tag ON public.tag FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_tag_tenant_id ON public.tag(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema='public' AND table_name='home_banner'
  ) THEN
    ALTER TABLE public.home_banner ADD COLUMN IF NOT EXISTS tenant_id uuid;
    ALTER TABLE public.home_banner ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_home_banner ON public.home_banner;
    CREATE POLICY tenant_select_home_banner ON public.home_banner FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_home_banner ON public.home_banner;
    CREATE POLICY tenant_modify_home_banner ON public.home_banner FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_home_banner_tenant_id ON public.home_banner(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema='public' AND table_name='church_info'
  ) THEN
    ALTER TABLE public.church_info ADD COLUMN IF NOT EXISTS tenant_id uuid;
    ALTER TABLE public.church_info ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_church_info ON public.church_info;
    CREATE POLICY tenant_select_church_info ON public.church_info FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_church_info ON public.church_info;
    CREATE POLICY tenant_modify_church_info ON public.church_info FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_church_info_tenant_id ON public.church_info(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema='public' AND table_name='course'
  ) THEN
    ALTER TABLE public.course ADD COLUMN IF NOT EXISTS tenant_id uuid;
    ALTER TABLE public.course ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_course ON public.course;
    CREATE POLICY tenant_select_course ON public.course FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_course ON public.course;
    CREATE POLICY tenant_modify_course ON public.course FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_course_tenant_id ON public.course(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema='public' AND table_name='course_enrollment'
  ) THEN
    ALTER TABLE public.course_enrollment ADD COLUMN IF NOT EXISTS tenant_id uuid;
    ALTER TABLE public.course_enrollment ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_course_enrollment ON public.course_enrollment;
    CREATE POLICY tenant_select_course_enrollment ON public.course_enrollment FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_course_enrollment ON public.course_enrollment;
    CREATE POLICY tenant_modify_course_enrollment ON public.course_enrollment FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_course_enrollment_tenant_id ON public.course_enrollment(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema='public' AND table_name='course_lesson'
  ) THEN
    ALTER TABLE public.course_lesson ADD COLUMN IF NOT EXISTS tenant_id uuid;
    ALTER TABLE public.course_lesson ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_course_lesson ON public.course_lesson;
    CREATE POLICY tenant_select_course_lesson ON public.course_lesson FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_course_lesson ON public.course_lesson;
    CREATE POLICY tenant_modify_course_lesson ON public.course_lesson FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_course_lesson_tenant_id ON public.course_lesson(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema='public' AND table_name='community_posts'
  ) THEN
    ALTER TABLE public.community_posts ADD COLUMN IF NOT EXISTS tenant_id uuid;
    ALTER TABLE public.community_posts ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_community_posts ON public.community_posts;
    CREATE POLICY tenant_select_community_posts ON public.community_posts FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_community_posts ON public.community_posts;
    CREATE POLICY tenant_modify_community_posts ON public.community_posts FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_community_posts_tenant_id ON public.community_posts(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema='public' AND table_name='community_comments'
  ) THEN
    ALTER TABLE public.community_comments ADD COLUMN IF NOT EXISTS tenant_id uuid;
    ALTER TABLE public.community_comments ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_community_comments ON public.community_comments;
    CREATE POLICY tenant_select_community_comments ON public.community_comments FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_community_comments ON public.community_comments;
    CREATE POLICY tenant_modify_community_comments ON public.community_comments FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_community_comments_tenant_id ON public.community_comments(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema='public' AND table_name='community_reactions'
  ) THEN
    ALTER TABLE public.community_reactions ADD COLUMN IF NOT EXISTS tenant_id uuid;
    ALTER TABLE public.community_reactions ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_community_reactions ON public.community_reactions;
    CREATE POLICY tenant_select_community_reactions ON public.community_reactions FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_community_reactions ON public.community_reactions;
    CREATE POLICY tenant_modify_community_reactions ON public.community_reactions FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_community_reactions_tenant_id ON public.community_reactions(tenant_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema='public' AND table_name='classifieds'
  ) THEN
    ALTER TABLE public.classifieds ADD COLUMN IF NOT EXISTS tenant_id uuid;
    ALTER TABLE public.classifieds ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS tenant_select_classifieds ON public.classifieds;
    CREATE POLICY tenant_select_classifieds ON public.classifieds FOR SELECT USING (tenant_id = public.current_tenant_id());
    DROP POLICY IF EXISTS tenant_modify_classifieds ON public.classifieds;
    CREATE POLICY tenant_modify_classifieds ON public.classifieds FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id());
    CREATE INDEX IF NOT EXISTS idx_classifieds_tenant_id ON public.classifieds(tenant_id);
  END IF;
END $$;
