-- =====================================================
-- FIX FUNCTION SEARCH PATHS - BATCH 8
-- =====================================================
-- Descrição: Corrige avisos de "function_search_path_mutable"
--            adicionando SET search_path TO '' e qualificando
--            tabelas com public.
-- Data: 2025-01-28
-- =====================================================

-- 1. assign_role_to_user
CREATE OR REPLACE FUNCTION public.assign_role_to_user(
  p_user_id UUID,
  p_role_id UUID,
  p_context_id UUID DEFAULT NULL,
  p_assigned_by UUID DEFAULT NULL,
  p_expires_at TIMESTAMPTZ DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_role_id UUID;
BEGIN
  -- Insere atribuição
  INSERT INTO public.user_roles (
    user_id, role_id, role_context_id,
    assigned_by, expires_at, notes
  ) VALUES (
    p_user_id, p_role_id, p_context_id,
    p_assigned_by, p_expires_at, p_notes
  ) RETURNING id INTO v_user_role_id;

  -- Log de auditoria
  INSERT INTO public.permission_audit_log (
    action_type, user_id, role_id,
    performed_by, details
  ) VALUES (
    'role_assigned', p_user_id, p_role_id,
    p_assigned_by, jsonb_build_object(
      'context_id', p_context_id,
      'expires_at', p_expires_at,
      'user_role_id', v_user_role_id
    )
  );

  RETURN v_user_role_id;
END;
$function$;

-- 2. remove_user_role
CREATE OR REPLACE FUNCTION public.remove_user_role(
  p_user_role_id UUID,
  p_removed_by UUID DEFAULT NULL
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id UUID;
  v_role_id UUID;
BEGIN
  -- Busca dados antes de remover
  SELECT user_id, role_id INTO v_user_id, v_role_id
  FROM public.user_roles
  WHERE id = p_user_role_id;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- Desativa o cargo
  UPDATE public.user_roles
  SET is_active = false,
      updated_at = NOW()
  WHERE id = p_user_role_id;

  -- Log de auditoria
  INSERT INTO public.permission_audit_log (
    action_type, user_id, role_id,
    performed_by, details
  ) VALUES (
    'role_removed', v_user_id, v_role_id,
    p_removed_by, jsonb_build_object(
      'user_role_id', p_user_role_id
    )
  );

  RETURN true;
END;
$function$;

-- 3. create_default_notification_preferences
CREATE OR REPLACE FUNCTION public.create_default_notification_preferences()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  INSERT INTO public.notification_preferences (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log do erro mas não bloqueia a criação do usuário
    RAISE WARNING 'Erro ao criar preferências de notificação para usuário %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$function$;

-- 4. log_access_level_change
CREATE OR REPLACE FUNCTION public.log_access_level_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF (TG_OP = 'UPDATE' AND OLD.access_level != NEW.access_level) THEN
    INSERT INTO public.access_level_history (
      user_id, from_level, from_level_number, to_level, to_level_number, reason, promoted_by
    ) VALUES (
      NEW.user_id, OLD.access_level, OLD.access_level_number, NEW.access_level, NEW.access_level_number, NEW.promotion_reason, NEW.promoted_by
    );
  ELSIF (TG_OP = 'INSERT') THEN
    INSERT INTO public.access_level_history (
      user_id, from_level, from_level_number, to_level, to_level_number, reason, promoted_by
    ) VALUES (
      NEW.user_id, NULL, NULL, NEW.access_level, NEW.access_level_number, 'Criação inicial', NEW.promoted_by
    );
  END IF;
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log do erro mas não bloqueia a operação
    RAISE WARNING 'Erro ao registrar histórico de nível de acesso para usuário %: %', NEW.user_id, SQLERRM;
    RETURN NEW;
END;
$function$;

-- 5. get_member_statistics
CREATE OR REPLACE FUNCTION public.get_member_statistics()
RETURNS TABLE (
  total_members BIGINT,
  active_members BIGINT,
  inactive_members BIGINT,
  new_this_month BIGINT,
  conversions_this_month BIGINT,
  baptisms_this_month BIGINT,
  average_age NUMERIC,
  male_count BIGINT,
  female_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) AS total_members,
    COUNT(*) FILTER (WHERE status = 'active') AS active_members,
    COUNT(*) FILTER (WHERE status = 'inactive') AS inactive_members,
    COUNT(*) FILTER (WHERE created_at >= date_trunc('month', CURRENT_DATE)) AS new_this_month,
    COUNT(*) FILTER (WHERE conversion_date >= date_trunc('month', CURRENT_DATE)) AS conversions_this_month,
    COUNT(*) FILTER (WHERE baptism_date >= date_trunc('month', CURRENT_DATE)) AS baptisms_this_month,
    ROUND(AVG(EXTRACT(YEAR FROM AGE(birthdate))), 1) AS average_age,
    COUNT(*) FILTER (WHERE gender = 'male') AS male_count,
    COUNT(*) FILTER (WHERE gender = 'female') AS female_count
  FROM public.member;
END;
$function$;

-- 6. get_financial_report
CREATE OR REPLACE FUNCTION public.get_financial_report(
  start_date DATE,
  end_date DATE
)
RETURNS TABLE (
  period TEXT,
  total_contributions NUMERIC,
  total_donations NUMERIC,
  total_expenses NUMERIC,
  net_balance NUMERIC,
  goal_progress NUMERIC
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
    COALESCE(SUM(c.amount) FILTER (WHERE c.date >= ds.month AND c.date < ds.month + INTERVAL '1 month'), 0) AS total_contributions,
    COALESCE(SUM(d.amount) FILTER (WHERE d.date >= ds.month AND d.date < ds.month + INTERVAL '1 month'), 0) AS total_donations,
    COALESCE(SUM(e.amount) FILTER (WHERE e.date >= ds.month AND e.date < ds.month + INTERVAL '1 month'), 0) AS total_expenses,
    COALESCE(SUM(c.amount) FILTER (WHERE c.date >= ds.month AND c.date < ds.month + INTERVAL '1 month'), 0) +
    COALESCE(SUM(d.amount) FILTER (WHERE d.date >= ds.month AND d.date < ds.month + INTERVAL '1 month'), 0) -
    COALESCE(SUM(e.amount) FILTER (WHERE e.date >= ds.month AND e.date < ds.month + INTERVAL '1 month'), 0) AS net_balance,
    CASE
      WHEN (SELECT SUM(target_amount) FROM public.financial_goal WHERE target_date >= ds.month AND target_date < ds.month + INTERVAL '1 month') > 0
      THEN ROUND(
        (COALESCE(SUM(c.amount) FILTER (WHERE c.date >= ds.month AND c.date < ds.month + INTERVAL '1 month'), 0) +
         COALESCE(SUM(d.amount) FILTER (WHERE d.date >= ds.month AND d.date < ds.month + INTERVAL '1 month'), 0)) /
        (SELECT SUM(target_amount) FROM public.financial_goal WHERE target_date >= ds.month AND target_date < ds.month + INTERVAL '1 month') * 100,
        2
      )
      ELSE 0
    END AS goal_progress
  FROM date_series ds
  LEFT JOIN public.contribution c ON c.date >= ds.month AND c.date < ds.month + INTERVAL '1 month'
  LEFT JOIN public.donation d ON d.date >= ds.month AND d.date < ds.month + INTERVAL '1 month'
  LEFT JOIN public.expense e ON e.date >= ds.month AND e.date < ds.month + INTERVAL '1 month'
  GROUP BY ds.month
  ORDER BY ds.month;
END;
$function$;

-- 7. get_financial_statistics
CREATE OR REPLACE FUNCTION public.get_financial_statistics()
RETURNS TABLE (
  total_contributions_month NUMERIC,
  total_donations_month NUMERIC,
  total_expenses_month NUMERIC,
  net_balance_month NUMERIC,
  total_contributions_year NUMERIC,
  total_donations_year NUMERIC,
  total_expenses_year NUMERIC,
  net_balance_year NUMERIC,
  active_goals BIGINT,
  completed_goals BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(SUM(c.amount) FILTER (WHERE c.date >= date_trunc('month', CURRENT_DATE)), 0) AS total_contributions_month,
    COALESCE(SUM(d.amount) FILTER (WHERE d.date >= date_trunc('month', CURRENT_DATE)), 0) AS total_donations_month,
    COALESCE(SUM(e.amount) FILTER (WHERE e.date >= date_trunc('month', CURRENT_DATE)), 0) AS total_expenses_month,
    COALESCE(SUM(c.amount) FILTER (WHERE c.date >= date_trunc('month', CURRENT_DATE)), 0) +
    COALESCE(SUM(d.amount) FILTER (WHERE d.date >= date_trunc('month', CURRENT_DATE)), 0) -
    COALESCE(SUM(e.amount) FILTER (WHERE e.date >= date_trunc('month', CURRENT_DATE)), 0) AS net_balance_month,
    COALESCE(SUM(c.amount) FILTER (WHERE c.date >= date_trunc('year', CURRENT_DATE)), 0) AS total_contributions_year,
    COALESCE(SUM(d.amount) FILTER (WHERE d.date >= date_trunc('year', CURRENT_DATE)), 0) AS total_donations_year,
    COALESCE(SUM(e.amount) FILTER (WHERE e.date >= date_trunc('year', CURRENT_DATE)), 0) AS total_expenses_year,
    COALESCE(SUM(c.amount) FILTER (WHERE c.date >= date_trunc('year', CURRENT_DATE)), 0) +
    COALESCE(SUM(d.amount) FILTER (WHERE d.date >= date_trunc('year', CURRENT_DATE)), 0) -
    COALESCE(SUM(e.amount) FILTER (WHERE e.date >= date_trunc('year', CURRENT_DATE)), 0) AS net_balance_year,
    (SELECT COUNT(*) FROM public.financial_goal WHERE status = 'active') AS active_goals,
    (SELECT COUNT(*) FROM public.financial_goal WHERE status = 'completed') AS completed_goals
  FROM public.contribution c
  FULL OUTER JOIN public.donation d ON 1=1
  FULL OUTER JOIN public.expense e ON 1=1;
END;
$function$;

-- 8. get_worship_attendance_report
CREATE OR REPLACE FUNCTION public.get_worship_attendance_report(
  start_date DATE,
  end_date DATE
)
RETURNS TABLE (
  period TEXT,
  total_services BIGINT,
  total_attendance BIGINT,
  average_attendance NUMERIC,
  max_attendance BIGINT,
  min_attendance BIGINT
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
    COUNT(ws.id) AS total_services,
    COALESCE(SUM(ws.attendance_count), 0) AS total_attendance,
    ROUND(AVG(ws.attendance_count), 1) AS average_attendance,
    MAX(ws.attendance_count) AS max_attendance,
    MIN(ws.attendance_count) AS min_attendance
  FROM date_series ds
  LEFT JOIN public.worship_service ws ON ws.date >= ds.month AND ws.date < ds.month + INTERVAL '1 month'
  GROUP BY ds.month
  ORDER BY ds.month;
END;
$function$;

-- 9. get_worship_statistics
CREATE OR REPLACE FUNCTION public.get_worship_statistics()
RETURNS TABLE (
  total_services_month BIGINT,
  total_attendance_month BIGINT,
  average_attendance_month NUMERIC,
  total_services_year BIGINT,
  total_attendance_year BIGINT,
  average_attendance_year NUMERIC,
  most_attended_service_type TEXT,
  least_attended_service_type TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE date >= date_trunc('month', CURRENT_DATE)) AS total_services_month,
    COALESCE(SUM(attendance_count) FILTER (WHERE date >= date_trunc('month', CURRENT_DATE)), 0) AS total_attendance_month,
    ROUND(AVG(attendance_count) FILTER (WHERE date >= date_trunc('month', CURRENT_DATE)), 1) AS average_attendance_month,
    COUNT(*) FILTER (WHERE date >= date_trunc('year', CURRENT_DATE)) AS total_services_year,
    COALESCE(SUM(attendance_count) FILTER (WHERE date >= date_trunc('year', CURRENT_DATE)), 0) AS total_attendance_year,
    ROUND(AVG(attendance_count) FILTER (WHERE date >= date_trunc('year', CURRENT_DATE)), 1) AS average_attendance_year,
    (SELECT service_type FROM public.worship_service WHERE date >= date_trunc('year', CURRENT_DATE) GROUP BY service_type ORDER BY AVG(attendance_count) DESC LIMIT 1) AS most_attended_service_type,
    (SELECT service_type FROM public.worship_service WHERE date >= date_trunc('year', CURRENT_DATE) GROUP BY service_type ORDER BY AVG(attendance_count) ASC LIMIT 1) AS least_attended_service_type
  FROM public.worship_service;
END;
$function$;
