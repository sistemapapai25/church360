-- =====================================================
-- TABELAS: BÍBLIA SAGRADA
-- =====================================================

-- =====================================================
-- TABELA: LIVROS DA BÍBLIA
-- =====================================================

CREATE TABLE IF NOT EXISTS public.bible_book (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  abbrev TEXT NOT NULL,
  testament TEXT NOT NULL, -- 'OT' (Old Testament) ou 'NT' (New Testament)
  order_number INTEGER NOT NULL,
  chapters INTEGER NOT NULL
);

-- Habilitar RLS
ALTER TABLE public.bible_book ENABLE ROW LEVEL SECURITY;

-- Criar políticas (todos podem ler)
DROP POLICY IF EXISTS "Todos podem visualizar livros da Bíblia" ON public.bible_book;
CREATE POLICY "Todos podem visualizar livros da Bíblia"
  ON public.bible_book
  FOR SELECT
  USING (true);

-- Criar índices
CREATE INDEX IF NOT EXISTS idx_bible_book_testament ON public.bible_book(testament);
CREATE INDEX IF NOT EXISTS idx_bible_book_order ON public.bible_book(order_number);

-- =====================================================
-- TABELA: VERSÍCULOS DA BÍBLIA
-- =====================================================

CREATE TABLE IF NOT EXISTS public.bible_verse (
  id SERIAL PRIMARY KEY,
  book_id INTEGER NOT NULL REFERENCES public.bible_book(id) ON DELETE CASCADE,
  chapter INTEGER NOT NULL,
  verse INTEGER NOT NULL,
  text TEXT NOT NULL,
  UNIQUE(book_id, chapter, verse)
);

-- Habilitar RLS
ALTER TABLE public.bible_verse ENABLE ROW LEVEL SECURITY;

-- Criar políticas (todos podem ler)
DROP POLICY IF EXISTS "Todos podem visualizar versículos da Bíblia" ON public.bible_verse;
CREATE POLICY "Todos podem visualizar versículos da Bíblia"
  ON public.bible_verse
  FOR SELECT
  USING (true);

-- Criar índices
CREATE INDEX IF NOT EXISTS idx_bible_verse_book ON public.bible_verse(book_id);
CREATE INDEX IF NOT EXISTS idx_bible_verse_chapter ON public.bible_verse(book_id, chapter);
CREATE INDEX IF NOT EXISTS idx_bible_verse_text ON public.bible_verse USING gin(to_tsvector('portuguese', text));

-- =====================================================
-- TABELA: FAVORITOS/MARCADORES
-- =====================================================

CREATE TABLE IF NOT EXISTS public.bible_bookmark (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES public.tenant(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  verse_id INTEGER NOT NULL REFERENCES public.bible_verse(id) ON DELETE CASCADE,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

DO $$
DECLARE
  constraint_name text;
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'bible_bookmark' AND column_name = 'member_id'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'bible_bookmark' AND column_name = 'user_id'
  ) THEN
    EXECUTE 'ALTER TABLE public.bible_bookmark RENAME COLUMN member_id TO user_id';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'bible_bookmark' AND column_name = 'tenant_id'
  ) THEN
    EXECUTE 'ALTER TABLE public.bible_bookmark ADD COLUMN tenant_id uuid';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'tenant'
  ) AND EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'current_tenant_id'
  ) THEN
    EXECUTE 'ALTER TABLE public.bible_bookmark ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id()';
    EXECUTE 'UPDATE public.bible_bookmark SET tenant_id = COALESCE(tenant_id, public.current_tenant_id(), (SELECT id FROM public.tenant LIMIT 1)) WHERE tenant_id IS NULL';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_account'
  ) THEN
    FOR constraint_name IN
      SELECT c.conname
      FROM pg_constraint c
      JOIN pg_class t ON t.oid = c.conrelid
      JOIN pg_namespace ns ON ns.oid = t.relnamespace
      WHERE ns.nspname = 'public'
        AND t.relname = 'bible_bookmark'
        AND c.contype = 'f'
        AND pg_get_constraintdef(c.oid) ILIKE '%(user_id)%'
    LOOP
      EXECUTE format('ALTER TABLE public.bible_bookmark DROP CONSTRAINT %I', constraint_name);
    END LOOP;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint c
      JOIN pg_class t ON t.oid = c.conrelid
      JOIN pg_namespace ns ON ns.oid = t.relnamespace
      WHERE ns.nspname = 'public'
        AND t.relname = 'bible_bookmark'
        AND c.contype = 'f'
        AND pg_get_constraintdef(c.oid) ILIKE '%REFERENCES public.user_account%'
    ) THEN
      EXECUTE 'ALTER TABLE public.bible_bookmark ADD CONSTRAINT bible_bookmark_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_account(id) ON DELETE CASCADE';
    END IF;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'tenant'
  ) THEN
    FOR constraint_name IN
      SELECT c.conname
      FROM pg_constraint c
      JOIN pg_class t ON t.oid = c.conrelid
      JOIN pg_namespace ns ON ns.oid = t.relnamespace
      WHERE ns.nspname = 'public'
        AND t.relname = 'bible_bookmark'
        AND c.contype = 'f'
        AND pg_get_constraintdef(c.oid) ILIKE '%(tenant_id)%'
    LOOP
      EXECUTE format('ALTER TABLE public.bible_bookmark DROP CONSTRAINT %I', constraint_name);
    END LOOP;

    EXECUTE 'ALTER TABLE public.bible_bookmark ADD CONSTRAINT bible_bookmark_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenant(id) ON DELETE CASCADE';
  END IF;

  FOR constraint_name IN
    SELECT c.conname
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace ns ON ns.oid = t.relnamespace
    WHERE ns.nspname = 'public'
      AND t.relname = 'bible_bookmark'
      AND c.contype = 'u'
      AND (
        pg_get_constraintdef(c.oid) ILIKE '%(user_id, verse_id)%'
        OR pg_get_constraintdef(c.oid) ILIKE '%(member_id, verse_id)%'
      )
  LOOP
    EXECUTE format('ALTER TABLE public.bible_bookmark DROP CONSTRAINT %I', constraint_name);
  END LOOP;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_bible_bookmark_unique
  ON public.bible_bookmark(tenant_id, user_id, verse_id);

