DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'devotionals'
  ) THEN
    ALTER TABLE public.devotionals ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Todos podem ver devocionais publicados" ON public.devotionals;
    DROP POLICY IF EXISTS "Coordenadores podem ver todos os devocionais" ON public.devotionals;
    DROP POLICY IF EXISTS "Coordenadores podem criar devocionais" ON public.devotionals;
    DROP POLICY IF EXISTS "Coordenadores podem atualizar devocionais" ON public.devotionals;
    DROP POLICY IF EXISTS "Coordenadores podem deletar devocionais" ON public.devotionals;

    DROP POLICY IF EXISTS devotionals_select_published_in_tenant ON public.devotionals;
    DROP POLICY IF EXISTS devotionals_select_all_coordinator_in_tenant ON public.devotionals;
    DROP POLICY IF EXISTS devotionals_insert_coordinator_in_tenant ON public.devotionals;
    DROP POLICY IF EXISTS devotionals_update_coordinator_in_tenant ON public.devotionals;
    DROP POLICY IF EXISTS devotionals_delete_coordinator_in_tenant ON public.devotionals;

    CREATE POLICY devotionals_select_published_in_tenant
    ON public.devotionals
    FOR SELECT
    TO authenticated
    USING (
      tenant_id = public.current_tenant_id()
      AND is_published = true
    );

    CREATE POLICY devotionals_select_all_coordinator_in_tenant
    ON public.devotionals
    FOR SELECT
    TO authenticated
    USING (
      tenant_id = public.current_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.user_access_level ual
        WHERE ual.user_id = auth.uid()
          AND ual.tenant_id = public.current_tenant_id()
          AND ual.access_level_number >= 4
      )
    );

    CREATE POLICY devotionals_insert_coordinator_in_tenant
    ON public.devotionals
    FOR INSERT
    TO authenticated
    WITH CHECK (
      tenant_id = public.current_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.user_access_level ual
        WHERE ual.user_id = auth.uid()
          AND ual.tenant_id = public.current_tenant_id()
          AND ual.access_level_number >= 4
      )
    );

    CREATE POLICY devotionals_update_coordinator_in_tenant
    ON public.devotionals
    FOR UPDATE
    TO authenticated
    USING (
      tenant_id = public.current_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.user_access_level ual
        WHERE ual.user_id = auth.uid()
          AND ual.tenant_id = public.current_tenant_id()
          AND ual.access_level_number >= 4
      )
    )
    WITH CHECK (tenant_id = public.current_tenant_id());

    CREATE POLICY devotionals_delete_coordinator_in_tenant
    ON public.devotionals
    FOR DELETE
    TO authenticated
    USING (
      tenant_id = public.current_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.user_access_level ual
        WHERE ual.user_id = auth.uid()
          AND ual.tenant_id = public.current_tenant_id()
          AND ual.access_level_number >= 4
      )
    );
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'devotional_readings'
  ) THEN
    ALTER TABLE public.devotional_readings ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Usuários podem ver suas leituras" ON public.devotional_readings;
    DROP POLICY IF EXISTS "Coordenadores podem ver todas as leituras" ON public.devotional_readings;
    DROP POLICY IF EXISTS "Usuários podem criar leituras" ON public.devotional_readings;
    DROP POLICY IF EXISTS "Usuários podem atualizar suas leituras" ON public.devotional_readings;
    DROP POLICY IF EXISTS "Usuários podem deletar suas leituras" ON public.devotional_readings;

    DROP POLICY IF EXISTS devotional_readings_select_own_in_tenant ON public.devotional_readings;
    DROP POLICY IF EXISTS devotional_readings_select_all_coordinator_in_tenant ON public.devotional_readings;
    DROP POLICY IF EXISTS devotional_readings_insert_own_in_tenant ON public.devotional_readings;
    DROP POLICY IF EXISTS devotional_readings_update_own_in_tenant ON public.devotional_readings;
    DROP POLICY IF EXISTS devotional_readings_delete_own_in_tenant ON public.devotional_readings;

    CREATE POLICY devotional_readings_select_own_in_tenant
    ON public.devotional_readings
    FOR SELECT
    TO authenticated
    USING (
      tenant_id = public.current_tenant_id()
      AND user_id = auth.uid()
    );

    CREATE POLICY devotional_readings_select_all_coordinator_in_tenant
    ON public.devotional_readings
    FOR SELECT
    TO authenticated
    USING (
      tenant_id = public.current_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.user_access_level ual
        WHERE ual.user_id = auth.uid()
          AND ual.tenant_id = public.current_tenant_id()
          AND ual.access_level_number >= 4
      )
    );

    CREATE POLICY devotional_readings_insert_own_in_tenant
    ON public.devotional_readings
    FOR INSERT
    TO authenticated
    WITH CHECK (
      tenant_id = public.current_tenant_id()
      AND user_id = auth.uid()
    );

    CREATE POLICY devotional_readings_update_own_in_tenant
    ON public.devotional_readings
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

    CREATE POLICY devotional_readings_delete_own_in_tenant
    ON public.devotional_readings
    FOR DELETE
    TO authenticated
    USING (
      tenant_id = public.current_tenant_id()
      AND user_id = auth.uid()
    );
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'devotionals'
  ) THEN
    IF EXISTS (
      SELECT 1
      FROM information_schema.table_constraints tc
      WHERE tc.table_schema = 'public'
        AND tc.table_name = 'devotionals'
        AND tc.constraint_name = 'devotionals_date_unique'
    ) THEN
      ALTER TABLE public.devotionals DROP CONSTRAINT devotionals_date_unique;
    END IF;

    DROP INDEX IF EXISTS public.idx_devotionals_date_unique;
    DROP INDEX IF EXISTS public.idx_devotionals_tenant_date_unique;
    CREATE UNIQUE INDEX idx_devotionals_tenant_date_unique
      ON public.devotionals(tenant_id, devotional_date);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'devotionals'
  ) THEN
    EXECUTE $sql$
      CREATE OR REPLACE FUNCTION public.get_today_devotional()
      RETURNS TABLE (
        id UUID,
        title TEXT,
        content TEXT,
        scripture_reference TEXT,
        devotional_date DATE,
        author_id UUID,
        is_published BOOLEAN,
        created_at TIMESTAMPTZ,
        updated_at TIMESTAMPTZ
      )
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path TO ''
      SET row_security TO on
      AS $function$
      BEGIN
        RETURN QUERY
        SELECT
          d.id,
          d.title,
          d.content,
          d.scripture_reference,
          d.devotional_date,
          d.author_id,
          d.is_published,
          d.created_at,
          d.updated_at
        FROM public.devotionals d
        WHERE d.tenant_id = public.current_tenant_id()
          AND d.devotional_date = CURRENT_DATE
          AND d.is_published = true
        LIMIT 1;
      END;
      $function$;
    $sql$;

    EXECUTE $sql$
      CREATE OR REPLACE FUNCTION public.get_devotional_stats(devotional_uuid UUID)
      RETURNS TABLE (
        total_reads BIGINT,
        unique_readers BIGINT
      )
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path TO ''
      SET row_security TO on
      AS $function$
      BEGIN
        RETURN QUERY
        SELECT
          COUNT(*)::BIGINT as total_reads,
          COUNT(DISTINCT dr.user_id)::BIGINT as unique_readers
        FROM public.devotional_readings dr
        JOIN public.devotionals d ON d.id = dr.devotional_id
        WHERE dr.devotional_id = devotional_uuid
          AND dr.tenant_id = public.current_tenant_id()
          AND d.tenant_id = public.current_tenant_id();
      END;
      $function$;
    $sql$;

    EXECUTE $sql$
      CREATE OR REPLACE FUNCTION public.get_user_reading_streak(user_uuid UUID)
      RETURNS INTEGER
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path TO ''
      SET row_security TO on
      AS $function$
      DECLARE
        streak INTEGER := 0;
        current_date_check DATE := CURRENT_DATE;
        has_reading BOOLEAN;
        is_coordinator BOOLEAN := false;
      BEGIN
        IF auth.uid() IS NULL THEN
          RAISE EXCEPTION 'not authenticated';
        END IF;

        SELECT EXISTS (
          SELECT 1
          FROM public.user_access_level ual
          WHERE ual.user_id = auth.uid()
            AND ual.tenant_id = public.current_tenant_id()
            AND ual.access_level_number >= 4
        ) INTO is_coordinator;

        IF user_uuid <> auth.uid() AND NOT is_coordinator THEN
          RAISE EXCEPTION 'forbidden';
        END IF;

        LOOP
          SELECT EXISTS (
            SELECT 1
            FROM public.devotional_readings dr
            JOIN public.devotionals d ON dr.devotional_id = d.id
            WHERE dr.user_id = user_uuid
              AND dr.tenant_id = public.current_tenant_id()
              AND d.tenant_id = public.current_tenant_id()
              AND d.devotional_date = current_date_check
          ) INTO has_reading;

          IF NOT has_reading THEN
            EXIT;
          END IF;

          streak := streak + 1;
          current_date_check := current_date_check - INTERVAL '1 day';
        END LOOP;

        RETURN streak;
      END;
      $function$;
    $sql$;
  END IF;
END $$;

