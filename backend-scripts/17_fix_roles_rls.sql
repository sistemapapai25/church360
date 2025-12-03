-- =====================================================
-- CORREÇÃO: Políticas RLS para tabela roles
-- =====================================================
-- Descrição: Corrige as políticas RLS para permitir INSERT/UPDATE/DELETE
-- Data: 2025-01-23
-- =====================================================

-- Habilitar RLS na tabela roles (se ainda não estiver)
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- REMOVER POLÍTICAS ANTIGAS
-- =====================================================

DROP POLICY IF EXISTS "Todos podem ver cargos ativos" ON roles;
DROP POLICY IF EXISTS "Gerenciar cargos requer permissão" ON roles;

-- =====================================================
-- CRIAR NOVAS POLÍTICAS CORRETAS
-- =====================================================

-- 1. SELECT: Todos podem ver cargos ativos
CREATE POLICY "Todos podem ver cargos ativos"
  ON roles FOR SELECT
  USING (is_active = true);

-- 2. INSERT: Apenas quem tem permissão pode criar cargos
CREATE POLICY "Criar cargos requer permissão"
  ON roles FOR INSERT
  WITH CHECK (
    check_user_permission(auth.uid(), 'settings.manage_roles')
  );

-- 3. UPDATE: Apenas quem tem permissão pode atualizar cargos
CREATE POLICY "Atualizar cargos requer permissão"
  ON roles FOR UPDATE
  USING (
    check_user_permission(auth.uid(), 'settings.manage_roles')
  )
  WITH CHECK (
    check_user_permission(auth.uid(), 'settings.manage_roles')
  );

-- 4. DELETE: Apenas quem tem permissão pode deletar cargos
CREATE POLICY "Deletar cargos requer permissão"
  ON roles FOR DELETE
  USING (
    check_user_permission(auth.uid(), 'settings.manage_roles')
  );

-- =====================================================
-- CORREÇÃO: Políticas RLS para role_contexts
-- =====================================================

DROP POLICY IF EXISTS "Todos podem ver contextos ativos" ON role_contexts;
DROP POLICY IF EXISTS "Gerenciar contextos requer permissão" ON role_contexts;

-- 1. SELECT: Todos podem ver contextos ativos
CREATE POLICY "Todos podem ver contextos ativos"
  ON role_contexts FOR SELECT
  USING (is_active = true);

-- 2. INSERT: Apenas quem tem permissão pode criar contextos
CREATE POLICY "Criar contextos requer permissão"
  ON role_contexts FOR INSERT
  WITH CHECK (
    check_user_permission(auth.uid(), 'settings.manage_roles')
  );

-- 3. UPDATE: Apenas quem tem permissão pode atualizar contextos
CREATE POLICY "Atualizar contextos requer permissão"
  ON role_contexts FOR UPDATE
  USING (
    check_user_permission(auth.uid(), 'settings.manage_roles')
  )
  WITH CHECK (
    check_user_permission(auth.uid(), 'settings.manage_roles')
  );

-- 4. DELETE: Apenas quem tem permissão pode deletar contextos
CREATE POLICY "Deletar contextos requer permissão"
  ON role_contexts FOR DELETE
  USING (
    check_user_permission(auth.uid(), 'settings.manage_roles')
  );

-- =====================================================
-- CORREÇÃO: Políticas RLS para role_permissions
-- =====================================================

DROP POLICY IF EXISTS "Todos podem ver permissões dos cargos" ON role_permissions;
DROP POLICY IF EXISTS "Gerenciar permissões de cargos requer permissão" ON role_permissions;

-- 1. SELECT: Todos podem ver permissões dos cargos
CREATE POLICY "Todos podem ver permissões dos cargos"
  ON role_permissions FOR SELECT
  USING (true);

-- 2. INSERT: Apenas quem tem permissão pode adicionar permissões
CREATE POLICY "Adicionar permissões a cargos requer permissão"
  ON role_permissions FOR INSERT
  WITH CHECK (
    check_user_permission(auth.uid(), 'settings.manage_roles')
  );

