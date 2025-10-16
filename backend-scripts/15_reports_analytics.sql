-- =====================================================
-- CHURCH 360 - SISTEMA DE RELATÓRIOS E ANALYTICS
-- =====================================================

-- =====================================================
-- 1. FUNÇÕES DE RELATÓRIO: MEMBROS
-- =====================================================

-- Relatório de crescimento de membros por período
CREATE OR REPLACE FUNCTION get_member_growth_report(
  start_date DATE,
  end_date DATE
)
RETURNS TABLE (
  period TEXT,
  new_members BIGINT,
  conversions BIGINT,
  baptisms BIGINT,
  total_members BIGINT
) AS $$
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
    (SELECT COUNT(*) FROM member WHERE created_at <= ds.month + INTERVAL '1 month') AS total_members
  FROM date_series ds
  LEFT JOIN member m ON m.created_at >= ds.month AND m.created_at < ds.month + INTERVAL '1 month'
  GROUP BY ds.month
  ORDER BY ds.month;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Estatísticas gerais de membros
CREATE OR REPLACE FUNCTION get_member_statistics()
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
) AS $$
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
  FROM member;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 2. FUNÇÕES DE RELATÓRIO: FINANCEIRO
-- =====================================================

-- Relatório financeiro por período
CREATE OR REPLACE FUNCTION get_financial_report(
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
) AS $$
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
      WHEN (SELECT SUM(target_amount) FROM financial_goal WHERE target_date >= ds.month AND target_date < ds.month + INTERVAL '1 month') > 0
      THEN ROUND(
        (COALESCE(SUM(c.amount) FILTER (WHERE c.date >= ds.month AND c.date < ds.month + INTERVAL '1 month'), 0) +
         COALESCE(SUM(d.amount) FILTER (WHERE d.date >= ds.month AND d.date < ds.month + INTERVAL '1 month'), 0)) /
        (SELECT SUM(target_amount) FROM financial_goal WHERE target_date >= ds.month AND target_date < ds.month + INTERVAL '1 month') * 100,
        2
      )
      ELSE 0
    END AS goal_progress
  FROM date_series ds
  LEFT JOIN contribution c ON c.date >= ds.month AND c.date < ds.month + INTERVAL '1 month'
  LEFT JOIN donation d ON d.date >= ds.month AND d.date < ds.month + INTERVAL '1 month'
  LEFT JOIN expense e ON e.date >= ds.month AND e.date < ds.month + INTERVAL '1 month'
  GROUP BY ds.month
  ORDER BY ds.month;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Estatísticas financeiras gerais
CREATE OR REPLACE FUNCTION get_financial_statistics()
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
) AS $$
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
    (SELECT COUNT(*) FROM financial_goal WHERE status = 'active') AS active_goals,
    (SELECT COUNT(*) FROM financial_goal WHERE status = 'completed') AS completed_goals
  FROM contribution c
  FULL OUTER JOIN donation d ON 1=1
  FULL OUTER JOIN expense e ON 1=1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 3. FUNÇÕES DE RELATÓRIO: CULTOS
-- =====================================================

-- Relatório de frequência em cultos
CREATE OR REPLACE FUNCTION get_worship_attendance_report(
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
) AS $$
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
  LEFT JOIN worship_service ws ON ws.date >= ds.month AND ws.date < ds.month + INTERVAL '1 month'
  GROUP BY ds.month
  ORDER BY ds.month;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Estatísticas de cultos
CREATE OR REPLACE FUNCTION get_worship_statistics()
RETURNS TABLE (
  total_services_month BIGINT,
  total_attendance_month BIGINT,
  average_attendance_month NUMERIC,
  total_services_year BIGINT,
  total_attendance_year BIGINT,
  average_attendance_year NUMERIC,
  most_attended_service_type TEXT,
  least_attended_service_type TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE date >= date_trunc('month', CURRENT_DATE)) AS total_services_month,
    COALESCE(SUM(attendance_count) FILTER (WHERE date >= date_trunc('month', CURRENT_DATE)), 0) AS total_attendance_month,
    ROUND(AVG(attendance_count) FILTER (WHERE date >= date_trunc('month', CURRENT_DATE)), 1) AS average_attendance_month,
    COUNT(*) FILTER (WHERE date >= date_trunc('year', CURRENT_DATE)) AS total_services_year,
    COALESCE(SUM(attendance_count) FILTER (WHERE date >= date_trunc('year', CURRENT_DATE)), 0) AS total_attendance_year,
    ROUND(AVG(attendance_count) FILTER (WHERE date >= date_trunc('year', CURRENT_DATE)), 1) AS average_attendance_year,
    (SELECT service_type FROM worship_service WHERE date >= date_trunc('year', CURRENT_DATE) GROUP BY service_type ORDER BY AVG(attendance_count) DESC LIMIT 1) AS most_attended_service_type,
    (SELECT service_type FROM worship_service WHERE date >= date_trunc('year', CURRENT_DATE) GROUP BY service_type ORDER BY AVG(attendance_count) ASC LIMIT 1) AS least_attended_service_type
  FROM worship_service;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 4. FUNÇÕES DE RELATÓRIO: GRUPOS
