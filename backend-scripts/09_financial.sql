  -- =====================================================
  -- SISTEMA FINANCEIRO - CHURCH 360
  -- =====================================================
  -- Criado em: 2025-10-14
  -- Descrição: Sistema completo de gestão financeira
  -- =====================================================

  -- =====================================================
  -- 1. ENUM TYPES
  -- =====================================================

  -- Tipo de contribuição
  DO $$
  BEGIN
    CREATE TYPE contribution_type AS ENUM (
      'tithe',        -- Dízimo
      'offering',     -- Oferta
      'missions',     -- Missões
      'building',     -- Construção
      'special',      -- Especial
      'other'         -- Outro
    );
  EXCEPTION
    WHEN duplicate_object THEN
      NULL;
  END $$;

  -- Método de pagamento
  DO $$
  BEGIN
    CREATE TYPE payment_method AS ENUM (
      'cash',         -- Dinheiro
      'debit',        -- Débito
      'credit',       -- Crédito
      'pix',          -- PIX
      'transfer',     -- Transferência
      'check',        -- Cheque
      'other'         -- Outro
    );
  EXCEPTION
    WHEN duplicate_object THEN
      NULL;
  END $$;

  -- =====================================================
  -- 2. TABELAS
  -- =====================================================

  -- Tabela de contribuições
  CREATE TABLE IF NOT EXISTS contribution (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id UUID REFERENCES member(id) ON DELETE SET NULL,
    type contribution_type NOT NULL DEFAULT 'offering',
    amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
    payment_method payment_method NOT NULL DEFAULT 'cash',
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    description TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
  );

  -- Tabela de metas financeiras
  CREATE TABLE IF NOT EXISTS financial_goal (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    description TEXT,
    target_amount DECIMAL(10, 2) NOT NULL CHECK (target_amount > 0),
    current_amount DECIMAL(10, 2) DEFAULT 0 CHECK (current_amount >= 0),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    CONSTRAINT valid_date_range CHECK (end_date >= start_date)
  );

  -- Tabela de despesas
  CREATE TABLE IF NOT EXISTS expense (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category VARCHAR(100) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
    payment_method payment_method NOT NULL DEFAULT 'cash',
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    description TEXT NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
  );

  -- =====================================================
  -- 3. ÍNDICES
  -- =====================================================

