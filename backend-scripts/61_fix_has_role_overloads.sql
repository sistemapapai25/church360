-- =====================================================
-- CORREÇÃO DEFINITIVA: has_role (Overloads)
-- =====================================================
-- Descrição: Remove TODAS as variações da função has_role
-- e recria com search_path seguro.
-- Isso cobre casos onde existe has_role(text) além de has_role(uuid, text).
-- =====================================================

-- 1. Remover TODAS as versões possíveis (para garantir limpeza)
DROP FUNCTION IF EXISTS public.has_role(text);
DROP FUNCTION IF EXISTS public.has_role(uuid, text);

-- 2. Recriar a versão principal (uuid, text)
CREATE OR REPLACE FUNCTION public.has_role(user_id uuid, role_name text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  -- Verifica se o usuário possui o papel especificado
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

-- 3. Recriar a versão de conveniência (apenas text) que usa o usuário atual
-- Esta versão também precisa de search_path seguro!
CREATE OR REPLACE FUNCTION public.has_role(role_name text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  -- Chama a função principal passando o ID do usuário autenticado
  RETURN public.has_role(auth.uid(), role_name);
END;
$function$;

-- =====================================================
-- Verificação (apenas informativo)
-- =====================================================
-- Se este script rodar sem erros, ambas as funções estarão seguras.
