CREATE OR REPLACE FUNCTION public.update_devotionals_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_devotional_readings_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_dashboard_widget_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.restore_default_dashboard_widgets()
RETURNS void
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  UPDATE public.dashboard_widget
  SET is_enabled = true
  WHERE is_default = true;
  
  UPDATE public.dashboard_widget SET display_order = 1 WHERE widget_key = 'birthdays_month';
  UPDATE public.dashboard_widget SET display_order = 2 WHERE widget_key = 'recent_members';
  UPDATE public.dashboard_widget SET display_order = 3 WHERE widget_key = 'upcoming_events';
  UPDATE public.dashboard_widget SET display_order = 4 WHERE widget_key = 'upcoming_expenses';
  UPDATE public.dashboard_widget SET display_order = 5 WHERE widget_key = 'member_growth';
  UPDATE public.dashboard_widget SET display_order = 6 WHERE widget_key = 'events_stats';
  UPDATE public.dashboard_widget SET display_order = 7 WHERE widget_key = 'top_active_groups';
  UPDATE public.dashboard_widget SET display_order = 8 WHERE widget_key = 'average_attendance';
  UPDATE public.dashboard_widget SET display_order = 9 WHERE widget_key = 'top_tags';
  UPDATE public.dashboard_widget SET display_order = 10 WHERE widget_key = 'financial_summary';
  UPDATE public.dashboard_widget SET display_order = 11 WHERE widget_key = 'contributions_by_type';
  UPDATE public.dashboard_widget SET display_order = 12 WHERE widget_key = 'financial_goals';
END;
$function$;

CREATE OR REPLACE FUNCTION public.sync_access_level_number()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.access_level_number := public.access_level_to_number(NEW.access_level);
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.number_to_access_level(level_number INTEGER)
RETURNS public.access_level_type
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO ''
AS $function$
BEGIN
  RETURN CASE level_number
    WHEN 0 THEN 'visitor'::public.access_level_type
    WHEN 1 THEN 'attendee'::public.access_level_type
    WHEN 2 THEN 'member'::public.access_level_type
    WHEN 3 THEN 'leader'::public.access_level_type
    WHEN 4 THEN 'coordinator'::public.access_level_type
    WHEN 5 THEN 'admin'::public.access_level_type
    ELSE 'visitor'::public.access_level_type
  END;
END;
$function$;

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
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.get_devotional_stats(devotional_uuid UUID)
RETURNS TABLE (
  total_reads BIGINT,
  unique_readers BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::BIGINT as total_reads,
    COUNT(DISTINCT dr.user_id)::BIGINT as unique_readers
  FROM public.devotional_readings dr
  WHERE dr.devotional_id = devotional_uuid;
END;
$function$;

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