-- Índices para contribuições
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='contribution' AND column_name='member_id'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_contribution_member ON public.contribution(member_id)';
  ELSIF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='contribution' AND column_name='user_id'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_contribution_user ON public.contribution(user_id)';
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_contribution_type ON contribution(type);
CREATE INDEX IF NOT EXISTS idx_contribution_date ON contribution(date);
CREATE INDEX IF NOT EXISTS idx_contribution_created_at ON contribution(created_at);

  -- Índices para metas financeiras
  CREATE INDEX IF NOT EXISTS idx_financial_goal_active ON financial_goal(is_active);
  CREATE INDEX IF NOT EXISTS idx_financial_goal_dates ON financial_goal(start_date, end_date);

  -- Índices para despesas
  CREATE INDEX IF NOT EXISTS idx_expense_category ON expense(category);
  CREATE INDEX IF NOT EXISTS idx_expense_date ON expense(date);
  CREATE INDEX IF NOT EXISTS idx_expense_created_at ON expense(created_at);

  -- =====================================================
  -- 4. TRIGGERS
  -- =====================================================

  -- Trigger para atualizar updated_at em financial_goal
  DROP TRIGGER IF EXISTS update_financial_goal_updated_at ON financial_goal;
  CREATE TRIGGER update_financial_goal_updated_at
    BEFORE UPDATE ON financial_goal
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

  -- =====================================================
  -- 5. ROW LEVEL SECURITY (RLS)
  -- =====================================================

  -- Habilitar RLS
  ALTER TABLE contribution ENABLE ROW LEVEL SECURITY;
  ALTER TABLE financial_goal ENABLE ROW LEVEL SECURITY;
  ALTER TABLE expense ENABLE ROW LEVEL SECURITY;

  CREATE OR REPLACE FUNCTION public.can_manage_financial(p_user_id uuid, p_tenant_id uuid)
  RETURNS boolean
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  DECLARE
    v_allowed boolean;
    v_tenant_id uuid;
    v_has_user_access_level_tenant_id boolean;
  BEGIN
    v_tenant_id := p_tenant_id;
    IF v_tenant_id IS NULL THEN
      BEGIN
        v_tenant_id := public.current_tenant_id();
      EXCEPTION
        WHEN undefined_function THEN
          v_tenant_id := NULL;
        WHEN OTHERS THEN
          v_tenant_id := NULL;
      END;
    END IF;

    IF to_regclass('public.user_tenant_membership') IS NOT NULL AND v_tenant_id IS NOT NULL THEN
      EXECUTE
        'SELECT EXISTS (
           SELECT 1
           FROM public.user_tenant_membership utm
           WHERE utm.user_id = $1
             AND utm.tenant_id = $2
             AND utm.is_active = true
             AND utm.access_level_number >= 4
         )'
      INTO v_allowed
      USING p_user_id, v_tenant_id;
      RETURN COALESCE(v_allowed, false);
    END IF;

    IF to_regclass('public.user_access_level') IS NOT NULL THEN
      SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'user_access_level'
          AND column_name = 'tenant_id'
      ) INTO v_has_user_access_level_tenant_id;

      IF v_has_user_access_level_tenant_id AND v_tenant_id IS NOT NULL THEN
        EXECUTE
          'SELECT EXISTS (
             SELECT 1
             FROM public.user_access_level ual
             WHERE ual.user_id = $1
               AND ual.tenant_id = $2
               AND ual.access_level_number >= 4
           )'
        INTO v_allowed
        USING p_user_id, v_tenant_id;
        RETURN COALESCE(v_allowed, false);
      END IF;

      EXECUTE
        'SELECT EXISTS (
           SELECT 1
           FROM public.user_access_level ual
           WHERE ual.user_id = $1
             AND ual.access_level_number >= 4
         )'
      INTO v_allowed
      USING p_user_id;
      RETURN COALESCE(v_allowed, false);
    END IF;

    RETURN false;
  END;
  $function$;

  -- Políticas para contribution
  DROP POLICY IF EXISTS "Usuários autenticados podem ver contribuições" ON contribution;
  CREATE POLICY "Usuários autenticados podem ver contribuições"
    ON contribution FOR SELECT
    TO authenticated
    USING (public.can_manage_financial(auth.uid(), contribution.tenant_id));

  DROP POLICY IF EXISTS "Usuários autenticados podem inserir contribuições" ON contribution;
  CREATE POLICY "Usuários autenticados podem inserir contribuições"
    ON contribution FOR INSERT
    TO authenticated
    WITH CHECK (public.can_manage_financial(auth.uid(), contribution.tenant_id));

  DROP POLICY IF EXISTS "Usuários autenticados podem atualizar contribuições" ON contribution;
  CREATE POLICY "Usuários autenticados podem atualizar contribuições"
    ON contribution FOR UPDATE
    TO authenticated
    USING (public.can_manage_financial(auth.uid(), contribution.tenant_id))
    WITH CHECK (public.can_manage_financial(auth.uid(), contribution.tenant_id));

  DROP POLICY IF EXISTS "Usuários autenticados podem deletar contribuições" ON contribution;
  CREATE POLICY "Usuários autenticados podem deletar contribuições"
    ON contribution FOR DELETE
    TO authenticated
    USING (public.can_manage_financial(auth.uid(), contribution.tenant_id));

  -- Políticas para financial_goal
  DROP POLICY IF EXISTS "Usuários autenticados podem ver metas" ON financial_goal;
  CREATE POLICY "Usuários autenticados podem ver metas"
    ON financial_goal FOR SELECT
    TO authenticated
    USING (true);

  DROP POLICY IF EXISTS "Usuários autenticados podem inserir metas" ON financial_goal;
  CREATE POLICY "Usuários autenticados podem inserir metas"
    ON financial_goal FOR INSERT
    TO authenticated
    WITH CHECK (true);

  DROP POLICY IF EXISTS "Usuários autenticados podem atualizar metas" ON financial_goal;
  CREATE POLICY "Usuários autenticados podem atualizar metas"
    ON financial_goal FOR UPDATE
    TO authenticated
    USING (true);

  DROP POLICY IF EXISTS "Usuários autenticados podem deletar metas" ON financial_goal;
  CREATE POLICY "Usuários autenticados podem deletar metas"
    ON financial_goal FOR DELETE
    TO authenticated
    USING (true);

  -- Políticas para expense
  DROP POLICY IF EXISTS "Usuários autenticados podem ver despesas" ON expense;
  CREATE POLICY "Usuários autenticados podem ver despesas"
    ON expense FOR SELECT
    TO authenticated
    USING (true);

  DROP POLICY IF EXISTS "Usuários autenticados podem inserir despesas" ON expense;
  CREATE POLICY "Usuários autenticados podem inserir despesas"
    ON expense FOR INSERT
    TO authenticated
    WITH CHECK (true);

  DROP POLICY IF EXISTS "Usuários autenticados podem atualizar despesas" ON expense;
  CREATE POLICY "Usuários autenticados podem atualizar despesas"
    ON expense FOR UPDATE
    TO authenticated
    USING (true);

  DROP POLICY IF EXISTS "Usuários autenticados podem deletar despesas" ON expense;
  CREATE POLICY "Usuários autenticados podem deletar despesas"
    ON expense FOR DELETE
    TO authenticated
    USING (true);

  -- =====================================================
  -- 6. DADOS DE EXEMPLO
  -- =====================================================

