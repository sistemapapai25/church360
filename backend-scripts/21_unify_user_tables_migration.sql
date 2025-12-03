-- =====================================================
-- Script 21: Migração - Unificação de Tabelas de Usuário
-- =====================================================
-- Descrição: Unifica user_account, member e visitor em uma única tabela
-- Data: 2025-10-24
-- Autor: Church 360 Gabriel
-- =====================================================

-- =====================================================
-- IMPORTANTE: EXECUTAR APÓS O SCRIPT 20
-- =====================================================
-- Este script vai:
-- 1. Expandir user_account com campos de member e visitor
-- 2. Atualizar todas as foreign keys
-- 3. Renomear tabelas relacionadas
-- 4. Remover tabelas antigas
-- =====================================================

BEGIN;

-- =====================================================
-- ETAPA 1: LIMPAR DADOS EXISTENTES
-- =====================================================

RAISE NOTICE '==============================================';
RAISE NOTICE 'ETAPA 1: Limpando dados existentes...';
RAISE NOTICE '==============================================';

-- Desabilitar triggers temporariamente
SET session_replication_role = replica;

-- Limpar dados de todas as tabelas relacionadas
TRUNCATE TABLE bible_bookmark CASCADE;
TRUNCATE TABLE church_schedule CASCADE;
TRUNCATE TABLE contribution CASCADE;
TRUNCATE TABLE course_enrollment CASCADE;
TRUNCATE TABLE donation CASCADE;
TRUNCATE TABLE event_registration CASCADE;
TRUNCATE TABLE "group" CASCADE;
TRUNCATE TABLE group_attendance CASCADE;
TRUNCATE TABLE group_member CASCADE;
TRUNCATE TABLE member_step CASCADE;
TRUNCATE TABLE member_tag CASCADE;
TRUNCATE TABLE ministry_member CASCADE;
TRUNCATE TABLE ministry_schedule CASCADE;
TRUNCATE TABLE reading_plan_progress CASCADE;
TRUNCATE TABLE visitor_followup CASCADE;
TRUNCATE TABLE visitor_visit CASCADE;
TRUNCATE TABLE worship_attendance CASCADE;

-- Limpar tabelas principais
TRUNCATE TABLE visitor CASCADE;
TRUNCATE TABLE member CASCADE;
TRUNCATE TABLE user_account CASCADE;
TRUNCATE TABLE user_access_level CASCADE;

-- Reabilitar triggers
SET session_replication_role = DEFAULT;

RAISE NOTICE '✅ Dados limpos com sucesso!';

-- =====================================================
-- ETAPA 2: ADICIONAR NOVOS CAMPOS EM user_account
-- =====================================================

RAISE NOTICE '==============================================';
RAISE NOTICE 'ETAPA 2: Expandindo user_account...';
RAISE NOTICE '==============================================';

-- Campos de member (dados pessoais)
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS first_name TEXT;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS last_name TEXT;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS nickname TEXT;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS cpf TEXT;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS birthdate DATE;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS gender member_gender;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS marital_status marital_status;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS marriage_date DATE;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS profession TEXT;

-- Campos de member (endereço)
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS address_complement TEXT;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS neighborhood TEXT;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS city TEXT;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS state TEXT;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS zip_code TEXT;

-- Campos de member (status e tipo)
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS status member_status DEFAULT 'visitor';
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS member_type member_type;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS photo_url TEXT;

-- Campos de member (relacionamentos)
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS household_id UUID REFERENCES household(id);
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS campus_id UUID REFERENCES campus(id);

-- Campos de member (datas espirituais)
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS conversion_date DATE;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS baptism_date DATE;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS membership_date DATE;

-- Campos de member (outros)
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES user_account(id);

-- Campos de visitor (jornada do visitante)
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS first_visit_date DATE;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS last_visit_date DATE;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS total_visits INTEGER DEFAULT 0;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS how_found how_found_church;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS visitor_source visitor_source;

