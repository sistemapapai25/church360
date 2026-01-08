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
        has_status boolean;
        has_nickname boolean;
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

        SELECT EXISTS (
          SELECT 1
          FROM information_schema.columns
          WHERE table_schema = 'public'
            AND table_name = 'user_account'
            AND column_name = 'status'
        ) INTO has_status;

        SELECT EXISTS (
          SELECT 1
          FROM information_schema.columns
          WHERE table_schema = 'public'
            AND table_name = 'user_account'
            AND column_name = 'nickname'
        ) INTO has_nickname;

        IF has_status AND has_nickname THEN
          INSERT INTO public.user_account (id, email, full_name, nickname, tenant_id, is_active, status)
          VALUES (uid, safe_email, COALESCE(safe_full_name, uid::text), safe_nickname, tid, true, 'visitor')
          ON CONFLICT (id) DO UPDATE SET
            email = COALESCE(EXCLUDED.email, public.user_account.email),
            full_name = COALESCE(NULLIF(public.user_account.full_name, ''), EXCLUDED.full_name, public.user_account.full_name),
            nickname = COALESCE(NULLIF(public.user_account.nickname, ''), EXCLUDED.nickname, public.user_account.nickname),
            tenant_id = COALESCE(public.user_account.tenant_id, tid),
            is_active = true,
            status = COALESCE(public.user_account.status, 'visitor');
        ELSIF has_nickname THEN
          INSERT INTO public.user_account (id, email, full_name, nickname, tenant_id, is_active)
          VALUES (uid, safe_email, COALESCE(safe_full_name, uid::text), safe_nickname, tid, true)
          ON CONFLICT (id) DO UPDATE SET
            email = COALESCE(EXCLUDED.email, public.user_account.email),
            full_name = COALESCE(NULLIF(public.user_account.full_name, ''), EXCLUDED.full_name, public.user_account.full_name),
            nickname = COALESCE(NULLIF(public.user_account.nickname, ''), EXCLUDED.nickname, public.user_account.nickname),
            tenant_id = COALESCE(public.user_account.tenant_id, tid),
            is_active = true;
        ELSIF has_status THEN
          INSERT INTO public.user_account (id, email, full_name, tenant_id, is_active, status)
          VALUES (uid, safe_email, COALESCE(safe_full_name, uid::text), tid, true, 'visitor')
          ON CONFLICT (id) DO UPDATE SET
            email = COALESCE(EXCLUDED.email, public.user_account.email),
            full_name = COALESCE(NULLIF(public.user_account.full_name, ''), EXCLUDED.full_name, public.user_account.full_name),
            tenant_id = COALESCE(public.user_account.tenant_id, tid),
            is_active = true,
            status = COALESCE(public.user_account.status, 'visitor');
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
          FROM information_schema.columns
          WHERE table_schema = 'public'
            AND table_name = 'user_account'
            AND column_name = 'auth_user_id'
        ) THEN
          UPDATE public.user_account ua
          SET auth_user_id = uid
          WHERE ua.id = uid
            AND (ua.auth_user_id IS NULL OR ua.auth_user_id <> uid);
        END IF;

        IF EXISTS (
          SELECT 1
          FROM information_schema.tables
          WHERE table_schema = 'public'
            AND table_name = 'user_access_level'
        ) THEN
          INSERT INTO public.user_access_level (user_id, tenant_id, access_level, access_level_number)
          VALUES (uid, tid, 'visitor', 0)
          ON CONFLICT (tenant_id, user_id) DO NOTHING;
        END IF;

        IF EXISTS (
          SELECT 1
          FROM information_schema.tables
          WHERE table_schema = 'public'
            AND table_name = 'user_tenant_membership'
        ) THEN
          INSERT INTO public.user_tenant_membership (tenant_id, user_id, access_level, access_level_number, is_active)
          VALUES (tid, uid, 'visitor', 0, true)
          ON CONFLICT (tenant_id, user_id) DO UPDATE SET
            is_active = true;
        END IF;
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
  IF to_regclass('public.user_roles') IS NOT NULL
    AND to_regclass('public.roles') IS NOT NULL
    AND to_regclass('public.permissions') IS NOT NULL
    AND to_regclass('public.role_permissions') IS NOT NULL
  THEN
    EXECUTE $sql$
      CREATE OR REPLACE FUNCTION public.get_user_effective_permissions(p_user_id uuid)
      RETURNS TABLE(
        permission_code text,
        permission_name text,
        source text,
        role_name text,
        context_name text,
        is_granted boolean
      )
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path TO ''
      SET row_security TO off
      AS $function$
      DECLARE
        tid uuid;
        actor uuid;
        allow_other boolean := false;
      BEGIN
        actor := auth.uid();
        IF actor IS NULL THEN
          RETURN;
        END IF;

        tid := COALESCE(
          NULLIF(current_setting('app.tenant_id', true), '')::uuid,
          NULLIF(current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'tenant_id', '')::uuid,
          NULLIF(current_setting('request.jwt.claims', true)::jsonb -> 'user_metadata' ->> 'tenant_id', '')::uuid
        );

        IF tid IS NULL THEN
          RETURN;
        END IF;

        IF p_user_id = actor THEN
          allow_other := true;
        ELSIF to_regclass('public.user_tenant_membership') IS NOT NULL THEN
          allow_other := EXISTS (
            SELECT 1
            FROM public.user_tenant_membership utm
            WHERE utm.user_id = actor
              AND utm.tenant_id = tid
              AND utm.is_active = true
              AND utm.access_level_number >= 5
          );
        END IF;

        IF NOT allow_other THEN
          RETURN;
        END IF;

        RETURN QUERY
        SELECT DISTINCT
          p.code,
          p.name,
          'role'::text,
          r.name,
          rc.context_name,
          rp.is_granted
        FROM public.user_roles ur
        JOIN public.roles r ON r.id = ur.role_id
        JOIN public.role_permissions rp ON rp.role_id = r.id
        JOIN public.permissions p ON p.id = rp.permission_id
        LEFT JOIN public.role_contexts rc ON rc.id = ur.role_context_id
        WHERE ur.user_id = p_user_id
          AND ur.tenant_id = tid
          AND COALESCE(ur.is_active, true) = true
          AND (ur.expires_at IS NULL OR ur.expires_at > now())
          AND COALESCE(r.is_active, true) = true
          AND COALESCE(p.is_active, true) = true

        UNION

        SELECT
          p.code,
          p.name,
          'custom'::text,
          NULL::text,
          NULL::text,
          ucp.is_granted
        FROM public.user_custom_permissions ucp
        JOIN public.permissions p ON p.id = ucp.permission_id
        WHERE ucp.user_id = p_user_id
          AND ucp.tenant_id = tid
          AND (ucp.expires_at IS NULL OR ucp.expires_at > now())
          AND COALESCE(p.is_active, true) = true;
      END
      $function$;
    $sql$;
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.user_roles') IS NOT NULL
    AND to_regclass('public.permissions') IS NOT NULL
    AND to_regclass('public.role_permissions') IS NOT NULL
  THEN
    EXECUTE $sql$
      CREATE OR REPLACE FUNCTION public.check_user_permission(
        p_user_id uuid,
        p_permission_code text
      )
      RETURNS boolean
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path TO ''
      SET row_security TO off
      AS $function$
      DECLARE
        tid uuid;
        actor uuid;
        allow_other boolean := false;
        v_has boolean;
      BEGIN
        actor := auth.uid();
        IF actor IS NULL THEN
          RETURN false;
        END IF;

        tid := COALESCE(
          NULLIF(current_setting('app.tenant_id', true), '')::uuid,
          NULLIF(current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'tenant_id', '')::uuid,
          NULLIF(current_setting('request.jwt.claims', true)::jsonb -> 'user_metadata' ->> 'tenant_id', '')::uuid
        );

        IF tid IS NULL THEN
          RETURN false;
        END IF;

        IF p_user_id = actor THEN
          allow_other := true;
        ELSIF to_regclass('public.user_tenant_membership') IS NOT NULL THEN
          allow_other := EXISTS (
            SELECT 1
            FROM public.user_tenant_membership utm
            WHERE utm.user_id = actor
              AND utm.tenant_id = tid
              AND utm.is_active = true
              AND utm.access_level_number >= 5
          );
        END IF;

        IF NOT allow_other THEN
          RETURN false;
        END IF;

        IF to_regclass('public.user_custom_permissions') IS NOT NULL THEN
          SELECT ucp.is_granted
          INTO v_has
          FROM public.user_custom_permissions ucp
          JOIN public.permissions p ON p.id = ucp.permission_id
          WHERE ucp.user_id = p_user_id
            AND ucp.tenant_id = tid
            AND p.code = p_permission_code
            AND (ucp.expires_at IS NULL OR ucp.expires_at > now())
          LIMIT 1;

          IF FOUND THEN
            RETURN COALESCE(v_has, false);
          END IF;
        END IF;

        SELECT EXISTS(
          SELECT 1
          FROM public.user_roles ur
          JOIN public.role_permissions rp ON rp.role_id = ur.role_id
          JOIN public.permissions p ON p.id = rp.permission_id
          WHERE ur.user_id = p_user_id
            AND ur.tenant_id = tid
            AND COALESCE(ur.is_active, true) = true
            AND (ur.expires_at IS NULL OR ur.expires_at > now())
            AND p.code = p_permission_code
            AND rp.is_granted = true
        )
        INTO v_has;

        RETURN COALESCE(v_has, false);
      END
      $function$;
    $sql$;
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.user_access_level') IS NOT NULL THEN
    EXECUTE $sql$
      CREATE OR REPLACE FUNCTION public.can_access_dashboard(p_user_id uuid)
      RETURNS boolean
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path TO ''
      SET row_security TO off
      AS $function$
      DECLARE
        tid uuid;
        actor uuid;
        allow_other boolean := false;
        v_access_level integer;
      BEGIN
        actor := auth.uid();
        IF actor IS NULL THEN
          RETURN false;
        END IF;

        tid := COALESCE(
          NULLIF(current_setting('app.tenant_id', true), '')::uuid,
          NULLIF(current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'tenant_id', '')::uuid,
          NULLIF(current_setting('request.jwt.claims', true)::jsonb -> 'user_metadata' ->> 'tenant_id', '')::uuid
        );

        IF tid IS NULL THEN
          RETURN false;
        END IF;

        IF p_user_id = actor THEN
          allow_other := true;
        ELSIF to_regclass('public.user_tenant_membership') IS NOT NULL THEN
          allow_other := EXISTS (
            SELECT 1
            FROM public.user_tenant_membership utm
            WHERE utm.user_id = actor
              AND utm.tenant_id = tid
              AND utm.is_active = true
              AND utm.access_level_number >= 5
          );
        END IF;

        IF NOT allow_other THEN
          RETURN false;
        END IF;

        BEGIN
          SELECT ual.access_level_number
          INTO v_access_level
          FROM public.user_access_level ual
          WHERE ual.user_id = p_user_id
            AND ual.tenant_id = tid
          LIMIT 1;
        EXCEPTION
          WHEN undefined_column THEN
            SELECT ual.access_level_number
            INTO v_access_level
            FROM public.user_access_level ual
            WHERE ual.user_id = p_user_id
            LIMIT 1;
        END;

        RETURN COALESCE(v_access_level, 0) >= 2;
      END
      $function$;
    $sql$;
  END IF;
END $$;