-- Habilitar RLS
ALTER TABLE public.bible_bookmark ENABLE ROW LEVEL SECURITY;

-- Criar políticas
DROP POLICY IF EXISTS "Usuários podem ver seus próprios favoritos" ON public.bible_bookmark;
CREATE POLICY "Usuários podem ver seus próprios favoritos"
  ON public.bible_bookmark
  FOR SELECT
  TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND user_id = auth.uid()
  );

DROP POLICY IF EXISTS "Usuários podem criar seus próprios favoritos" ON public.bible_bookmark;
CREATE POLICY "Usuários podem criar seus próprios favoritos"
  ON public.bible_bookmark
  FOR INSERT
  TO authenticated
  WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND user_id = auth.uid()
  );

DROP POLICY IF EXISTS "Usuários podem atualizar seus próprios favoritos" ON public.bible_bookmark;
CREATE POLICY "Usuários podem atualizar seus próprios favoritos"
  ON public.bible_bookmark
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

DROP POLICY IF EXISTS "Usuários podem deletar seus próprios favoritos" ON public.bible_bookmark;
CREATE POLICY "Usuários podem deletar seus próprios favoritos"
  ON public.bible_bookmark
  FOR DELETE
  TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND user_id = auth.uid()
  );

-- Criar índices
CREATE INDEX IF NOT EXISTS idx_bible_bookmark_tenant ON public.bible_bookmark(tenant_id);
CREATE INDEX IF NOT EXISTS idx_bible_bookmark_user ON public.bible_bookmark(user_id);
CREATE INDEX IF NOT EXISTS idx_bible_bookmark_verse ON public.bible_bookmark(verse_id);

-- =====================================================
-- TABELA: DICIONÁRIO (STRONG / PT AUTORAL)
-- =====================================================

CREATE TABLE IF NOT EXISTS public.bible_lexeme (
  id BIGSERIAL PRIMARY KEY,
  strong_code TEXT NOT NULL UNIQUE,
  language TEXT NOT NULL CHECK (language IN ('hebrew', 'greek')),
  lemma TEXT,
  transliteration TEXT,
  pt_gloss TEXT,
  pt_definition TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.bible_lexeme ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Todos podem visualizar léxicos" ON public.bible_lexeme;
CREATE POLICY "Todos podem visualizar léxicos"
  ON public.bible_lexeme
  FOR SELECT
  USING (true);

DO $$
DECLARE
  tid uuid;
BEGIN
  IF to_regclass('public.permissions') IS NOT NULL THEN
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'permissions'
        AND column_name = 'tenant_id'
    ) THEN
      BEGIN
        tid := public.current_tenant_id();
      EXCEPTION
        WHEN undefined_function THEN
          tid := NULL;
      END;

      tid := COALESCE(
        NULLIF(current_setting('app.tenant_id', true), '')::uuid,
        NULLIF(current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'tenant_id', '')::uuid,
        NULLIF(current_setting('request.jwt.claims', true)::jsonb -> 'user_metadata' ->> 'tenant_id', '')::uuid,
        tid,
        (SELECT id FROM public.tenant LIMIT 1)
      );

      IF tid IS NOT NULL THEN
        INSERT INTO public.permissions (tenant_id, code, name, description, category, subcategory, requires_context, is_active)
        VALUES (
          tid,
          'bible.manage_lexicon',
          'Gerenciar Léxico (Strong)',
          'Editar gloss e definição PT do Strong',
          'bible',
          'manage',
          false,
          true
        )
        ON CONFLICT DO NOTHING;
      END IF;
    ELSE
      INSERT INTO public.permissions (code, name, description, category, subcategory, requires_context, is_active)
      VALUES (
        'bible.manage_lexicon',
        'Gerenciar Léxico (Strong)',
        'Editar gloss e definição PT do Strong',
        'bible',
        'manage',
        false,
        true
      )
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;
END $$;

