DO $$
DECLARE
  fn record;
BEGIN
  FOR fn IN
    SELECT p.oid::regprocedure AS signature
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'is_admin'
  LOOP
    EXECUTE format(
      'ALTER FUNCTION %s SET search_path TO public, auth',
      fn.signature
    );
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.log_access_level_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_has_tenant_id boolean;
  v_tenant_id uuid;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'access_level_history'
      AND column_name = 'tenant_id'
  ) INTO v_has_tenant_id;

  BEGIN
    v_tenant_id := NULLIF(to_jsonb(NEW)->>'tenant_id', '')::uuid;
  EXCEPTION
    WHEN OTHERS THEN
      v_tenant_id := NULL;
  END;

  IF v_tenant_id IS NULL THEN
    BEGIN
      v_tenant_id := public.current_tenant_id();
    EXCEPTION
      WHEN undefined_function THEN
        v_tenant_id := NULL;
      WHEN OTHERS THEN
        v_tenant_id := NULL;
    END;
  END IF;

  IF (TG_OP = 'UPDATE' AND OLD.access_level != NEW.access_level) THEN
    IF v_has_tenant_id THEN
      INSERT INTO public.access_level_history (
        tenant_id,
        user_id,
        from_level,
        from_level_number,
        to_level,
        to_level_number,
        reason,
        promoted_by
      ) VALUES (
        v_tenant_id,
        NEW.user_id,
        OLD.access_level,
        OLD.access_level_number,
        NEW.access_level,
        NEW.access_level_number,
        NEW.promotion_reason,
        NEW.promoted_by
      );
    ELSE
      INSERT INTO public.access_level_history (
        user_id,
        from_level,
        from_level_number,
        to_level,
        to_level_number,
        reason,
        promoted_by
      ) VALUES (
        NEW.user_id,
        OLD.access_level,
        OLD.access_level_number,
        NEW.access_level,
        NEW.access_level_number,
        NEW.promotion_reason,
        NEW.promoted_by
      );
    END IF;
  ELSIF (TG_OP = 'INSERT') THEN
    IF v_has_tenant_id THEN
      INSERT INTO public.access_level_history (
        tenant_id,
        user_id,
        from_level,
        from_level_number,
        to_level,
        to_level_number,
        reason,
        promoted_by
      ) VALUES (
        v_tenant_id,
        NEW.user_id,
        NULL,
        NULL,
        NEW.access_level,
        NEW.access_level_number,
        'Criação inicial',
        NEW.promoted_by
      );
    ELSE
      INSERT INTO public.access_level_history (
        user_id,
        from_level,
        from_level_number,
        to_level,
        to_level_number,
        reason,
        promoted_by
      ) VALUES (
        NEW.user_id,
        NULL,
        NULL,
        NEW.access_level,
        NEW.access_level_number,
        'Criação inicial',
        NEW.promoted_by
      );
    END IF;
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Erro ao registrar histórico de nível de acesso para usuário %: %', NEW.user_id, SQLERRM;
    RETURN NEW;
END;
$function$;

