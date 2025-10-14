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
CREATE TYPE contribution_type AS ENUM (
  'tithe',        -- Dízimo
  'offering',     -- Oferta
  'missions',     -- Missões
  'building',     -- Construção
  'special',      -- Especial
  'other'         -- Outro
);

-- Método de pagamento
CREATE TYPE payment_method AS ENUM (
  'cash',         -- Dinheiro
  'debit',        -- Débito
  'credit',       -- Crédito
  'pix',          -- PIX
  'transfer',     -- Transferência
  'check',        -- Cheque
  'other'         -- Outro
);

-- =====================================================
-- 2. TABELAS
-- =====================================================

-- Tabela de contribuições
CREATE TABLE contribution (
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
CREATE TABLE financial_goal (
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
CREATE TABLE expense (
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
CREATE INDEX idx_contribution_member ON contribution(member_id);
CREATE INDEX idx_contribution_type ON contribution(type);
CREATE INDEX idx_contribution_date ON contribution(date);
CREATE INDEX idx_contribution_created_at ON contribution(created_at);

-- Índices para metas financeiras
CREATE INDEX idx_financial_goal_active ON financial_goal(is_active);
CREATE INDEX idx_financial_goal_dates ON financial_goal(start_date, end_date);

-- Índices para despesas
CREATE INDEX idx_expense_category ON expense(category);
CREATE INDEX idx_expense_date ON expense(date);
CREATE INDEX idx_expense_created_at ON expense(created_at);

-- =====================================================
-- 4. TRIGGERS
-- =====================================================

-- Trigger para atualizar updated_at em financial_goal
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

-- Políticas para contribution
CREATE POLICY "Usuários autenticados podem ver contribuições"
  ON contribution FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Usuários autenticados podem inserir contribuições"
  ON contribution FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Usuários autenticados podem atualizar contribuições"
  ON contribution FOR UPDATE
  TO authenticated
  USING (true);

CREATE POLICY "Usuários autenticados podem deletar contribuições"
  ON contribution FOR DELETE
  TO authenticated
  USING (true);

-- Políticas para financial_goal
CREATE POLICY "Usuários autenticados podem ver metas"
  ON financial_goal FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Usuários autenticados podem inserir metas"
  ON financial_goal FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Usuários autenticados podem atualizar metas"
  ON financial_goal FOR UPDATE
  TO authenticated
  USING (true);

CREATE POLICY "Usuários autenticados podem deletar metas"
  ON financial_goal FOR DELETE
  TO authenticated
  USING (true);

-- Políticas para expense
CREATE POLICY "Usuários autenticados podem ver despesas"
  ON expense FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Usuários autenticados podem inserir despesas"
  ON expense FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Usuários autenticados podem atualizar despesas"
  ON expense FOR UPDATE
  TO authenticated
  USING (true);

CREATE POLICY "Usuários autenticados podem deletar despesas"
  ON expense FOR DELETE
  TO authenticated
  USING (true);

-- =====================================================
-- 6. DADOS DE EXEMPLO
-- =====================================================

-- Inserir algumas contribuições de exemplo
INSERT INTO contribution (member_id, type, amount, payment_method, date, description) VALUES
  ((SELECT id FROM member LIMIT 1 OFFSET 0), 'tithe', 500.00, 'pix', '2025-10-01', 'Dízimo de Outubro'),
  ((SELECT id FROM member LIMIT 1 OFFSET 1), 'tithe', 300.00, 'cash', '2025-10-01', 'Dízimo de Outubro'),
  ((SELECT id FROM member LIMIT 1 OFFSET 2), 'offering', 100.00, 'debit', '2025-10-05', 'Oferta de Gratidão'),
  ((SELECT id FROM member LIMIT 1 OFFSET 3), 'missions', 200.00, 'pix', '2025-10-08', 'Oferta para Missões'),
  ((SELECT id FROM member LIMIT 1 OFFSET 4), 'tithe', 450.00, 'transfer', '2025-10-10', 'Dízimo de Outubro'),
  ((SELECT id FROM member LIMIT 1 OFFSET 0), 'offering', 150.00, 'cash', '2025-10-12', 'Oferta de Ação de Graças'),
  ((SELECT id FROM member LIMIT 1 OFFSET 1), 'building', 1000.00, 'pix', '2025-10-13', 'Contribuição para Reforma'),
  ((SELECT id FROM member LIMIT 1 OFFSET 2), 'tithe', 350.00, 'cash', '2025-10-13', 'Dízimo de Outubro');

-- Inserir meta financeira de exemplo
INSERT INTO financial_goal (name, description, target_amount, current_amount, start_date, end_date) VALUES
  ('Reforma do Templo', 'Meta para reforma completa do templo', 50000.00, 15000.00, '2025-10-01', '2025-12-31'),
  ('Missões 2025', 'Apoio a missionários e projetos missionários', 20000.00, 5000.00, '2025-01-01', '2025-12-31');

-- Inserir algumas despesas de exemplo
INSERT INTO expense (category, amount, payment_method, date, description) VALUES
  ('Manutenção', 500.00, 'cash', '2025-10-02', 'Conserto do ar condicionado'),
  ('Água e Luz', 350.00, 'debit', '2025-10-05', 'Conta de energia elétrica'),
  ('Material de Limpeza', 150.00, 'cash', '2025-10-07', 'Produtos de limpeza'),
  ('Equipamentos', 2000.00, 'transfer', '2025-10-10', 'Microfone novo para louvor'),
  ('Água e Luz', 200.00, 'debit', '2025-10-12', 'Conta de água');

-- =====================================================
-- FIM DO SCRIPT
-- =====================================================

