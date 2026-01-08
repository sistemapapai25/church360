-- =====================================================
-- FIX SECURITY ADVISOR ISSUES: FUNCTION SEARCH PATH MUTABLE (BATCH 12)
-- =====================================================
-- This script fixes "function_search_path_mutable" warnings for 7 functions.
-- It explicitly sets search_path to '' and fully qualifies all object references.
--
-- Note: The following functions were NOT found in the codebase and are skipped:
-- - trg_dispatch_job_after_insert
-- - trg_dispatch_job_after_update
-- These triggers likely involve external service calls and redefining them blindly is unsafe.
--
-- Fixed functions:
-- 1. trigger_set_timestamp
-- 2. sync_user_names
-- 3. update_dispatch_job_updated_at
-- 4. get_dashboard_summary
-- 5. compute_whatsapp_auto_next_run
-- 6. set_whatsapp_auto_next_run
-- 7. update_message_template_updated_at

-- 1. trigger_set_timestamp
CREATE OR REPLACE FUNCTION public.trigger_set_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

-- 2. sync_user_names
CREATE OR REPLACE FUNCTION public.sync_user_names()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  -- Se first_name ou last_name foram alterados, atualiza full_name
  IF (TG_OP = 'INSERT' OR 
      NEW.first_name IS DISTINCT FROM OLD.first_name OR 
      NEW.last_name IS DISTINCT FROM OLD.last_name) THEN
    
    -- Construir full_name a partir de first_name e last_name
    IF NEW.first_name IS NOT NULL AND NEW.last_name IS NOT NULL THEN
      NEW.full_name := TRIM(NEW.first_name || ' ' || NEW.last_name);
    ELSIF NEW.first_name IS NOT NULL THEN
      NEW.full_name := NEW.first_name;
    ELSIF NEW.last_name IS NOT NULL THEN
      NEW.full_name := NEW.last_name;
    END IF;
  END IF;

  -- Se full_name foi alterado e first_name/last_name estão vazios, divide full_name
  IF (TG_OP = 'INSERT' OR NEW.full_name IS DISTINCT FROM OLD.full_name) THEN
    IF NEW.full_name IS NOT NULL AND 
       (NEW.first_name IS NULL OR NEW.last_name IS NULL) THEN
      
      -- Dividir full_name em first_name e last_name
      DECLARE
        name_parts TEXT[];
      BEGIN
        name_parts := string_to_array(TRIM(NEW.full_name), ' ');
        
        IF array_length(name_parts, 1) >= 2 THEN
          -- Primeiro nome é o primeiro elemento
          NEW.first_name := name_parts[1];
          -- Sobrenome é o resto
          NEW.last_name := array_to_string(name_parts[2:array_length(name_parts, 1)], ' ');
        ELSIF array_length(name_parts, 1) = 1 THEN
          -- Se só tem um nome, coloca em first_name
          NEW.first_name := name_parts[1];
          NEW.last_name := '';
        END IF;
      END;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

-- 3. update_dispatch_job_updated_at
CREATE OR REPLACE FUNCTION public.update_dispatch_job_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

-- 4. get_dashboard_summary
CREATE OR REPLACE FUNCTION public.get_dashboard_summary()
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
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.member) AS total_members,
    (SELECT COUNT(*) FROM public.member WHERE status = 'active') AS active_members,
    (SELECT COUNT(*) FROM public.member WHERE created_at >= date_trunc('month', CURRENT_DATE)) AS new_members_this_month,
    (SELECT COUNT(*) FROM public."group") AS total_groups,
    (SELECT COUNT(*) FROM public."group" WHERE status = 'active') AS active_groups,
    (SELECT COUNT(*) FROM public.ministry) AS total_ministries,
    (SELECT COUNT(*) FROM public.visitor) AS total_visitors,
    (SELECT COUNT(*) FROM public.visitor WHERE first_visit_date >= date_trunc('month', CURRENT_DATE)) AS new_visitors_this_month,
    (SELECT COUNT(*) FROM public.worship_service WHERE date >= date_trunc('month', CURRENT_DATE)) AS services_this_month,
    (SELECT ROUND(AVG(attendance_count), 1) FROM public.worship_service WHERE date >= date_trunc('month', CURRENT_DATE)) AS average_attendance,
    (SELECT COALESCE(SUM(amount), 0) FROM public.contribution WHERE date >= date_trunc('month', CURRENT_DATE)) +
    (SELECT COALESCE(SUM(amount), 0) FROM public.donation WHERE date >= date_trunc('month', CURRENT_DATE)) AS contributions_this_month,
    (SELECT COALESCE(SUM(amount), 0) FROM public.expense WHERE date >= date_trunc('month', CURRENT_DATE)) AS expenses_this_month,
    (SELECT COALESCE(SUM(amount), 0) FROM public.contribution WHERE date >= date_trunc('month', CURRENT_DATE)) +
    (SELECT COALESCE(SUM(amount), 0) FROM public.donation WHERE date >= date_trunc('month', CURRENT_DATE)) -
    (SELECT COALESCE(SUM(amount), 0) FROM public.expense WHERE date >= date_trunc('month', CURRENT_DATE)) AS net_balance_this_month;
END;
$function$;

-- 5. compute_whatsapp_auto_next_run
CREATE OR REPLACE FUNCTION public.compute_whatsapp_auto_next_run(send_time TEXT, tz TEXT)
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  base_date DATE := (NOW() AT TIME ZONE tz)::DATE;
  local_ts TIMESTAMP := to_timestamp(to_char(base_date, 'YYYY-MM-DD') || ' ' || send_time, 'YYYY-MM-DD HH24:MI');
  next_run TIMESTAMPTZ := local_ts AT TIME ZONE tz;
BEGIN
  IF next_run <= NOW() THEN
    next_run := (local_ts + INTERVAL '1 day') AT TIME ZONE tz;
  END IF;
  RETURN next_run;
END;
$function$;

-- 6. set_whatsapp_auto_next_run
CREATE OR REPLACE FUNCTION public.set_whatsapp_auto_next_run()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NEW.next_run IS NULL THEN
    NEW.next_run = public.compute_whatsapp_auto_next_run(NEW.send_time, NEW.timezone);
  END IF;
  RETURN NEW;
END;
$function$;

-- 7. update_message_template_updated_at
CREATE OR REPLACE FUNCTION public.update_message_template_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;
