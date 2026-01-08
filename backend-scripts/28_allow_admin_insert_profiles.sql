-- =====================================================
-- Script 28: Permissões de Gestão de Perfis (Admin/Líder)
-- =====================================================
-- Descrição: Permite que usuários com nível de acesso >= 3 (Líder)
-- criem, atualizem e deletem registros na tabela user_account
-- (Necessário para cadastrar crianças, visitantes, etc.)
-- =====================================================

-- 1. INSERT: Permitir criar novos perfis
DROP POLICY IF EXISTS "Admins/Leaders can insert profiles" ON user_account;
CREATE POLICY "Admins/Leaders can insert profiles"
    ON user_account FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_access_level ual
            WHERE ual.user_id = auth.uid()
            AND ual.access_level_number >= 3 -- 3=Leader, 4=Coordinator, 5=Admin
        )
    );

-- 2. UPDATE: Permitir editar perfis de terceiros
DROP POLICY IF EXISTS "Admins/Leaders can update profiles" ON user_account;
CREATE POLICY "Admins/Leaders can update profiles"
    ON user_account FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_access_level ual
            WHERE ual.user_id = auth.uid()
            AND ual.access_level_number >= 3
        )
    );

-- 3. DELETE: Permitir deletar perfis
DROP POLICY IF EXISTS "Admins/Leaders can delete profiles" ON user_account;
CREATE POLICY "Admins/Leaders can delete profiles"
    ON user_account FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_access_level ual
            WHERE ual.user_id = auth.uid()
            AND ual.access_level_number >= 3
        )
    );
