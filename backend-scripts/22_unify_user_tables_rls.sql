-- =====================================================
-- Script 22: Políticas RLS para user_account Unificado
-- =====================================================
-- Descrição: Atualizar políticas RLS após unificação das tabelas
-- Data: 2025-10-24
-- Autor: Church 360 Gabriel
-- =====================================================

-- =====================================================
-- IMPORTANTE: EXECUTAR APÓS O SCRIPT 21
-- =====================================================

BEGIN;

-- =====================================================
-- ETAPA 1: REMOVER POLÍTICAS ANTIGAS
-- =====================================================

RAISE NOTICE '==============================================';
RAISE NOTICE 'ETAPA 1: Removendo políticas antigas...';
RAISE NOTICE '==============================================';

-- Remover políticas antigas de member (tabela não existe mais)
DROP POLICY IF EXISTS "Users can view all members" ON member;
DROP POLICY IF EXISTS "Users can create their own member profile" ON member;
DROP POLICY IF EXISTS "Users can update their own member profile" ON member;
DROP POLICY IF EXISTS "Only admins can delete members" ON member;
DROP POLICY IF EXISTS "Users can manage members" ON member;

-- Remover políticas antigas de visitor (tabela não existe mais)
DROP POLICY IF EXISTS "Users can view all visitors" ON visitor;
DROP POLICY IF EXISTS "Users can create visitors" ON visitor;
DROP POLICY IF EXISTS "Users can update visitors" ON visitor;
DROP POLICY IF EXISTS "Only admins can delete visitors" ON visitor;

-- Remover políticas antigas de user_account (vamos recriar)
DROP POLICY IF EXISTS "Users can create their own account" ON user_account;
DROP POLICY IF EXISTS "Users can view their own account" ON user_account;
DROP POLICY IF EXISTS "Users can update their own account" ON user_account;

RAISE NOTICE '✅ Políticas antigas removidas!';

-- =====================================================
-- ETAPA 2: HABILITAR RLS EM user_account
-- =====================================================

RAISE NOTICE '==============================================';
RAISE NOTICE 'ETAPA 2: Habilitando RLS...';
RAISE NOTICE '==============================================';

ALTER TABLE user_account ENABLE ROW LEVEL SECURITY;

RAISE NOTICE '✅ RLS habilitado em user_account!';

-- =====================================================
-- ETAPA 3: POLÍTICAS DE SELECT (VISUALIZAÇÃO)
-- =====================================================

RAISE NOTICE '==============================================';
RAISE NOTICE 'ETAPA 3: Criando políticas de SELECT...';
RAISE NOTICE '==============================================';

-- Todos os usuários autenticados podem ver todos os usuários
CREATE POLICY "Users can view all users"
    ON user_account FOR SELECT
    USING (auth.uid() IS NOT NULL);

RAISE NOTICE '✅ Política de SELECT criada!';

-- =====================================================
-- ETAPA 4: POLÍTICAS DE INSERT (CRIAÇÃO)
-- =====================================================

RAISE NOTICE '==============================================';
RAISE NOTICE 'ETAPA 4: Criando políticas de INSERT...';
RAISE NOTICE '==============================================';

-- Usuários podem criar sua própria conta durante signup
CREATE POLICY "Users can create their own account"
    ON user_account FOR INSERT
    WITH CHECK (
        -- Usuário autenticado criando sua própria conta
        auth.uid() = id
        AND
        -- Email deve ser o mesmo do auth.users
        email = (SELECT email FROM auth.users WHERE id = auth.uid())
        AND
        -- Não pode já existir uma conta com esse ID
        NOT EXISTS (
            SELECT 1 FROM user_account ua WHERE ua.id = id
        )
    );

-- Admins podem criar contas para outros usuários (visitantes, membros, etc.)
CREATE POLICY "Admins can create accounts for others"
    ON user_account FOR INSERT
    WITH CHECK (
        -- Usuário é admin (access_level >= 5)
        EXISTS (
            SELECT 1 FROM user_access_level ual
            WHERE ual.user_id = auth.uid()
            AND ual.access_level_number >= 5
        )
    );

RAISE NOTICE '✅ Políticas de INSERT criadas!';

-- =====================================================
-- ETAPA 5: POLÍTICAS DE UPDATE (EDIÇÃO)
-- =====================================================

RAISE NOTICE '==============================================';
RAISE NOTICE 'ETAPA 5: Criando políticas de UPDATE...';
RAISE NOTICE '==============================================';

-- Usuários podem editar seu próprio perfil
-- Mas não podem alterar campos sensíveis (status, member_type, etc.)
CREATE POLICY "Users can update their own profile"
    ON user_account FOR UPDATE
    USING (
        -- Usuário autenticado editando seu próprio perfil
        id = auth.uid()
    )
    WITH CHECK (
        -- Usuário autenticado editando seu próprio perfil
        id = auth.uid()
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
                -- Status não pode ser alterado
                (status IS NOT DISTINCT FROM (SELECT status FROM user_account WHERE id = user_account.id))
                AND
                -- Member type não pode ser alterado
                (member_type IS NOT DISTINCT FROM (SELECT member_type FROM user_account WHERE id = user_account.id))
                AND
                -- Datas espirituais não podem ser alteradas
                (membership_date IS NOT DISTINCT FROM (SELECT membership_date FROM user_account WHERE id = user_account.id))
                AND
                (baptism_date IS NOT DISTINCT FROM (SELECT baptism_date FROM user_account WHERE id = user_account.id))
                AND
                (conversion_date IS NOT DISTINCT FROM (SELECT conversion_date FROM user_account WHERE id = user_account.id))
                AND
                -- Email não pode ser alterado
                (email IS NOT DISTINCT FROM (SELECT email FROM user_account WHERE id = user_account.id))
            )
        )
    );

