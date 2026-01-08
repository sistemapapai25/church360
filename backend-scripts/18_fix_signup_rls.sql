-- ============================================
-- CHURCH 360 - CORRIGIR RLS PARA PERMITIR SIGNUP
-- ============================================
-- Script: 18_fix_signup_rls.sql
-- Descrição: Adiciona políticas RLS para permitir que novos usuários
--            se cadastrem no sistema e remove triggers antigos
-- Data: 2025-10-23
-- ============================================

-- =====================================================
-- 0. REMOVER TRIGGERS ANTIGOS QUE CAUSAM CONFLITO
-- =====================================================

-- Remover trigger antigo que tenta inserir em user_roles com estrutura antiga
DROP TRIGGER IF EXISTS on_auth_user_created_role ON auth.users;

-- Remover função antiga também
DROP FUNCTION IF EXISTS handle_new_user_role() CASCADE;

-- Corrigir função de notificações para ter SECURITY DEFINER
-- (sem isso, o trigger falha porque auth.uid() é NULL durante signup)
CREATE OR REPLACE FUNCTION public.create_default_notification_preferences()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER  -- IMPORTANTE: Permite bypass do RLS durante signup
SET search_path = public
AS $$
BEGIN
  INSERT INTO notification_preferences (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log do erro mas não bloqueia a criação do usuário
    RAISE WARNING 'Erro ao criar preferências de notificação para usuário %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;

-- Corrigir função de log de access level para ter SECURITY DEFINER
-- (sem isso, o trigger falha ao tentar inserir em access_level_history durante signup)
CREATE OR REPLACE FUNCTION public.log_access_level_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER  -- IMPORTANTE: Permite bypass do RLS
SET search_path = public
AS $$
BEGIN
  IF (TG_OP = 'UPDATE' AND OLD.access_level != NEW.access_level) THEN
    INSERT INTO access_level_history (
      user_id, from_level, from_level_number, to_level, to_level_number, reason, promoted_by
    ) VALUES (
      NEW.user_id, OLD.access_level, OLD.access_level_number, NEW.access_level, NEW.access_level_number, NEW.promotion_reason, NEW.promoted_by
    );
  ELSIF (TG_OP = 'INSERT') THEN
    INSERT INTO access_level_history (
      user_id, from_level, from_level_number, to_level, to_level_number, reason, promoted_by
    ) VALUES (
      NEW.user_id, NULL, NULL, NEW.access_level, NEW.access_level_number, 'Criação inicial', NEW.promoted_by
    );
  END IF;
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log do erro mas não bloqueia a operação
    RAISE WARNING 'Erro ao registrar histórico de nível de acesso para usuário %: %', NEW.user_id, SQLERRM;
    RETURN NEW;
END;
$$;

-- =====================================================
-- 1. POLÍTICAS PARA user_account
-- =====================================================

-- Permitir que novos usuários criem sua própria conta
-- (quando auth.uid() = id, significa que é o próprio usuário se cadastrando)
CREATE POLICY "Users can create their own account"
  ON user_account FOR INSERT
  WITH CHECK (auth.uid() = id);

-- =====================================================
-- 2. POLÍTICAS PARA user_access_level
-- =====================================================

-- Remover a política restritiva atual
DROP POLICY IF EXISTS "Only admins can create access levels" ON user_access_level;

-- Criar nova política que permite:
-- 1. Admins podem criar níveis para qualquer usuário
-- 2. Novos usuários podem criar seu próprio nível inicial (visitor)
CREATE POLICY "Users can create access levels"
  ON user_access_level FOR INSERT
  WITH CHECK (
    -- Admin pode criar para qualquer um
    EXISTS (
      SELECT 1 FROM user_access_level ual
      WHERE ual.user_id = auth.uid()
      AND ual.access_level_number >= 5
    )
    OR
    -- Novo usuário pode criar seu próprio nível inicial como visitor
    -- E não pode já existir um registro para esse user_id
    (
      user_id = auth.uid()
      AND access_level = 'visitor'
      AND access_level_number = 0
      AND NOT EXISTS (
        SELECT 1 FROM user_access_level ual2
        WHERE ual2.user_id = user_access_level.user_id  -- Referência correta à tabela
      )
    )
  );

-- =====================================================
-- 3. POLÍTICAS PARA access_level_history
-- =====================================================

-- Permitir que o trigger insira registros de histórico
-- (o trigger é executado no contexto do usuário que está fazendo a operação)
DROP POLICY IF EXISTS "Allow trigger to insert access level history" ON access_level_history;

-- =====================================================
-- VERIFICAÇÃO
-- =====================================================

-- Listar todas as políticas de user_account
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
WHERE tablename = 'user_account'
ORDER BY policyname;

-- Listar todas as políticas de user_access_level
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
WHERE tablename = 'user_access_level'
ORDER BY policyname;
