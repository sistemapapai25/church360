-- =====================================================
-- Script 26: Corrigir Recursão Infinita nas Políticas RLS
-- =====================================================
-- Descrição: Corrigir erro "infinite recursion detected in policy"
-- Data: 2025-10-24
-- =====================================================

-- =====================================================
-- PROBLEMA: Recursão infinita nas políticas RLS
-- =====================================================
-- O erro acontece porque as políticas de SELECT/UPDATE verificam
-- user_access_level, que por sua vez precisa acessar user_account,
-- criando um loop infinito.
--
-- SOLUÇÃO: Simplificar as políticas para evitar recursão
-- =====================================================

BEGIN;

-- =====================================================
-- ETAPA 1: REMOVER TODAS AS POLÍTICAS ATUAIS
-- =====================================================

DROP POLICY IF EXISTS "Allow signup" ON user_account;
DROP POLICY IF EXISTS "Users can view their own account" ON user_account;
DROP POLICY IF EXISTS "Users can update their own account" ON user_account;
DROP POLICY IF EXISTS "Users can delete their own account" ON user_account;
DROP POLICY IF EXISTS "Admins can view all accounts" ON user_account;
DROP POLICY IF EXISTS "Admins can update all accounts" ON user_account;
DROP POLICY IF EXISTS "Admins can delete all accounts" ON user_account;

-- =====================================================
-- ETAPA 2: CRIAR POLÍTICAS SIMPLES (SEM RECURSÃO)
-- =====================================================

-- Política 1: INSERT (signup)
-- Permite que usuários autenticados criem sua própria conta
CREATE POLICY "Allow signup"
    ON user_account FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

-- Política 2: SELECT (visualizar)
-- Permite que todos os usuários autenticados vejam todas as contas
-- (necessário para listar membros, visitantes, etc.)
CREATE POLICY "Users can view all accounts"
    ON user_account FOR SELECT
    TO authenticated
    USING (true);

-- Política 3: UPDATE (atualizar)
-- Permite que usuários atualizem APENAS sua própria conta
CREATE POLICY "Users can update own account"
    ON user_account FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Política 4: DELETE (deletar)
-- Ninguém pode deletar contas (apenas admins via dashboard)
-- Por enquanto, não criamos política de DELETE
-- (isso significa que DELETE será bloqueado por padrão)

COMMIT;

-- =====================================================
-- VERIFICAÇÃO
-- =====================================================

-- Verificar políticas criadas
SELECT 
  schemaname,
  tablename,
  policyname,
  cmd,
  roles,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'user_account'
ORDER BY cmd, policyname;

-- =====================================================
-- RESULTADO ESPERADO:
-- - 3 políticas criadas:
--   1. "Allow signup" (INSERT)
--   2. "Users can view all accounts" (SELECT)
--   3. "Users can update own account" (UPDATE)
-- - Nenhuma recursão infinita
-- =====================================================

