-- =====================================================
-- FIX: Disable RLS on auth schema tables
-- =====================================================
-- PROBLEMA: O RLS foi ativado nas tabelas do schema auth,
-- impedindo o serviço de autenticação de acessar seus dados.
-- 
-- SOLUÇÃO: Desabilitar RLS em todas as tabelas do schema auth
-- exceto oauth_* que já estão corretas.
--
-- NOTA: Este script precisa ser executado com permissões
-- elevadas (service_role ou postgres superuser)
-- =====================================================

-- Desabilitar RLS nas tabelas críticas de autenticação
ALTER TABLE auth.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE auth.identities DISABLE ROW LEVEL SECURITY;
ALTER TABLE auth.sessions DISABLE ROW LEVEL SECURITY;
ALTER TABLE auth.refresh_tokens DISABLE ROW LEVEL SECURITY;
ALTER TABLE auth.instances DISABLE ROW LEVEL SECURITY;
ALTER TABLE auth.schema_migrations DISABLE ROW LEVEL SECURITY;
ALTER TABLE auth.audit_log_entries DISABLE ROW LEVEL SECURITY;

-- Desabilitar RLS nas tabelas SAML/SSO
ALTER TABLE auth.saml_providers DISABLE ROW LEVEL SECURITY;
ALTER TABLE auth.saml_relay_states DISABLE ROW LEVEL SECURITY;
ALTER TABLE auth.sso_providers DISABLE ROW LEVEL SECURITY;
ALTER TABLE auth.sso_domains DISABLE ROW LEVEL SECURITY;

-- Desabilitar RLS nas tabelas MFA
ALTER TABLE auth.mfa_factors DISABLE ROW LEVEL SECURITY;
ALTER TABLE auth.mfa_challenges DISABLE ROW LEVEL SECURITY;
ALTER TABLE auth.mfa_amr_claims DISABLE ROW LEVEL SECURITY;

-- Desabilitar RLS nas tabelas de fluxo e tokens
ALTER TABLE auth.flow_state DISABLE ROW LEVEL SECURITY;
ALTER TABLE auth.one_time_tokens DISABLE ROW LEVEL SECURITY;

-- Verificar resultado
DO $$
DECLARE
    tbl RECORD;
    rls_count INTEGER := 0;
BEGIN
    FOR tbl IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'auth' 
        AND rowsecurity = true
    LOOP
        rls_count := rls_count + 1;
        RAISE WARNING 'Tabela auth.% ainda tem RLS ativado', tbl.tablename;
    END LOOP;
    
    IF rls_count = 0 THEN
        RAISE NOTICE '✅ Sucesso! Todas as tabelas auth têm RLS desabilitado.';
    ELSE
        RAISE WARNING '⚠️ Ainda existem % tabela(s) com RLS ativado no schema auth', rls_count;
    END IF;
END $$;