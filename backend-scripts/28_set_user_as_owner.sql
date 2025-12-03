-- =====================================================
-- CHURCH 360 - DEFINIR USUÁRIO COMO OWNER
-- =====================================================
-- Descrição: Define o usuário admin@church360.com como Owner
-- Atualiza tanto role_global quanto access_level
-- =====================================================

BEGIN;

-- =====================================================
-- ETAPA 1: VERIFICAR SE O USUÁRIO EXISTE
-- =====================================================

DO $$
DECLARE
  v_user_id UUID;
  v_email TEXT := 'admin@church360.com';
BEGIN
  -- Buscar o ID do usuário
  SELECT id INTO v_user_id
  FROM user_account
  WHERE email = v_email;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário com email % não encontrado!', v_email;
  END IF;

  RAISE NOTICE 'Usuário encontrado: % (ID: %)', v_email, v_user_id;
END $$;

-- =====================================================
-- ETAPA 2: ATUALIZAR role_global PARA 'owner'
-- =====================================================

UPDATE user_account
SET 
  role_global = 'owner',
  updated_at = NOW()
WHERE email = 'admin@church360.com';

-- =====================================================
-- ETAPA 3: CRIAR/ATUALIZAR access_level PARA 'admin' (nível 5)
-- =====================================================

INSERT INTO user_access_level (
  user_id,
  access_level,
  access_level_number,
  promoted_at,
  promoted_by,
  promotion_reason,
  notes
)
SELECT
  id,
  'admin'::access_level_type,
  5,
  NOW(),
  id, -- Auto-promoção (ou pode ser NULL)
  'Definido como Owner/Admin do sistema',
  'Usuário principal com acesso total ao sistema'
FROM user_account
WHERE email = 'admin@church360.com'
ON CONFLICT (user_id) DO UPDATE SET
  access_level = 'admin'::access_level_type,
  access_level_number = 5,
  promoted_at = NOW(),
  promotion_reason = 'Definido como Owner/Admin do sistema',
  notes = 'Usuário principal com acesso total ao sistema',
  updated_at = NOW();

COMMIT;

-- =====================================================
-- ETAPA 4: VERIFICAR RESULTADO
-- =====================================================

-- Verificar user_account
SELECT 
  id,
  email,
  full_name,
  role_global,
  is_active,
  created_at,
  updated_at
FROM user_account
WHERE email = 'admin@church360.com';

-- Verificar user_access_level
SELECT 
  ual.id,
  ual.user_id,
  ua.email,
  ua.full_name,
  ual.access_level,
  ual.access_level_number,
  ual.promoted_at,
  ual.promotion_reason,
  ual.notes
FROM user_access_level ual
JOIN user_account ua ON ua.id = ual.user_id
WHERE ua.email = 'admin@church360.com';

-- =====================================================
-- FIM DO SCRIPT
-- =====================================================