-- Campos de visitor (acompanhamento espiritual)
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS prayer_request TEXT;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS interests TEXT;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS is_salvation BOOLEAN DEFAULT FALSE;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS salvation_date DATE;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS testimony TEXT;

-- Campos de visitor (discipulado e batismo)
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS wants_baptism BOOLEAN DEFAULT FALSE;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS baptism_event_id UUID;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS baptism_course_id UUID;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS wants_discipleship BOOLEAN DEFAULT FALSE;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS discipleship_course_id UUID;

-- Campos de visitor (mentoria e acompanhamento)
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS assigned_mentor_id UUID REFERENCES user_account(id);
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS follow_up_status TEXT DEFAULT 'pending';
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS last_contact_date DATE;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS wants_contact BOOLEAN DEFAULT TRUE;
ALTER TABLE user_account ADD COLUMN IF NOT EXISTS wants_to_return BOOLEAN DEFAULT FALSE;

RAISE NOTICE '✅ user_account expandido com sucesso!';

-- =====================================================
-- ETAPA 3: ATUALIZAR FOREIGN KEYS (member_id → user_id)
-- =====================================================

RAISE NOTICE '==============================================';
RAISE NOTICE 'ETAPA 3: Atualizando foreign keys...';
RAISE NOTICE '==============================================';

-- bible_bookmark
ALTER TABLE bible_bookmark DROP CONSTRAINT IF EXISTS bible_bookmark_member_id_fkey;
ALTER TABLE bible_bookmark RENAME COLUMN member_id TO user_id;
ALTER TABLE bible_bookmark ADD CONSTRAINT bible_bookmark_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES user_account(id) ON DELETE CASCADE;

-- church_schedule
ALTER TABLE church_schedule DROP CONSTRAINT IF EXISTS church_schedule_responsible_id_fkey;
ALTER TABLE church_schedule RENAME COLUMN responsible_id TO user_id;
ALTER TABLE church_schedule ADD CONSTRAINT church_schedule_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES user_account(id) ON DELETE SET NULL;

-- contribution
ALTER TABLE contribution DROP CONSTRAINT IF EXISTS contribution_member_id_fkey;
ALTER TABLE contribution RENAME COLUMN member_id TO user_id;
ALTER TABLE contribution ADD CONSTRAINT contribution_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES user_account(id) ON DELETE CASCADE;

-- course_enrollment
ALTER TABLE course_enrollment DROP CONSTRAINT IF EXISTS course_enrollment_member_id_fkey;
ALTER TABLE course_enrollment RENAME COLUMN member_id TO user_id;
ALTER TABLE course_enrollment ADD CONSTRAINT course_enrollment_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES user_account(id) ON DELETE CASCADE;

-- donation
ALTER TABLE donation DROP CONSTRAINT IF EXISTS donation_member_id_fkey;
ALTER TABLE donation RENAME COLUMN member_id TO user_id;
ALTER TABLE donation ADD CONSTRAINT donation_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES user_account(id) ON DELETE CASCADE;

-- event_registration
ALTER TABLE event_registration DROP CONSTRAINT IF EXISTS event_registration_member_id_fkey;
ALTER TABLE event_registration RENAME COLUMN member_id TO user_id;
ALTER TABLE event_registration ADD CONSTRAINT event_registration_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES user_account(id) ON DELETE CASCADE;

-- group (leader_id)
ALTER TABLE "group" DROP CONSTRAINT IF EXISTS group_leader_id_fkey;
ALTER TABLE "group" RENAME COLUMN leader_id TO leader_user_id;
ALTER TABLE "group" ADD CONSTRAINT group_leader_user_id_fkey 
    FOREIGN KEY (leader_user_id) REFERENCES user_account(id) ON DELETE SET NULL;

-- group (host_id)
ALTER TABLE "group" DROP CONSTRAINT IF EXISTS group_host_id_fkey;
ALTER TABLE "group" RENAME COLUMN host_id TO host_user_id;
ALTER TABLE "group" ADD CONSTRAINT group_host_user_id_fkey 
    FOREIGN KEY (host_user_id) REFERENCES user_account(id) ON DELETE SET NULL;

