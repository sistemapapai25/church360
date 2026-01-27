DO $$
DECLARE
  v_exists boolean;
  v_has_tenant_id boolean;
  v_has_idprofissao boolean;
  v_has_profissao boolean;
  pol record;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'profissao'
  ) INTO v_exists;

  IF NOT v_exists THEN
    RETURN;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profissao' AND column_name = 'tenant_id'
  ) INTO v_has_tenant_id;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profissao' AND column_name = 'idprofissao'
  ) INTO v_has_idprofissao;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profissao' AND column_name = 'profissao'
  ) INTO v_has_profissao;

  IF NOT v_has_idprofissao THEN
    ALTER TABLE public.profissao ADD COLUMN idprofissao text;
  END IF;

  IF NOT v_has_profissao THEN
    ALTER TABLE public.profissao ADD COLUMN profissao text;
  END IF;

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
