-- Fix function search paths for batch 7
-- Addresses warnings for: can_access_dashboard, get_user_study_groups, update_visitor_stats, get_group_progress, get_participant_attendance_rate, get_user_role_contexts, get_member_growth_report

-- 1. can_access_dashboard
CREATE OR REPLACE FUNCTION public.can_access_dashboard(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_access_level INTEGER;
BEGIN
  -- Busca nível de acesso do usuário
  SELECT access_level_number INTO v_access_level
  FROM public.user_access_level
  WHERE user_id = p_user_id;

  -- Nível 2+ pode acessar Dashboard
  RETURN COALESCE(v_access_level, 0) >= 2;
END;
$function$;

-- 2. get_user_role_contexts
CREATE OR REPLACE FUNCTION public.get_user_role_contexts(
  p_user_id UUID,
  p_role_id UUID DEFAULT NULL
) RETURNS TABLE(
  context_id UUID,
  context_name TEXT,
  role_name TEXT,
  role_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    rc.id,
    rc.context_name,
    r.name,
    r.id
  FROM public.user_roles ur
  JOIN public.roles r ON r.id = ur.role_id
  LEFT JOIN public.role_contexts rc ON rc.id = ur.role_context_id
  WHERE ur.user_id = p_user_id
    AND ur.is_active = true
    AND (ur.expires_at IS NULL OR ur.expires_at > NOW())
    AND (p_role_id IS NULL OR r.id = p_role_id)
    AND rc.id IS NOT NULL;
END;
$function$;

-- 3. get_user_study_groups
CREATE OR REPLACE FUNCTION public.get_user_study_groups(target_user_id UUID)
RETURNS TABLE (
  group_id UUID,
  group_name TEXT,
  group_status public.study_group_status,
  user_role public.participant_role,
  total_lessons BIGINT,
  completed_lessons BIGINT,
  attendance_rate NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    sg.id,
    sg.name,
    sg.status,
    sp.role,
    (SELECT COUNT(*) FROM public.study_lessons WHERE study_group_id = sg.id AND status = 'published'),
    (SELECT COUNT(*) FROM public.study_attendance sa
     JOIN public.study_lessons sl ON sl.id = sa.study_lesson_id
     WHERE sl.study_group_id = sg.id
     AND sa.user_id = target_user_id
     AND sa.status = 'present'),
    CASE
      WHEN (SELECT COUNT(*) FROM public.study_lessons WHERE study_group_id = sg.id AND status = 'published') = 0 THEN 0
      ELSE (
        SELECT ROUND(
          (COUNT(*) FILTER (WHERE sa.status = 'present')::NUMERIC /
           COUNT(*)::NUMERIC) * 100, 2
        )
        FROM public.study_attendance sa
        JOIN public.study_lessons sl ON sl.id = sa.study_lesson_id
        WHERE sl.study_group_id = sg.id
        AND sa.user_id = target_user_id
      )
    END
  FROM public.study_groups sg
  JOIN public.study_participants sp ON sp.study_group_id = sg.id
  WHERE sp.user_id = target_user_id
  AND sp.is_active = true
  AND sg.tenant_id = public.current_tenant_id();
END;
$function$;

-- 4. get_group_progress
CREATE OR REPLACE FUNCTION public.get_group_progress(target_group_id UUID)
RETURNS TABLE (
  total_lessons BIGINT,
  published_lessons BIGINT,
  total_participants BIGINT,
  active_participants BIGINT,
  average_attendance_rate NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.study_lessons WHERE study_group_id = target_group_id),
    (SELECT COUNT(*) FROM public.study_lessons WHERE study_group_id = target_group_id AND status = 'published'),
    (SELECT COUNT(*) FROM public.study_participants WHERE study_group_id = target_group_id),
    (SELECT COUNT(*) FROM public.study_participants WHERE study_group_id = target_group_id AND is_active = true),
    CASE
      WHEN (SELECT COUNT(*) FROM public.study_lessons WHERE study_group_id = target_group_id AND status = 'published') = 0 THEN 0
      ELSE (
        SELECT ROUND(AVG(attendance_rate), 2)
        FROM (
          SELECT
            (COUNT(*) FILTER (WHERE sa.status = 'present')::NUMERIC /
             NULLIF(COUNT(*)::NUMERIC, 0)) * 100 AS attendance_rate
          FROM public.study_participants sp
          LEFT JOIN public.study_attendance sa ON sa.user_id = sp.user_id
          LEFT JOIN public.study_lessons sl ON sl.id = sa.study_lesson_id AND sl.study_group_id = target_group_id
          WHERE sp.study_group_id = target_group_id
          AND sp.is_active = true
          GROUP BY sp.user_id
        ) AS rates
      )
    END;
END;
$function$;

-- 5. get_participant_attendance_rate
CREATE OR REPLACE FUNCTION public.get_participant_attendance_rate(
  target_group_id UUID,
  target_user_id UUID
)
RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  total_lessons BIGINT;
  present_count BIGINT;
BEGIN
  -- Contar total de lições publicadas
  SELECT COUNT(*) INTO total_lessons
  FROM public.study_lessons
  WHERE study_group_id = target_group_id
  AND status = 'published';

  IF total_lessons = 0 THEN
    RETURN 0;
  END IF;

  -- Contar presenças
  SELECT COUNT(*) INTO present_count
  FROM public.study_attendance sa
  JOIN public.study_lessons sl ON sl.id = sa.study_lesson_id
  WHERE sl.study_group_id = target_group_id
  AND sa.user_id = target_user_id
  AND sa.status = 'present';

  RETURN ROUND((present_count::NUMERIC / total_lessons::NUMERIC) * 100, 2);
END;
$function$;

-- 6. get_member_growth_report
CREATE OR REPLACE FUNCTION public.get_member_growth_report(
  start_date DATE,
  end_date DATE
)
RETURNS TABLE (
  period TEXT,
  new_members BIGINT,
  conversions BIGINT,
  baptisms BIGINT,
  total_members BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
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
    COUNT(m.id) FILTER (WHERE m.created_at >= ds.month AND m.created_at < ds.month + INTERVAL '1 month') AS new_members,
    COUNT(m.id) FILTER (WHERE m.conversion_date >= ds.month AND m.conversion_date < ds.month + INTERVAL '1 month') AS conversions,
    COUNT(m.id) FILTER (WHERE m.baptism_date >= ds.month AND m.baptism_date < ds.month + INTERVAL '1 month') AS baptisms,
    (SELECT COUNT(*) FROM public.member WHERE created_at <= ds.month + INTERVAL '1 month') AS total_members
  FROM date_series ds
  LEFT JOIN public.member m ON m.created_at >= ds.month AND m.created_at < ds.month + INTERVAL '1 month'
  GROUP BY ds.month
  ORDER BY ds.month;
END;
$function$;

-- 7. update_visitor_stats
CREATE OR REPLACE FUNCTION public.update_visitor_stats()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.visitor
    SET 
      total_visits = (
        SELECT COUNT(*) FROM public.visitor_visit
        WHERE visitor_id = NEW.visitor_id
      ),
      last_visit_date = NEW.visit_date
    WHERE id = NEW.visitor_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.visitor
    SET 
      total_visits = (
        SELECT COUNT(*) FROM public.visitor_visit
        WHERE visitor_id = OLD.visitor_id
      ),
      last_visit_date = (
        SELECT MAX(visit_date) FROM public.visitor_visit
        WHERE visitor_id = OLD.visitor_id
      )
    WHERE id = OLD.visitor_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$function$;