-- group_attendance
ALTER TABLE group_attendance DROP CONSTRAINT IF EXISTS group_attendance_member_id_fkey;
ALTER TABLE group_attendance RENAME COLUMN member_id TO user_id;
ALTER TABLE group_attendance ADD CONSTRAINT group_attendance_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES user_account(id) ON DELETE CASCADE;

-- group_member
ALTER TABLE group_member DROP CONSTRAINT IF EXISTS group_member_member_id_fkey;
ALTER TABLE group_member RENAME COLUMN member_id TO user_id;
ALTER TABLE group_member ADD CONSTRAINT group_member_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES user_account(id) ON DELETE CASCADE;

-- member_step
ALTER TABLE member_step DROP CONSTRAINT IF EXISTS member_step_member_id_fkey;
ALTER TABLE member_step RENAME COLUMN member_id TO user_id;
ALTER TABLE member_step ADD CONSTRAINT member_step_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES user_account(id) ON DELETE CASCADE;

-- member_tag
ALTER TABLE member_tag DROP CONSTRAINT IF EXISTS member_tag_member_id_fkey;
ALTER TABLE member_tag RENAME COLUMN member_id TO user_id;
ALTER TABLE member_tag ADD CONSTRAINT member_tag_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES user_account(id) ON DELETE CASCADE;

-- ministry_member
ALTER TABLE ministry_member DROP CONSTRAINT IF EXISTS ministry_member_member_id_fkey;
ALTER TABLE ministry_member RENAME COLUMN member_id TO user_id;
ALTER TABLE ministry_member ADD CONSTRAINT ministry_member_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES user_account(id) ON DELETE CASCADE;

-- ministry_schedule
ALTER TABLE ministry_schedule DROP CONSTRAINT IF EXISTS ministry_schedule_member_id_fkey;
ALTER TABLE ministry_schedule RENAME COLUMN member_id TO user_id;
ALTER TABLE ministry_schedule ADD CONSTRAINT ministry_schedule_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES user_account(id) ON DELETE CASCADE;

-- reading_plan_progress
ALTER TABLE reading_plan_progress DROP CONSTRAINT IF EXISTS reading_plan_progress_member_id_fkey;
ALTER TABLE reading_plan_progress RENAME COLUMN member_id TO user_id;
ALTER TABLE reading_plan_progress ADD CONSTRAINT reading_plan_progress_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES user_account(id) ON DELETE CASCADE;

-- worship_attendance
ALTER TABLE worship_attendance DROP CONSTRAINT IF EXISTS worship_attendance_member_id_fkey;
ALTER TABLE worship_attendance RENAME COLUMN member_id TO user_id;
ALTER TABLE worship_attendance ADD CONSTRAINT worship_attendance_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES user_account(id) ON DELETE CASCADE;

RAISE NOTICE '✅ Foreign keys atualizadas com sucesso!';

-- =====================================================
-- ETAPA 4: RENOMEAR TABELAS RELACIONADAS A VISITOR
-- =====================================================

RAISE NOTICE '==============================================';
RAISE NOTICE 'ETAPA 4: Renomeando tabelas de visitor...';
RAISE NOTICE '==============================================';

-- Renomear visitor_followup para user_followup
ALTER TABLE visitor_followup RENAME TO user_followup;
ALTER TABLE user_followup DROP CONSTRAINT IF EXISTS visitor_followup_visitor_id_fkey;
ALTER TABLE user_followup RENAME COLUMN visitor_id TO user_id;
ALTER TABLE user_followup ADD CONSTRAINT user_followup_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES user_account(id) ON DELETE CASCADE;

-- Renomear visitor_visit para user_visit
ALTER TABLE visitor_visit RENAME TO user_visit;
ALTER TABLE user_visit DROP CONSTRAINT IF EXISTS visitor_visit_visitor_id_fkey;
ALTER TABLE user_visit RENAME COLUMN visitor_id TO user_id;
ALTER TABLE user_visit ADD CONSTRAINT user_visit_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES user_account(id) ON DELETE CASCADE;

