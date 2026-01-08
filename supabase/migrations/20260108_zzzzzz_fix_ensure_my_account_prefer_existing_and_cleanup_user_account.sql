DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'user_account'
  ) THEN
    EXECUTE $sql$
      CREATE OR REPLACE FUNCTION public.ensure_my_account(
        _tenant_id uuid DEFAULT NULL::uuid,
        _email text DEFAULT NULL::text,
        _full_name text DEFAULT NULL::text,
        _nickname text DEFAULT NULL::text
      )
      RETURNS void
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path TO ''
      SET row_security TO off
      AS $function$
      DECLARE
        uid uuid;
        tid uuid;
        safe_email text;
        safe_full_name text;
        safe_nickname text;
        existing_id uuid;
      BEGIN
        uid := auth.uid();
        IF uid IS NULL THEN
          RAISE EXCEPTION 'not authenticated';
        END IF;

        tid := COALESCE(
          NULLIF(current_setting('app.tenant_id', true), '')::uuid,
          NULLIF(current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'tenant_id', '')::uuid,
          NULLIF(current_setting('request.jwt.claims', true)::jsonb -> 'user_metadata' ->> 'tenant_id', '')::uuid,
          _tenant_id
        );

        IF tid IS NULL THEN
          RAISE EXCEPTION 'TENANT_ID_MISSING';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM public.tenant t WHERE t.id = tid) THEN
          RAISE EXCEPTION 'TENANT_ID_NOT_FOUND: %', tid;
        END IF;

        PERFORM set_config('app.tenant_id', tid::text, true);

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

        SELECT ua.id
        INTO existing_id
        FROM public.user_account ua
        WHERE ua.tenant_id = tid
          AND ua.auth_user_id = uid
        ORDER BY
          COALESCE(ua.is_active, false) DESC,
          CASE COALESCE(ua.status::text, '')
            WHEN 'member_active' THEN 4
            WHEN 'member_inactive' THEN 3
            WHEN 'visitor' THEN 1
            ELSE 0
          END DESC,
          ua.created_at DESC
        LIMIT 1;

        IF existing_id IS NULL AND safe_email IS NOT NULL THEN
          SELECT ua.id
          INTO existing_id
          FROM public.user_account ua
          WHERE ua.tenant_id = tid
            AND lower(ua.email) = lower(safe_email)
          ORDER BY
            COALESCE(ua.is_active, false) DESC,
            CASE COALESCE(ua.status::text, '')
              WHEN 'member_active' THEN 4
              WHEN 'member_inactive' THEN 3
              WHEN 'visitor' THEN 1
              ELSE 0
            END DESC,
            ua.created_at DESC
          LIMIT 1;
        END IF;

        IF existing_id IS NOT NULL THEN
          UPDATE public.user_account ua
          SET
            email = COALESCE(NULLIF(ua.email, ''), safe_email, ua.email),
            full_name = COALESCE(NULLIF(ua.full_name, ''), safe_full_name, ua.full_name),
            nickname = COALESCE(NULLIF(ua.nickname, ''), safe_nickname, ua.nickname),
            is_active = true,
            auth_user_id = uid,
            tenant_id = COALESCE(ua.tenant_id, tid),
            status = COALESCE(ua.status, 'visitor')
          WHERE ua.id = existing_id;

          RETURN;
        END IF;

        INSERT INTO public.user_account (id, email, full_name, nickname, tenant_id, is_active, status, auth_user_id)
        VALUES (uid, safe_email, COALESCE(safe_full_name, uid::text), safe_nickname, tid, true, 'visitor', uid)
        ON CONFLICT (id) DO UPDATE SET
          email = COALESCE(EXCLUDED.email, public.user_account.email),
          full_name = COALESCE(NULLIF(public.user_account.full_name, ''), EXCLUDED.full_name, public.user_account.full_name),
          nickname = COALESCE(NULLIF(public.user_account.nickname, ''), EXCLUDED.nickname, public.user_account.nickname),
          tenant_id = COALESCE(public.user_account.tenant_id, tid),
          is_active = true,
          status = COALESCE(public.user_account.status, 'visitor'),
          auth_user_id = COALESCE(public.user_account.auth_user_id, EXCLUDED.auth_user_id);
      END
      $function$;

      CREATE OR REPLACE FUNCTION public.ensure_my_account(
        _tenant_id uuid DEFAULT NULL::uuid,
        _email text DEFAULT NULL::text,
        _full_name text DEFAULT NULL::text
      )
      RETURNS void
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path TO ''
      SET row_security TO off
      AS $function$
      BEGIN
        PERFORM public.ensure_my_account(_tenant_id, _email, _full_name, NULL::text);
      END
      $function$;
    $sql$;
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.user_account') IS NOT NULL THEN
    ALTER TABLE public.user_account
      DROP CONSTRAINT IF EXISTS user_account_duplicate_assigned_mentor_id_fkey,
      DROP CONSTRAINT IF EXISTS user_account_duplicate_created_by_fkey,
      DROP CONSTRAINT IF EXISTS user_account_duplicate_campus_id_fkey,
      DROP CONSTRAINT IF EXISTS user_account_duplicate_household_id_fkey;

    EXECUTE 'DROP INDEX IF EXISTS public.uq_user_account_email_not_null';
    EXECUTE 'DROP INDEX IF EXISTS public.uq_user_account_tenant_email';
    EXECUTE 'DROP INDEX IF EXISTS public.user_account_duplicate_email_idx';
  END IF;
END $$;
