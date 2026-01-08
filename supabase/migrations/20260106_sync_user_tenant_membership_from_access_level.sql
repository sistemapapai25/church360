DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_tenant_membership'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_access_level'
  ) THEN
    EXECUTE $sql$
      CREATE OR REPLACE FUNCTION public.sync_user_tenant_membership_from_access_level()
      RETURNS trigger
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path TO ''
      SET row_security TO off
      AS $f$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          IF OLD.tenant_id IS NULL THEN
            RETURN OLD;
          END IF;
          UPDATE public.user_tenant_membership utm
          SET is_active = false,
              updated_at = now()
          WHERE utm.tenant_id = OLD.tenant_id
            AND utm.user_id = OLD.user_id;
          RETURN OLD;
        END IF;

        IF NEW.tenant_id IS NULL THEN
          RETURN NEW;
        END IF;

        INSERT INTO public.user_tenant_membership (
          tenant_id,
          user_id,
          access_level,
          access_level_number,
          is_active
        ) VALUES (
          NEW.tenant_id,
          NEW.user_id,
          NEW.access_level,
          NEW.access_level_number,
          true
        )
        ON CONFLICT (tenant_id, user_id) DO UPDATE SET
          access_level = EXCLUDED.access_level,
          access_level_number = EXCLUDED.access_level_number,
          is_active = true,
          updated_at = now();

        RETURN NEW;
      END
      $f$;
    $sql$;

    EXECUTE $sql$
      INSERT INTO public.user_tenant_membership (tenant_id, user_id, access_level, access_level_number, is_active)
      SELECT ual.tenant_id, ual.user_id, ual.access_level, ual.access_level_number, true
      FROM public.user_access_level ual
      WHERE ual.tenant_id IS NOT NULL
      ON CONFLICT (tenant_id, user_id) DO UPDATE SET
        access_level = EXCLUDED.access_level,
        access_level_number = EXCLUDED.access_level_number,
        is_active = true,
        updated_at = now();
    $sql$;

    DROP TRIGGER IF EXISTS sync_user_tenant_membership_from_access_level_insupd ON public.user_access_level;
    CREATE TRIGGER sync_user_tenant_membership_from_access_level_insupd
      AFTER INSERT OR UPDATE ON public.user_access_level
      FOR EACH ROW
      EXECUTE FUNCTION public.sync_user_tenant_membership_from_access_level();

    DROP TRIGGER IF EXISTS sync_user_tenant_membership_from_access_level_del ON public.user_access_level;
    CREATE TRIGGER sync_user_tenant_membership_from_access_level_del
      BEFORE DELETE ON public.user_access_level
      FOR EACH ROW
      EXECUTE FUNCTION public.sync_user_tenant_membership_from_access_level();
  END IF;
END $$;

