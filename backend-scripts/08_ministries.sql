-- =====================================================
-- CHURCH 360 - SISTEMA DE MINISTÉRIOS
-- =====================================================
-- Criado em: 13/10/2025
-- Descrição: Tabelas para gerenciar ministérios e escalas
-- =====================================================

-- Enum para função no ministério
CREATE TYPE ministry_role AS ENUM (
  'leader',        -- Líder do ministério
  'coordinator',   -- Coordenador
  'member'         -- Membro
);

-- Tabela de ministérios
CREATE TABLE ministry (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(100) NOT NULL,
  description TEXT,
  color VARCHAR(20) DEFAULT '0xFF2196F3', -- Cor para identificação visual
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES user_account(id) ON DELETE SET NULL
);

-- Tabela de membros do ministério
CREATE TABLE ministry_member (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ministry_id UUID NOT NULL REFERENCES ministry(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES member(id) ON DELETE CASCADE,
  role ministry_role DEFAULT 'member',
  joined_at DATE DEFAULT CURRENT_DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(ministry_id, member_id) -- Um membro não pode estar duplicado no mesmo ministério
);

-- Tabela de escalas (atribuir membros de ministérios para eventos)
CREATE TABLE ministry_schedule (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES event(id) ON DELETE CASCADE,
  ministry_id UUID NOT NULL REFERENCES ministry(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES member(id) ON DELETE CASCADE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES user_account(id) ON DELETE SET NULL,
  UNIQUE(event_id, ministry_id, member_id) -- Evitar duplicatas
);

-- =====================================================
-- ÍNDICES
-- =====================================================

CREATE INDEX idx_ministry_active ON ministry(is_active);
CREATE INDEX idx_ministry_member_ministry ON ministry_member(ministry_id);
CREATE INDEX idx_ministry_member_member ON ministry_member(member_id);
CREATE INDEX idx_ministry_schedule_event ON ministry_schedule(event_id);
CREATE INDEX idx_ministry_schedule_ministry ON ministry_schedule(ministry_id);
CREATE INDEX idx_ministry_schedule_member ON ministry_schedule(member_id);

-- =====================================================
-- TRIGGERS
-- =====================================================

-- Trigger para atualizar updated_at automaticamente
CREATE TRIGGER update_ministry_updated_at
  BEFORE UPDATE ON ministry
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- RLS (ROW LEVEL SECURITY)
-- =====================================================

ALTER TABLE ministry ENABLE ROW LEVEL SECURITY;
ALTER TABLE ministry_member ENABLE ROW LEVEL SECURITY;
ALTER TABLE ministry_schedule ENABLE ROW LEVEL SECURITY;

-- Políticas para ministry
CREATE POLICY "Permitir leitura de ministérios para usuários autenticados"
  ON ministry FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Permitir inserção de ministérios para usuários autenticados"
  ON ministry FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Permitir atualização de ministérios para usuários autenticados"
  ON ministry FOR UPDATE
  TO authenticated
  USING (true);

CREATE POLICY "Permitir exclusão de ministérios para usuários autenticados"
  ON ministry FOR DELETE
  TO authenticated
  USING (true);

-- Políticas para ministry_member
CREATE POLICY "Permitir leitura de membros de ministérios para usuários autenticados"
  ON ministry_member FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Permitir inserção de membros de ministérios para usuários autenticados"
  ON ministry_member FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Permitir atualização de membros de ministérios para usuários autenticados"
  ON ministry_member FOR UPDATE
  TO authenticated
  USING (true);

CREATE POLICY "Permitir exclusão de membros de ministérios para usuários autenticados"
  ON ministry_member FOR DELETE
  TO authenticated
  USING (true);

-- Políticas para ministry_schedule
CREATE POLICY "Permitir leitura de escalas para usuários autenticados"
  ON ministry_schedule FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Permitir inserção de escalas para usuários autenticados"
  ON ministry_schedule FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Permitir atualização de escalas para usuários autenticados"
  ON ministry_schedule FOR UPDATE
  TO authenticated
  USING (true);

CREATE POLICY "Permitir exclusão de escalas para usuários autenticados"
  ON ministry_schedule FOR DELETE
  TO authenticated
  USING (true);

-- =====================================================
-- DADOS DE EXEMPLO (SEED)
-- =====================================================

-- Inserir ministérios de exemplo
INSERT INTO ministry (name, description, color) VALUES
  ('Louvor', 'Ministério de louvor e adoração', '0xFFE91E63'),
  ('Infantil', 'Ministério infantil e escola bíblica', '0xFFFF9800'),
  ('Jovens', 'Ministério de jovens', '0xFF9C27B0'),
  ('Mídia', 'Ministério de mídia e tecnologia', '0xFF2196F3'),
  ('Intercessão', 'Ministério de oração e intercessão', '0xFF4CAF50'),
  ('Recepção', 'Ministério de recepção e hospitalidade', '0xFF00BCD4'),
  ('Dança', 'Ministério de dança e coreografia', '0xFFFF5722');

-- Buscar IDs dos ministérios e membros para relacionar
DO $$
DECLARE
  ministry_louvor_id UUID;
  ministry_infantil_id UUID;
  ministry_jovens_id UUID;
  ministry_midia_id UUID;
  member1_id UUID;
  member2_id UUID;
  member3_id UUID;
  member4_id UUID;
BEGIN
  -- Buscar IDs dos ministérios
  SELECT id INTO ministry_louvor_id FROM ministry WHERE name = 'Louvor' LIMIT 1;
  SELECT id INTO ministry_infantil_id FROM ministry WHERE name = 'Infantil' LIMIT 1;
  SELECT id INTO ministry_jovens_id FROM ministry WHERE name = 'Jovens' LIMIT 1;
  SELECT id INTO ministry_midia_id FROM ministry WHERE name = 'Mídia' LIMIT 1;
  
  -- Buscar IDs de alguns membros
  SELECT id INTO member1_id FROM member WHERE first_name = 'João' LIMIT 1;
  SELECT id INTO member2_id FROM member WHERE first_name = 'Maria' LIMIT 1;
  SELECT id INTO member3_id FROM member WHERE first_name = 'Pedro' LIMIT 1;
  SELECT id INTO member4_id FROM member WHERE first_name = 'Ana' LIMIT 1;
  
  -- Adicionar membros aos ministérios (se os membros existirem)
  IF member1_id IS NOT NULL AND ministry_louvor_id IS NOT NULL THEN
    INSERT INTO ministry_member (ministry_id, member_id, role) 
    VALUES (ministry_louvor_id, member1_id, 'leader');
  END IF;
  
  IF member2_id IS NOT NULL AND ministry_infantil_id IS NOT NULL THEN
    INSERT INTO ministry_member (ministry_id, member_id, role) 
    VALUES (ministry_infantil_id, member2_id, 'leader');
  END IF;
  
  IF member3_id IS NOT NULL AND ministry_jovens_id IS NOT NULL THEN
    INSERT INTO ministry_member (ministry_id, member_id, role) 
    VALUES (ministry_jovens_id, member3_id, 'coordinator');
  END IF;
  
  IF member4_id IS NOT NULL AND ministry_midia_id IS NOT NULL THEN
    INSERT INTO ministry_member (ministry_id, member_id, role) 
    VALUES (ministry_midia_id, member4_id, 'member');
  END IF;
END $$;

-- =====================================================
-- FIM DO SCRIPT
-- =====================================================