DO $$
DECLARE
  v_tenant UUID;
BEGIN
  SELECT id INTO v_tenant FROM public.tenant LIMIT 1;
  IF v_tenant IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema='public' AND table_name='contribution' AND column_name='member_id'
    ) AND EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema='public' AND table_name='member'
    ) THEN
      IF NOT EXISTS (SELECT 1 FROM public.contribution) THEN
        INSERT INTO public.contribution (tenant_id, member_id, type, amount, payment_method, date, description) VALUES
          (v_tenant, (SELECT id FROM public.member LIMIT 1 OFFSET 0), 'tithe', 500.00, 'pix', '2025-10-01', 'Dízimo de Outubro'),
          (v_tenant, (SELECT id FROM public.member LIMIT 1 OFFSET 1), 'tithe', 300.00, 'cash', '2025-10-01', 'Dízimo de Outubro'),
          (v_tenant, (SELECT id FROM public.member LIMIT 1 OFFSET 2), 'offering', 100.00, 'debit', '2025-10-05', 'Oferta de Gratidão'),
          (v_tenant, (SELECT id FROM public.member LIMIT 1 OFFSET 3), 'missions', 200.00, 'pix', '2025-10-08', 'Oferta para Missões'),
          (v_tenant, (SELECT id FROM public.member LIMIT 1 OFFSET 4), 'tithe', 450.00, 'transfer', '2025-10-10', 'Dízimo de Outubro'),
          (v_tenant, (SELECT id FROM public.member LIMIT 1 OFFSET 0), 'offering', 150.00, 'cash', '2025-10-12', 'Oferta de Ação de Graças'),
          (v_tenant, (SELECT id FROM public.member LIMIT 1 OFFSET 1), 'building', 1000.00, 'pix', '2025-10-13', 'Contribuição para Reforma'),
          (v_tenant, (SELECT id FROM public.member LIMIT 1 OFFSET 2), 'tithe', 350.00, 'cash', '2025-10-13', 'Dízimo de Outubro');
      END IF;
    ELSIF EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema='public' AND table_name='contribution' AND column_name='user_id'
    ) AND EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema='public' AND table_name='user_account'
    ) THEN
      IF NOT EXISTS (SELECT 1 FROM public.contribution) THEN
        INSERT INTO public.contribution (tenant_id, user_id, type, amount, payment_method, date, description) VALUES
          (v_tenant, (SELECT id FROM public.user_account LIMIT 1 OFFSET 0), 'tithe', 500.00, 'pix', '2025-10-01', 'Dízimo de Outubro'),
          (v_tenant, (SELECT id FROM public.user_account LIMIT 1 OFFSET 1), 'tithe', 300.00, 'cash', '2025-10-01', 'Dízimo de Outubro'),
          (v_tenant, (SELECT id FROM public.user_account LIMIT 1 OFFSET 2), 'offering', 100.00, 'debit', '2025-10-05', 'Oferta de Gratidão'),
          (v_tenant, (SELECT id FROM public.user_account LIMIT 1 OFFSET 3), 'missions', 200.00, 'pix', '2025-10-08', 'Oferta para Missões'),
          (v_tenant, (SELECT id FROM public.user_account LIMIT 1 OFFSET 4), 'tithe', 450.00, 'transfer', '2025-10-10', 'Dízimo de Outubro'),
          (v_tenant, (SELECT id FROM public.user_account LIMIT 1 OFFSET 0), 'offering', 150.00, 'cash', '2025-10-12', 'Oferta de Ação de Graças'),
          (v_tenant, (SELECT id FROM public.user_account LIMIT 1 OFFSET 1), 'building', 1000.00, 'pix', '2025-10-13', 'Contribuição para Reforma'),
          (v_tenant, (SELECT id FROM public.user_account LIMIT 1 OFFSET 2), 'tithe', 350.00, 'cash', '2025-10-13', 'Dízimo de Outubro');
      END IF;
    END IF;
  END IF;
