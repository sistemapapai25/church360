-- =====================================================
-- Script 20: Backup e Preparação para Unificação
-- =====================================================
-- Descrição: Criar backup da estrutura atual antes da migração
-- Data: 2025-10-24
-- Autor: Church 360 Gabriel
-- =====================================================

-- =====================================================
-- IMPORTANTE: EXECUTAR ANTES DO SCRIPT 21
-- =====================================================
-- Este script cria views de backup para documentar
-- a estrutura atual antes da grande migração.
-- =====================================================

-- =====================================================
-- 1. DOCUMENTAR ESTRUTURA ATUAL
-- =====================================================

-- Criar schema para backup (se não existir)
CREATE SCHEMA IF NOT EXISTS backup;

-- =====================================================
-- 2. CRIAR VIEWS DE BACKUP
-- =====================================================

-- Backup da estrutura de user_account (antes da migração)
CREATE OR REPLACE VIEW backup.user_account_structure_before AS
SELECT 
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'user_account'
ORDER BY ordinal_position;

-- Backup da estrutura de member (antes de remover)
CREATE OR REPLACE VIEW backup.member_structure AS
SELECT 
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'member'
ORDER BY ordinal_position;

-- Backup da estrutura de visitor (antes de remover)
CREATE OR REPLACE VIEW backup.visitor_structure AS
SELECT 
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'visitor'
ORDER BY ordinal_position;

-- Backup de foreign keys que referenciam member
CREATE OR REPLACE VIEW backup.member_foreign_keys AS
SELECT 
    tc.table_name,
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu 
    ON tc.constraint_name = kcu.constraint_name 
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu 
    ON ccu.constraint_name = tc.constraint_name 
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
AND tc.table_schema = 'public'
AND ccu.table_name = 'member'
ORDER BY tc.table_name;

-- Backup de foreign keys que referenciam visitor
CREATE OR REPLACE VIEW backup.visitor_foreign_keys AS
SELECT 
    tc.table_name,
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu 
    ON tc.constraint_name = kcu.constraint_name 
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu 
    ON ccu.constraint_name = tc.constraint_name 
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
AND tc.table_schema = 'public'
AND ccu.table_name = 'visitor'
ORDER BY tc.table_name;

-- =====================================================
-- 3. VERIFICAR DADOS EXISTENTES
-- =====================================================

-- Contar registros em cada tabela
DO $$
DECLARE
    user_account_count INTEGER;
    member_count INTEGER;
    visitor_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_account_count FROM user_account;
    SELECT COUNT(*) INTO member_count FROM member;
    SELECT COUNT(*) INTO visitor_count FROM visitor;
    
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'CONTAGEM DE REGISTROS ANTES DA MIGRAÇÃO:';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'user_account: % registros', user_account_count;
    RAISE NOTICE 'member: % registros', member_count;
    RAISE NOTICE 'visitor: % registros', visitor_count;
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'ATENÇÃO: Todos os dados serão APAGADOS!';
    RAISE NOTICE 'Se precisar manter dados, PARE AQUI!';
    RAISE NOTICE '==============================================';
END $$;

-- =====================================================
-- RESUMO DO BACKUP
-- =====================================================
-- 
-- Views criadas no schema 'backup':
-- 1. backup.user_account_structure_before
-- 2. backup.member_structure
-- 3. backup.visitor_structure
-- 4. backup.member_foreign_keys
-- 5. backup.visitor_foreign_keys
-- 
-- Para consultar:
-- SELECT * FROM backup.user_account_structure_before;
-- SELECT * FROM backup.member_structure;
-- SELECT * FROM backup.visitor_structure;
-- SELECT * FROM backup.member_foreign_keys;
-- SELECT * FROM backup.visitor_foreign_keys;
-- 
-- =====================================================

