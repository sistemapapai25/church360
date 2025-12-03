-- =====================================================
-- Script 27: Limpar TODAS as Políticas RLS Duplicadas
-- =====================================================
-- Descrição: Remover todas as políticas antigas e criar apenas as corretas
-- Data: 2025-10-24
-- =====================================================

BEGIN;

-- =====================================================
-- ETAPA 1: REMOVER TODAS AS POLÍTICAS EXISTENTES
-- =====================================================

-- Políticas de DELETE
DROP POLICY IF EXISTS "Only admins can delete users" ON user_account;

-- Políticas de INSERT
DROP POLICY IF EXISTS "Allow signup" ON user_account;

-- Políticas de SELECT (TODAS!)
DROP POLICY IF EXISTS "Users can view all accounts" ON user_account;
DROP POLICY IF EXISTS "Users can view all users" ON user_account;
DROP POLICY IF EXISTS "Users can view all users in their DB" ON user_account;
DROP POLICY IF EXISTS "Users can view their own account" ON user_account;

-- Políticas de UPDATE (TODAS!)
DROP POLICY IF EXISTS "Users can update own account" ON user_account;
DROP POLICY IF EXISTS "Admins can update any profile" ON user_account;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_account;
DROP POLICY IF EXISTS "Users can update their own account" ON user_account;

-- =====================================================
-- ETAPA 2: CRIAR APENAS 3 POLÍTICAS SIMPLES
-- =====================================================

-- Política 1: INSERT (signup)
-- Permite que usuários autenticados criem sua própria conta
CREATE POLICY "signup_policy"
    ON user_account FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

-- Política 2: SELECT (visualizar)
-- Permite que todos os usuários autenticados vejam todas as contas
CREATE POLICY "select_policy"
    ON user_account FOR SELECT
    TO authenticated
    USING (true);

-- Política 3: UPDATE (atualizar)
-- Permite que usuários atualizem APENAS sua própria conta
CREATE POLICY "update_policy"
    ON user_account FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

COMMIT;

-- =====================================================
-- VERIFICAÇÃO FINAL
-- =====================================================

SELECT 
  policyname,
  cmd,
  roles
FROM pg_policies
WHERE tablename = 'user_account'
ORDER BY cmd, policyname;

-- =====================================================
-- RESULTADO ESPERADO:
-- Apenas 3 políticas:
-- 1. "signup_policy" (INSERT, authenticated)
-- 2. "select_policy" (SELECT, authenticated)
-- 3. "update_policy" (UPDATE, authenticated)
-- =====================================================

