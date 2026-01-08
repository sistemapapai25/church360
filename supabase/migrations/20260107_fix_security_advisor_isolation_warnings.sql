CREATE OR REPLACE FUNCTION public.has_role(user_id uuid, role_name text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.user_roles ur
    JOIN public.roles r ON r.id = ur.role_id
    WHERE ur.user_id = has_role.user_id
      AND r.name = has_role.role_name
      AND ur.is_active = true
      AND (ur.expires_at IS NULL OR ur.expires_at > now())
  );
END;
$function$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'app_role'
  ) THEN
    EXECUTE $ddl$
      CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role public.app_role)
      RETURNS boolean
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path TO ''
      AS $function$
      BEGIN
        RETURN public.has_role(_user_id, _role::text);
      END;
      $function$;
    $ddl$;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.is_admin_or_pastor(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_tenant_id uuid;
BEGIN
  BEGIN
    SELECT public.current_tenant_id() INTO v_tenant_id;
  EXCEPTION
    WHEN undefined_function THEN
      v_tenant_id := NULL;
  END;

  IF to_regclass('public.user_tenant_membership') IS NOT NULL THEN
    RETURN EXISTS (
      SELECT 1
      FROM public.user_tenant_membership utm
      WHERE utm.user_id = p_user_id
        AND utm.is_active = true
        AND utm.access_level_number >= 4
        AND (v_tenant_id IS NULL OR utm.tenant_id = v_tenant_id)
    );
  END IF;

  IF to_regclass('public.user_access_level') IS NOT NULL THEN
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'user_access_level'
        AND column_name = 'tenant_id'
    ) AND v_tenant_id IS NOT NULL THEN
      RETURN EXISTS (
        SELECT 1
        FROM public.user_access_level ual
        WHERE ual.user_id = p_user_id
          AND ual.tenant_id = v_tenant_id
          AND ual.access_level_number >= 4
      );
    END IF;

    RETURN EXISTS (
      SELECT 1
      FROM public.user_access_level ual
      WHERE ual.user_id = p_user_id
        AND ual.access_level_number >= 4
    );
  END IF;

  RETURN false;
END;
$function$;

ALTER TABLE public.church_info ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Church info is viewable by everyone" ON public.church_info;
DROP POLICY IF EXISTS "Church info is insertable by authenticated users" ON public.church_info;
DROP POLICY IF EXISTS "Church info is updatable by authenticated users" ON public.church_info;
DROP POLICY IF EXISTS tenant_select_church_info ON public.church_info;
DROP POLICY IF EXISTS tenant_modify_church_info ON public.church_info;
DROP POLICY IF EXISTS church_info_select_members ON public.church_info;
DROP POLICY IF EXISTS church_info_insert_admin ON public.church_info;
DROP POLICY IF EXISTS church_info_update_admin ON public.church_info;
DROP POLICY IF EXISTS church_info_delete_admin ON public.church_info;

CREATE POLICY church_info_select_members
ON public.church_info
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.user_tenant_membership utm
    WHERE utm.user_id = auth.uid()
      AND utm.tenant_id = public.church_info.tenant_id
      AND utm.is_active = true
  )
);

CREATE POLICY church_info_insert_admin
ON public.church_info
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.user_tenant_membership utm
    WHERE utm.user_id = auth.uid()
      AND utm.tenant_id = public.church_info.tenant_id
      AND utm.is_active = true
      AND utm.access_level_number >= 5
  )
);

CREATE POLICY church_info_update_admin
ON public.church_info
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.user_tenant_membership utm
    WHERE utm.user_id = auth.uid()
      AND utm.tenant_id = public.church_info.tenant_id
      AND utm.is_active = true
      AND utm.access_level_number >= 5
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.user_tenant_membership utm
    WHERE utm.user_id = auth.uid()
      AND utm.tenant_id = public.church_info.tenant_id
      AND utm.is_active = true
      AND utm.access_level_number >= 5
  )
);

CREATE POLICY church_info_delete_admin
ON public.church_info
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.user_tenant_membership utm
    WHERE utm.user_id = auth.uid()
      AND utm.tenant_id = public.church_info.tenant_id
      AND utm.is_active = true
      AND utm.access_level_number >= 5
  )
);

ALTER TABLE public.access_level_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view all access level history" ON public.access_level_history;
DROP POLICY IF EXISTS access_level_history_select ON public.access_level_history;

CREATE POLICY access_level_history_select
ON public.access_level_history
FOR SELECT
TO authenticated
USING (
  public.access_level_history.user_id = auth.uid()
  OR EXISTS (
    SELECT 1
    FROM public.user_tenant_membership utm
    WHERE utm.user_id = auth.uid()
      AND utm.tenant_id = public.access_level_history.tenant_id
      AND utm.is_active = true
      AND utm.access_level_number >= 5
  )
);

DO $$
DECLARE
  p record;
BEGIN
  FOR p IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('contribution', 'contribution_info')
      AND cmd IN ('INSERT', 'UPDATE', 'DELETE')
      AND (
        COALESCE(qual, '') ~* '^\s*true\s*$'
        OR COALESCE(with_check, '') ~* '^\s*true\s*$'
      )
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', p.policyname, p.schemaname, p.tablename);
  END LOOP;
