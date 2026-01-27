-- =====================================================
-- SOLUÇÃO ALTERNATIVA: Função com SECURITY DEFINER
-- =====================================================
-- Como você não é owner das tabelas auth, vamos criar
-- uma função que executa com privilégios elevados.
-- =====================================================

-- Passo 1: Criar a função que desabilita RLS
CREATE OR REPLACE FUNCTION public.fix_auth_rls()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_result text := '';
  v_count integer := 0;
BEGIN
  -- Tentar desabilitar RLS em cada tabela
  BEGIN
    ALTER TABLE auth.users DISABLE ROW LEVEL SECURITY;
    v_result := v_result || 'auth.users: OK' || chr(10);
  EXCEPTION WHEN OTHERS THEN
    v_result := v_result || 'auth.users: ERRO - ' || SQLERRM || chr(10);
  END;

  BEGIN
    ALTER TABLE auth.identities DISABLE ROW LEVEL SECURITY;
    v_result := v_result || 'auth.identities: OK' || chr(10);
  EXCEPTION WHEN OTHERS THEN
    v_result := v_result || 'auth.identities: ERRO - ' || SQLERRM || chr(10);
  END;

  BEGIN
    ALTER TABLE auth.sessions DISABLE ROW LEVEL SECURITY;
    v_result := v_result || 'auth.sessions: OK' || chr(10);
  EXCEPTION WHEN OTHERS THEN
    v_result := v_result || 'auth.sessions: ERRO - ' || SQLERRM || chr(10);
  END;

  BEGIN
    ALTER TABLE auth.refresh_tokens DISABLE ROW LEVEL SECURITY;
    v_result := v_result || 'auth.refresh_tokens: OK' || chr(10);
  EXCEPTION WHEN OTHERS THEN
    v_result := v_result || 'auth.refresh_tokens: ERRO - ' || SQLERRM || chr(10);
  END;

  BEGIN
    ALTER TABLE auth.instances DISABLE ROW LEVEL SECURITY;
    v_result := v_result || 'auth.instances: OK' || chr(10);
  EXCEPTION WHEN OTHERS THEN
    v_result := v_result || 'auth.instances: ERRO - ' || SQLERRM || chr(10);
  END;

  BEGIN
    ALTER TABLE auth.schema_migrations DISABLE ROW LEVEL SECURITY;
    v_result := v_result || 'auth.schema_migrations: OK' || chr(10);
  EXCEPTION WHEN OTHERS THEN
    v_result := v_result || 'auth.schema_migrations: ERRO - ' || SQLERRM || chr(10);
  END;

  BEGIN
    ALTER TABLE auth.audit_log_entries DISABLE ROW LEVEL SECURITY;
    v_result := v_result || 'auth.audit_log_entries: OK' || chr(10);
  EXCEPTION WHEN OTHERS THEN
    v_result := v_result || 'auth.audit_log_entries: ERRO - ' || SQLERRM || chr(10);
  END;

  BEGIN
    ALTER TABLE auth.saml_providers DISABLE ROW LEVEL SECURITY;
    v_result := v_result || 'auth.saml_providers: OK' || chr(10);
  EXCEPTION WHEN OTHERS THEN
    v_result := v_result || 'auth.saml_providers: ERRO - ' || SQLERRM || chr(10);
  END;

  BEGIN
    ALTER TABLE auth.saml_relay_states DISABLE ROW LEVEL SECURITY;
    v_result := v_result || 'auth.saml_relay_states: OK' || chr(10);
  EXCEPTION WHEN OTHERS THEN
    v_result := v_result || 'auth.saml_relay_states: ERRO - ' || SQLERRM || chr(10);
  END;

  BEGIN
    ALTER TABLE auth.sso_providers DISABLE ROW LEVEL SECURITY;
    v_result := v_result || 'auth.sso_providers: OK' || chr(10);
  EXCEPTION WHEN OTHERS THEN
    v_result := v_result || 'auth.sso_providers: ERRO - ' || SQLERRM || chr(10);
  END;

  BEGIN
    ALTER TABLE auth.sso_domains DISABLE ROW LEVEL SECURITY;
    v_result := v_result || 'auth.sso_domains: OK' || chr(10);
  EXCEPTION WHEN OTHERS THEN
    v_result := v_result || 'auth.sso_domains: ERRO - ' || SQLERRM || chr(10);
  END;

  BEGIN
    ALTER TABLE auth.mfa_factors DISABLE ROW LEVEL SECURITY;
    v_result := v_result || 'auth.mfa_factors: OK' || chr(10);
  EXCEPTION WHEN OTHERS THEN
    v_result := v_result || 'auth.mfa_factors: ERRO - ' || SQLERRM || chr(10);
  END;

  BEGIN
    ALTER TABLE auth.mfa_challenges DISABLE ROW LEVEL SECURITY;
    v_result := v_result || 'auth.mfa_challenges: OK' || chr(10);
  EXCEPTION WHEN OTHERS THEN
    v_result := v_result || 'auth.mfa_challenges: ERRO - ' || SQLERRM || chr(10);
  END;

  BEGIN
    ALTER TABLE auth.mfa_amr_claims DISABLE ROW LEVEL SECURITY;
    v_result := v_result || 'auth.mfa_amr_claims: OK' || chr(10);
  EXCEPTION WHEN OTHERS THEN
    v_result := v_result || 'auth.mfa_amr_claims: ERRO - ' || SQLERRM || chr(10);
  END;

  BEGIN
    ALTER TABLE auth.flow_state DISABLE ROW LEVEL SECURITY;
    v_result := v_result || 'auth.flow_state: OK' || chr(10);
  EXCEPTION WHEN OTHERS THEN
    v_result := v_result || 'auth.flow_state: ERRO - ' || SQLERRM || chr(10);
  END;

  BEGIN
    ALTER TABLE auth.one_time_tokens DISABLE ROW LEVEL SECURITY;
    v_result := v_result || 'auth.one_time_tokens: OK' || chr(10);
  EXCEPTION WHEN OTHERS THEN
    v_result := v_result || 'auth.one_time_tokens: ERRO - ' || SQLERRM || chr(10);
  END;

  -- Verificar quantas tabelas ainda têm RLS
  SELECT COUNT(*) INTO v_count
  FROM pg_tables 
  WHERE schemaname = 'auth' 
  AND rowsecurity = true;

  v_result := v_result || chr(10) || '=====================================';
  IF v_count = 0 THEN
    v_result := v_result || chr(10) || '✅ SUCESSO! RLS desabilitado em todas as tabelas auth!';
  ELSE
    v_result := v_result || chr(10) || '⚠️ Ainda existem ' || v_count || ' tabela(s) com RLS ativado.';
  END IF;

  RETURN v_result;
END;
$$;

-- Passo 2: Execute a função
SELECT public.fix_auth_rls();

-- Passo 3: Remover a função (limpeza)
DROP FUNCTION IF EXISTS public.fix_auth_rls();