-- =====================================================

-- Relatório de participação em grupos
CREATE OR REPLACE FUNCTION get_group_participation_report(
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
) AS $$
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
    (SELECT COUNT(*) FROM "group" WHERE created_at <= ds.month + INTERVAL '1 month') AS total_groups,
    (SELECT COUNT(*) FROM "group" WHERE status = 'active' AND created_at <= ds.month + INTERVAL '1 month') AS active_groups,
    (SELECT COUNT(*) FROM group_member WHERE joined_at <= ds.month + INTERVAL '1 month') AS total_members,
    ROUND((SELECT COUNT(*)::NUMERIC FROM group_member WHERE joined_at <= ds.month + INTERVAL '1 month') / 
          NULLIF((SELECT COUNT(*) FROM "group" WHERE created_at <= ds.month + INTERVAL '1 month'), 0), 1) AS average_members_per_group,
    COUNT(gm.id) FILTER (WHERE gm.date >= ds.month AND gm.date < ds.month + INTERVAL '1 month') AS total_meetings,
    ROUND(AVG(
      (SELECT COUNT(*) FROM group_attendance ga WHERE ga.group_meeting_id = gm.id)
    ), 1) AS average_attendance
  FROM date_series ds
  LEFT JOIN group_meeting gm ON gm.date >= ds.month AND gm.date < ds.month + INTERVAL '1 month'
  GROUP BY ds.month
  ORDER BY ds.month;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Estatísticas de grupos
CREATE OR REPLACE FUNCTION get_group_statistics()
RETURNS TABLE (
  total_groups BIGINT,
  active_groups BIGINT,
  total_members BIGINT,
  average_members_per_group NUMERIC,
  meetings_this_month BIGINT,
  average_attendance_this_month NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) AS total_groups,
    COUNT(*) FILTER (WHERE status = 'active') AS active_groups,
    (SELECT COUNT(*) FROM group_member) AS total_members,
    ROUND((SELECT COUNT(*)::NUMERIC FROM group_member) / NULLIF(COUNT(*), 0), 1) AS average_members_per_group,
    (SELECT COUNT(*) FROM group_meeting WHERE date >= date_trunc('month', CURRENT_DATE)) AS meetings_this_month,
    (SELECT ROUND(AVG(
      (SELECT COUNT(*) FROM group_attendance ga WHERE ga.group_meeting_id = gm.id)
    ), 1) FROM group_meeting gm WHERE gm.date >= date_trunc('month', CURRENT_DATE)) AS average_attendance_this_month
  FROM "group";
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 5. FUNÇÕES DE RELATÓRIO: DEVOCIONAIS
-- =====================================================

-- Relatório de engajamento em devocionais
CREATE OR REPLACE FUNCTION get_devotional_engagement_report(
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
) AS $$
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
    COUNT(d.id) FILTER (WHERE d.date >= ds.month AND d.date < ds.month + INTERVAL '1 month') AS total_devotionals,
    COUNT(dr.id) FILTER (WHERE dr.read_at >= ds.month AND dr.read_at < ds.month + INTERVAL '1 month') AS total_readings,
    COUNT(DISTINCT dr.user_id) FILTER (WHERE dr.read_at >= ds.month AND dr.read_at < ds.month + INTERVAL '1 month') AS unique_readers,
    ROUND(
      COUNT(dr.id) FILTER (WHERE dr.read_at >= ds.month AND dr.read_at < ds.month + INTERVAL '1 month')::NUMERIC /
      NULLIF(COUNT(d.id) FILTER (WHERE d.date >= ds.month AND d.date < ds.month + INTERVAL '1 month'), 0),
      1
    ) AS average_readings_per_devotional,
    ROUND(
      COUNT(DISTINCT dr.user_id) FILTER (WHERE dr.read_at >= ds.month AND dr.read_at < ds.month + INTERVAL '1 month')::NUMERIC /
      NULLIF((SELECT COUNT(*) FROM member WHERE status = 'active'), 0) * 100,
      2
    ) AS engagement_rate
  FROM date_series ds
  LEFT JOIN devotionals d ON d.date >= ds.month AND d.date < ds.month + INTERVAL '1 month'
  LEFT JOIN devotional_readings dr ON dr.read_at >= ds.month AND dr.read_at < ds.month + INTERVAL '1 month'
  GROUP BY ds.month
  ORDER BY ds.month;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Estatísticas de devocionais
