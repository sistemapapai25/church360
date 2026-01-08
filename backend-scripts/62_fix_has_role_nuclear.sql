-- =====================================================
-- CORREÇÃO NUCLEAR: has_role
-- =====================================================
-- Descrição: Remove TODAS as versões de has_role existentes
-- e recria apenas as versões seguras.
-- Isso resolve problemas de cache, overloads ocultos ou definições antigas.
-- =====================================================

-- 1. Bloco anônimo para encontrar e remover TODAS as funções 'has_role' no schema public
DO $$
DECLARE
    r RECORD;
BEGIN
    -- Itera sobre todas as funções chamadas 'has_role' no schema 'public'
    FOR r IN 
        SELECT p.oid::regprocedure AS func_signature
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE p.proname = 'has_role'
        AND n.nspname = 'public'
    LOOP
        RAISE NOTICE 'Removendo função antiga: %', r.func_signature;
        EXECUTE 'DROP FUNCTION ' || r.func_signature || ' CASCADE';
    END LOOP;
END $$;

-- 2. Recriar a versão principal (uuid, text) com segurança máxima
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
CREATE OR REPLACE FUNCTION public.has_role(role_name text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  -- Chama a função principal passando o ID do usuário autenticado (auth.uid())
  RETURN public.has_role(auth.uid(), role_name);
END;
$function$;

-- =====================================================
-- FIM
-- =====================================================