DROP POLICY IF EXISTS "Gerenciar léxicos requer permissão" ON public.bible_lexeme;
DO $$
BEGIN
  IF to_regprocedure('public.check_user_permission(uuid,text)') IS NOT NULL THEN
    EXECUTE $sql$
      CREATE POLICY "Gerenciar léxicos requer permissão"
        ON public.bible_lexeme
        FOR ALL
        TO authenticated
        USING (public.check_user_permission(auth.uid(), 'bible.manage_lexicon'))
        WITH CHECK (public.check_user_permission(auth.uid(), 'bible.manage_lexicon'))
    $sql$;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_bible_lexeme_strong_code ON public.bible_lexeme(strong_code);

CREATE TABLE IF NOT EXISTS public.bible_lexeme_base_import (
  strong_code TEXT NOT NULL,
  language TEXT NOT NULL CHECK (language IN ('hebrew', 'greek')),
  lemma TEXT,
  transliteration TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bible_lexeme_base_import_strong_code
  ON public.bible_lexeme_base_import(strong_code);

ALTER TABLE public.bible_lexeme_base_import ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Gerenciar import de léxico requer permissão" ON public.bible_lexeme_base_import;
DO $$
BEGIN
  IF to_regprocedure('public.check_user_permission(uuid,text)') IS NOT NULL THEN
    EXECUTE $sql$
      CREATE POLICY "Gerenciar import de léxico requer permissão"
        ON public.bible_lexeme_base_import
        FOR ALL
        TO authenticated
        USING (public.check_user_permission(auth.uid(), 'bible.manage_lexicon'))
        WITH CHECK (public.check_user_permission(auth.uid(), 'bible.manage_lexicon'))
    $sql$;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.merge_bible_lexeme_base_import(
  p_truncate_after boolean DEFAULT true
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
SET row_security TO off
AS $function$
DECLARE
  v_merged bigint := 0;
BEGIN
  IF to_regclass('public.bible_lexeme_base_import') IS NULL THEN
    RETURN 0;
  END IF;

  IF to_regclass('public.bible_lexeme') IS NULL THEN
    RETURN 0;
  END IF;

  WITH src AS (
    SELECT
      upper(trim(strong_code)) AS strong_code,
      lower(trim(language)) AS language,
      NULLIF(trim(lemma), '') AS lemma,
      NULLIF(trim(transliteration), '') AS transliteration
    FROM public.bible_lexeme_base_import
    WHERE NULLIF(trim(strong_code), '') IS NOT NULL
      AND NULLIF(trim(language), '') IS NOT NULL
  ),
  dedup AS (
    SELECT DISTINCT ON (strong_code)
      strong_code,
      language,
      lemma,
      transliteration
    FROM src
    ORDER BY strong_code, (lemma IS NOT NULL) DESC, (transliteration IS NOT NULL) DESC
  ),
  upserted AS (
    INSERT INTO public.bible_lexeme (
      strong_code,
      language,
      lemma,
      transliteration,
      updated_at
    )
    SELECT
      d.strong_code,
      d.language,
      d.lemma,
      d.transliteration,
      now()
    FROM dedup d
    ON CONFLICT (strong_code) DO UPDATE SET
      language = EXCLUDED.language,
      lemma = COALESCE(NULLIF(EXCLUDED.lemma, ''), public.bible_lexeme.lemma),
      transliteration = COALESCE(NULLIF(EXCLUDED.transliteration, ''), public.bible_lexeme.transliteration),
      updated_at = now()
    RETURNING 1
  )
  SELECT count(*) INTO v_merged FROM upserted;

  IF p_truncate_after THEN
    TRUNCATE TABLE public.bible_lexeme_base_import;
  END IF;

  RETURN v_merged;
END
$function$;

CREATE OR REPLACE FUNCTION public.search_normalized_lexemes(
  p_prefix text,
  p_num_part int,
  p_suffix text DEFAULT NULL,
  p_limit int DEFAULT 50
)
RETURNS SETOF public.bible_lexeme
LANGUAGE plpgsql
STABLE
SET search_path TO ''
AS $function$
DECLARE
  v_prefix text;
  v_digits text;
  v_suffix text;
  v_pattern text;
  v_limit int;
BEGIN
  v_prefix := upper(trim(coalesce(p_prefix, '')));
  v_digits := coalesce(p_num_part::text, '');
  v_suffix := upper(trim(coalesce(p_suffix, '')));
  v_limit := greatest(coalesce(p_limit, 50), 1);

  IF v_prefix NOT IN ('H', 'G') THEN
    RETURN;
  END IF;

  IF v_digits !~ '^[0-9]{1,5}$' THEN
    RETURN;
  END IF;

  IF v_suffix <> '' AND v_suffix !~ '^[A-Z]{1,8}$' THEN
    RETURN;
  END IF;

  IF v_suffix <> '' THEN
    v_pattern := '^' || v_prefix || '0*' || v_digits || v_suffix || '$';
  ELSE
    v_pattern := '^' || v_prefix || '0*' || v_digits || '[A-Z]*$';
  END IF;

  RETURN QUERY
  WITH ranked AS (
    SELECT
      l.*,
      regexp_replace(upper(l.strong_code), '^([HG])0*([0-9]{1,5})([A-Z]*)$', '\3') AS norm_suffix,
      (upper(l.strong_code) ~ '^[HG]0') AS has_zero_padding
    FROM public.bible_lexeme l
    WHERE upper(l.strong_code) ~ v_pattern
  ),
  dedup AS (
    SELECT DISTINCT ON (norm_suffix)
      ranked.*
    FROM ranked
    ORDER BY
      norm_suffix ASC,
      (ranked.pt_gloss IS NULL) ASC,
      (ranked.pt_definition IS NULL) ASC,
      (ranked.lemma IS NULL) ASC,
      (ranked.transliteration IS NULL) ASC,
      ranked.has_zero_padding ASC,
      length(ranked.strong_code) ASC,
      ranked.strong_code ASC
  )
  SELECT
    d.id,
    d.strong_code,
    d.language,
    d.lemma,
    d.transliteration,
    d.pt_gloss,
    d.pt_definition,
    d.created_at,
    d.updated_at
  FROM dedup d
  ORDER BY
    (d.norm_suffix = '') DESC,
    d.norm_suffix ASC,
    d.strong_code ASC
  LIMIT v_limit;
END
$function$;

-- =====================================================
-- TABELA: TOKENS POR VERSÍCULO (MAPEAMENTO -> STRONG)
-- =====================================================

CREATE TABLE IF NOT EXISTS public.bible_verse_token (
  id BIGSERIAL PRIMARY KEY,
  verse_id INTEGER NOT NULL REFERENCES public.bible_verse(id) ON DELETE CASCADE,
  token_index INTEGER NOT NULL,
  start_offset INTEGER NOT NULL,
  end_offset INTEGER NOT NULL,
  surface TEXT NOT NULL,
  normalized TEXT,
  lexeme_id BIGINT REFERENCES public.bible_lexeme(id) ON DELETE SET NULL,
  confidence REAL,
  source TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(verse_id, token_index),
  CHECK (start_offset >= 0),
  CHECK (end_offset > start_offset)
);

ALTER TABLE public.bible_verse_token ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Todos podem visualizar tokens de versículos" ON public.bible_verse_token;
CREATE POLICY "Todos podem visualizar tokens de versículos"
  ON public.bible_verse_token
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Gerenciar tokens requer permissão" ON public.bible_verse_token;
DO $$
BEGIN
  IF to_regprocedure('public.check_user_permission(uuid,text)') IS NOT NULL THEN
    EXECUTE $sql$
      CREATE POLICY "Gerenciar tokens requer permissão"
        ON public.bible_verse_token
        FOR ALL
        TO authenticated
        USING (public.check_user_permission(auth.uid(), 'bible.manage_lexicon'))
        WITH CHECK (public.check_user_permission(auth.uid(), 'bible.manage_lexicon'))
    $sql$;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_bible_verse_token_verse_id ON public.bible_verse_token(verse_id);
CREATE INDEX IF NOT EXISTS idx_bible_verse_token_lexeme_id ON public.bible_verse_token(lexeme_id);
CREATE INDEX IF NOT EXISTS idx_bible_verse_token_offsets ON public.bible_verse_token(verse_id, start_offset, end_offset);

CREATE TABLE IF NOT EXISTS public.bible_verse_token_base_import (
  verse_id INTEGER NOT NULL REFERENCES public.bible_verse(id) ON DELETE CASCADE,
  token_index INTEGER NOT NULL,
  start_offset INTEGER NOT NULL,
  end_offset INTEGER NOT NULL,
  surface TEXT NOT NULL,
  normalized TEXT,
  strong_code TEXT,
  confidence REAL,
  source TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(verse_id, token_index),
  CHECK (start_offset >= 0),
  CHECK (end_offset > start_offset)
);

ALTER TABLE public.bible_verse_token_base_import ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Gerenciar import de tokens requer permissão" ON public.bible_verse_token_base_import;
DO $$
BEGIN
  IF to_regprocedure('public.check_user_permission(uuid,text)') IS NOT NULL THEN
    EXECUTE $sql$
      CREATE POLICY "Gerenciar import de tokens requer permissão"
        ON public.bible_verse_token_base_import
        FOR ALL
        TO authenticated
        USING (public.check_user_permission(auth.uid(), 'bible.manage_lexicon'))
        WITH CHECK (public.check_user_permission(auth.uid(), 'bible.manage_lexicon'))
    $sql$;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_bible_verse_token_base_import_verse_id
  ON public.bible_verse_token_base_import(verse_id);

CREATE INDEX IF NOT EXISTS idx_bible_verse_token_base_import_strong_code
  ON public.bible_verse_token_base_import(strong_code);

CREATE OR REPLACE FUNCTION public.merge_bible_verse_token_base_import(
  p_truncate_after boolean DEFAULT true,
  p_strict_surface boolean DEFAULT true
)
RETURNS bigint
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
  v_merged bigint := 0;
  v_invalid bigint := 0;
BEGIN
  IF to_regclass('public.bible_verse_token_base_import') IS NULL THEN
    RETURN 0;
  END IF;

  IF to_regclass('public.bible_verse_token') IS NULL THEN
    RETURN 0;
  END IF;

  IF to_regclass('public.bible_verse') IS NULL THEN
    RETURN 0;
  END IF;

  IF to_regclass('public.bible_lexeme') IS NULL THEN
    RETURN 0;
  END IF;

  WITH src AS (
    SELECT
      verse_id,
      token_index,
      start_offset,
      end_offset,
      NULLIF(trim(surface), '') AS surface,
      NULLIF(trim(normalized), '') AS normalized,
      NULLIF(upper(trim(strong_code)), '') AS strong_code,
      confidence,
      NULLIF(trim(source), '') AS source
    FROM public.bible_verse_token_base_import
    WHERE NULLIF(trim(surface), '') IS NOT NULL
  ),
  checked AS (
    SELECT
      s.*,
      v.text AS verse_text,
      substring(v.text from s.start_offset + 1 for (s.end_offset - s.start_offset)) AS extracted
    FROM src s
    JOIN public.bible_verse v ON v.id = s.verse_id
    WHERE s.start_offset >= 0
      AND s.end_offset > s.start_offset
      AND s.end_offset <= char_length(v.text)
  )
  SELECT count(*) INTO v_invalid
  FROM checked
  WHERE p_strict_surface
    AND extracted <> surface;

  IF p_strict_surface AND v_invalid > 0 THEN
    RAISE EXCEPTION 'bible_verse_token_base_import: % linhas com surface divergente', v_invalid;
  END IF;

  WITH src AS (
    SELECT
      verse_id,
      token_index,
      start_offset,
      end_offset,
      NULLIF(trim(surface), '') AS surface,
      NULLIF(trim(normalized), '') AS normalized,
      NULLIF(upper(trim(strong_code)), '') AS strong_code,
      confidence,
      NULLIF(trim(source), '') AS source
    FROM public.bible_verse_token_base_import
    WHERE NULLIF(trim(surface), '') IS NOT NULL
  ),
  checked AS (
    SELECT
      s.*,
      v.text AS verse_text,
      substring(v.text from s.start_offset + 1 for (s.end_offset - s.start_offset)) AS extracted
    FROM src s
    JOIN public.bible_verse v ON v.id = s.verse_id
    WHERE s.start_offset >= 0
      AND s.end_offset > s.start_offset
      AND s.end_offset <= char_length(v.text)
      AND (NOT p_strict_surface OR substring(v.text from s.start_offset + 1 for (s.end_offset - s.start_offset)) = s.surface)
  ),
  missing_lexemes AS (
    SELECT DISTINCT
      c.strong_code AS strong_code,
      CASE
        WHEN c.strong_code LIKE 'H%' THEN 'hebrew'
        WHEN c.strong_code LIKE 'G%' THEN 'greek'
        ELSE NULL
      END AS language
    FROM checked c
    WHERE c.strong_code IS NOT NULL
  ),
  inserted_lexemes AS (
    INSERT INTO public.bible_lexeme (strong_code, language, updated_at)
    SELECT
      m.strong_code,
      m.language,
      now()
    FROM missing_lexemes m
    WHERE m.language IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM public.bible_lexeme l WHERE l.strong_code = m.strong_code
      )
    ON CONFLICT (strong_code) DO NOTHING
    RETURNING 1
  ),
  upserted AS (
    INSERT INTO public.bible_verse_token (
      verse_id,
      token_index,
      start_offset,
      end_offset,
      surface,
      normalized,
      lexeme_id,
      confidence,
      source
    )
    SELECT
      c.verse_id,
      c.token_index,
      c.start_offset,
      c.end_offset,
      c.surface,
      COALESCE(c.normalized, lower(c.surface)),
      l.id,
      c.confidence,
      c.source
    FROM checked c
    LEFT JOIN public.bible_lexeme l
      ON l.strong_code = c.strong_code
    ON CONFLICT (verse_id, token_index) DO UPDATE SET
      start_offset = EXCLUDED.start_offset,
      end_offset = EXCLUDED.end_offset,
      surface = EXCLUDED.surface,
      normalized = EXCLUDED.normalized,
      lexeme_id = EXCLUDED.lexeme_id,
      confidence = EXCLUDED.confidence,
      source = EXCLUDED.source
    RETURNING 1
  )
  SELECT count(*) INTO v_merged FROM upserted;

  IF p_truncate_after THEN
    TRUNCATE TABLE public.bible_verse_token_base_import;
  END IF;

  RETURN v_merged;
END
$function$;

CREATE OR REPLACE FUNCTION public.validate_bible_tokens_for_book(
  p_book_id int
)
RETURNS TABLE (
  total_verses bigint,
  verses_with_tokens bigint,
  tokens_total bigint,
  tokens_out_of_bounds bigint,
  tokens_overlap_or_backwards bigint
)
LANGUAGE sql
SET search_path TO ''
AS $function$
WITH verses AS (
  SELECT id, text
  FROM public.bible_verse
  WHERE book_id = p_book_id
),
tokens AS (
  SELECT
    t.verse_id,
    t.token_index,
    t.start_offset,
    t.end_offset,
    v.text
  FROM public.bible_verse_token t
  JOIN verses v ON v.id = t.verse_id
),
ordered AS (
  SELECT
    verse_id,
    token_index,
    start_offset,
    end_offset,
    text,
    lag(end_offset) OVER (PARTITION BY verse_id ORDER BY start_offset, end_offset, token_index) AS prev_end
  FROM tokens
)
SELECT
  (SELECT count(*) FROM verses) AS total_verses,
  (SELECT count(DISTINCT verse_id) FROM tokens) AS verses_with_tokens,
  (SELECT count(*) FROM tokens) AS tokens_total,
  (SELECT count(*) FROM tokens WHERE start_offset < 0 OR end_offset <= start_offset OR end_offset > char_length(text)) AS tokens_out_of_bounds,
  (SELECT count(*) FROM ordered WHERE prev_end IS NOT NULL AND start_offset < prev_end) AS tokens_overlap_or_backwards
$function$;

CREATE OR REPLACE FUNCTION public.upsert_bible_verse_tokens_from_surfaces(
  p_verse_id int,
  p_tokens jsonb,
  p_source text DEFAULT NULL,
  p_default_confidence real DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
  v_merged bigint := 0;
  v_text text;
  v_item jsonb;
  v_surface text;
  v_token_index int;
  v_token_index_text text;
  v_strong_code text;
  v_normalized text;
  v_confidence real;
  v_confidence_text text;
  v_source text;
  v_pos int;
  v_start int;
  v_end int;
  v_language text;
  v_lexeme_id bigint;
  v_cursor int := 0;
  v_loop_index int := 0;
  v_ok boolean := true;
  v_computed jsonb := '[]'::jsonb;
  v_surface_cursors jsonb := '{}'::jsonb;
  v_search_cursor int := 0;
  v_fail_surface text;
  v_fail_token_index int;
  v_fail_cursor int := 0;
BEGIN
  IF p_verse_id IS NULL THEN
    RETURN 0;
  END IF;

  IF p_tokens IS NULL OR jsonb_typeof(p_tokens) <> 'array' THEN
    RETURN 0;
  END IF;

  SELECT text INTO v_text
  FROM public.bible_verse
  WHERE id = p_verse_id;

  IF v_text IS NULL THEN
    RETURN 0;
  END IF;

  v_ok := true;
  v_cursor := 0;
  v_loop_index := 0;
  v_computed := '[]'::jsonb;
  v_fail_surface := NULL;
  v_fail_token_index := NULL;
  v_fail_cursor := 0;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_tokens) LOOP
    v_surface := NULLIF(trim(v_item->>'surface'), '');
    IF v_surface IS NULL THEN
      CONTINUE;
    END IF;

    v_token_index_text := v_item->>'token_index';
    v_token_index := NULL;
    IF v_token_index_text IS NOT NULL THEN
      BEGIN
        v_token_index := v_token_index_text::int;
      EXCEPTION
        WHEN invalid_text_representation THEN
          v_token_index := NULL;
      END;
    END IF;
    IF v_token_index IS NULL THEN
      v_token_index := v_loop_index;
    END IF;
    v_loop_index := v_loop_index + 1;

    v_strong_code := NULLIF(upper(trim(v_item->>'strong_code')), '');
    v_normalized := COALESCE(NULLIF(trim(v_item->>'normalized'), ''), lower(v_surface));

    v_confidence := NULL;
    v_confidence_text := v_item->>'confidence';
    IF v_confidence_text IS NOT NULL THEN
      BEGIN
        v_confidence := v_confidence_text::real;
      EXCEPTION
        WHEN invalid_text_representation THEN
          v_confidence := NULL;
      END;
    END IF;
    v_confidence := COALESCE(v_confidence, p_default_confidence);

    v_source := COALESCE(NULLIF(trim(v_item->>'source'), ''), p_source);

    v_search_cursor := v_cursor;
    v_pos := strpos(substring(v_text from v_search_cursor + 1), v_surface);
    IF v_pos = 0 THEN
      v_ok := false;
      v_fail_surface := v_surface;
      v_fail_token_index := v_token_index;
      v_fail_cursor := v_search_cursor;
      EXIT;
    END IF;

    v_start := v_search_cursor + v_pos - 1;
    v_end := v_start + char_length(v_surface);

    v_computed := v_computed || jsonb_build_array(
      jsonb_build_object(
        'token_index', v_token_index,
        'surface', v_surface,
        'normalized', v_normalized,
        'strong_code', v_strong_code,
        'confidence', v_confidence,
        'source', v_source,
        'start_offset', v_start,
        'end_offset', v_end
      )
    );

    v_cursor := v_end;
  END LOOP;

  IF NOT v_ok THEN
    v_ok := true;
    v_cursor := 0;
    v_loop_index := 0;
    v_computed := '[]'::jsonb;
    v_surface_cursors := '{}'::jsonb;

    FOR v_item IN SELECT value FROM jsonb_array_elements(p_tokens) LOOP
      v_surface := NULLIF(trim(v_item->>'surface'), '');
      IF v_surface IS NULL THEN
        CONTINUE;
      END IF;

      v_token_index_text := v_item->>'token_index';
      v_token_index := NULL;
      IF v_token_index_text IS NOT NULL THEN
        BEGIN
          v_token_index := v_token_index_text::int;
        EXCEPTION
          WHEN invalid_text_representation THEN
            v_token_index := NULL;
        END;
      END IF;
      IF v_token_index IS NULL THEN
        v_token_index := v_loop_index;
      END IF;
      v_loop_index := v_loop_index + 1;

      v_strong_code := NULLIF(upper(trim(v_item->>'strong_code')), '');
      v_normalized := COALESCE(NULLIF(trim(v_item->>'normalized'), ''), lower(v_surface));

      v_confidence := NULL;
      v_confidence_text := v_item->>'confidence';
      IF v_confidence_text IS NOT NULL THEN
        BEGIN
          v_confidence := v_confidence_text::real;
        EXCEPTION
          WHEN invalid_text_representation THEN
            v_confidence := NULL;
        END;
      END IF;
      v_confidence := COALESCE(v_confidence, p_default_confidence);

      v_source := COALESCE(NULLIF(trim(v_item->>'source'), ''), p_source);

      v_search_cursor := COALESCE(NULLIF((v_surface_cursors->>v_surface), '')::int, 0);
      v_pos := strpos(substring(v_text from v_search_cursor + 1), v_surface);
      IF v_pos = 0 THEN
        v_ok := false;
        v_fail_surface := v_surface;
        v_fail_token_index := v_token_index;
        v_fail_cursor := v_search_cursor;
        EXIT;
      END IF;

      v_start := v_search_cursor + v_pos - 1;
      v_end := v_start + char_length(v_surface);

      v_computed := v_computed || jsonb_build_array(
        jsonb_build_object(
          'token_index', v_token_index,
          'surface', v_surface,
          'normalized', v_normalized,
          'strong_code', v_strong_code,
          'confidence', v_confidence,
          'source', v_source,
          'start_offset', v_start,
          'end_offset', v_end
        )
      );

      v_surface_cursors := jsonb_set(v_surface_cursors, ARRAY[v_surface], to_jsonb(v_end), true);
    END LOOP;
  END IF;

  IF NOT v_ok THEN
    RAISE EXCEPTION 'Token não encontrado: verse_id %, token_index %, surface "%", cursor %', p_verse_id, v_fail_token_index, v_fail_surface, v_fail_cursor;
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(v_computed) LOOP
    v_surface := v_item->>'surface';
    v_token_index := (v_item->>'token_index')::int;
    v_start := (v_item->>'start_offset')::int;
    v_end := (v_item->>'end_offset')::int;
    v_normalized := v_item->>'normalized';
    v_strong_code := NULLIF(v_item->>'strong_code', '');
    v_source := NULLIF(v_item->>'source', '');
    v_confidence_text := v_item->>'confidence';
    v_confidence := NULL;
    IF v_confidence_text IS NOT NULL AND v_confidence_text <> 'null' THEN
      BEGIN
        v_confidence := v_confidence_text::real;
      EXCEPTION
        WHEN invalid_text_representation THEN
          v_confidence := NULL;
      END;
    END IF;

    v_lexeme_id := NULL;
    IF v_strong_code IS NOT NULL THEN
      v_language := CASE
        WHEN v_strong_code LIKE 'H%' THEN 'hebrew'
        WHEN v_strong_code LIKE 'G%' THEN 'greek'
        ELSE NULL
      END;

      IF v_language IS NOT NULL THEN
        INSERT INTO public.bible_lexeme (strong_code, language, updated_at)
        VALUES (v_strong_code, v_language, now())
        ON CONFLICT (strong_code) DO UPDATE SET
          language = EXCLUDED.language,
          updated_at = now();

        SELECT id INTO v_lexeme_id
        FROM public.bible_lexeme
        WHERE strong_code = v_strong_code;
      END IF;
    END IF;

    INSERT INTO public.bible_verse_token (
      verse_id,
      token_index,
      start_offset,
      end_offset,
      surface,
      normalized,
      lexeme_id,
      confidence,
      source
    )
    VALUES (
      p_verse_id,
      v_token_index,
      v_start,
      v_end,
      v_surface,
      v_normalized,
      v_lexeme_id,
      v_confidence,
      v_source
    )
    ON CONFLICT (verse_id, token_index) DO UPDATE SET
      start_offset = EXCLUDED.start_offset,
      end_offset = EXCLUDED.end_offset,
      surface = EXCLUDED.surface,
      normalized = EXCLUDED.normalized,
      lexeme_id = EXCLUDED.lexeme_id,
      confidence = EXCLUDED.confidence,
      source = EXCLUDED.source;

    v_merged := v_merged + 1;
  END LOOP;

  RETURN v_merged;
END
$function$;

-- =====================================================
-- DADOS: LIVROS DA BÍBLIA (66 livros)
-- =====================================================

INSERT INTO public.bible_book (id, name, abbrev, testament, order_number, chapters) VALUES
-- ANTIGO TESTAMENTO
(1, 'Gênesis', 'Gn', 'OT', 1, 50),
(2, 'Êxodo', 'Êx', 'OT', 2, 40),
(3, 'Levítico', 'Lv', 'OT', 3, 27),
(4, 'Números', 'Nm', 'OT', 4, 36),
(5, 'Deuteronômio', 'Dt', 'OT', 5, 34),
(6, 'Josué', 'Js', 'OT', 6, 24),
(7, 'Juízes', 'Jz', 'OT', 7, 21),
(8, 'Rute', 'Rt', 'OT', 8, 4),
(9, '1 Samuel', '1Sm', 'OT', 9, 31),
(10, '2 Samuel', '2Sm', 'OT', 10, 24),
(11, '1 Reis', '1Rs', 'OT', 11, 22),
(12, '2 Reis', '2Rs', 'OT', 12, 25),
(13, '1 Crônicas', '1Cr', 'OT', 13, 29),
(14, '2 Crônicas', '2Cr', 'OT', 14, 36),
(15, 'Esdras', 'Ed', 'OT', 15, 10),
(16, 'Neemias', 'Ne', 'OT', 16, 13),
(17, 'Ester', 'Et', 'OT', 17, 10),
(18, 'Jó', 'Jó', 'OT', 18, 42),
(19, 'Salmos', 'Sl', 'OT', 19, 150),
(20, 'Provérbios', 'Pv', 'OT', 20, 31),
(21, 'Eclesiastes', 'Ec', 'OT', 21, 12),
(22, 'Cânticos', 'Ct', 'OT', 22, 8),
(23, 'Isaías', 'Is', 'OT', 23, 66),
(24, 'Jeremias', 'Jr', 'OT', 24, 52),
(25, 'Lamentações', 'Lm', 'OT', 25, 5),
(26, 'Ezequiel', 'Ez', 'OT', 26, 48),
(27, 'Daniel', 'Dn', 'OT', 27, 12),
(28, 'Oséias', 'Os', 'OT', 28, 14),
(29, 'Joel', 'Jl', 'OT', 29, 3),
(30, 'Amós', 'Am', 'OT', 30, 9),
(31, 'Obadias', 'Ob', 'OT', 31, 1),
(32, 'Jonas', 'Jn', 'OT', 32, 4),
(33, 'Miquéias', 'Mq', 'OT', 33, 7),
(34, 'Naum', 'Na', 'OT', 34, 3),
(35, 'Habacuque', 'Hc', 'OT', 35, 3),
(36, 'Sofonias', 'Sf', 'OT', 36, 3),
(37, 'Ageu', 'Ag', 'OT', 37, 2),
(38, 'Zacarias', 'Zc', 'OT', 38, 14),
(39, 'Malaquias', 'Ml', 'OT', 39, 4),

-- NOVO TESTAMENTO
(40, 'Mateus', 'Mt', 'NT', 40, 28),
(41, 'Marcos', 'Mc', 'NT', 41, 16),
(42, 'Lucas', 'Lc', 'NT', 42, 24),
(43, 'João', 'Jo', 'NT', 43, 21),
(44, 'Atos', 'At', 'NT', 44, 28),
(45, 'Romanos', 'Rm', 'NT', 45, 16),
(46, '1 Coríntios', '1Co', 'NT', 46, 16),
(47, '2 Coríntios', '2Co', 'NT', 47, 13),
(48, 'Gálatas', 'Gl', 'NT', 48, 6),
(49, 'Efésios', 'Ef', 'NT', 49, 6),
(50, 'Filipenses', 'Fp', 'NT', 50, 4),
(51, 'Colossenses', 'Cl', 'NT', 51, 4),
(52, '1 Tessalonicenses', '1Ts', 'NT', 52, 5),
(53, '2 Tessalonicenses', '2Ts', 'NT', 53, 3),
(54, '1 Timóteo', '1Tm', 'NT', 54, 6),
(55, '2 Timóteo', '2Tm', 'NT', 55, 4),
(56, 'Tito', 'Tt', 'NT', 56, 3),
(57, 'Filemom', 'Fm', 'NT', 57, 1),
(58, 'Hebreus', 'Hb', 'NT', 58, 13),
(59, 'Tiago', 'Tg', 'NT', 59, 5),
(60, '1 Pedro', '1Pe', 'NT', 60, 5),
(61, '2 Pedro', '2Pe', 'NT', 61, 3),
(62, '1 João', '1Jo', 'NT', 62, 5),
(63, '2 João', '2Jo', 'NT', 63, 1),
(64, '3 João', '3Jo', 'NT', 64, 1),
(65, 'Judas', 'Jd', 'NT', 65, 1),
(66, 'Apocalipse', 'Ap', 'NT', 66, 22)
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- NOTA IMPORTANTE
-- =====================================================
-- Os versículos da Bíblia (31.105 versículos) serão importados
-- em um script separado devido ao tamanho do arquivo.
-- 
-- Para importar os versículos:
-- 1. Baixe o JSON da Bíblia ARC do repositório:
--    https://github.com/damarals/biblias/blob/master/inst/json/ARC.json
-- 
-- 2. Use um script Python/Node.js para converter o JSON em SQL
--    e importar para a tabela bible_verse
-- 
-- 3. Ou use a API do Supabase para importar os dados via código
-- =====================================================
