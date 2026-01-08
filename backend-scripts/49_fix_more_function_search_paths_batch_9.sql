-- Fix function search paths for batch 9 (Notifications, Devotionals, Prayer Requests, Testimonies, Reports)
-- Addresses "function_search_path_mutable" warnings from Supabase Security Advisor

-- =====================================================
-- 1. NOTIFICATIONS
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_unread_notifications_count(target_user_id UUID)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)
    FROM public.notifications
    WHERE user_id = target_user_id
    AND status != 'read'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_all_notifications_as_read(target_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  UPDATE public.notifications
  SET status = 'read', read_at = NOW()
  WHERE user_id = target_user_id
  AND status != 'read';
END;
$$;

CREATE OR REPLACE FUNCTION public.create_devotional_notification(devotional_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  devotional_title TEXT;
  user_record RECORD;
BEGIN
  -- Buscar título do devocional
  SELECT title INTO devotional_title
  FROM public.devotionals
  WHERE id = devotional_id;

  -- Criar notificação para todos os usuários que têm preferência ativada
  FOR user_record IN
    SELECT np.user_id
    FROM public.notification_preferences np
    WHERE np.devotional_daily = true
  LOOP
    INSERT INTO public.notifications (
      user_id,
      type,
      title,
      body,
      data,
      route,
      status
    ) VALUES (
      user_record.user_id,
      'devotional_daily',
      'Novo Devocional Diário 📖',
      devotional_title,
      jsonb_build_object('devotional_id', devotional_id),
      '/devotionals/' || devotional_id,
      'pending'
    );
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_event_reminder_notification(event_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  event_title TEXT;
  event_date TIMESTAMPTZ;
  user_record RECORD;
BEGIN
  -- Buscar informações do evento
  SELECT title, start_date INTO event_title, event_date
  FROM public.events
  WHERE id = event_id;

  -- Criar notificação para todos os usuários que têm preferência ativada
  FOR user_record IN
    SELECT np.user_id
    FROM public.notification_preferences np
    WHERE np.event_reminder = true
  LOOP
    INSERT INTO public.notifications (
      user_id,
      type,
      title,
      body,
      data,
      route,
      status
    ) VALUES (
      user_record.user_id,
      'event_reminder',
      'Lembrete de Evento 📅',
      'O evento "' || event_title || '" acontece amanhã!',
      jsonb_build_object('event_id', event_id),
      '/events/' || event_id,
      'pending'
    );
  END LOOP;
END;
$$;

-- =====================================================
-- 2. DEVOTIONALS
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_today_devotional()
RETURNS TABLE (
  id UUID,
  title TEXT,
  content TEXT,
  scripture_reference TEXT,
  devotional_date DATE,
  author_id UUID,
  is_published BOOLEAN,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    d.id,
    d.title,
    d.content,
    d.scripture_reference,
    d.devotional_date,
    d.author_id,
    d.is_published,
    d.created_at,
    d.updated_at
  FROM public.devotionals d
  WHERE d.devotional_date = CURRENT_DATE
  AND d.is_published = true
  LIMIT 1;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_devotional_stats(devotional_uuid UUID)
RETURNS TABLE (
  total_reads BIGINT,
  unique_readers BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::BIGINT as total_reads,
    COUNT(DISTINCT user_id)::BIGINT as unique_readers
  FROM public.devotional_readings
  WHERE devotional_id = devotional_uuid;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_reading_streak(user_uuid UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  streak INTEGER := 0;
  current_date_check DATE := CURRENT_DATE;
  has_reading BOOLEAN;
BEGIN
  LOOP
    -- Verificar se há leitura nesta data
    SELECT EXISTS (
      SELECT 1 
      FROM public.devotional_readings dr
      JOIN public.devotionals d ON dr.devotional_id = d.id
      WHERE dr.user_id = user_uuid
      AND d.devotional_date = current_date_check
    ) INTO has_reading;
    
    -- Se não há leitura, parar
    IF NOT has_reading THEN
      EXIT;
    END IF;
    
    -- Incrementar streak e voltar um dia
    streak := streak + 1;
    current_date_check := current_date_check - INTERVAL '1 day';
  END LOOP;
  
  RETURN streak;
END;
$$;

-- =====================================================
-- 3. PRAYER REQUESTS
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_prayer_request_stats(request_uuid UUID)
RETURNS TABLE (
  total_prayers BIGINT,
  unique_prayers BIGINT,
  has_testimony BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(prp.id)::BIGINT as total_prayers,
    COUNT(DISTINCT prp.user_id)::BIGINT as unique_prayers,
    EXISTS (
      SELECT 1 FROM public.prayer_request_testimonies prt
      WHERE prt.prayer_request_id = request_uuid
    ) as has_testimony
  FROM public.prayer_request_prayers prp
  WHERE prp.prayer_request_id = request_uuid;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_prayer_requests_by_category()
RETURNS TABLE (
  category public.prayer_category,
  total_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  RETURN QUERY
  SELECT
    pr.category,
    COUNT(*)::BIGINT as total_count
  FROM public.prayer_requests pr
  GROUP BY pr.category
  ORDER BY total_count DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_prayer_requests_by_status()
RETURNS TABLE (
  status public.prayer_status,
  total_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  RETURN QUERY
  SELECT
    pr.status,
    COUNT(*)::BIGINT as total_count
  FROM public.prayer_requests pr
  GROUP BY pr.status
  ORDER BY total_count DESC;
END;
$$;

-- =====================================================
-- 4. TESTIMONIES
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_recent_public_testimonies(limit_count INT DEFAULT 10)
RETURNS TABLE (
  id UUID,
  title TEXT,
  description TEXT,
  author_id UUID,
  allow_whatsapp_contact BOOLEAN,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  RETURN QUERY
  SELECT
    t.id,
    t.title,
    t.description,
    t.author_id,
    t.allow_whatsapp_contact,
    t.created_at
  FROM public.testimonies t
  WHERE t.is_public = true
  ORDER BY t.created_at DESC
  LIMIT limit_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.count_user_testimonies(user_id UUID)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  total_count INT;
BEGIN
  SELECT COUNT(*)::INT INTO total_count
  FROM public.testimonies
  WHERE author_id = user_id;
  
  RETURN total_count;
END;
$$;

-- =====================================================
-- 5. REPORTS & ANALYTICS (Remaining)
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_group_participation_report(
  start_date DATE,
  end_date DATE
)
RETURNS TABLE (
  period TEXT,
  total_groups BIGINT,
  active_groups BIGINT,
  total_members BIGINT,
  average_members_per_group NUMERIC,
  total_meetings BIGINT,
  average_attendance NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  RETURN QUERY
  WITH date_series AS (
    SELECT generate_series(
      date_trunc('month', start_date),
      date_trunc('month', end_date),
      '1 month'::interval
    )::DATE AS month
  )
  SELECT
    TO_CHAR(ds.month, 'Mon/YYYY') AS period,
    (SELECT COUNT(*) FROM public."group" WHERE created_at <= ds.month + INTERVAL '1 month') AS total_groups,
    (SELECT COUNT(*) FROM public."group" WHERE status = 'active' AND created_at <= ds.month + INTERVAL '1 month') AS active_groups,
    (SELECT COUNT(*) FROM public.group_member WHERE joined_at <= ds.month + INTERVAL '1 month') AS total_members,
    ROUND((SELECT COUNT(*)::NUMERIC FROM public.group_member WHERE joined_at <= ds.month + INTERVAL '1 month') / 
          NULLIF((SELECT COUNT(*) FROM public."group" WHERE created_at <= ds.month + INTERVAL '1 month'), 0), 1) AS average_members_per_group,
    COUNT(gm.id) FILTER (WHERE gm.date >= ds.month AND gm.date < ds.month + INTERVAL '1 month') AS total_meetings,
    ROUND(AVG(
      (SELECT COUNT(*) FROM public.group_attendance ga WHERE ga.group_meeting_id = gm.id)
    ), 1) AS average_attendance
  FROM date_series ds
  LEFT JOIN public.group_meeting gm ON gm.date >= ds.month AND gm.date < ds.month + INTERVAL '1 month'
  GROUP BY ds.month
  ORDER BY ds.month;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_group_statistics()
RETURNS TABLE (
  total_groups BIGINT,
  active_groups BIGINT,
  total_members BIGINT,
  average_members_per_group NUMERIC,
  meetings_this_month BIGINT,
  average_attendance_this_month NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) AS total_groups,
    COUNT(*) FILTER (WHERE status = 'active') AS active_groups,
    (SELECT COUNT(*) FROM public.group_member) AS total_members,
    ROUND((SELECT COUNT(*)::NUMERIC FROM public.group_member) / NULLIF(COUNT(*), 0), 1) AS average_members_per_group,
    (SELECT COUNT(*) FROM public.group_meeting WHERE date >= date_trunc('month', CURRENT_DATE)) AS meetings_this_month,
    (SELECT ROUND(AVG(
      (SELECT COUNT(*) FROM public.group_attendance ga WHERE ga.group_meeting_id = gm.id)
    ), 1) FROM public.group_meeting gm WHERE gm.date >= date_trunc('month', CURRENT_DATE)) AS average_attendance_this_month
  FROM public."group";
END;
$$;

CREATE OR REPLACE FUNCTION public.get_devotional_engagement_report(
  start_date DATE,
  end_date DATE
)
RETURNS TABLE (
  period TEXT,
  total_devotionals BIGINT,
  total_readings BIGINT,
  unique_readers BIGINT,
  average_readings_per_devotional NUMERIC,
  engagement_rate NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  RETURN QUERY
  WITH date_series AS (
    SELECT generate_series(
      date_trunc('month', start_date),
      date_trunc('month', end_date),
      '1 month'::interval
    )::DATE AS month
  )
  SELECT
    TO_CHAR(ds.month, 'Mon/YYYY') AS period,
    COUNT(d.id) FILTER (WHERE d.devotional_date >= ds.month AND d.devotional_date < ds.month + INTERVAL '1 month') AS total_devotionals,
    COUNT(dr.id) FILTER (WHERE dr.read_at >= ds.month AND dr.read_at < ds.month + INTERVAL '1 month') AS total_readings,
    COUNT(DISTINCT dr.user_id) FILTER (WHERE dr.read_at >= ds.month AND dr.read_at < ds.month + INTERVAL '1 month') AS unique_readers,
    ROUND(
      COUNT(dr.id) FILTER (WHERE dr.read_at >= ds.month AND dr.read_at < ds.month + INTERVAL '1 month')::NUMERIC /
      NULLIF(COUNT(d.id) FILTER (WHERE d.devotional_date >= ds.month AND d.devotional_date < ds.month + INTERVAL '1 month'), 0),
      1
    ) AS average_readings_per_devotional,
    ROUND(
      COUNT(DISTINCT dr.user_id) FILTER (WHERE dr.read_at >= ds.month AND dr.read_at < ds.month + INTERVAL '1 month')::NUMERIC /
      NULLIF((SELECT COUNT(*) FROM public.member WHERE status = 'active'), 0) * 100,
      2
    ) AS engagement_rate
  FROM date_series ds
  LEFT JOIN public.devotionals d ON d.devotional_date >= ds.month AND d.devotional_date < ds.month + INTERVAL '1 month'
  LEFT JOIN public.devotional_readings dr ON dr.read_at >= ds.month AND dr.read_at < ds.month + INTERVAL '1 month'
  GROUP BY ds.month
  ORDER BY ds.month;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_devotional_statistics()
RETURNS TABLE (
  total_devotionals BIGINT,
  readings_this_month BIGINT,
  unique_readers_this_month BIGINT,
  engagement_rate_this_month NUMERIC,
  readings_this_year BIGINT,
  unique_readers_this_year BIGINT,
  engagement_rate_this_year NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) AS total_devotionals,
    (SELECT COUNT(*) FROM public.devotional_readings WHERE read_at >= date_trunc('month', CURRENT_DATE)) AS readings_this_month,
    (SELECT COUNT(DISTINCT user_id) FROM public.devotional_readings WHERE read_at >= date_trunc('month', CURRENT_DATE)) AS unique_readers_this_month,
    ROUND(
      (SELECT COUNT(DISTINCT user_id)::NUMERIC FROM public.devotional_readings WHERE read_at >= date_trunc('month', CURRENT_DATE)) /
      NULLIF((SELECT COUNT(*) FROM public.member WHERE status = 'active'), 0) * 100,
      2
    ) AS engagement_rate_this_month,
    (SELECT COUNT(*) FROM public.devotional_readings WHERE read_at >= date_trunc('year', CURRENT_DATE)) AS readings_this_year,
    (SELECT COUNT(DISTINCT user_id) FROM public.devotional_readings WHERE read_at >= date_trunc('year', CURRENT_DATE)) AS unique_readers_this_year,
    ROUND(
      (SELECT COUNT(DISTINCT user_id)::NUMERIC FROM public.devotional_readings WHERE read_at >= date_trunc('year', CURRENT_DATE)) /
      NULLIF((SELECT COUNT(*) FROM public.member WHERE status = 'active'), 0) * 100,
      2
    ) AS engagement_rate_this_year
  FROM public.devotionals;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_ministry_participation_report()
RETURNS TABLE (
  ministry_name TEXT,
  total_members BIGINT,
  active_members BIGINT,
  schedules_this_month BIGINT,
  engagement_rate NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  RETURN QUERY
  SELECT
    m.name AS ministry_name,
    COUNT(mm.id) AS total_members,
    COUNT(mm.id) FILTER (WHERE mm.is_active = true) AS active_members,
    COUNT(ms.id) FILTER (WHERE ms.date >= date_trunc('month', CURRENT_DATE)) AS schedules_this_month,
    ROUND(
      COUNT(mm.id) FILTER (WHERE mm.is_active = true)::NUMERIC /
      NULLIF((SELECT COUNT(*) FROM public.member WHERE status = 'active'), 0) * 100,
      2
    ) AS engagement_rate
  FROM public.ministry m
  LEFT JOIN public.ministry_member mm ON mm.ministry_id = m.id
  LEFT JOIN public.ministry_schedule ms ON ms.ministry_id = m.id
  GROUP BY m.id, m.name
  ORDER BY total_members DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_ministry_statistics()
RETURNS TABLE (
  total_ministries BIGINT,
  active_ministries BIGINT,
  total_members BIGINT,
  average_members_per_ministry NUMERIC,
  schedules_this_month BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) AS total_ministries,
    COUNT(*) FILTER (WHERE is_active = true) AS active_ministries,
    (SELECT COUNT(*) FROM public.ministry_member) AS total_members,
    ROUND((SELECT COUNT(*)::NUMERIC FROM public.ministry_member) / NULLIF(COUNT(*), 0), 1) AS average_members_per_ministry,
    (SELECT COUNT(*) FROM public.ministry_schedule WHERE date >= date_trunc('month', CURRENT_DATE)) AS schedules_this_month
  FROM public.ministry;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_visitor_conversion_report(
  start_date DATE,
  end_date DATE
)
RETURNS TABLE (
  period TEXT,
  new_visitors BIGINT,
  total_visits BIGINT,
  followups_completed BIGINT,
  converted_to_members BIGINT,
  conversion_rate NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  RETURN QUERY
  WITH date_series AS (
    SELECT generate_series(
      date_trunc('month', start_date),
      date_trunc('month', end_date),
      '1 month'::interval
    )::DATE AS month
  )
  SELECT
    TO_CHAR(ds.month, 'Mon/YYYY') AS period,
    COUNT(v.id) FILTER (WHERE v.first_visit_date >= ds.month AND v.first_visit_date < ds.month + INTERVAL '1 month') AS new_visitors,
    COUNT(vv.id) FILTER (WHERE vv.visit_date >= ds.month AND vv.visit_date < ds.month + INTERVAL '1 month') AS total_visits,
    COUNT(vf.id) FILTER (WHERE vf.followup_date >= ds.month AND vf.followup_date < ds.month + INTERVAL '1 month' AND vf.status = 'completed') AS followups_completed,
    COUNT(v.id) FILTER (WHERE v.became_member = true AND v.first_visit_date >= ds.month AND v.first_visit_date < ds.month + INTERVAL '1 month') AS converted_to_members,
    ROUND(
      COUNT(v.id) FILTER (WHERE v.became_member = true AND v.first_visit_date >= ds.month AND v.first_visit_date < ds.month + INTERVAL '1 month')::NUMERIC /
      NULLIF(COUNT(v.id) FILTER (WHERE v.first_visit_date >= ds.month AND v.first_visit_date < ds.month + INTERVAL '1 month'), 0) * 100,
      2
    ) AS conversion_rate
  FROM date_series ds
  LEFT JOIN public.visitor v ON v.first_visit_date >= ds.month AND v.first_visit_date < ds.month + INTERVAL '1 month'
  LEFT JOIN public.visitor_visit vv ON vv.visit_date >= ds.month AND vv.visit_date < ds.month + INTERVAL '1 month'
  LEFT JOIN public.visitor_followup vf ON vf.followup_date >= ds.month AND vf.followup_date < ds.month + INTERVAL '1 month'
  GROUP BY ds.month
  ORDER BY ds.month;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_visitor_statistics()
RETURNS TABLE (
  total_visitors BIGINT,
  new_this_month BIGINT,
  visits_this_month BIGINT,
  followups_pending BIGINT,
  converted_to_members BIGINT,
  conversion_rate NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) AS total_visitors,
    COUNT(*) FILTER (WHERE first_visit_date >= date_trunc('month', CURRENT_DATE)) AS new_this_month,
    (SELECT COUNT(*) FROM public.visitor_visit WHERE visit_date >= date_trunc('month', CURRENT_DATE)) AS visits_this_month,
    (SELECT COUNT(*) FROM public.visitor_followup WHERE status = 'pending') AS followups_pending,
    COUNT(*) FILTER (WHERE became_member = true) AS converted_to_members,
    ROUND(
      COUNT(*) FILTER (WHERE became_member = true)::NUMERIC /
      NULLIF(COUNT(*), 0) * 100,
      2
    ) AS conversion_rate
  FROM public.visitor;
END;
$$;
