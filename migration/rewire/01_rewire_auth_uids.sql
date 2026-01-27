-- Rewire de Auth UIDs (Opcao B)
-- PRE-REQ: criar e popular public.migration_auth_uid_map (old_auth_uid -> new_auth_uid).
-- Rode com role que bypassa RLS (service_role/owner).
-- Padrão: modo PREVIEW. Para aplicar, mude p_apply para true.

BEGIN;

CREATE TABLE IF NOT EXISTS public.migration_auth_uid_map (
  old_auth_uid uuid PRIMARY KEY,
  new_auth_uid uuid NOT NULL
);

CREATE TABLE IF NOT EXISTS public.migration_auth_uid_preview (
  phase text NOT NULL,
  table_schema text NOT NULL,
  table_name text NOT NULL,
  column_name text NOT NULL,
  mapped_rows bigint NOT NULL,
  unmapped_rows bigint NOT NULL,
  note text
);

-- Checagens basicas da tabela de mapeamento
DO $$
DECLARE
  dup_count integer;
  map_count integer;
BEGIN
  SELECT count(*) INTO map_count FROM public.migration_auth_uid_map;
  IF map_count = 0 THEN
    RAISE NOTICE 'migration_auth_uid_map esta vazia. Preencha antes de aplicar.';
  END IF;

  SELECT count(*) INTO dup_count
  FROM (
    SELECT new_auth_uid
    FROM public.migration_auth_uid_map
    GROUP BY new_auth_uid
    HAVING count(*) > 1
  ) d;

  IF dup_count > 0 THEN
    RAISE EXCEPTION 'Mapa invalido: new_auth_uid repetido. Ajuste migration_auth_uid_map.';
  END IF;
END $$;

DO $$
DECLARE
  p_apply boolean := false; -- mude para true quando quiser aplicar
  r record;
