-- ============================================
-- CHURCH 360 - CORRIGIR STATUS DE USUÁRIOS EXISTENTES
-- ============================================
-- Script: 23_fix_existing_users_status.sql
-- Descrição: Atualiza registros de user_account que não têm status definido
--            ou que foram criados com a estrutura antiga
-- Data: 2025-10-24
-- ============================================

-- =====================================================
-- ETAPA 1: Verificar registros sem status
-- =====================================================

SELECT
  id,
  email,
  full_name,
  status,
  is_active,
  created_at
FROM user_account
WHERE status IS NULL;

-- =====================================================
-- ETAPA 2: Atualizar registros sem status para 'visitor'
-- =====================================================

UPDATE user_account
SET status = 'visitor'
WHERE status IS NULL;

-- =====================================================
-- ETAPA 3: Verificar se há registros com role_global
-- =====================================================

-- Nota: A coluna role_global pode não existir mais após a migração
-- Este SELECT pode falhar se a coluna já foi removida (isso é OK)

DO $$
BEGIN
  -- Verificar se a coluna role_global ainda existe
  IF EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'user_account' 
    AND column_name = 'role_global'
  ) THEN
    RAISE NOTICE 'Coluna role_global ainda existe. Considere removê-la.';
  ELSE
    RAISE NOTICE 'Coluna role_global já foi removida. ✅';
  END IF;
END $$;

-- =====================================================
-- ETAPA 4: Verificar resultado
-- =====================================================

SELECT 
  id,
  email,
  full_name,
  status,
  is_active,
  created_at
FROM user_account
ORDER BY created_at DESC
LIMIT 10;

-- =====================================================
-- RESUMO
-- =====================================================

SELECT 
  status,
  COUNT(*) as total
FROM user_account
GROUP BY status
ORDER BY total DESC;

RAISE NOTICE '✅ Status de usuários corrigido!';

