DO $$
DECLARE
  v_created_auth INTEGER := 0;
  v_created_access INTEGER := 0;
  v_deleted_auth INTEGER := 0;
BEGIN
  WITH mismatches AS (
    SELECT ua.id AS ua_id, ua.email AS email
    FROM user_account ua
    JOIN auth.users au ON au.email = ua.email
    WHERE au.id <> ua.id
  )
  DELETE FROM auth.users au
  USING mismatches m
  WHERE au.email = m.email;

  GET DIAGNOSTICS v_deleted_auth = ROW_COUNT;

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
    '00000000-0000-0000-0000-000000000000',
    ua.id,
    'authenticated',
    'authenticated',
    ua.email,
    crypt('123456', gen_salt('bf')),
    NOW(),
    NULL,
    NULL,
    '{"provider":"email","providers":["email"]}',
    json_build_object('full_name', coalesce(ua.first_name,'') || ' ' || coalesce(ua.last_name,'')),
    NOW(),
    NOW(),
    '', '', '', ''
  FROM user_account ua
  WHERE EXISTS (
    SELECT 1 FROM (
      SELECT ua2.id AS ua_id, ua2.email AS email
      FROM user_account ua2
      JOIN auth.users au2 ON au2.email = ua2.email
      WHERE au2.id <> ua2.id
    ) m WHERE m.ua_id = ua.id
  );

  GET DIAGNOSTICS v_created_auth = ROW_COUNT;

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
    'Correção em lote: visitante padrão'
  FROM user_account ua
  WHERE EXISTS (
    SELECT 1 FROM auth.users au WHERE au.id = ua.id
  )
  AND NOT EXISTS (
    SELECT 1 FROM user_access_level ual WHERE ual.user_id = ua.id
  );

  GET DIAGNOSTICS v_created_access = ROW_COUNT;
  RAISE NOTICE 'auth.users removidos: %', v_deleted_auth;
  RAISE NOTICE 'auth.users criados: %', v_created_auth;
  RAISE NOTICE 'user_access_level criados: %', v_created_access;
END $$;

-- Verificações
SELECT COUNT(*) AS sem_auth
FROM user_account ua
WHERE ua.email IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM auth.users au WHERE au.id = ua.id);

SELECT COUNT(*) AS sem_access
FROM user_account ua
WHERE EXISTS (SELECT 1 FROM auth.users au WHERE au.id = ua.id)
  AND NOT EXISTS (SELECT 1 FROM user_access_level ual WHERE ual.user_id = ua.id);