-- 3. UPDATE: Apenas quem tem permissão pode atualizar permissões
CREATE POLICY "Atualizar permissões de cargos requer permissão"
  ON role_permissions FOR UPDATE
  USING (
    check_user_permission(auth.uid(), 'settings.manage_roles')
  )
  WITH CHECK (
    check_user_permission(auth.uid(), 'settings.manage_roles')
  );

-- 4. DELETE: Apenas quem tem permissão pode remover permissões
CREATE POLICY "Remover permissões de cargos requer permissão"
  ON role_permissions FOR DELETE
  USING (
    check_user_permission(auth.uid(), 'settings.manage_roles')
  );

-- =====================================================
-- CORREÇÃO: Políticas RLS para user_roles
-- =====================================================

DROP POLICY IF EXISTS "Usuários veem próprios cargos" ON user_roles;
DROP POLICY IF EXISTS "Ver todos cargos requer permissão" ON user_roles;
DROP POLICY IF EXISTS "Gerenciar atribuições requer permissão" ON user_roles;

-- 1. SELECT: Usuários podem ver seus próprios cargos
CREATE POLICY "Usuários veem próprios cargos"
  ON user_roles FOR SELECT
  USING (user_id = auth.uid());

-- 2. SELECT: Quem tem permissão pode ver todos os cargos
CREATE POLICY "Ver todos cargos requer permissão"
  ON user_roles FOR SELECT
  USING (
    check_user_permission(auth.uid(), 'settings.manage_permissions')
  );

-- 3. INSERT: Apenas quem tem permissão pode atribuir cargos
CREATE POLICY "Atribuir cargos requer permissão"
  ON user_roles FOR INSERT
  WITH CHECK (
    check_user_permission(auth.uid(), 'settings.manage_permissions')
  );

-- 4. UPDATE: Apenas quem tem permissão pode atualizar atribuições
CREATE POLICY "Atualizar atribuições requer permissão"
  ON user_roles FOR UPDATE
  USING (
    check_user_permission(auth.uid(), 'settings.manage_permissions')
  )
  WITH CHECK (
    check_user_permission(auth.uid(), 'settings.manage_permissions')
  );

-- 5. DELETE: Apenas quem tem permissão pode remover atribuições
CREATE POLICY "Remover atribuições requer permissão"
  ON user_roles FOR DELETE
  USING (
    check_user_permission(auth.uid(), 'settings.manage_permissions')
  );

-- =====================================================
-- CORREÇÃO: Políticas RLS para user_custom_permissions
-- =====================================================

DROP POLICY IF EXISTS "Usuários veem próprias permissões" ON user_custom_permissions;
DROP POLICY IF EXISTS "Ver todas permissões customizadas requer permissão" ON user_custom_permissions;
DROP POLICY IF EXISTS "Gerenciar permissões customizadas requer permissão" ON user_custom_permissions;

-- 1. SELECT: Usuários podem ver suas próprias permissões customizadas
CREATE POLICY "Usuários veem próprias permissões"
  ON user_custom_permissions FOR SELECT
  USING (user_id = auth.uid());

-- 2. SELECT: Quem tem permissão pode ver todas
CREATE POLICY "Ver todas permissões customizadas requer permissão"
  ON user_custom_permissions FOR SELECT
  USING (
    check_user_permission(auth.uid(), 'settings.manage_permissions')
  );

-- 3. INSERT: Apenas quem tem permissão pode criar permissões customizadas
CREATE POLICY "Criar permissões customizadas requer permissão"
  ON user_custom_permissions FOR INSERT
  WITH CHECK (
    check_user_permission(auth.uid(), 'settings.manage_permissions')
  );

-- 4. UPDATE: Apenas quem tem permissão pode atualizar permissões customizadas
CREATE POLICY "Atualizar permissões customizadas requer permissão"
  ON user_custom_permissions FOR UPDATE
  USING (
    check_user_permission(auth.uid(), 'settings.manage_permissions')
  )
  WITH CHECK (
    check_user_permission(auth.uid(), 'settings.manage_permissions')
  );

-- 5. DELETE: Apenas quem tem permissão pode deletar permissões customizadas
CREATE POLICY "Deletar permissões customizadas requer permissão"
  ON user_custom_permissions FOR DELETE
  USING (
    check_user_permission(auth.uid(), 'settings.manage_permissions')
  );

-- =====================================================
-- FIM DO SCRIPT
-- =====================================================

