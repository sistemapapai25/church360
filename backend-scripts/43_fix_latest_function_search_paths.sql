-- =====================================================
-- FIX SECURITY WARNINGS: function_search_path_mutable
-- Batch 4: 7 functions + dynamic fix for 4 missing functions
-- =====================================================

-- 1. count_user_testimonies
CREATE OR REPLACE FUNCTION public.count_user_testimonies(user_id UUID)
RETURNS INT 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  total_count INT;
BEGIN
  SELECT COUNT(*)::INT INTO total_count
  FROM public.testimonies
  WHERE author_id = user_id;
  
  RETURN total_count;
END;
$function$;

-- 2. update_updated_at_column
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

-- 3. get_user_effective_permissions
CREATE OR REPLACE FUNCTION public.get_user_effective_permissions(p_user_id UUID)
RETURNS TABLE(
  permission_code TEXT,
  permission_name TEXT,
  source TEXT,
  role_name TEXT,
  context_name TEXT,
  is_granted BOOLEAN
) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RETURN QUERY
  -- Permissões dos cargos
  SELECT DISTINCT
    p.code,
    p.name,
    'role'::TEXT,
    r.name,
    rc.context_name,
    rp.is_granted
  FROM public.user_roles ur
  JOIN public.roles r ON r.id = ur.role_id
  JOIN public.role_permissions rp ON rp.role_id = r.id
  JOIN public.permissions p ON p.id = rp.permission_id
  LEFT JOIN public.role_contexts rc ON rc.id = ur.role_context_id
  WHERE ur.user_id = p_user_id
    AND ur.is_active = true
    AND (ur.expires_at IS NULL OR ur.expires_at > NOW())
    AND r.is_active = true
    AND p.is_active = true

  UNION

  -- Permissões customizadas
  SELECT
    p.code,
    p.name,
    'custom'::TEXT,
    NULL,
    NULL,
    ucp.is_granted
  FROM public.user_custom_permissions ucp
  JOIN public.permissions p ON p.id = ucp.permission_id
  WHERE ucp.user_id = p_user_id
    AND (ucp.expires_at IS NULL OR ucp.expires_at > NOW())
    AND p.is_active = true;
END;
$function$;

-- 4. update_fcm_tokens_updated_at
CREATE OR REPLACE FUNCTION public.update_fcm_tokens_updated_at()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

-- 5. update_notification_preferences_updated_at
CREATE OR REPLACE FUNCTION public.update_notification_preferences_updated_at()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

-- 6. update_notifications_updated_at
CREATE OR REPLACE FUNCTION public.update_notifications_updated_at()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = NOW();
  
  -- Se status mudou para 'sent', atualizar sent_at
  IF NEW.status = 'sent' AND OLD.status != 'sent' THEN
    NEW.sent_at = NOW();
  END IF;
  
  -- Se status mudou para 'read', atualizar read_at
  IF NEW.status = 'read' AND OLD.status != 'read' THEN
    NEW.read_at = NOW();
  END IF;
  
  RETURN NEW;
END;
$function$;

-- 7. notify_prayer_request_prayed
CREATE OR REPLACE FUNCTION public.notify_prayer_request_prayed()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
  request_author_id UUID;
  request_title TEXT;
  praying_user_name TEXT;
BEGIN
  -- Buscar autor do pedido
  SELECT author_id, title INTO request_author_id, request_title
  FROM public.prayer_requests
  WHERE id = NEW.prayer_request_id;
  
  -- Não notificar se o autor orou pelo próprio pedido
  IF request_author_id = NEW.user_id THEN
    RETURN NEW;
  END IF;
  
  -- Buscar nome do usuário que orou (se disponível)
  -- Por enquanto, usar "Alguém" como placeholder
  praying_user_name := 'Alguém';
  
  -- Criar notificação
  INSERT INTO public.notifications (
    user_id,
    type,
    title,
    body,
    data,
    route,
    status
  ) VALUES (
    request_author_id,
    'prayer_request_prayed',
    'Alguém orou por você! 🙏',
    praying_user_name || ' orou pelo seu pedido: "' || request_title || '"',
    jsonb_build_object('prayer_request_id', NEW.prayer_request_id),
    '/prayer-requests/' || NEW.prayer_request_id,
    'pending'
  );
  
  RETURN NEW;
END;
$function$;

-- 8. Dynamic Fix for Missing Functions
-- Functions: gerar_codigo_qr, calcular_duracao_presenca, registrar_log_auditoria, gerar_codigo_verificacao
DO $$
DECLARE
    target_funcs text[] := ARRAY['gerar_codigo_qr', 'calcular_duracao_presenca', 'registrar_log_auditoria', 'gerar_codigo_verificacao'];
    func_name text;
    func_signature text;
BEGIN
    FOREACH func_name IN ARRAY target_funcs
    LOOP
        FOR func_signature IN 
            SELECT format('%I.%I(%s)', n.nspname, p.proname, pg_get_function_identity_arguments(p.oid))
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE p.proname = func_name AND n.nspname = 'public'
        LOOP
            EXECUTE format('ALTER FUNCTION %s SET search_path = ''''', func_signature);
            RAISE NOTICE 'Fixed search_path for %', func_signature;
        END LOOP;
    END LOOP;
END $$;
