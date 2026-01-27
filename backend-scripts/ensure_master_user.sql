-- Ensure master user alignment for dev login and permissions.
DO $$
DECLARE
  v_user_id uuid := '418a25db-76d5-47f8-9ff4-c8e6d8325a1f';
  v_tenant_id uuid := 'd8b6be47-f99f-45b8-a3f4-b7ca3cca9645';
  v_email text := 'financeiro.teste@church360.dev';
  v_full_name text := 'Financeiro Teste';
  v_has_tenant_col boolean;
BEGIN
  IF to_regclass('public.user_account') IS NOT NULL THEN
    UPDATE public.user_account
    SET auth_user_id = v_user_id,
        tenant_id = COALESCE(tenant_id, v_tenant_id),
        email = COALESCE(NULLIF(email, ''), v_email),
        full_name = COALESCE(NULLIF(full_name, ''), v_full_name),
        first_name = COALESCE(NULLIF(first_name, ''), 'Financeiro'),
        last_name = COALESCE(NULLIF(last_name, ''), 'Teste'),
        nickname = COALESCE(NULLIF(nickname, ''), 'Financeiro'),
        is_active = true
    WHERE id = v_user_id OR auth_user_id = v_user_id OR email = v_email;

    IF NOT FOUND THEN
      INSERT INTO public.user_account (
        id,
        auth_user_id,
        email,
        full_name,
        first_name,
        last_name,
        nickname,
        tenant_id,
        is_active,
        status,
        role_global
      )
      VALUES (
        v_user_id,
        v_user_id,
        v_email,
        v_full_name,
        'Financeiro',
        'Teste',
        'Financeiro',
        v_tenant_id,
        true,
        'visitor',
        'member'
      )
      ON CONFLICT (id) DO UPDATE SET
        auth_user_id = EXCLUDED.auth_user_id,
        tenant_id = COALESCE(public.user_account.tenant_id, EXCLUDED.tenant_id),
        email = COALESCE(NULLIF(public.user_account.email, ''), EXCLUDED.email),
        full_name = COALESCE(NULLIF(public.user_account.full_name, ''), EXCLUDED.full_name),
        first_name = COALESCE(NULLIF(public.user_account.first_name, ''), EXCLUDED.first_name),
        last_name = COALESCE(NULLIF(public.user_account.last_name, ''), EXCLUDED.last_name),
        nickname = COALESCE(NULLIF(public.user_account.nickname, ''), EXCLUDED.nickname),
        is_active = true;
    END IF;
  END IF;

  IF to_regclass('public.user_access_level') IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'user_access_level'
        AND column_name = 'tenant_id'
    ) INTO v_has_tenant_col;

    IF v_has_tenant_col THEN
      UPDATE public.user_access_level
      SET tenant_id = COALESCE(tenant_id, v_tenant_id),
          access_level = 'admin',
          access_level_number = 5
      WHERE user_id = v_user_id
        AND (tenant_id = v_tenant_id OR tenant_id IS NULL);

      IF NOT FOUND THEN
        INSERT INTO public.user_access_level (
          user_id,
          tenant_id,
          access_level,
          access_level_number
        )
        VALUES (v_user_id, v_tenant_id, 'admin', 5)
        ON CONFLICT (tenant_id, user_id) DO UPDATE SET
          access_level = EXCLUDED.access_level,
          access_level_number = EXCLUDED.access_level_number;
      END IF;
    ELSE
      UPDATE public.user_access_level
      SET access_level = 'admin',
          access_level_number = 5
      WHERE user_id = v_user_id;

      IF NOT FOUND THEN
        INSERT INTO public.user_access_level (
          user_id,
          access_level,
          access_level_number
        )
        VALUES (v_user_id, 'admin', 5)
        ON CONFLICT (user_id) DO UPDATE SET
          access_level = EXCLUDED.access_level,
          access_level_number = EXCLUDED.access_level_number;
      END IF;
    END IF;
  END IF;

  IF to_regclass('public.user_tenant_membership') IS NOT NULL THEN
    UPDATE public.user_tenant_membership
    SET access_level = 'admin',
        access_level_number = 5,
        is_active = true
    WHERE user_id = v_user_id
      AND tenant_id = v_tenant_id;

    IF NOT FOUND THEN
      INSERT INTO public.user_tenant_membership (
        tenant_id,
        user_id,
        access_level,
        access_level_number,
        is_active
      )
      VALUES (v_tenant_id, v_user_id, 'admin', 5, true)
      ON CONFLICT (tenant_id, user_id) DO UPDATE SET
        access_level = EXCLUDED.access_level,
        access_level_number = EXCLUDED.access_level_number,
        is_active = true;
    END IF;
  END IF;

  IF to_regclass('public.user_custom_permissions') IS NOT NULL
    AND to_regclass('public.permissions') IS NOT NULL THEN
    INSERT INTO public.user_custom_permissions (
      user_id,
      tenant_id,
      permission_id,
      is_granted
    )
    SELECT v_user_id, v_tenant_id, p.id, true
    FROM public.permissions p
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.user_custom_permissions ucp
      WHERE ucp.user_id = v_user_id
        AND ucp.tenant_id = v_tenant_id
        AND ucp.permission_id = p.id
    );

    UPDATE public.user_custom_permissions
    SET is_granted = true
    WHERE user_id = v_user_id
      AND tenant_id = v_tenant_id;
  END IF;
END $$;
