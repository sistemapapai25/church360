-- =====================================================
-- CORREÇÃO: Security Advisor Issues
-- =====================================================
-- Descrição: Corrige problemas apontados pelo Supabase Security Advisor
-- 1. Habilita RLS em tabelas que possuem políticas mas RLS estava desabilitado.
-- 2. Altera Views para usar security_invoker=on (segurança de quem chama).
-- =====================================================

-- 1. Habilitar RLS em tabelas com políticas existentes
ALTER TABLE public.custom_report_permission ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_participants ENABLE ROW LEVEL SECURITY;

-- 2. Corrigir Views "Security Definer" para "Security Invoker"
-- Isso garante que a view respeite as políticas RLS do usuário que está consultando.
ALTER VIEW public.v_dispatch_rules_active SET (security_invoker = on);
ALTER VIEW public.v_dispatch_jobs_pending SET (security_invoker = on);
