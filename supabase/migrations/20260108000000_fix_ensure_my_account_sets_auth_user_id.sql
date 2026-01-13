DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_account'
  ) THEN
    EXECUTE $sql$
      CREATE OR REPLACE FUNCTION public.ensure_my_account(
        _tenant_id uuid DEFAULT NULL,
        _email text DEFAULT NULL,
        _full_name text DEFAULT NULL,
        _nickname text DEFAULT NULL
      )
      RETURNS void
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path TO ''
      SET row_security TO off
      AS $f$
      DECLARE
        uid uuid;
        tid uuid;
        safe_email text;
        safe_full_name text;
        safe_nickname text;
      BEGIN
        uid := auth.uid();
        IF uid IS NULL THEN
          RAISE EXCEPTION 'not authenticated';
        END IF;

        tid := public.jwt_tenant_id();
        IF tid IS NULL THEN
          RAISE EXCEPTION 'tenant_id ausente na sessão';
        END IF;

        IF _tenant_id IS NOT NULL AND _tenant_id <> tid THEN
          RAISE EXCEPTION 'tenant_id inválido para esta sessão';
        END IF;

        safe_email := NULLIF(trim(_email), '');
        safe_full_name := NULLIF(trim(_full_name), '');
        IF safe_full_name IS NULL AND safe_email IS NOT NULL THEN
          safe_full_name := split_part(safe_email, '@', 1);
        END IF;

        safe_nickname := NULLIF(trim(_nickname), '');
        IF safe_nickname IS NULL THEN
          safe_nickname := NULLIF(trim(safe_full_name), '');
        END IF;
        IF safe_nickname IS NULL AND safe_email IS NOT NULL THEN
          safe_nickname := split_part(safe_email, '@', 1);
        END IF;
        IF safe_nickname IS NULL THEN
          safe_nickname := uid::text;
        END IF;

        IF EXISTS (
          SELECT 1
          FROM information_schema.columns c
          WHERE c.table_schema = 'public'
            AND c.table_name = 'user_account'
            AND c.column_name = 'nickname'
        ) THEN
          INSERT INTO public.user_account (id, email, full_name, nickname, tenant_id, is_active)
          VALUES (uid, safe_email, COALESCE(safe_full_name, uid::text), safe_nickname, tid, true)
          ON CONFLICT (id) DO UPDATE SET
            email = COALESCE(EXCLUDED.email, public.user_account.email),
            full_name = COALESCE(NULLIF(public.user_account.full_name, ''), EXCLUDED.full_name, public.user_account.full_name),
            nickname = COALESCE(NULLIF(public.user_account.nickname, ''), EXCLUDED.nickname, public.user_account.nickname),
            tenant_id = COALESCE(public.user_account.tenant_id, tid),
            is_active = true;
        ELSE
          INSERT INTO public.user_account (id, email, full_name, tenant_id, is_active)
          VALUES (uid, safe_email, COALESCE(safe_full_name, uid::text), tid, true)
          ON CONFLICT (id) DO UPDATE SET
            email = COALESCE(EXCLUDED.email, public.user_account.email),
            full_name = COALESCE(NULLIF(public.user_account.full_name, ''), EXCLUDED.full_name, public.user_account.full_name),
            tenant_id = COALESCE(public.user_account.tenant_id, tid),
            is_active = true;
        END IF;

        IF EXISTS (
          SELECT 1
          FROM information_schema.columns c
          WHERE c.table_schema = 'public'
            AND c.table_name = 'user_account'
            AND c.column_name = 'auth_user_id'
        ) THEN
          EXECUTE format(
            'UPDATE public.user_account ua
             SET auth_user_id = %L::uuid
             WHERE ua.id = %L::uuid
               AND (ua.auth_user_id IS NULL OR ua.auth_user_id <> %L::uuid)',
            uid, uid, uid
          );
        END IF;

        IF EXISTS (
          SELECT 1 FROM public.tenant t
          WHERE t.id = tid AND t.allow_self_signup = true
        ) THEN
          INSERT INTO public.user_access_level (user_id, tenant_id, access_level, access_level_number)
          VALUES (uid, tid, 'visitor', 0)
          ON CONFLICT (tenant_id, user_id) DO NOTHING;

          INSERT INTO public.user_tenant_membership (tenant_id, user_id, access_level, access_level_number, is_active)
          VALUES (tid, uid, 'visitor', 0, true)
          ON CONFLICT (tenant_id, user_id) DO UPDATE SET
            is_active = true;
        END IF;
      END
      $f$;
    $sql$;
  END IF;
END $$;

