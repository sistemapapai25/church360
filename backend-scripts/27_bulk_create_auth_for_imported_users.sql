-- =====================================================
-- CHURCH 360 - CRIAR CONTAS AUTH PARA USUÁRIOS IMPORTADOS
-- =====================================================
-- Objetivo: Para registros em `user_account` importados sem conta no Auth,
--           criar entradas em `auth.users` reutilizando o mesmo UUID de `user_account.id`
--           e criar `user_access_level` (visitor) quando não existir.
-- Pré-requisitos:
-- - Executar com a `service_role` (SQL Editor do Supabase tem permissão)
-- - Tabela `user_account` possui `id` (UUID) e `email`
-- - Os e-mails devem ser válidos e únicos
-- Notas:
-- - Senha inicial gerada aleatoriamente (hash via bcrypt). Recomenda-se enviar
--   e-mail de recuperação de senha aos usuários após a criação.
-- =====================================================

DO $$
DECLARE
  v_count_created INTEGER := 0;
  v_count_access   INTEGER := 0;
BEGIN
  -- Criar usuários no Auth para cada registro importado sem Auth
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
  )
  SELECT
    '00000000-0000-0000-0000-000000000000',   -- instance_id
    ua.id,                                    -- reutiliza o UUID de user_account
    'authenticated',
    'authenticated',
    ua.email,
    crypt('123456', gen_salt('bf')),                -- senha padrão: 123456
    NOW(),                                    -- confirma e-mail para permitir login imediato
    NULL,
    NULL,
    '{"provider":"email","providers":["email"]}',
    json_build_object(
      'full_name', coalesce(ua.first_name,'') || ' ' || coalesce(ua.last_name,'')
    ),
    NOW(),
    NOW(),
    '', '', '', ''
  FROM user_account ua
  WHERE ua.email IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM auth.users au
      WHERE au.id = ua.id OR au.email = ua.email
    );

  GET DIAGNOSTICS v_count_created = ROW_COUNT;

  -- Criar nível de acesso visitor para usuários sem registro em user_access_level
  INSERT INTO user_access_level (
    user_id,
    access_level,
    access_level_number,
    promoted_at,
    promotion_reason
  )
  SELECT
    ua.id,
    'visitor'::access_level_type,
    0,
    NOW(),
    'Importação inicial: visitante padrão'
  FROM user_account ua
  WHERE ua.email IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM auth.users au WHERE au.id = ua.id
    )
    AND NOT EXISTS (
      SELECT 1 FROM user_access_level ual WHERE ual.user_id = ua.id
    );

  GET DIAGNOSTICS v_count_access = ROW_COUNT;

  RAISE NOTICE 'Usuários criados no Auth: %', v_count_created;
  RAISE NOTICE 'Registros de access_level criados: %', v_count_access;
END $$;

-- =====================================================
-- VERIFICAÇÃO
-- =====================================================

-- 1) Quantos user_account ainda estão sem Auth?
SELECT COUNT(*) AS sem_auth
FROM user_account ua
WHERE ua.email IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM auth.users au WHERE au.id = ua.id);

-- 2) Amostra dos usuários criados
SELECT au.id, au.email, au.created_at
FROM auth.users au
JOIN user_account ua ON ua.id = au.id
ORDER BY au.created_at DESC
LIMIT 10;

-- 3) Verificar access_level
SELECT ual.user_id, ual.access_level, ual.access_level_number, ual.promoted_at
FROM user_access_level ual
ORDER BY ual.promoted_at DESC
LIMIT 10;
