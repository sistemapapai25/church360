-- =====================================================
-- SISTEMA DE VISITANTES
-- =====================================================

-- Enum para status do visitante
CREATE TYPE visitor_status AS ENUM (
  'first_visit',      -- Primeira visita
  'returning',        -- Retornando
  'regular',          -- Frequentando regularmente
  'converted',        -- Convertido em membro
  'inactive'          -- Inativo
);

-- Enum para como conheceu a igreja
CREATE TYPE how_found_church AS ENUM (
  'friend_invitation',  -- Convite de amigo
  'family',            -- Família
  'social_media',      -- Redes sociais
  'google_search',     -- Busca no Google
  'passing_by',        -- Passando pela rua
  'event',             -- Evento especial
  'other'              -- Outro
);

-- Tabela de visitantes
CREATE TABLE visitor (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  email VARCHAR(255),
  phone VARCHAR(20),
  birth_date DATE,
  address TEXT,
  city VARCHAR(100),
  state VARCHAR(50),
  zip_code VARCHAR(20),
  
  -- Informações da visita
  first_visit_date DATE NOT NULL DEFAULT CURRENT_DATE,
  last_visit_date DATE,
  total_visits INTEGER DEFAULT 1,
  status visitor_status DEFAULT 'first_visit',
  how_found how_found_church,
  
  -- Informações adicionais
  prayer_request TEXT,
  interests TEXT,
  notes TEXT,
  
  -- Conversão
  converted_to_member_id UUID REFERENCES member(id) ON DELETE SET NULL,
  converted_at TIMESTAMPTZ,
  
  -- Responsável pelo acompanhamento
  assigned_to UUID REFERENCES user_account(id) ON DELETE SET NULL,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES user_account(id) ON DELETE SET NULL
);

-- Tabela de visitas (histórico)
CREATE TABLE visitor_visit (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  visitor_id UUID NOT NULL REFERENCES visitor(id) ON DELETE CASCADE,
  visit_date DATE NOT NULL DEFAULT CURRENT_DATE,
  worship_service_id UUID REFERENCES worship_service(id) ON DELETE SET NULL,
  notes TEXT,
  was_contacted BOOLEAN DEFAULT FALSE,
  contact_date DATE,
  contact_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES user_account(id) ON DELETE SET NULL
);