END $$;

  -- Inserir meta financeira de exemplo
DO $$
DECLARE
  v_tenant UUID;
BEGIN
  SELECT id INTO v_tenant FROM public.tenant LIMIT 1;
  IF v_tenant IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.financial_goal WHERE tenant_id = v_tenant AND name = 'Reforma do Templo') THEN
      INSERT INTO public.financial_goal (tenant_id, name, description, target_amount, current_amount, start_date, end_date) VALUES
        (v_tenant, 'Reforma do Templo', 'Meta para reforma completa do templo', 50000.00, 15000.00, '2025-10-01', '2025-12-31');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.financial_goal WHERE tenant_id = v_tenant AND name = 'Missões 2025') THEN
      INSERT INTO public.financial_goal (tenant_id, name, description, target_amount, current_amount, start_date, end_date) VALUES
        (v_tenant, 'Missões 2025', 'Apoio a missionários e projetos missionários', 20000.00, 5000.00, '2025-01-01', '2025-12-31');
    END IF;
  END IF;
END $$;

  -- Inserir algumas despesas de exemplo
DO $$
DECLARE
  v_tenant UUID;
BEGIN
  SELECT id INTO v_tenant FROM public.tenant LIMIT 1;
  IF v_tenant IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.expense WHERE tenant_id = v_tenant) THEN
    INSERT INTO public.expense (tenant_id, category, amount, payment_method, date, description) VALUES
      (v_tenant, 'Manutenção', 500.00, 'cash', '2025-10-02', 'Conserto do ar condicionado'),
      (v_tenant, 'Água e Luz', 350.00, 'debit', '2025-10-05', 'Conta de energia elétrica'),
      (v_tenant, 'Material de Limpeza', 150.00, 'cash', '2025-10-07', 'Produtos de limpeza'),
      (v_tenant, 'Equipamentos', 2000.00, 'transfer', '2025-10-10', 'Microfone novo para louvor'),
      (v_tenant, 'Água e Luz', 200.00, 'debit', '2025-10-12', 'Conta de água');
  END IF;
END $$;

  -- =====================================================
  -- FIM DO SCRIPT
  -- =====================================================
