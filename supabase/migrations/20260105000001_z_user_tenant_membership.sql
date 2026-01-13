DROP FUNCTION IF EXISTS public.ensure_my_account(uuid, text, text);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'tenant'
  ) THEN
    ALTER TABLE public.tenant
      ADD COLUMN IF NOT EXISTS allow_self_signup boolean NOT NULL DEFAULT false;

    IF (SELECT COUNT(*) FROM public.tenant) = 1 THEN
      UPDATE public.tenant SET allow_self_signup = true;
    END IF;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_account'
  ) THEN
    EXECUTE $sql$
      CREATE OR REPLACE FUNCTION public.jwt_tenant_id()
      RETURNS uuid
      LANGUAGE sql
      STABLE
      SECURITY DEFINER
      SET search_path TO ''
      SET row_security TO off
      AS $f$
        SELECT COALESCE(
          NULLIF(current_setting('app.tenant_id', true), '')::uuid,
          NULLIF((current_setting('request.headers', true)::jsonb ->> 'x-tenant-id')::text, '')::uuid,
          (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'tenant_id')::uuid,
          (current_setting('request.jwt.claims', true)::jsonb -> 'user_metadata' ->> 'tenant_id')::uuid
        )
      $f$;
    $sql$;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_account'
  ) THEN
    EXECUTE $sql$
      CREATE TABLE IF NOT EXISTS public.user_tenant_membership (
        tenant_id uuid NOT NULL REFERENCES public.tenant(id) ON DELETE CASCADE DEFAULT public.jwt_tenant_id(),
        user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
        access_level public.access_level_type NOT NULL DEFAULT 'visitor',
        access_level_number integer NOT NULL DEFAULT 0,
        is_active boolean NOT NULL DEFAULT true,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        PRIMARY KEY (tenant_id, user_id)
      );
    $sql$;

    CREATE INDEX IF NOT EXISTS idx_user_tenant_membership_user_id
      ON public.user_tenant_membership(user_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_tenant_membership'
  ) THEN
    DROP TRIGGER IF EXISTS handle_user_tenant_membership_updated_at ON public.user_tenant_membership;
    CREATE TRIGGER handle_user_tenant_membership_updated_at
      BEFORE UPDATE ON public.user_tenant_membership
      FOR EACH ROW
      EXECUTE FUNCTION public.handle_updated_at();
  END IF;
END $$;

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
        _full_name text DEFAULT NULL
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

        INSERT INTO public.user_account (id, email, full_name, tenant_id, is_active)
        VALUES (uid, safe_email, COALESCE(safe_full_name, uid::text), tid, true)
        ON CONFLICT (id) DO UPDATE SET
          email = COALESCE(EXCLUDED.email, public.user_account.email),
          full_name = COALESCE(NULLIF(public.user_account.full_name, ''), EXCLUDED.full_name, public.user_account.full_name),
          tenant_id = COALESCE(public.user_account.tenant_id, tid),
          is_active = true;

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

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_tenant_membership'
  ) THEN
    INSERT INTO public.user_tenant_membership (tenant_id, user_id, access_level, access_level_number, is_active)
    SELECT ual.tenant_id, ual.user_id, ual.access_level, ual.access_level_number, true
    FROM public.user_access_level ual
    WHERE ual.tenant_id IS NOT NULL
    ON CONFLICT (tenant_id, user_id) DO UPDATE SET
      access_level = EXCLUDED.access_level,
      access_level_number = EXCLUDED.access_level_number,
      is_active = true;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_account'
  ) THEN
    EXECUTE $sql$
      CREATE OR REPLACE FUNCTION public.current_tenant_id()
      RETURNS uuid
      LANGUAGE plpgsql
      STABLE
      SECURITY DEFINER
      SET search_path TO ''
      SET row_security TO off
      AS $f$
      DECLARE
        tid uuid;
      BEGIN
        tid := public.jwt_tenant_id();
        IF tid IS NULL THEN
          RETURN NULL;
        END IF;

        IF auth.uid() IS NULL THEN
          RETURN NULL;
        END IF;

        IF EXISTS (
          SELECT 1
          FROM public.user_tenant_membership utm
          WHERE utm.user_id = auth.uid()
            AND utm.tenant_id = tid
            AND utm.is_active = true
        ) THEN
          RETURN tid;
        END IF;

        IF EXISTS (
          SELECT 1
          FROM public.user_access_level ual
          WHERE ual.user_id = auth.uid()
            AND ual.tenant_id = tid
        ) THEN
          RETURN tid;
        END IF;

        RETURN NULL;
      END
      $f$;
    $sql$;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_tenant_membership'
  ) THEN
    ALTER TABLE public.user_tenant_membership ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS user_tenant_membership_select ON public.user_tenant_membership;
    DROP POLICY IF EXISTS user_tenant_membership_insert_self_visitor ON public.user_tenant_membership;
    DROP POLICY IF EXISTS user_tenant_membership_update_admin ON public.user_tenant_membership;
    DROP POLICY IF EXISTS user_tenant_membership_delete_admin ON public.user_tenant_membership;

    CREATE POLICY user_tenant_membership_select
    ON public.user_tenant_membership
    FOR SELECT
    TO authenticated
    USING (
      user_id = auth.uid()
      OR (
        tenant_id = public.current_tenant_id()
        AND EXISTS (
          SELECT 1
          FROM public.user_access_level ual
          WHERE ual.user_id = auth.uid()
            AND ual.tenant_id = public.current_tenant_id()
            AND ual.access_level_number >= 5
        )
      )
    );

    CREATE POLICY user_tenant_membership_insert_self_visitor
    ON public.user_tenant_membership
    FOR INSERT
    TO authenticated
    WITH CHECK (
      user_id = auth.uid()
      AND tenant_id = public.jwt_tenant_id()
      AND access_level = 'visitor'
      AND access_level_number = 0
      AND EXISTS (
        SELECT 1
        FROM public.tenant t
        WHERE t.id = tenant_id
          AND t.allow_self_signup = true
      )
    );

    CREATE POLICY user_tenant_membership_update_admin
    ON public.user_tenant_membership
    FOR UPDATE
    TO authenticated
    USING (
      tenant_id = public.current_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.user_access_level ual
        WHERE ual.user_id = auth.uid()
          AND ual.tenant_id = public.current_tenant_id()
          AND ual.access_level_number >= 5
      )
    )
    WITH CHECK (tenant_id = public.current_tenant_id());

    CREATE POLICY user_tenant_membership_delete_admin
    ON public.user_tenant_membership
    FOR DELETE
    TO authenticated
    USING (
      tenant_id = public.current_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.user_access_level ual
        WHERE ual.user_id = auth.uid()
          AND ual.tenant_id = public.current_tenant_id()
          AND ual.access_level_number >= 5
      )
    );
  END IF;
END $$;
