-- Ensure profissao is globally readable and unaccent calls resolve with search_path = ''.
DO $$
DECLARE
  v_has_tenant_id boolean;
  pol record;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'profissao'
  ) THEN
    RETURN;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profissao' AND column_name = 'tenant_id'
  ) INTO v_has_tenant_id;

  IF v_has_tenant_id THEN
    ALTER TABLE public.profissao ALTER COLUMN tenant_id DROP DEFAULT;
    ALTER TABLE public.profissao DROP COLUMN tenant_id;
  END IF;

  ALTER TABLE public.profissao ENABLE ROW LEVEL SECURITY;

  FOR pol IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'profissao'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.profissao', pol.policyname);
  END LOOP;

  CREATE POLICY profissao_select_all
  ON public.profissao
  FOR SELECT
  TO authenticated
  USING (true);
END $$;

DO $$
DECLARE
  v_unaccent_schema text;
  has_idprofissao boolean;
  has_id boolean;
BEGIN
  SELECT n.nspname
  INTO v_unaccent_schema
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE p.proname = 'unaccent'
    AND n.nspname IN ('public', 'extensions')
  LIMIT 1;

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profissao'
      AND column_name = 'idprofissao'
  ) INTO has_idprofissao;

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profissao'
      AND column_name = 'id'
  ) INTO has_id;

  IF has_idprofissao THEN
    EXECUTE 'CREATE OR REPLACE VIEW public.v_profissao AS
      SELECT
        p.idprofissao::text AS id,
        p.profissao::text AS label,
        false AS is_fallback
      FROM public.profissao p';
  ELSIF has_id THEN
    EXECUTE 'CREATE OR REPLACE VIEW public.v_profissao AS
      SELECT
        p.id::text AS id,
        p.profissao::text AS label,
        false AS is_fallback
      FROM public.profissao p';
  ELSE
    IF v_unaccent_schema = 'public' THEN
      EXECUTE 'CREATE OR REPLACE VIEW public.v_profissao AS
        SELECT
          md5(lower(public.unaccent(p.profissao)))::text AS id,
          p.profissao::text AS label,
          true AS is_fallback
        FROM public.profissao p';
    ELSIF v_unaccent_schema = 'extensions' THEN
      EXECUTE 'CREATE OR REPLACE VIEW public.v_profissao AS
        SELECT
          md5(lower(extensions.unaccent(p.profissao)))::text AS id,
          p.profissao::text AS label,
          true AS is_fallback
        FROM public.profissao p';
    ELSE
      EXECUTE 'CREATE OR REPLACE VIEW public.v_profissao AS
        SELECT
          md5(lower(p.profissao))::text AS id,
          p.profissao::text AS label,
          true AS is_fallback
        FROM public.profissao p';
    END IF;
  END IF;

  ALTER VIEW public.v_profissao SET (security_invoker = true);
END $$;

CREATE OR REPLACE FUNCTION public.search_profissao(
  p_query text,
  p_limit integer DEFAULT 20
)
RETURNS TABLE (
  id text,
  label text,
  is_fallback boolean
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE
  v_unaccent_schema text;
BEGIN
  SELECT n.nspname
  INTO v_unaccent_schema
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE p.proname = 'unaccent'
    AND n.nspname IN ('public', 'extensions')
  LIMIT 1;

  IF v_unaccent_schema = 'public' THEN
    RETURN QUERY
      SELECT
        v.id,
        v.label,
        v.is_fallback
      FROM public.v_profissao v
      WHERE
        p_query IS NOT NULL
        AND length(trim(p_query)) >= 1
        AND public.unaccent(lower(v.label)) LIKE public.unaccent(lower('%' || trim(p_query) || '%'))
      ORDER BY
        CASE
          WHEN public.unaccent(lower(v.label)) LIKE public.unaccent(lower(trim(p_query) || '%')) THEN 0
          ELSE 1
        END,
        position(public.unaccent(lower(trim(p_query))) in public.unaccent(lower(v.label))),
        v.label
      LIMIT LEAST(GREATEST(p_limit, 1), 50);
  ELSIF v_unaccent_schema = 'extensions' THEN
    RETURN QUERY
      SELECT
        v.id,
        v.label,
        v.is_fallback
      FROM public.v_profissao v
      WHERE
        p_query IS NOT NULL
        AND length(trim(p_query)) >= 1
        AND extensions.unaccent(lower(v.label)) LIKE extensions.unaccent(lower('%' || trim(p_query) || '%'))
      ORDER BY
        CASE
          WHEN extensions.unaccent(lower(v.label)) LIKE extensions.unaccent(lower(trim(p_query) || '%')) THEN 0
          ELSE 1
        END,
        position(extensions.unaccent(lower(trim(p_query))) in extensions.unaccent(lower(v.label))),
        v.label
      LIMIT LEAST(GREATEST(p_limit, 1), 50);
  ELSE
    RETURN QUERY
      SELECT
        v.id,
        v.label,
        v.is_fallback
      FROM public.v_profissao v
      WHERE
        p_query IS NOT NULL
        AND length(trim(p_query)) >= 1
        AND lower(v.label) LIKE lower('%' || trim(p_query) || '%')
      ORDER BY
        CASE
          WHEN lower(v.label) LIKE lower(trim(p_query) || '%') THEN 0
          ELSE 1
        END,
        position(lower(trim(p_query)) in lower(v.label)),
        v.label
      LIMIT LEAST(GREATEST(p_limit, 1), 50);
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_profession_label(
  p_profession_id text
)
RETURNS text
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path TO ''
AS $function$
  SELECT v.label
  FROM public.v_profissao v
  WHERE v.id = p_profession_id
  LIMIT 1;
$function$;

GRANT SELECT ON public.profissao TO authenticated;
GRANT SELECT ON public.v_profissao TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_profissao(text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_profession_label(text) TO authenticated;
