-- ============================================
-- CHURCH 360 - ADICIONAR USUÁRIO À TABELA USER_ACCOUNT
-- ============================================

-- Inserir usuário na tabela user_account
INSERT INTO user_account (
  id,
  email,
  full_name,
  role_global,
  is_active
) VALUES (
  '5e404c9a-53fe-441e-9ee6-e794f335b973',
  'alcidescostant@hotmail.com',
  'Alcides Costant',
  'owner',
  true
)
ON CONFLICT (id) DO UPDATE SET
  email = EXCLUDED.email,
  full_name = EXCLUDED.full_name,
  role_global = EXCLUDED.role_global,
  is_active = EXCLUDED.is_active;

-- Verificar se foi criado
SELECT 
  id, 
  email, 
  full_name, 
  role_global, 
  is_active,
  created_at 
FROM user_account 
WHERE id = '5e404c9a-53fe-441e-9ee6-e794f335b973';

