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
          (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'tenant_id')::uuid,
          (current_setting('request.jwt.claims', true)::jsonb -> 'user_metadata' ->> 'tenant_id')::uuid
        )
      $f$;
    $sql$;

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
DECLARE
  constraint_name text;
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_access_level'
  ) THEN
    ALTER TABLE public.user_access_level
      ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenant(id) ON DELETE CASCADE;

    ALTER TABLE public.user_access_level
      ALTER COLUMN tenant_id SET DEFAULT public.jwt_tenant_id();

    UPDATE public.user_access_level ual
    SET tenant_id = COALESCE(
      ual.tenant_id,
      (SELECT ua.tenant_id FROM public.user_account ua WHERE ua.id = ual.user_id LIMIT 1),
      (SELECT id FROM public.tenant LIMIT 1)
    )
    WHERE ual.tenant_id IS NULL;

    IF NOT EXISTS (SELECT 1 FROM public.user_access_level WHERE tenant_id IS NULL) THEN
      ALTER TABLE public.user_access_level ALTER COLUMN tenant_id SET NOT NULL;
    END IF;

    FOR constraint_name IN
      SELECT conname
      FROM pg_constraint
      WHERE conrelid = 'public.user_access_level'::regclass
        AND contype = 'u'
        AND pg_get_constraintdef(oid) ILIKE '%(user_id)%'
        AND pg_get_constraintdef(oid) NOT ILIKE '%tenant_id%'
    LOOP
      EXECUTE format('ALTER TABLE public.user_access_level DROP CONSTRAINT %I', constraint_name);
    END LOOP;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conrelid = 'public.user_access_level'::regclass
        AND conname = 'user_access_level_tenant_user_unique'
    ) THEN
      ALTER TABLE public.user_access_level
        ADD CONSTRAINT user_access_level_tenant_user_unique UNIQUE (tenant_id, user_id);
    END IF;

    CREATE INDEX IF NOT EXISTS idx_user_access_level_tenant_user
      ON public.user_access_level(tenant_id, user_id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_access_level'
  ) THEN
    ALTER TABLE public.user_access_level ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS user_access_level_select ON public.user_access_level;
    DROP POLICY IF EXISTS user_access_level_insert_self_visitor ON public.user_access_level;

    CREATE POLICY user_access_level_select
    ON public.user_access_level
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid() OR tenant_id = public.current_tenant_id());

    CREATE POLICY user_access_level_insert_self_visitor
    ON public.user_access_level
    FOR INSERT
    TO authenticated
    WITH CHECK (
      user_id = auth.uid()
      AND tenant_id = public.jwt_tenant_id()
      AND access_level = 'visitor'
      AND access_level_number = 0
      AND EXISTS (
        SELECT 1 FROM public.tenant t
        WHERE t.id = tenant_id
          AND t.allow_self_signup = true
      )
    );
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
          RAISE EXCEPTION 'tenant_id ausente no token';
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
        END IF;
      END
      $f$;
    $sql$;
  END IF;
END $$;
