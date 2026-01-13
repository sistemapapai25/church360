DO $$
DECLARE
  v_has_utm boolean;
  v_has_ual boolean;
  v_ual_has_tenant boolean;
BEGIN
  IF to_regclass('public.study_participants') IS NULL THEN
    RETURN;
  END IF;

  EXECUTE $sql$
    CREATE OR REPLACE FUNCTION public.is_active_study_group_participant(
      _study_group_id uuid,
      _user_id uuid,
      _tenant_id uuid
    )
    RETURNS boolean
    LANGUAGE sql
    STABLE
    SECURITY DEFINER
    SET search_path TO ''
    SET row_security TO off
    AS $f$
      SELECT EXISTS (
        SELECT 1
        FROM public.study_participants sp
        WHERE sp.study_group_id = _study_group_id
          AND sp.user_id = _user_id
          AND sp.tenant_id = _tenant_id
          AND sp.is_active = true
      )
    $f$;
  $sql$;

  EXECUTE $sql$
    CREATE OR REPLACE FUNCTION public.is_active_study_group_leader(
      _study_group_id uuid,
      _user_id uuid,
      _tenant_id uuid
    )
    RETURNS boolean
    LANGUAGE sql
    STABLE
    SECURITY DEFINER
    SET search_path TO ''
    SET row_security TO off
    AS $f$
      SELECT EXISTS (
        SELECT 1
        FROM public.study_participants sp
        WHERE sp.study_group_id = _study_group_id
          AND sp.user_id = _user_id
          AND sp.tenant_id = _tenant_id
          AND sp.is_active = true
          AND sp.role IN ('leader', 'co_leader')
      )
    $f$;
  $sql$;

  ALTER TABLE public.study_participants ENABLE ROW LEVEL SECURITY;

  REVOKE ALL ON FUNCTION public.is_active_study_group_participant(uuid, uuid, uuid) FROM PUBLIC;
  GRANT EXECUTE ON FUNCTION public.is_active_study_group_participant(uuid, uuid, uuid) TO authenticated;

  REVOKE ALL ON FUNCTION public.is_active_study_group_leader(uuid, uuid, uuid) FROM PUBLIC;
  GRANT EXECUTE ON FUNCTION public.is_active_study_group_leader(uuid, uuid, uuid) TO authenticated;

  DROP POLICY IF EXISTS "Participantes podem ver membros do grupo" ON public.study_participants;

  DROP POLICY IF EXISTS study_participants_select_group_members ON public.study_participants;
  DROP POLICY IF EXISTS study_participants_insert_self_public ON public.study_participants;
  DROP POLICY IF EXISTS study_participants_insert_leader ON public.study_participants;
  DROP POLICY IF EXISTS study_participants_update_leader ON public.study_participants;
  DROP POLICY IF EXISTS study_participants_update_self ON public.study_participants;
  DROP POLICY IF EXISTS study_participants_delete_self ON public.study_participants;

  SELECT (to_regclass('public.user_tenant_membership') IS NOT NULL) INTO v_has_utm;
  SELECT (to_regclass('public.user_access_level') IS NOT NULL) INTO v_has_ual;
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'user_access_level'
      AND column_name = 'tenant_id'
  ) INTO v_ual_has_tenant;

  IF v_has_utm THEN
    EXECUTE $ddl$
      CREATE POLICY study_participants_select_group_members
      ON public.study_participants
      FOR SELECT
      TO authenticated
      USING (
        tenant_id = public.current_tenant_id()
        AND EXISTS (
          SELECT 1
          FROM public.user_tenant_membership utm
          WHERE utm.user_id = auth.uid()
            AND utm.tenant_id = tenant_id
            AND utm.is_active = true
        )
        AND public.is_active_study_group_participant(study_group_id, auth.uid(), tenant_id)
      );
    $ddl$;
  ELSIF v_has_ual AND v_ual_has_tenant THEN
    EXECUTE $ddl$
      CREATE POLICY study_participants_select_group_members
      ON public.study_participants
      FOR SELECT
      TO authenticated
      USING (
        tenant_id = public.current_tenant_id()
        AND EXISTS (
          SELECT 1
          FROM public.user_access_level ual
          WHERE ual.user_id = auth.uid()
            AND ual.tenant_id = tenant_id
        )
        AND public.is_active_study_group_participant(study_group_id, auth.uid(), tenant_id)
      );
    $ddl$;
  ELSE
    CREATE POLICY study_participants_select_group_members
    ON public.study_participants
    FOR SELECT
    TO authenticated
    USING (
      tenant_id = public.current_tenant_id()
      AND public.is_active_study_group_participant(study_group_id, auth.uid(), tenant_id)
    );
  END IF;

  CREATE POLICY study_participants_insert_self_public
  ON public.study_participants
  FOR INSERT
  TO authenticated
  WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND user_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.study_groups sg
      WHERE sg.id = study_group_id
        AND sg.tenant_id = tenant_id
        AND sg.is_public = true
    )
  );

  CREATE POLICY study_participants_insert_leader
  ON public.study_participants
  FOR INSERT
  TO authenticated
  WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND public.is_active_study_group_leader(study_group_id, auth.uid(), tenant_id)
  );

  CREATE POLICY study_participants_update_leader
  ON public.study_participants
  FOR UPDATE
  TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND public.is_active_study_group_leader(study_group_id, auth.uid(), tenant_id)
  )
  WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND public.is_active_study_group_leader(study_group_id, auth.uid(), tenant_id)
  );

  CREATE POLICY study_participants_update_self
  ON public.study_participants
  FOR UPDATE
  TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND user_id = auth.uid()
  )
  WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND user_id = auth.uid()
  );

  CREATE POLICY study_participants_delete_self
  ON public.study_participants
  FOR DELETE
  TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND user_id = auth.uid()
  );
END $$;
