-- ============================================
-- CHURCH 360 - CRIAR USUÁRIO OWNER
-- ============================================
-- Este script cria o primeiro usuário owner
-- ============================================

-- Criar usuário no auth.users e user_account
DO $$
DECLARE
  new_user_id UUID;
BEGIN
  -- Inserir usuário no auth.users (sistema de autenticação do Supabase)
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    recovery_sent_at,
    last_sign_in_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    'owner@teste.com',
    crypt('Teste@123', gen_salt('bf')), -- Senha: Teste@123
    NOW(),
    NOW(),
    NOW(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Owner Teste"}',
    NOW(),
    NOW(),
    '',
    '',
    '',
    ''
  )
  RETURNING id INTO new_user_id;

  -- Inserir na tabela user_account
  INSERT INTO user_account (
    id,
    email,
    full_name,
    role_global,
    is_active
  ) VALUES (
    new_user_id,
    'owner@teste.com',
    'Owner Teste',
    'owner',
    true
  );

  -- Mostrar o UUID criado
  RAISE NOTICE 'Usuário criado com sucesso! UUID: %', new_user_id;
END $$;

-- Verificar se foi criado
SELECT id, email, full_name, role_global, created_at 
FROM user_account 
WHERE email = 'owner@teste.com';