-- Tabela de follow-up (acompanhamento)
CREATE TABLE visitor_followup (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  visitor_id UUID NOT NULL REFERENCES visitor(id) ON DELETE CASCADE,
  followup_date DATE NOT NULL,
  followup_type VARCHAR(50), -- 'call', 'email', 'visit', 'whatsapp', etc
  description TEXT,
  completed BOOLEAN DEFAULT FALSE,
  completed_at TIMESTAMPTZ,
  completed_by UUID REFERENCES user_account(id) ON DELETE SET NULL,
  assigned_to UUID REFERENCES user_account(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES user_account(id) ON DELETE SET NULL
);

-- Índices para performance
CREATE INDEX idx_visitor_status ON visitor(status);
CREATE INDEX idx_visitor_first_visit_date ON visitor(first_visit_date);
CREATE INDEX idx_visitor_last_visit_date ON visitor(last_visit_date);
CREATE INDEX idx_visitor_assigned_to ON visitor(assigned_to);
CREATE INDEX idx_visitor_email ON visitor(email);
CREATE INDEX idx_visitor_phone ON visitor(phone);

CREATE INDEX idx_visitor_visit_visitor_id ON visitor_visit(visitor_id);
CREATE INDEX idx_visitor_visit_date ON visitor_visit(visit_date);
CREATE INDEX idx_visitor_visit_worship_service_id ON visitor_visit(worship_service_id);

CREATE INDEX idx_visitor_followup_visitor_id ON visitor_followup(visitor_id);
CREATE INDEX idx_visitor_followup_date ON visitor_followup(followup_date);
CREATE INDEX idx_visitor_followup_completed ON visitor_followup(completed);
CREATE INDEX idx_visitor_followup_assigned_to ON visitor_followup(assigned_to);

-- Trigger para atualizar updated_at
CREATE TRIGGER update_visitor_updated_at
  BEFORE UPDATE ON visitor
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Trigger para atualizar total_visits e last_visit_date
CREATE OR REPLACE FUNCTION update_visitor_stats()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE visitor
    SET 
      total_visits = (
        SELECT COUNT(*) FROM visitor_visit
        WHERE visitor_id = NEW.visitor_id
      ),
      last_visit_date = NEW.visit_date
    WHERE id = NEW.visitor_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE visitor
    SET 
      total_visits = (
        SELECT COUNT(*) FROM visitor_visit
        WHERE visitor_id = OLD.visitor_id
      ),
      last_visit_date = (
        SELECT MAX(visit_date) FROM visitor_visit
        WHERE visitor_id = OLD.visitor_id
      )
    WHERE id = OLD.visitor_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_visitor_stats_trigger
  AFTER INSERT OR DELETE ON visitor_visit
  FOR EACH ROW
  EXECUTE FUNCTION update_visitor_stats();

-- RLS Policies
ALTER TABLE visitor ENABLE ROW LEVEL SECURITY;
ALTER TABLE visitor_visit ENABLE ROW LEVEL SECURITY;
ALTER TABLE visitor_followup ENABLE ROW LEVEL SECURITY;

-- Policy: Todos podem ver visitantes
CREATE POLICY "Visitantes são visíveis para usuários autenticados"
  ON visitor FOR SELECT
  USING (auth.role() = 'authenticated');

-- Policy: Todos podem inserir visitantes
CREATE POLICY "Usuários autenticados podem inserir visitantes"
  ON visitor FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- Policy: Todos podem atualizar visitantes
CREATE POLICY "Usuários autenticados podem atualizar visitantes"
  ON visitor FOR UPDATE
  USING (auth.role() = 'authenticated');

-- Policy: Todos podem deletar visitantes
CREATE POLICY "Usuários autenticados podem deletar visitantes"
  ON visitor FOR DELETE
  USING (auth.role() = 'authenticated');

-- Policies para visitor_visit
CREATE POLICY "Visitas são visíveis para usuários autenticados"
  ON visitor_visit FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Usuários autenticados podem inserir visitas"
  ON visitor_visit FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Usuários autenticados podem atualizar visitas"
  ON visitor_visit FOR UPDATE
  USING (auth.role() = 'authenticated');

CREATE POLICY "Usuários autenticados podem deletar visitas"
  ON visitor_visit FOR DELETE
  USING (auth.role() = 'authenticated');

-- Policies para visitor_followup
CREATE POLICY "Follow-ups são visíveis para usuários autenticados"
  ON visitor_followup FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Usuários autenticados podem inserir follow-ups"
  ON visitor_followup FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Usuários autenticados podem atualizar follow-ups"
  ON visitor_followup FOR UPDATE
  USING (auth.role() = 'authenticated');

CREATE POLICY "Usuários autenticados podem deletar follow-ups"
  ON visitor_followup FOR DELETE
  USING (auth.role() = 'authenticated');

-- Dados de exemplo
INSERT INTO visitor (first_name, last_name, email, phone, first_visit_date, status, how_found, prayer_request, notes)
VALUES
  ('João', 'Silva', 'joao.silva@email.com', '(11) 98765-4321', CURRENT_DATE - INTERVAL '7 days', 'returning', 'friend_invitation', 'Oração pela família', 'Muito interessado em conhecer mais sobre a igreja'),
  ('Maria', 'Santos', 'maria.santos@email.com', '(11) 97654-3210', CURRENT_DATE - INTERVAL '14 days', 'regular', 'social_media', NULL, 'Participou do grupo de jovens'),
  ('Pedro', 'Oliveira', 'pedro.oliveira@email.com', '(11) 96543-2109', CURRENT_DATE - INTERVAL '30 days', 'first_visit', 'passing_by', 'Oração por emprego', 'Primeira visita, gostou muito'),
  ('Ana', 'Costa', 'ana.costa@email.com', '(11) 95432-1098', CURRENT_DATE - INTERVAL '60 days', 'inactive', 'event', NULL, 'Veio no evento de Natal, não retornou'),
  ('Carlos', 'Ferreira', 'carlos.ferreira@email.com', '(11) 94321-0987', CURRENT_DATE - INTERVAL '3 days', 'first_visit', 'google_search', 'Oração pela saúde', 'Muito receptivo, quer voltar');

-- Inserir visitas de exemplo
INSERT INTO visitor_visit (visitor_id, visit_date, notes, was_contacted, contact_date)
SELECT 
  id,
  first_visit_date,
  'Primeira visita',
  TRUE,
  first_visit_date + INTERVAL '1 day'
FROM visitor;

-- Inserir follow-ups de exemplo
INSERT INTO visitor_followup (visitor_id, followup_date, followup_type, description, completed, assigned_to)
SELECT 
  id,
  CURRENT_DATE + INTERVAL '3 days',
  'call',
  'Ligar para agradecer a visita e convidar para próximo culto',
  FALSE,
  NULL
FROM visitor
WHERE status IN ('first_visit', 'returning');

