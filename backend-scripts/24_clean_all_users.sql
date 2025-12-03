-- =====================================================
-- SCRIPT: Limpar todos os usuários e começar do zero
-- =====================================================
-- ATENÇÃO: Este script vai DELETAR TODOS os usuários e dados relacionados!
-- Use apenas em ambiente de desenvolvimento/teste
-- =====================================================

-- ETAPA 1: Verificar usuários existentes
SELECT
  id,
  email,
  created_at
FROM auth.users
ORDER BY created_at;

-- ETAPA 2: Verificar registros em user_account
SELECT
  id,
  email,
  full_name,
  status,
  created_at
FROM user_account
ORDER BY created_at;

-- =====================================================
-- ETAPA 3: DELETAR TODOS OS DADOS (MÉTODO SIMPLES)
-- =====================================================

-- MÉTODO: Desabilitar constraints temporariamente e deletar tudo

-- 3.1: Desabilitar temporariamente as foreign key constraints
SET session_replication_role = 'replica';

-- 3.2: Deletar de user_account (principal tabela)
DELETE FROM user_account;

-- 3.3: Deletar de auth.users
DELETE FROM auth.users;

-- 3.4: Reabilitar foreign key constraints
SET session_replication_role = 'origin';

-- =====================================================
-- ETAPA 4: Verificar que tudo foi deletado
-- =====================================================

SELECT COUNT(*) as total_users FROM auth.users;
SELECT COUNT(*) as total_user_accounts FROM user_account;
SELECT COUNT(*) as total_study_groups FROM study_groups;
SELECT COUNT(*) as total_ministries FROM ministries;
SELECT COUNT(*) as total_groups FROM groups;

-- =====================================================
-- RESULTADO ESPERADO:
-- Todos os contadores devem estar em 0
-- =====================================================

-- Agora você pode criar uma nova conta no app!

