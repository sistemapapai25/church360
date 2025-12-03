-- =====================================================
-- Script 25: Corrigir Permissões de Signup
-- =====================================================
-- Descrição: Corrigir erro "permission denied for table users"
-- Data: 2025-10-24
-- =====================================================

-- =====================================================
-- DIAGNÓSTICO: Verificar configurações atuais
-- =====================================================

-- 1. Verificar se RLS está habilitado em user_account
SELECT 
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename = 'user_account';

-- 2. Verificar políticas RLS em user_account
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'user_account';

-- 3. Verificar se há triggers em user_account
SELECT 
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE event_object_table = 'user_account';

-- =====================================================
-- SOLUÇÃO: Garantir que signup funcione
-- =====================================================

-- OPÇÃO 1: Desabilitar RLS temporariamente para signup
-- (NÃO RECOMENDADO para produção, mas útil para teste)

-- Desabilitar RLS em user_account
ALTER TABLE user_account DISABLE ROW LEVEL SECURITY;

-- =====================================================
-- OPÇÃO 2: Criar política RLS mais permissiva para signup
-- =====================================================

-- Habilitar RLS
ALTER TABLE user_account ENABLE ROW LEVEL SECURITY;

-- Remover política antiga de INSERT
DROP POLICY IF EXISTS "Users can create their own account" ON user_account;
DROP POLICY IF EXISTS "Admins can create accounts for others" ON user_account;
DROP POLICY IF EXISTS "Allow signup" ON user_account;

-- Criar política PERMISSIVA para INSERT (signup)
-- Permite que qualquer usuário autenticado crie sua própria conta
CREATE POLICY "Allow signup"
    ON user_account FOR INSERT
    TO authenticated
    WITH CHECK (
        -- Usuário autenticado criando sua própria conta
        auth.uid() = id
    );

-- Política para SELECT (visualizar)
DROP POLICY IF EXISTS "Users can view their own account" ON user_account;
CREATE POLICY "Users can view their own account"
    ON user_account FOR SELECT
    TO authenticated
    USING (
        -- Usuário pode ver sua própria conta
        auth.uid() = id
        OR
        -- Ou é admin
        EXISTS (
            SELECT 1 FROM user_access_level ual
            WHERE ual.user_id = auth.uid()
            AND ual.access_level_number >= 5
        )
    );

-- Política para UPDATE (atualizar)
DROP POLICY IF EXISTS "Users can update their own account" ON user_account;
CREATE POLICY "Users can update their own account"
    ON user_account FOR UPDATE
    TO authenticated
    USING (
        -- Usuário pode atualizar sua própria conta
        auth.uid() = id
        OR
        -- Ou é admin
        EXISTS (
            SELECT 1 FROM user_access_level ual
            WHERE ual.user_id = auth.uid()
            AND ual.access_level_number >= 5
        )
    )
    WITH CHECK (
        -- Usuário pode atualizar sua própria conta
        auth.uid() = id
        OR
        -- Ou é admin
        EXISTS (
            SELECT 1 FROM user_access_level ual
            WHERE ual.user_id = auth.uid()
            AND ual.access_level_number >= 5
        )
    );

-- =====================================================
-- VERIFICAÇÃO FINAL
-- =====================================================

-- Verificar políticas criadas
SELECT 
  policyname,
  cmd,
  roles
FROM pg_policies
WHERE tablename = 'user_account'
ORDER BY cmd, policyname;

-- =====================================================
-- TESTE: Simular signup
-- =====================================================

-- Este SELECT deve retornar vazio (nenhum erro)
-- Se retornar erro, há problema com as políticas
SELECT 
  id,
  email,
  full_name,
  status
FROM user_account
WHERE id = auth.uid();

-- =====================================================
-- RESULTADO ESPERADO:
-- - RLS habilitado em user_account
-- - Política "Allow signup" criada
-- - Política "Users can view their own account" criada
-- - Política "Users can update their own account" criada
-- - Nenhum erro ao executar SELECT
-- =====================================================

