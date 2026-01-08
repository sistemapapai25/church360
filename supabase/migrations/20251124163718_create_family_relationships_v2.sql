-- =====================================================
-- Script 31: Migração - Tabela de Relacionamentos Familiares
-- =====================================================
-- Descrição: Cria a tabela para armazenar relacionamentos entre membros
-- Data: 2025-11-24
-- =====================================================

-- 1. Criar a tabela
CREATE TABLE IF NOT EXISTS relacionamentos_familiares (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    membro_id UUID NOT NULL,
    parente_id UUID NOT NULL,
    tipo_relacionamento TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    
    -- Foreign Keys (apontando para user_account)
    CONSTRAINT relacionamentos_familiares_membro_id_fkey 
        FOREIGN KEY (membro_id) REFERENCES user_account(id) ON DELETE CASCADE,
    CONSTRAINT relacionamentos_familiares_parente_id_fkey 
        FOREIGN KEY (parente_id) REFERENCES user_account(id) ON DELETE CASCADE,
    
    -- Constraint para evitar relacionamento consigo mesmo
    CONSTRAINT check_not_self_relationship 
        CHECK (membro_id != parente_id),
    
    -- Constraint única para evitar duplicatas
    CONSTRAINT unique_relationship 
        UNIQUE (membro_id, parente_id)
);

-- 2. Criar índices para performance
CREATE INDEX IF NOT EXISTS idx_relacionamentos_membro_id ON relacionamentos_familiares(membro_id);
CREATE INDEX IF NOT EXISTS idx_relacionamentos_parente_id ON relacionamentos_familiares(parente_id);

-- 3. Habilitar RLS
ALTER TABLE relacionamentos_familiares ENABLE ROW LEVEL SECURITY;

-- 4. Policies
-- Policy: SELECT (todos autenticados podem visualizar)
DROP POLICY IF EXISTS relacionamentos_select_all ON relacionamentos_familiares;
CREATE POLICY relacionamentos_select_all 
ON relacionamentos_familiares 
FOR SELECT 
TO authenticated 
USING (true);

-- Policy: INSERT (usuário autenticado pode inserir para si mesmo ou se for admin)
DROP POLICY IF EXISTS relacionamentos_insert_policy ON relacionamentos_familiares;
CREATE POLICY relacionamentos_insert_policy 
ON relacionamentos_familiares 
FOR INSERT 
TO authenticated 
WITH CHECK (
    auth.uid() = membro_id
    OR
    EXISTS (
        SELECT 1 FROM user_account 
        WHERE id = auth.uid() AND role_global = 'admin'
    )
);

-- Policy: DELETE
DROP POLICY IF EXISTS relacionamentos_delete_policy ON relacionamentos_familiares;
CREATE POLICY relacionamentos_delete_policy 
ON relacionamentos_familiares 
FOR DELETE 
TO authenticated 
USING (
    auth.uid() = membro_id
    OR
    EXISTS (
        SELECT 1 FROM user_account 
        WHERE id = auth.uid() AND role_global = 'admin'
    )
);

-- Policy: UPDATE
DROP POLICY IF EXISTS relacionamentos_update_policy ON relacionamentos_familiares;
CREATE POLICY relacionamentos_update_policy 
ON relacionamentos_familiares 
FOR UPDATE 
TO authenticated 
USING (
    auth.uid() = membro_id
    OR
    EXISTS (
        SELECT 1 FROM user_account 
        WHERE id = auth.uid() AND role_global = 'admin'
    )
)
WITH CHECK (
    auth.uid() = membro_id
    OR
    EXISTS (
        SELECT 1 FROM user_account 
        WHERE id = auth.uid() AND role_global = 'admin'
    )
);;
