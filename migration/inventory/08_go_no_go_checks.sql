-- Go/No-Go checks (rodar na origem e no destino)

-- Schemas alvo (public + custom, exclui auth/storage/system)
CREATE TEMP TABLE IF NOT EXISTS _schemas_to_check(
  schema_name text PRIMARY KEY
) ON COMMIT DROP;
DELETE FROM _schemas_to_check;
INSERT INTO _schemas_to_check (schema_name)
SELECT n.nspname
FROM pg_namespace n
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'auth', 'storage')
  AND EXISTS (
    SELECT 1 FROM pg_tables t WHERE t.schemaname = n.nspname
  );

-- 1) Contagem por tabela (exclui auth)
DO $$
DECLARE
  r record;
BEGIN
  CREATE TEMP TABLE IF NOT EXISTS _table_counts(
    table_schema text,
    table_name text,
    total bigint
  ) ON COMMIT DROP;
  DELETE FROM _table_counts;

  FOR r IN
    SELECT schemaname, tablename
    FROM pg_tables
    WHERE schemaname IN (SELECT schema_name FROM _schemas_to_check)
  LOOP
    EXECUTE format(
      'INSERT INTO _table_counts SELECT %L, %L, count(*) FROM %I.%I',
      r.schemaname, r.tablename, r.schemaname, r.tablename
    );
  END LOOP;
END $$;

SELECT * FROM _table_counts ORDER BY table_schema, table_name;

-- 2) Contagem por tenant_id + min/max updated_at (quando existir)
DO $$
DECLARE
  r record;
  has_updated_at boolean;
BEGIN
  CREATE TEMP TABLE IF NOT EXISTS _tenant_counts(
    table_schema text,
    table_name text,
    tenant_id text,
    total bigint,
    min_updated_at timestamptz,
    max_updated_at timestamptz
  ) ON COMMIT DROP;
  DELETE FROM _tenant_counts;

  FOR r IN
    SELECT c.table_schema, c.table_name
    FROM information_schema.columns c
    JOIN information_schema.tables t
      ON t.table_schema = c.table_schema
     AND t.table_name = c.table_name
    WHERE c.column_name = 'tenant_id'
      AND t.table_type = 'BASE TABLE'
      AND c.table_schema IN (SELECT schema_name FROM _schemas_to_check)
  LOOP
    SELECT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = r.table_schema
        AND table_name = r.table_name
        AND column_name = 'updated_at'
    ) INTO has_updated_at;

    IF has_updated_at THEN
      EXECUTE format(
        'INSERT INTO _tenant_counts
         SELECT %L, %L, tenant_id::text, count(*), min(updated_at), max(updated_at)
         FROM %I.%I
         GROUP BY tenant_id',
        r.table_schema, r.table_name, r.table_schema, r.table_name
      );
    ELSE
      EXECUTE format(
        'INSERT INTO _tenant_counts
         SELECT %L, %L, tenant_id::text, count(*), NULL::timestamptz, NULL::timestamptz
         FROM %I.%I
         GROUP BY tenant_id',
        r.table_schema, r.table_name, r.table_schema, r.table_name
      );
    END IF;
  END LOOP;
END $$;

SELECT * FROM _tenant_counts ORDER BY table_schema, table_name, tenant_id;

-- 3) Linhas com tenant_id NULL
DO $$
DECLARE
  r record;
BEGIN
  CREATE TEMP TABLE IF NOT EXISTS _tenant_nulls(
    table_schema text,
    table_name text,
    null_tenant_rows bigint
  ) ON COMMIT DROP;
  DELETE FROM _tenant_nulls;

  FOR r IN
    SELECT c.table_schema, c.table_name
    FROM information_schema.columns c
    JOIN information_schema.tables t
      ON t.table_schema = c.table_schema
     AND t.table_name = c.table_name
    WHERE c.column_name = 'tenant_id'
      AND t.table_type = 'BASE TABLE'
      AND c.table_schema IN (SELECT schema_name FROM _schemas_to_check)
  LOOP
    EXECUTE format(
      'INSERT INTO _tenant_nulls
       SELECT %L, %L, count(*)
       FROM %I.%I
       WHERE tenant_id IS NULL',
      r.table_schema, r.table_name, r.table_schema, r.table_name
    );
  END LOOP;
END $$;

SELECT * FROM _tenant_nulls WHERE null_tenant_rows > 0 ORDER BY null_tenant_rows DESC, table_schema, table_name;

-- 4) Orfaos de FK para auth.users
DO $$
DECLARE
  r record;
BEGIN
  CREATE TEMP TABLE IF NOT EXISTS _auth_orphans(
    table_schema text,
    table_name text,
    column_name text,
    orphan_count bigint
  ) ON COMMIT DROP;
  DELETE FROM _auth_orphans;

  CREATE TEMP TABLE IF NOT EXISTS _auth_orphans_errors(
    table_schema text,
    table_name text,
    column_name text,
    error_message text
  ) ON COMMIT DROP;
  DELETE FROM _auth_orphans_errors;

  FOR r IN
    SELECT
      n.nspname as schema,
      c.relname as table,
      a.attname as column
    FROM pg_constraint con
    JOIN pg_class c ON c.oid = con.conrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = ANY(con.conkey)
    JOIN pg_class cf ON cf.oid = con.confrelid
    JOIN pg_namespace nf ON nf.oid = cf.relnamespace
    WHERE con.contype = 'f'
      AND nf.nspname = 'auth'
      AND cf.relname = 'users'
  LOOP
    BEGIN
      EXECUTE format(
        'INSERT INTO _auth_orphans
         SELECT %L, %L, %L, count(*)
         FROM %I.%I t
         LEFT JOIN auth.users u ON t.%I = u.id
         WHERE t.%I IS NOT NULL AND u.id IS NULL',
        r.schema, r.table, r.column, r.schema, r.table, r.column, r.column
      );
    EXCEPTION WHEN OTHERS THEN
      INSERT INTO _auth_orphans_errors (table_schema, table_name, column_name, error_message)
      VALUES (r.schema, r.table, r.column, SQLERRM);
    END;
  END LOOP;
END $$;

SELECT * FROM _auth_orphans WHERE orphan_count > 0 ORDER BY orphan_count DESC, table_schema, table_name, column_name;
SELECT * FROM _auth_orphans_errors ORDER BY table_schema, table_name, column_name;

-- 5) Tabelas sem RLS (exclui auth)
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname IN (SELECT schema_name FROM _schemas_to_check)
  AND rowsecurity = false
ORDER BY 1,2;

-- 6) Storage: owner NULL (se houver storage)
SELECT bucket_id,
       count(*) FILTER (WHERE owner IS NULL) AS owner_nulls,
       count(*) AS total
FROM storage.objects
GROUP BY 1
ORDER BY 1;

-- 7) Policies do storage.objects
SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects'
ORDER BY 1,2,3;
