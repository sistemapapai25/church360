DO $$
DECLARE
  pol record;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'profissao'
  ) THEN
    RETURN;
  END IF;

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
  TO public
  USING (true);
END $$;

GRANT SELECT ON public.profissao TO anon;
GRANT SELECT ON public.v_profissao TO anon;
GRANT EXECUTE ON FUNCTION public.search_profissao(text, integer) TO anon;
GRANT EXECUTE ON FUNCTION public.get_profession_label(text) TO anon;
