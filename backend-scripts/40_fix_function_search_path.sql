-- =====================================================
-- CORREÇÃO: Function Search Path Mutable (Security)
-- =====================================================
-- Descrição: Recria as funções apontadas pelo Security Advisor
-- definindo explicitamente o search_path para evitar injeção de schema.
-- =====================================================

-- 1. has_role
-- Recriando função para verificar papéis com search_path seguro
CREATE OR REPLACE FUNCTION public.has_role(user_id uuid, role_name text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  -- Como search_path está vazio, precisamos qualificar tudo com public.
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

-- 2. is_admin_or_pastor
-- ATENÇÃO: Corrigindo parâmetro para evitar conflito de nomes
DROP FUNCTION IF EXISTS public.is_admin_or_pastor(uuid);

CREATE OR REPLACE FUNCTION public.is_admin_or_pastor(p_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.user_access_level ual
    WHERE ual.user_id = p_user_id
      AND ual.access_level_number >= 4 -- Admin (5) ou Pastor (4)
  );
END;
$function$;

-- 3. update_whatsapp_relatorios_automaticos_updated_at
CREATE OR REPLACE FUNCTION public.update_whatsapp_relatorios_automaticos_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$;

-- 4. update_testimonies_updated_at
CREATE OR REPLACE FUNCTION public.update_testimonies_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$;
