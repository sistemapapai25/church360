-- =====================================================
-- Script 19: Políticas RLS para Perfil de Membro
-- =====================================================
-- Descrição: Permite que usuários criem e editem seu próprio perfil de membro
-- Data: 2025-10-23
-- Autor: Church 360 Gabriel
-- =====================================================

-- =====================================================
-- 1. REMOVER POLÍTICAS ANTIGAS
-- =====================================================

-- Remover políticas antigas muito permissivas
DROP POLICY IF EXISTS "Users can manage members" ON member;
DROP POLICY IF EXISTS "Users can view all members" ON member;

-- =====================================================
-- 2. POLÍTICA DE SELECT (VISUALIZAÇÃO)
-- =====================================================

-- Todos os usuários autenticados podem ver todos os membros
CREATE POLICY "Users can view all members"
  ON member FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- =====================================================
-- 3. POLÍTICA DE INSERT (CRIAÇÃO)
-- =====================================================

-- Usuários podem criar seu próprio perfil de membro
-- Apenas se ainda não existir um perfil com o mesmo email
CREATE POLICY "Users can create their own member profile"
  ON member FOR INSERT
  WITH CHECK (
    -- Usuário autenticado
    auth.uid() IS NOT NULL
    AND
    -- Email do membro deve ser o mesmo do usuário autenticado
    email = (SELECT email FROM auth.users WHERE id = auth.uid())
    AND
    -- Não pode já existir um perfil com esse email
    NOT EXISTS (
      SELECT 1 FROM member m WHERE m.email = member.email
    )
  );

-- =====================================================
-- 4. POLÍTICA DE UPDATE (EDIÇÃO)
-- =====================================================

-- Usuários podem editar seu próprio perfil
-- Mas não podem alterar campos sensíveis (status, member_type, etc.)
-- Apenas admins (access_level >= 5) podem alterar campos sensíveis
CREATE POLICY "Users can update their own member profile"
  ON member FOR UPDATE
  USING (
    -- Email do membro deve ser o mesmo do usuário autenticado
    email = (SELECT email FROM auth.users WHERE id = auth.uid())
  )
  WITH CHECK (
    -- Email do membro deve ser o mesmo do usuário autenticado
    email = (SELECT email FROM auth.users WHERE id = auth.uid())
    AND
    -- Verificar se pode alterar campos sensíveis
    (
      -- Se for admin (access_level >= 5), pode alterar tudo
      EXISTS (
        SELECT 1 FROM user_access_level ual
        WHERE ual.user_id = auth.uid()
        AND ual.access_level_number >= 5
      )
      OR
      -- Se não for admin, campos sensíveis devem permanecer iguais
      (
        (status IS NOT DISTINCT FROM (SELECT status FROM member WHERE id = member.id))
        AND
        (member_type IS NOT DISTINCT FROM (SELECT member_type FROM member WHERE id = member.id))
        AND
        (membership_date IS NOT DISTINCT FROM (SELECT membership_date FROM member WHERE id = member.id))
        AND
        (baptism_date IS NOT DISTINCT FROM (SELECT baptism_date FROM member WHERE id = member.id))
        AND
        (conversion_date IS NOT DISTINCT FROM (SELECT conversion_date FROM member WHERE id = member.id))
      )
    )
  );

-- =====================================================
-- 5. POLÍTICA DE DELETE (EXCLUSÃO)
-- =====================================================

-- Apenas admins podem deletar membros
CREATE POLICY "Only admins can delete members"
  ON member FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_access_level ual
      WHERE ual.user_id = auth.uid()
      AND ual.access_level_number >= 5
    )
  );

-- =====================================================
-- RESUMO DAS POLÍTICAS
-- =====================================================
-- 
-- SELECT: Todos os usuários autenticados podem ver todos os membros
-- 
-- INSERT: Usuários podem criar seu próprio perfil
--   - Email deve ser o mesmo do usuário autenticado
--   - Não pode já existir um perfil com esse email
-- 
-- UPDATE: Usuários podem editar seu próprio perfil
--   - Email deve ser o mesmo do usuário autenticado
--   - Campos sensíveis (status, member_type, datas especiais) só podem ser alterados por admins
--   - Admins (access_level >= 5) podem alterar tudo
-- 
-- DELETE: Apenas admins podem deletar membros
-- 
-- =====================================================

