-- =====================================================
-- CORREÇÃO: Function Search Path Mutable (Security) - Parte 5 (Final)
-- =====================================================
-- Descrição: Corrige search_path de funções remanescentes e recria algumas
-- que podem não ter sido atualizadas corretamente.
-- =====================================================

-- 1. get_unread_notifications_count (Nova identificação)
CREATE OR REPLACE FUNCTION public.get_unread_notifications_count(target_user_id UUID)
RETURNS BIGINT 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RETURN (
    SELECT COUNT(*)
    FROM public.notifications
    WHERE user_id = target_user_id
    AND status != 'read'
  );
END;
$function$;

-- 2. has_role (Reforço - Garantir correção)
CREATE OR REPLACE FUNCTION public.has_role(user_id uuid, role_name text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.user_roles ur
    JOIN public.roles r ON r.id = ur.role_id
    WHERE ur.user_id = has_role.user_id 
      AND r.name = has_role.role_name
      AND ur.is_active = true
      AND (ur.expires_at IS NULL OR ur.expires_at > now())
  );
END;
$function$;

-- 3. mark_all_notifications_as_read (Reforço)
CREATE OR REPLACE FUNCTION public.mark_all_notifications_as_read(target_user_id UUID)
RETURNS VOID 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  UPDATE public.notifications
  SET status = 'read', read_at = NOW()
  WHERE user_id = target_user_id
  AND status != 'read';
END;
$function$;

-- 4. update_worship_attendance_count (Reforço)
CREATE OR REPLACE FUNCTION public.update_worship_attendance_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.worship_service
    SET total_attendance = (
      SELECT COUNT(*) FROM public.worship_attendance
      WHERE worship_service_id = NEW.worship_service_id
    )
    WHERE id = NEW.worship_service_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.worship_service
    SET total_attendance = (
      SELECT COUNT(*) FROM public.worship_attendance
      WHERE worship_service_id = OLD.worship_service_id
    )
    WHERE id = OLD.worship_service_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$function$;

-- 5. create_devotional_notification (Reforço)
CREATE OR REPLACE FUNCTION public.create_devotional_notification(devotional_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  devotional_title TEXT;
  user_record RECORD;
BEGIN
  SELECT title INTO devotional_title
  FROM public.devotionals
  WHERE id = devotional_id;

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
$function$;

-- 6. create_event_reminder_notification (Reforço)
CREATE OR REPLACE FUNCTION public.create_event_reminder_notification(event_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  event_title TEXT;
  event_date TIMESTAMPTZ;
  user_record RECORD;
BEGIN
  SELECT title, start_date INTO event_title, event_date
  FROM public.events
  WHERE id = event_id;

  FOR user_record IN
    SELECT np.user_id
    FROM public.notification_preferences np
    WHERE np.events_reminder = true
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
      'O evento "' || event_title || '" acontecerá em breve!',
      jsonb_build_object('event_id', event_id),
      '/events/' || event_id,
      'pending'
    );
  END LOOP;
END;
$function$;

-- 7. update_dashboard_widget_updated_at (Reforço)
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

-- 8. restore_default_dashboard_widgets (Reforço)
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

-- 9. check_user_permission (Reforço)
CREATE OR REPLACE FUNCTION public.check_user_permission(
  p_user_id UUID,
  p_permission_code TEXT
) RETURNS BOOLEAN 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_has_permission BOOLEAN;
BEGIN
  SELECT is_granted INTO v_has_permission
  FROM public.user_custom_permissions ucp
  JOIN public.permissions p ON p.id = ucp.permission_id
  WHERE ucp.user_id = p_user_id
    AND p.code = p_permission_code
    AND (ucp.expires_at IS NULL OR ucp.expires_at > NOW())
  LIMIT 1;

  IF FOUND THEN
    RETURN v_has_permission;
  END IF;

  SELECT EXISTS(
    SELECT 1
    FROM public.user_roles ur
    JOIN public.role_permissions rp ON rp.role_id = ur.role_id
    JOIN public.permissions p ON p.id = rp.permission_id
    WHERE ur.user_id = p_user_id
      AND p.code = p_permission_code
      AND ur.is_active = true
      AND (ur.expires_at IS NULL OR ur.expires_at > NOW())
      AND rp.is_granted = true
  ) INTO v_has_permission;

  RETURN COALESCE(v_has_permission, false);
END;
$function$;