RAISE NOTICE '✅ Tabelas renomeadas com sucesso!';

-- =====================================================
-- ETAPA 5: REMOVER TABELAS ANTIGAS
-- =====================================================

RAISE NOTICE '==============================================';
RAISE NOTICE 'ETAPA 5: Removendo tabelas antigas...';
RAISE NOTICE '==============================================';

-- Remover tabela visitor (já migrada para user_account)
DROP TABLE IF EXISTS visitor CASCADE;
RAISE NOTICE '✅ Tabela visitor removida!';

-- Remover tabela member (já migrada para user_account)
DROP TABLE IF EXISTS member CASCADE;
RAISE NOTICE '✅ Tabela member removida!';

-- =====================================================
-- ETAPA 6: ATUALIZAR CONSTRAINTS E ÍNDICES
-- =====================================================

RAISE NOTICE '==============================================';
RAISE NOTICE 'ETAPA 6: Criando índices e constraints...';
RAISE NOTICE '==============================================';

-- Índices para melhorar performance
CREATE INDEX IF NOT EXISTS idx_user_account_email ON user_account(email);
CREATE INDEX IF NOT EXISTS idx_user_account_status ON user_account(status);
CREATE INDEX IF NOT EXISTS idx_user_account_campus_id ON user_account(campus_id);
CREATE INDEX IF NOT EXISTS idx_user_account_household_id ON user_account(household_id);
CREATE INDEX IF NOT EXISTS idx_user_account_created_by ON user_account(created_by);
CREATE INDEX IF NOT EXISTS idx_user_account_assigned_mentor_id ON user_account(assigned_mentor_id);

-- Constraint para garantir que first_name e last_name sejam preenchidos
-- quando o status não for visitor
ALTER TABLE user_account ADD CONSTRAINT check_names_required
    CHECK (
        status = 'visitor' OR
        (first_name IS NOT NULL AND last_name IS NOT NULL)
    );

RAISE NOTICE '✅ Índices e constraints criados!';

-- =====================================================
-- ETAPA 7: ATUALIZAR TRIGGER DE updated_at
-- =====================================================

RAISE NOTICE '==============================================';
RAISE NOTICE 'ETAPA 7: Atualizando triggers...';
RAISE NOTICE '==============================================';

-- Garantir que o trigger de updated_at existe
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_user_account_updated_at ON user_account;
CREATE TRIGGER update_user_account_updated_at
    BEFORE UPDATE ON user_account
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

RAISE NOTICE '✅ Triggers atualizados!';

-- =====================================================
-- RESUMO DA MIGRAÇÃO
-- =====================================================

RAISE NOTICE '==============================================';
RAISE NOTICE '🎉 MIGRAÇÃO CONCLUÍDA COM SUCESSO!';
RAISE NOTICE '==============================================';
RAISE NOTICE '';
RAISE NOTICE 'Mudanças aplicadas:';
RAISE NOTICE '1. ✅ user_account expandido com campos de member e visitor';
RAISE NOTICE '2. ✅ 15 foreign keys atualizadas (member_id → user_id)';
RAISE NOTICE '3. ✅ Tabelas renomeadas:';
RAISE NOTICE '   - visitor_followup → user_followup';
RAISE NOTICE '   - visitor_visit → user_visit';
RAISE NOTICE '4. ✅ Tabelas removidas: member, visitor';
RAISE NOTICE '5. ✅ Índices criados para performance';
RAISE NOTICE '6. ✅ Constraints e triggers atualizados';
RAISE NOTICE '';
RAISE NOTICE 'Próximos passos:';
RAISE NOTICE '1. Execute o Script 22 para atualizar RLS policies';
RAISE NOTICE '2. Atualize o código Flutter para usar user_account';
RAISE NOTICE '3. Teste o signup e criação de visitantes';
RAISE NOTICE '';
RAISE NOTICE '==============================================';

COMMIT;

