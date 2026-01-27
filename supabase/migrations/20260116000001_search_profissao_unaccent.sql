DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS unaccent;
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
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
  has_idprofissao boolean;
  has_id boolean;
BEGIN
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

  IF has_idprofissao AND has_id THEN
    RETURN QUERY
      SELECT
        COALESCE(p.idprofissao::text, p.id::text) AS id,
        p.profissao::text AS label,
        false AS is_fallback
      FROM public.profissao p
      WHERE
        p_query IS NOT NULL
        AND length(trim(p_query)) >= 1
        AND unaccent(lower(p.profissao)) LIKE unaccent(lower('%' || trim(p_query) || '%'))
      ORDER BY
        CASE
          WHEN unaccent(lower(p.profissao)) LIKE unaccent(lower(trim(p_query) || '%')) THEN 0
          ELSE 1
        END,
        position(unaccent(lower(trim(p_query))) in unaccent(lower(p.profissao))),
        p.profissao
      LIMIT LEAST(GREATEST(p_limit, 1), 50);
  ELSIF has_idprofissao THEN
    RETURN QUERY
      SELECT
        p.idprofissao::text AS id,
        p.profissao::text AS label,
        false AS is_fallback
      FROM public.profissao p
      WHERE
        p_query IS NOT NULL
        AND length(trim(p_query)) >= 1
        AND unaccent(lower(p.profissao)) LIKE unaccent(lower('%' || trim(p_query) || '%'))
      ORDER BY
        CASE
          WHEN unaccent(lower(p.profissao)) LIKE unaccent(lower(trim(p_query) || '%')) THEN 0
          ELSE 1
        END,
        position(unaccent(lower(trim(p_query))) in unaccent(lower(p.profissao))),
        p.profissao
      LIMIT LEAST(GREATEST(p_limit, 1), 50);
  ELSIF has_id THEN
    RETURN QUERY
      SELECT
        p.id::text AS id,
        p.profissao::text AS label,
        false AS is_fallback
      FROM public.profissao p
      WHERE
        p_query IS NOT NULL
        AND length(trim(p_query)) >= 1
        AND unaccent(lower(p.profissao)) LIKE unaccent(lower('%' || trim(p_query) || '%'))
      ORDER BY
        CASE
          WHEN unaccent(lower(p.profissao)) LIKE unaccent(lower(trim(p_query) || '%')) THEN 0
          ELSE 1
        END,
        position(unaccent(lower(trim(p_query))) in unaccent(lower(p.profissao))),
        p.profissao
      LIMIT LEAST(GREATEST(p_limit, 1), 50);
  ELSE
    RETURN QUERY
      SELECT
        p.profissao::text AS id,
        p.profissao::text AS label,
        true AS is_fallback
      FROM public.profissao p
      WHERE
        p_query IS NOT NULL
        AND length(trim(p_query)) >= 1
        AND unaccent(lower(p.profissao)) LIKE unaccent(lower('%' || trim(p_query) || '%'))
      ORDER BY
        CASE
          WHEN unaccent(lower(p.profissao)) LIKE unaccent(lower(trim(p_query) || '%')) THEN 0
          ELSE 1
        END,
        position(unaccent(lower(trim(p_query))) in unaccent(lower(p.profissao))),
        p.profissao
      LIMIT LEAST(GREATEST(p_limit, 1), 50);
  END IF;
END;
$function$;