CREATE OR REPLACE FUNCTION get_devotional_statistics()
RETURNS TABLE (
  total_devotionals BIGINT,
  readings_this_month BIGINT,
  unique_readers_this_month BIGINT,
  engagement_rate_this_month NUMERIC,
  readings_this_year BIGINT,
  unique_readers_this_year BIGINT,
  engagement_rate_this_year NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) AS total_devotionals,
    (SELECT COUNT(*) FROM devotional_readings WHERE read_at >= date_trunc('month', CURRENT_DATE)) AS readings_this_month,
    (SELECT COUNT(DISTINCT user_id) FROM devotional_readings WHERE read_at >= date_trunc('month', CURRENT_DATE)) AS unique_readers_this_month,
    ROUND(
      (SELECT COUNT(DISTINCT user_id)::NUMERIC FROM devotional_readings WHERE read_at >= date_trunc('month', CURRENT_DATE)) /
      NULLIF((SELECT COUNT(*) FROM member WHERE status = 'active'), 0) * 100,
      2
    ) AS engagement_rate_this_month,
    (SELECT COUNT(*) FROM devotional_readings WHERE read_at >= date_trunc('year', CURRENT_DATE)) AS readings_this_year,
    (SELECT COUNT(DISTINCT user_id) FROM devotional_readings WHERE read_at >= date_trunc('year', CURRENT_DATE)) AS unique_readers_this_year,
    ROUND(
      (SELECT COUNT(DISTINCT user_id)::NUMERIC FROM devotional_readings WHERE read_at >= date_trunc('year', CURRENT_DATE)) /
      NULLIF((SELECT COUNT(*) FROM member WHERE status = 'active'), 0) * 100,
      2
    ) AS engagement_rate_this_year
  FROM devotionals;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 6. FUNÇÕES DE RELATÓRIO: MINISTÉRIOS
-- =====================================================

