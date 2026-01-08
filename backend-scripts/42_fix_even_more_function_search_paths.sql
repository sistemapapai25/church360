-- =====================================================
-- CORREÇÃO: Function Search Path Mutable (Security) - Parte 3
-- =====================================================
-- Descrição: Recria mais funções apontadas pelo Security Advisor
-- definindo explicitamente o search_path para evitar injeção de schema.
-- =====================================================

-- 1. update_prayer_requests_updated_at
CREATE OR REPLACE FUNCTION public.update_prayer_requests_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = NOW();
  
  -- Se status mudou para 'answered', atualizar answered_at
  IF NEW.status = 'answered' AND OLD.status != 'answered' THEN
    NEW.answered_at = NOW();
  END IF;
  
  RETURN NEW;
END;
$function$;

-- 2. update_prayer_request_prayers_updated_at
CREATE OR REPLACE FUNCTION public.update_prayer_request_prayers_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

-- 3. update_prayer_request_testimonies_updated_at
CREATE OR REPLACE FUNCTION public.update_prayer_request_testimonies_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

-- 4. get_prayer_request_stats
CREATE OR REPLACE FUNCTION public.get_prayer_request_stats(request_uuid UUID)
RETURNS TABLE (
  total_prayers BIGINT,
  unique_prayers BIGINT,
  has_testimony BOOLEAN
) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(prp.id)::BIGINT as total_prayers,
    COUNT(DISTINCT prp.user_id)::BIGINT as unique_prayers,
    EXISTS (
      SELECT 1 FROM public.prayer_request_testimonies prt
      JOIN public.prayer_requests pr ON prt.prayer_request_id = pr.id
      WHERE prt.prayer_request_id = request_uuid
        AND pr.tenant_id = public.current_tenant_id()
    ) as has_testimony
  FROM public.prayer_request_prayers prp
  JOIN public.prayer_requests pr ON prp.prayer_request_id = pr.id
  WHERE prp.prayer_request_id = request_uuid
    AND pr.tenant_id = public.current_tenant_id();
END;
$function$;

-- 5. get_prayer_requests_by_category
CREATE OR REPLACE FUNCTION public.get_prayer_requests_by_category()
RETURNS TABLE (
  category public.prayer_category,
  total_count BIGINT
) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    pr.category,
    COUNT(*)::BIGINT as total_count
  FROM public.prayer_requests pr
  WHERE pr.tenant_id = public.current_tenant_id()
  GROUP BY pr.category
  ORDER BY total_count DESC;
END;
$function$;

-- 6. get_prayer_requests_by_status
CREATE OR REPLACE FUNCTION public.get_prayer_requests_by_status()
RETURNS TABLE (
  status public.prayer_status,
  total_count BIGINT
) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    pr.status,
    COUNT(*)::BIGINT as total_count
  FROM public.prayer_requests pr
  WHERE pr.tenant_id = public.current_tenant_id()
  GROUP BY pr.status
  ORDER BY total_count DESC;
END;
$function$;

-- 7. get_recent_public_testimonies
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
AS $function$
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
$function$;
