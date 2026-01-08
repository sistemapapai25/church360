-- =====================================================
-- CORREÇÃO: Function Search Path Mutable (Security) - Parte 2
-- =====================================================
-- Descrição: Recria mais funções apontadas pelo Security Advisor
-- definindo explicitamente o search_path para evitar injeção de schema.
-- =====================================================

-- 1. access_level_to_number
CREATE OR REPLACE FUNCTION public.access_level_to_number(level public.access_level_type)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO ''
AS $function$
BEGIN
  RETURN CASE level
    WHEN 'visitor' THEN 0
    WHEN 'attendee' THEN 1
    WHEN 'member' THEN 2
    WHEN 'leader' THEN 3
    WHEN 'coordinator' THEN 4
    WHEN 'admin' THEN 5
    ELSE 0
  END;
END;
$function$;

-- 2. number_to_access_level
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

-- 3. sync_access_level_number
CREATE OR REPLACE FUNCTION public.sync_access_level_number()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  -- Chama a função qualificada
  NEW.access_level_number := public.access_level_to_number(NEW.access_level);
  RETURN NEW;
END;
$function$;

-- 4. update_quick_news_updated_at
CREATE OR REPLACE FUNCTION public.update_quick_news_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$;

-- 5. update_dispatch_rule_updated_at
CREATE OR REPLACE FUNCTION public.update_dispatch_rule_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$;

-- 6. update_devotionals_updated_at
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

-- 7. update_devotional_readings_updated_at
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

-- 8. get_today_devotional
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

-- 9. get_devotional_stats
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

-- 10. get_user_reading_streak
CREATE OR REPLACE FUNCTION public.get_user_reading_streak(user_uuid UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
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
$function$;