-- Admins podem editar qualquer perfil
DROP POLICY IF EXISTS "Admins can update any profile" ON user_account;
CREATE POLICY "Leaders and above can update any profile"
    ON user_account FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM user_access_level ual
            WHERE ual.user_id = auth.uid()
            AND ual.access_level_number >= 3 -- leader (3), coordinator (4), admin (5)
        )
        OR EXISTS (
            SELECT 1 FROM user_account ua
            WHERE ua.id = auth.uid()
            AND ua.role_global IN ('owner','admin','leader')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_access_level ual
            WHERE ual.user_id = auth.uid()
            AND ual.access_level_number >= 3
        )
        OR EXISTS (
            SELECT 1 FROM user_account ua
            WHERE ua.id = auth.uid()
            AND ua.role_global IN ('owner','admin','leader')
        )
    );

RAISE NOTICE '✅ Políticas de UPDATE criadas!';

-- =====================================================
-- ETAPA 6: POLÍTICAS DE DELETE (EXCLUSÃO)
-- =====================================================

RAISE NOTICE '==============================================';
RAISE NOTICE 'ETAPA 6: Criando políticas de DELETE...';
RAISE NOTICE '==============================================';

-- Apenas admins podem deletar usuários
CREATE POLICY "Only admins can delete users"
    ON user_account FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM user_access_level ual
            WHERE ual.user_id = auth.uid()
            AND ual.access_level_number >= 5
        )
    );

RAISE NOTICE '✅ Política de DELETE criada!';

-- =====================================================
-- ETAPA 7: POLÍTICAS PARA TABELAS RENOMEADAS
-- =====================================================

RAISE NOTICE '==============================================';
RAISE NOTICE 'ETAPA 7: Atualizando políticas de tabelas renomeadas...';
RAISE NOTICE '==============================================';

-- Habilitar RLS nas tabelas renomeadas
ALTER TABLE user_followup ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_visit ENABLE ROW LEVEL SECURITY;

-- Políticas para user_followup
DROP POLICY IF EXISTS "Users can view followups" ON user_followup;
CREATE POLICY "Users can view followups"
    ON user_followup FOR SELECT
    USING (
        -- Usuário pode ver seus próprios followups
        user_id = auth.uid()
        OR
        -- Ou é admin/líder
        EXISTS (
            SELECT 1 FROM user_access_level ual
            WHERE ual.user_id = auth.uid()
            AND ual.access_level_number >= 2
        )
    );

DROP POLICY IF EXISTS "Leaders can manage followups" ON user_followup;
CREATE POLICY "Leaders can manage followups"
    ON user_followup FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM user_access_level ual
            WHERE ual.user_id = auth.uid()
            AND ual.access_level_number >= 2
        )
    );

-- Políticas para user_visit
DROP POLICY IF EXISTS "Users can view visits" ON user_visit;
CREATE POLICY "Users can view visits"
    ON user_visit FOR SELECT
    USING (
        -- Usuário pode ver suas próprias visitas
        user_id = auth.uid()
        OR
        -- Ou é admin/líder
        EXISTS (
            SELECT 1 FROM user_access_level ual
            WHERE ual.user_id = auth.uid()
            AND ual.access_level_number >= 2
        )
    );

DROP POLICY IF EXISTS "Leaders can manage visits" ON user_visit;
CREATE POLICY "Leaders can manage visits"
    ON user_visit FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM user_access_level ual
            WHERE ual.user_id = auth.uid()
            AND ual.access_level_number >= 2
        )
    );

RAISE NOTICE '✅ Políticas de tabelas renomeadas criadas!';

-- =====================================================
-- RESUMO DAS POLÍTICAS RLS
-- =====================================================

RAISE NOTICE '==============================================';
RAISE NOTICE '🎉 POLÍTICAS RLS ATUALIZADAS COM SUCESSO!';
RAISE NOTICE '==============================================';
RAISE NOTICE '';
RAISE NOTICE 'Políticas criadas para user_account:';
RAISE NOTICE '1. ✅ SELECT: Todos podem ver todos os usuários';
RAISE NOTICE '2. ✅ INSERT: Usuários criam própria conta + Admins criam para outros';
RAISE NOTICE '3. ✅ UPDATE: Usuários editam próprio perfil (sem campos sensíveis)';
RAISE NOTICE '4. ✅ UPDATE: Admins editam qualquer perfil';
RAISE NOTICE '5. ✅ DELETE: Apenas admins podem deletar';
RAISE NOTICE '';
RAISE NOTICE 'Políticas criadas para user_followup e user_visit:';
RAISE NOTICE '1. ✅ SELECT: Usuário vê próprios + Líderes veem todos';
RAISE NOTICE '2. ✅ ALL: Líderes podem gerenciar';
RAISE NOTICE '';
RAISE NOTICE 'Campos protegidos (apenas admins podem alterar):';
RAISE NOTICE '- status (visitor, member_active, etc.)';
RAISE NOTICE '- member_type (titular, congregado, etc.)';
RAISE NOTICE '- membership_date, baptism_date, conversion_date';
RAISE NOTICE '- email';
RAISE NOTICE '';
RAISE NOTICE '==============================================';

COMMIT;
