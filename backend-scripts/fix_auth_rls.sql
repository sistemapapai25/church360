-- Disable RLS on auth schema tables to allow GoTrue to query schema.
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT c.relname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'auth'
      AND c.relkind = 'r'
  LOOP
    EXECUTE format('ALTER TABLE auth.%I DISABLE ROW LEVEL SECURITY', r.relname);
  END LOOP;
END $$;
