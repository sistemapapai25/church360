DO $$
DECLARE
  v_has_auth_user_id boolean;
  v_has_ual boolean;
  v_has_utm boolean;
  v_ual_has_tenant boolean;
  v_utm_has_access_level boolean;
  v_utm_has_access_level_number boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'user_account'
      AND column_name = 'auth_user_id'
  ) INTO v_has_auth_user_id;

  IF NOT v_has_auth_user_id THEN
    RETURN;
  END IF;

  SELECT (to_regclass('public.user_access_level') IS NOT NULL) INTO v_has_ual;
  SELECT (to_regclass('public.user_tenant_membership') IS NOT NULL) INTO v_has_utm;

  IF v_has_ual THEN
    SELECT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'user_access_level'
        AND column_name = 'tenant_id'
    ) INTO v_ual_has_tenant;

    IF v_ual_has_tenant THEN
      EXECUTE $sql$
        WITH id_map AS (
          SELECT ua.id AS old_id, ua.auth_user_id AS new_id
          FROM public.user_account ua
          WHERE ua.auth_user_id IS NOT NULL
            AND ua.auth_user_id <> ua.id
        ),
        old_agg AS (
          SELECT
            ual.tenant_id,
            m.new_id AS user_id,
            MAX(COALESCE(ual.access_level_number, 0)) AS access_level_number
          FROM public.user_access_level ual
          JOIN id_map m ON m.old_id = ual.user_id
          GROUP BY ual.tenant_id, m.new_id
        )
        INSERT INTO public.user_access_level (tenant_id, user_id, access_level, access_level_number)
        SELECT
          oa.tenant_id,
          oa.user_id,
          (CASE oa.access_level_number
            WHEN 0 THEN 'visitor'
            WHEN 1 THEN 'attendee'
            WHEN 2 THEN 'member'
            WHEN 3 THEN 'leader'
            WHEN 4 THEN 'coordinator'
            ELSE 'admin'
          END)::public.access_level_type,
          oa.access_level_number
        FROM old_agg oa
        ON CONFLICT (tenant_id, user_id) DO UPDATE SET
          access_level_number = GREATEST(public.user_access_level.access_level_number, EXCLUDED.access_level_number),
          access_level = (CASE GREATEST(public.user_access_level.access_level_number, EXCLUDED.access_level_number)
            WHEN 0 THEN 'visitor'
            WHEN 1 THEN 'attendee'
            WHEN 2 THEN 'member'
            WHEN 3 THEN 'leader'
            WHEN 4 THEN 'coordinator'
            ELSE 'admin'
          END)::public.access_level_type;
      $sql$;
    ELSE
      EXECUTE $sql$
        WITH id_map AS (
          SELECT ua.id AS old_id, ua.auth_user_id AS new_id
          FROM public.user_account ua
          WHERE ua.auth_user_id IS NOT NULL
            AND ua.auth_user_id <> ua.id
        ),
        old_agg AS (
          SELECT
            m.new_id AS user_id,
            MAX(COALESCE(ual.access_level_number, 0)) AS access_level_number
          FROM public.user_access_level ual
          JOIN id_map m ON m.old_id = ual.user_id
          GROUP BY m.new_id
        )
        INSERT INTO public.user_access_level (user_id, access_level, access_level_number)
        SELECT
          oa.user_id,
          (CASE oa.access_level_number
            WHEN 0 THEN 'visitor'
            WHEN 1 THEN 'attendee'
            WHEN 2 THEN 'member'
            WHEN 3 THEN 'leader'
            WHEN 4 THEN 'coordinator'
            ELSE 'admin'
          END)::public.access_level_type,
          oa.access_level_number
        FROM old_agg oa
        ON CONFLICT (user_id) DO UPDATE SET
          access_level_number = GREATEST(public.user_access_level.access_level_number, EXCLUDED.access_level_number),
          access_level = (CASE GREATEST(public.user_access_level.access_level_number, EXCLUDED.access_level_number)
            WHEN 0 THEN 'visitor'
            WHEN 1 THEN 'attendee'
            WHEN 2 THEN 'member'
            WHEN 3 THEN 'leader'
            WHEN 4 THEN 'coordinator'
            ELSE 'admin'
          END)::public.access_level_type;
      $sql$;
    END IF;

    EXECUTE $sql$
      WITH id_map AS (
        SELECT ua.id AS old_id, ua.auth_user_id AS new_id
        FROM public.user_account ua
        WHERE ua.auth_user_id IS NOT NULL
          AND ua.auth_user_id <> ua.id
      )
      DELETE FROM public.user_access_level ual
      USING id_map m
      WHERE ual.user_id = m.old_id;
    $sql$;
  END IF;

  IF v_has_utm THEN
    SELECT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'user_tenant_membership'
        AND column_name = 'access_level'
    ) INTO v_utm_has_access_level;
    SELECT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'user_tenant_membership'
        AND column_name = 'access_level_number'
    ) INTO v_utm_has_access_level_number;

    IF v_utm_has_access_level AND v_utm_has_access_level_number THEN
      EXECUTE $sql$
        WITH id_map AS (
          SELECT ua.id AS old_id, ua.auth_user_id AS new_id
          FROM public.user_account ua
          WHERE ua.auth_user_id IS NOT NULL
            AND ua.auth_user_id <> ua.id
        ),
        old_agg AS (
          SELECT
            utm.tenant_id,
            m.new_id AS user_id,
            BOOL_OR(COALESCE(utm.is_active, false)) AS is_active,
            MAX(COALESCE(utm.access_level_number, 0)) AS access_level_number
          FROM public.user_tenant_membership utm
          JOIN id_map m ON m.old_id = utm.user_id
          GROUP BY utm.tenant_id, m.new_id
        )
        INSERT INTO public.user_tenant_membership (tenant_id, user_id, access_level, access_level_number, is_active)
        SELECT
          oa.tenant_id,
          oa.user_id,
          (CASE oa.access_level_number
            WHEN 0 THEN 'visitor'
            WHEN 1 THEN 'attendee'
            WHEN 2 THEN 'member'
            WHEN 3 THEN 'leader'
            WHEN 4 THEN 'coordinator'
            ELSE 'admin'
          END)::public.access_level_type,
          oa.access_level_number,
          oa.is_active
        FROM old_agg oa
        ON CONFLICT (tenant_id, user_id) DO UPDATE SET
          access_level_number = GREATEST(public.user_tenant_membership.access_level_number, EXCLUDED.access_level_number),
          access_level = (CASE GREATEST(public.user_tenant_membership.access_level_number, EXCLUDED.access_level_number)
            WHEN 0 THEN 'visitor'
            WHEN 1 THEN 'attendee'
            WHEN 2 THEN 'member'
            WHEN 3 THEN 'leader'
            WHEN 4 THEN 'coordinator'
            ELSE 'admin'
          END)::public.access_level_type,
          is_active = (public.user_tenant_membership.is_active OR EXCLUDED.is_active);
      $sql$;
    ELSIF v_utm_has_access_level_number THEN
      EXECUTE $sql$
        WITH id_map AS (
          SELECT ua.id AS old_id, ua.auth_user_id AS new_id
          FROM public.user_account ua
          WHERE ua.auth_user_id IS NOT NULL
            AND ua.auth_user_id <> ua.id
        ),
        old_agg AS (
          SELECT
            utm.tenant_id,
            m.new_id AS user_id,
            BOOL_OR(COALESCE(utm.is_active, false)) AS is_active,
            MAX(COALESCE(utm.access_level_number, 0)) AS access_level_number
          FROM public.user_tenant_membership utm
          JOIN id_map m ON m.old_id = utm.user_id
          GROUP BY utm.tenant_id, m.new_id
        )
        INSERT INTO public.user_tenant_membership (tenant_id, user_id, access_level_number, is_active)
        SELECT
          oa.tenant_id,
          oa.user_id,
          oa.access_level_number,
          oa.is_active
        FROM old_agg oa
        ON CONFLICT (tenant_id, user_id) DO UPDATE SET
          access_level_number = GREATEST(public.user_tenant_membership.access_level_number, EXCLUDED.access_level_number),
          is_active = (public.user_tenant_membership.is_active OR EXCLUDED.is_active);
      $sql$;
    ELSE
      EXECUTE $sql$
        WITH id_map AS (
          SELECT ua.id AS old_id, ua.auth_user_id AS new_id
          FROM public.user_account ua
          WHERE ua.auth_user_id IS NOT NULL
            AND ua.auth_user_id <> ua.id
        ),
        old_agg AS (
          SELECT
            utm.tenant_id,
            m.new_id AS user_id,
            BOOL_OR(COALESCE(utm.is_active, false)) AS is_active
          FROM public.user_tenant_membership utm
          JOIN id_map m ON m.old_id = utm.user_id
          GROUP BY utm.tenant_id, m.new_id
        )
        INSERT INTO public.user_tenant_membership (tenant_id, user_id, is_active)
        SELECT
          oa.tenant_id,
          oa.user_id,
          oa.is_active
        FROM old_agg oa
        ON CONFLICT (tenant_id, user_id) DO UPDATE SET
          is_active = (public.user_tenant_membership.is_active OR EXCLUDED.is_active);
      $sql$;
    END IF;

    EXECUTE $sql$
      WITH id_map AS (
        SELECT ua.id AS old_id, ua.auth_user_id AS new_id
        FROM public.user_account ua
        WHERE ua.auth_user_id IS NOT NULL
          AND ua.auth_user_id <> ua.id
      )
      DELETE FROM public.user_tenant_membership utm
      USING id_map m
      WHERE utm.user_id = m.old_id;
    $sql$;
  END IF;
END $$;
