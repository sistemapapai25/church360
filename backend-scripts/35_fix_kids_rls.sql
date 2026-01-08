-- Corrigir permissões RLS para a tabela de guardiões usando user_access_level
-- Data: 19/12/2025

-- Remover policy antiga se existir
DROP POLICY IF EXISTS "Guardians visible to staff and parents" ON kids_authorized_guardian;

-- 1. Policy de LEITURA (SELECT)
-- Permitir se for Admin/Líder (via user_access_level) OU se for o criador do registro
CREATE POLICY "Select guardians" ON kids_authorized_guardian
    FOR SELECT
    TO authenticated
    USING (
        -- É Admin/Líder (nível >= 3)
        EXISTS (
            SELECT 1 FROM user_access_level ual
            WHERE ual.user_id = auth.uid()
            AND ual.access_level_number >= 3
        )
        OR
        -- É o criador do registro
        created_by = auth.uid()
    );

-- 2. Policy de INSERÇÃO (INSERT)
-- Permitir se for Admin/Líder
CREATE POLICY "Insert guardians" ON kids_authorized_guardian
    FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_access_level ual
            WHERE ual.user_id = auth.uid()
            AND ual.access_level_number >= 3
        )
    );

-- 3. Policy de ATUALIZAÇÃO (UPDATE)
-- Permitir se for Admin/Líder
CREATE POLICY "Update guardians" ON kids_authorized_guardian
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_access_level ual
            WHERE ual.user_id = auth.uid()
            AND ual.access_level_number >= 3
        )
    );

-- 4. Policy de EXCLUSÃO (DELETE)
-- Permitir se for Admin/Líder
CREATE POLICY "Delete guardians" ON kids_authorized_guardian
    FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_access_level ual
            WHERE ual.user_id = auth.uid()
            AND ual.access_level_number >= 3
        )
    );