-- Relatório de participação em ministérios
CREATE OR REPLACE FUNCTION get_ministry_participation_report()
RETURNS TABLE (
  ministry_name TEXT,
  total_members BIGINT,
  active_members BIGINT,
  schedules_this_month BIGINT,
  engagement_rate NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    m.name AS ministry_name,
    COUNT(mm.id) AS total_members,
    COUNT(mm.id) FILTER (WHERE mm.is_active = true) AS active_members,
    COUNT(ms.id) FILTER (WHERE ms.date >= date_trunc('month', CURRENT_DATE)) AS schedules_this_month,
    ROUND(
      COUNT(mm.id) FILTER (WHERE mm.is_active = true)::NUMERIC /
      NULLIF((SELECT COUNT(*) FROM member WHERE status = 'active'), 0) * 100,
      2
    ) AS engagement_rate
  FROM ministry m
  LEFT JOIN ministry_member mm ON mm.ministry_id = m.id
  LEFT JOIN ministry_schedule ms ON ms.ministry_id = m.id
  GROUP BY m.id, m.name
  ORDER BY total_members DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Estatísticas de ministérios
CREATE OR REPLACE FUNCTION get_ministry_statistics()
RETURNS TABLE (
  total_ministries BIGINT,
  active_ministries BIGINT,
  total_members BIGINT,
  average_members_per_ministry NUMERIC,
  schedules_this_month BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) AS total_ministries,
    COUNT(*) FILTER (WHERE is_active = true) AS active_ministries,
    (SELECT COUNT(*) FROM ministry_member) AS total_members,
    ROUND((SELECT COUNT(*)::NUMERIC FROM ministry_member) / NULLIF(COUNT(*), 0), 1) AS average_members_per_ministry,
    (SELECT COUNT(*) FROM ministry_schedule WHERE date >= date_trunc('month', CURRENT_DATE)) AS schedules_this_month
  FROM ministry;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 7. FUNÇÕES DE RELATÓRIO: VISITANTES
-- =====================================================

-- Relatório de visitantes e conversão
CREATE OR REPLACE FUNCTION get_visitor_conversion_report(
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
) AS $$
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
  LEFT JOIN visitor v ON v.first_visit_date >= ds.month AND v.first_visit_date < ds.month + INTERVAL '1 month'
  LEFT JOIN visitor_visit vv ON vv.visit_date >= ds.month AND vv.visit_date < ds.month + INTERVAL '1 month'
  LEFT JOIN visitor_followup vf ON vf.followup_date >= ds.month AND vf.followup_date < ds.month + INTERVAL '1 month'
  GROUP BY ds.month
  ORDER BY ds.month;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Estatísticas de visitantes
CREATE OR REPLACE FUNCTION get_visitor_statistics()
RETURNS TABLE (
  total_visitors BIGINT,
  new_this_month BIGINT,
  visits_this_month BIGINT,
  followups_pending BIGINT,
  converted_to_members BIGINT,
  conversion_rate NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) AS total_visitors,
    COUNT(*) FILTER (WHERE first_visit_date >= date_trunc('month', CURRENT_DATE)) AS new_this_month,
    (SELECT COUNT(*) FROM visitor_visit WHERE visit_date >= date_trunc('month', CURRENT_DATE)) AS visits_this_month,
    (SELECT COUNT(*) FROM visitor_followup WHERE status = 'pending') AS followups_pending,
    COUNT(*) FILTER (WHERE became_member = true) AS converted_to_members,
    ROUND(
      COUNT(*) FILTER (WHERE became_member = true)::NUMERIC /
      NULLIF(COUNT(*), 0) * 100,
      2
    ) AS conversion_rate
  FROM visitor;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 8. DASHBOARD GERAL
-- =====================================================

-- Função para obter resumo geral do dashboard
CREATE OR REPLACE FUNCTION get_dashboard_summary()
RETURNS TABLE (
  total_members BIGINT,
  active_members BIGINT,
  new_members_this_month BIGINT,
  total_groups BIGINT,
  active_groups BIGINT,
  total_ministries BIGINT,
  total_visitors BIGINT,
  new_visitors_this_month BIGINT,
  services_this_month BIGINT,
  average_attendance NUMERIC,
  contributions_this_month NUMERIC,
  expenses_this_month NUMERIC,
  net_balance_this_month NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM member) AS total_members,
    (SELECT COUNT(*) FROM member WHERE status = 'active') AS active_members,
    (SELECT COUNT(*) FROM member WHERE created_at >= date_trunc('month', CURRENT_DATE)) AS new_members_this_month,
    (SELECT COUNT(*) FROM "group") AS total_groups,
    (SELECT COUNT(*) FROM "group" WHERE status = 'active') AS active_groups,
    (SELECT COUNT(*) FROM ministry) AS total_ministries,
    (SELECT COUNT(*) FROM visitor) AS total_visitors,
    (SELECT COUNT(*) FROM visitor WHERE first_visit_date >= date_trunc('month', CURRENT_DATE)) AS new_visitors_this_month,
    (SELECT COUNT(*) FROM worship_service WHERE date >= date_trunc('month', CURRENT_DATE)) AS services_this_month,
    (SELECT ROUND(AVG(attendance_count), 1) FROM worship_service WHERE date >= date_trunc('month', CURRENT_DATE)) AS average_attendance,
    (SELECT COALESCE(SUM(amount), 0) FROM contribution WHERE date >= date_trunc('month', CURRENT_DATE)) +
    (SELECT COALESCE(SUM(amount), 0) FROM donation WHERE date >= date_trunc('month', CURRENT_DATE)) AS contributions_this_month,
    (SELECT COALESCE(SUM(amount), 0) FROM expense WHERE date >= date_trunc('month', CURRENT_DATE)) AS expenses_this_month,
    (SELECT COALESCE(SUM(amount), 0) FROM contribution WHERE date >= date_trunc('month', CURRENT_DATE)) +
    (SELECT COALESCE(SUM(amount), 0) FROM donation WHERE date >= date_trunc('month', CURRENT_DATE)) -
    (SELECT COALESCE(SUM(amount), 0) FROM expense WHERE date >= date_trunc('month', CURRENT_DATE)) AS net_balance_this_month;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
