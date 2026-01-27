DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS unaccent;
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END $$;

DO $$
DECLARE
  has_idprofissao boolean;
  has_id boolean;
  has_unaccent boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE p.proname = 'unaccent'
      AND n.nspname IN ('public', 'extensions')
  ) INTO has_unaccent;

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
    IF has_unaccent THEN
      EXECUTE 'CREATE OR REPLACE VIEW public.v_profissao AS
        SELECT
          md5(lower(unaccent(p.profissao)))::text AS id,
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
  has_unaccent boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE p.proname = 'unaccent'
      AND n.nspname IN ('public', 'extensions')
  ) INTO has_unaccent;

  IF has_unaccent THEN
    RETURN QUERY
      SELECT
        v.id,
        v.label,
        v.is_fallback
      FROM public.v_profissao v
      WHERE
        p_query IS NOT NULL
        AND length(trim(p_query)) >= 1
        AND unaccent(lower(v.label)) LIKE unaccent(lower('%' || trim(p_query) || '%'))
      ORDER BY
        CASE
          WHEN unaccent(lower(v.label)) LIKE unaccent(lower(trim(p_query) || '%')) THEN 0
          ELSE 1
        END,
        position(unaccent(lower(trim(p_query))) in unaccent(lower(v.label))),
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