BEGIN
  TRUNCATE public.migration_auth_uid_preview;

  CREATE TEMP TABLE IF NOT EXISTS phase1_targets (
    table_schema text,
    table_name text,
    column_name text,
    note text,
    PRIMARY KEY (table_schema, table_name, column_name)
  ) ON COMMIT DROP;
  DELETE FROM phase1_targets;

  -- Fase 1 (central): user_account.auth_user_id e tabelas de membership/roles (se existirem)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'user_account' AND column_name = 'auth_user_id'
  ) THEN
    INSERT INTO phase1_targets VALUES ('public','user_account','auth_user_id','canonical_auth_user_id');
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'user_tenant_membership' AND column_name = 'user_id'
  ) THEN
    INSERT INTO phase1_targets VALUES ('public','user_tenant_membership','user_id','membership');
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'user_roles' AND column_name = 'user_id'
  ) THEN
    INSERT INTO phase1_targets VALUES ('public','user_roles','user_id','roles');
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'access_level_history' AND column_name = 'user_id'
  ) THEN
    INSERT INTO phase1_targets VALUES ('public','access_level_history','user_id','access_level_history');
  END IF;

  CREATE TEMP TABLE IF NOT EXISTS phase2_targets (
    table_schema text,
    table_name text,
    column_name text,
    reason text,
    PRIMARY KEY (table_schema, table_name, column_name)
  ) ON COMMIT DROP;
  DELETE FROM phase2_targets;

  -- FKs formais para auth.users
  INSERT INTO phase2_targets (table_schema, table_name, column_name, reason)
  SELECT
    n.nspname as table_schema,
    c.relname as table_name,
    a.attname as column_name,
    'fk_auth_users' as reason
  FROM pg_constraint con
  JOIN pg_class c ON c.oid = con.conrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = ANY(con.conkey)
  JOIN pg_class cf ON cf.oid = con.confrelid
  JOIN pg_namespace nf ON nf.oid = cf.relnamespace
  WHERE con.contype = 'f'
    AND nf.nspname = 'auth'
    AND cf.relname = 'users'
    AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'auth', 'storage')
    AND NOT EXISTS (
      SELECT 1 FROM phase1_targets p
      WHERE p.table_schema = n.nspname
        AND p.table_name = c.relname
        AND p.column_name = a.attname
    )
  ON CONFLICT DO NOTHING;

  -- Heuristica: colunas UUID com nomes tipicos de usuario (somente BASE TABLE)
  INSERT INTO phase2_targets (table_schema, table_name, column_name, reason)
  SELECT c.table_schema, c.table_name, c.column_name, 'heuristic_uuid'
  FROM information_schema.columns c
  JOIN information_schema.tables t
    ON t.table_schema = c.table_schema AND t.table_name = c.table_name
  WHERE t.table_type = 'BASE TABLE'
    AND c.table_schema NOT IN ('pg_catalog', 'information_schema', 'auth', 'storage')
    AND c.data_type = 'uuid'
    AND (
      c.column_name in (
        'user_id','created_by','updated_by','auth_user_id','owner','member_id',
        'author_id','assignee_id','created_user_id','updated_user_id',
        'created_by_user_id','updated_by_user_id'
      )
      OR c.column_name like '%_user_id'
      OR c.column_name like '%_by'
      OR c.column_name like '%owner%'
    )
    AND NOT EXISTS (
      SELECT 1 FROM phase1_targets p
      WHERE p.table_schema = c.table_schema
        AND p.table_name = c.table_name
        AND p.column_name = c.column_name
    )
  ON CONFLICT DO NOTHING;

  -- Preview: fase 1
  FOR r IN SELECT * FROM phase1_targets ORDER BY table_schema, table_name, column_name LOOP
    EXECUTE format(
      'INSERT INTO public.migration_auth_uid_preview
       (phase, table_schema, table_name, column_name, mapped_rows, unmapped_rows, note)
       SELECT %L, %L, %L, %L,
              count(*) FILTER (WHERE m.old_auth_uid IS NOT NULL),
              count(*) FILTER (WHERE t.%I IS NOT NULL AND m.old_auth_uid IS NULL),
              %L
       FROM %I.%I t
       LEFT JOIN public.migration_auth_uid_map m ON t.%I = m.old_auth_uid',
      'phase1', r.table_schema, r.table_name, r.column_name,
      r.column_name, r.note, r.table_schema, r.table_name, r.column_name
    );
  END LOOP;

  -- Preview: fase 2
  FOR r IN SELECT * FROM phase2_targets ORDER BY table_schema, table_name, column_name LOOP
    EXECUTE format(
      'INSERT INTO public.migration_auth_uid_preview
       (phase, table_schema, table_name, column_name, mapped_rows, unmapped_rows, note)
       SELECT %L, %L, %L, %L,
              count(*) FILTER (WHERE m.old_auth_uid IS NOT NULL),
              count(*) FILTER (WHERE t.%I IS NOT NULL AND m.old_auth_uid IS NULL),
              %L
       FROM %I.%I t
       LEFT JOIN public.migration_auth_uid_map m ON t.%I = m.old_auth_uid',
      'phase2', r.table_schema, r.table_name, r.column_name,
      r.column_name, r.reason, r.table_schema, r.table_name, r.column_name
    );
  END LOOP;

  IF p_apply THEN
    -- Fase 1 updates
    FOR r IN SELECT * FROM phase1_targets ORDER BY table_schema, table_name, column_name LOOP
      EXECUTE format(
        'UPDATE %I.%I t
         SET %I = m.new_auth_uid
         FROM public.migration_auth_uid_map m
         WHERE t.%I = m.old_auth_uid',
        r.table_schema, r.table_name, r.column_name, r.column_name
      );
    END LOOP;

    -- Fase 2 updates
    FOR r IN SELECT * FROM phase2_targets ORDER BY table_schema, table_name, column_name LOOP
      EXECUTE format(
        'UPDATE %I.%I t
         SET %I = m.new_auth_uid
         FROM public.migration_auth_uid_map m
         WHERE t.%I = m.old_auth_uid',
        r.table_schema, r.table_name, r.column_name, r.column_name
      );
    END LOOP;
  END IF;
END $$;

COMMIT;

-- Para ver o preview, execute:
-- SELECT * FROM public.migration_auth_uid_preview ORDER BY unmapped_rows DESC, mapped_rows DESC, phase, table_schema, table_name, column_name;
