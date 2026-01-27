-- Move unaccent extension out of public schema to satisfy security linter.
CREATE SCHEMA IF NOT EXISTS extensions;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_extension e
    JOIN pg_namespace n ON n.oid = e.extnamespace
    WHERE e.extname = 'unaccent'
  ) THEN
    IF EXISTS (
      SELECT 1
      FROM pg_extension e
      JOIN pg_namespace n ON n.oid = e.extnamespace
      WHERE e.extname = 'unaccent'
        AND n.nspname <> 'extensions'
    ) THEN
      EXECUTE 'ALTER EXTENSION unaccent SET SCHEMA extensions';
    END IF;
  ELSE
    BEGIN
      CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA extensions;
    EXCEPTION
      WHEN insufficient_privilege THEN
        NULL;
    END;
  END IF;
END $$;