END $$;

DO $$
DECLARE
  v_has_tenant_id boolean;
BEGIN
  IF to_regclass('public.contribution') IS NOT NULL THEN
    ALTER TABLE public.contribution ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Usuários autenticados podem inserir contribuições" ON public.contribution;
    DROP POLICY IF EXISTS "Usuários autenticados podem atualizar contribuições" ON public.contribution;
    DROP POLICY IF EXISTS "Usuários autenticados podem deletar contribuições" ON public.contribution;
    DROP POLICY IF EXISTS "Usuários autenticados podem ver contribuições" ON public.contribution;

    DROP POLICY IF EXISTS contribution_select_manage ON public.contribution;
    DROP POLICY IF EXISTS contribution_insert_manage ON public.contribution;
    DROP POLICY IF EXISTS contribution_update_manage ON public.contribution;
    DROP POLICY IF EXISTS contribution_delete_manage ON public.contribution;

    SELECT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'contribution'
        AND column_name = 'tenant_id'
    ) INTO v_has_tenant_id;

    IF v_has_tenant_id THEN
      CREATE POLICY contribution_select_manage
      ON public.contribution
      FOR SELECT
      TO authenticated
      USING (
        public.contribution.tenant_id = public.current_tenant_id()
        AND public.is_admin_or_pastor(auth.uid())
      );

      CREATE POLICY contribution_insert_manage
      ON public.contribution
      FOR INSERT
      TO authenticated
      WITH CHECK (
        public.contribution.tenant_id = public.current_tenant_id()
        AND public.is_admin_or_pastor(auth.uid())
      );

      CREATE POLICY contribution_update_manage
      ON public.contribution
      FOR UPDATE
      TO authenticated
      USING (
        public.contribution.tenant_id = public.current_tenant_id()
        AND public.is_admin_or_pastor(auth.uid())
      )
      WITH CHECK (
        public.contribution.tenant_id = public.current_tenant_id()
        AND public.is_admin_or_pastor(auth.uid())
      );

      CREATE POLICY contribution_delete_manage
      ON public.contribution
      FOR DELETE
      TO authenticated
      USING (
        public.contribution.tenant_id = public.current_tenant_id()
        AND public.is_admin_or_pastor(auth.uid())
      );
    ELSE
      CREATE POLICY contribution_select_manage
      ON public.contribution
      FOR SELECT
      TO authenticated
      USING (public.is_admin_or_pastor(auth.uid()));

      CREATE POLICY contribution_insert_manage
      ON public.contribution
      FOR INSERT
      TO authenticated
      WITH CHECK (public.is_admin_or_pastor(auth.uid()));

      CREATE POLICY contribution_update_manage
      ON public.contribution
      FOR UPDATE
      TO authenticated
      USING (public.is_admin_or_pastor(auth.uid()))
      WITH CHECK (public.is_admin_or_pastor(auth.uid()));

      CREATE POLICY contribution_delete_manage
      ON public.contribution
      FOR DELETE
      TO authenticated
      USING (public.is_admin_or_pastor(auth.uid()));
    END IF;
  END IF;
END $$;

DO $$
DECLARE
  v_has_tenant_id boolean;
BEGIN
  IF to_regclass('public.contribution_info') IS NOT NULL THEN
    ALTER TABLE public.contribution_info ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Permitir atualização para usuários autenticados" ON public.contribution_info;

    DROP POLICY IF EXISTS tenant_select_contribution_info ON public.contribution_info;
    DROP POLICY IF EXISTS tenant_modify_contribution_info ON public.contribution_info;

    DROP POLICY IF EXISTS contribution_info_select ON public.contribution_info;
    DROP POLICY IF EXISTS contribution_info_manage ON public.contribution_info;

    SELECT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'contribution_info'
        AND column_name = 'tenant_id'
    ) INTO v_has_tenant_id;

    IF v_has_tenant_id THEN
      CREATE POLICY contribution_info_select
      ON public.contribution_info
      FOR SELECT
      TO authenticated
      USING (
        public.contribution_info.tenant_id = public.current_tenant_id()
        AND EXISTS (
          SELECT 1
          FROM public.user_tenant_membership utm
          WHERE utm.user_id = auth.uid()
            AND utm.tenant_id = public.contribution_info.tenant_id
            AND utm.is_active = true
        )
      );

      CREATE POLICY contribution_info_manage
      ON public.contribution_info
      FOR ALL
      TO authenticated
      USING (
        public.contribution_info.tenant_id = public.current_tenant_id()
        AND public.is_admin_or_pastor(auth.uid())
      )
      WITH CHECK (
        public.contribution_info.tenant_id = public.current_tenant_id()
        AND public.is_admin_or_pastor(auth.uid())
      );
    ELSE
      CREATE POLICY contribution_info_select
      ON public.contribution_info
      FOR SELECT
      TO authenticated
      USING (true);

      CREATE POLICY contribution_info_manage
      ON public.contribution_info
      FOR ALL
      TO authenticated
      USING (public.is_admin_or_pastor(auth.uid()))
      WITH CHECK (public.is_admin_or_pastor(auth.uid()));
    END IF;
  END IF;
END $$;
