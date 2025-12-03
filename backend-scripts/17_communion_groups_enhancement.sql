-- =====================================================
-- Script: 17_communion_groups_enhancement.sql
-- Descrição: Melhorias para Grupos de Comunhão (Células)
-- Adiciona: Anfitrião, Material, Visitantes, Almas Salvas
-- =====================================================

-- =====================================================
-- 1. ADICIONAR CAMPO DE ANFITRIÃO NA TABELA GROUP
-- =====================================================

-- Adicionar coluna host_id (anfitrião da casa)
ALTER TABLE "group" 
ADD COLUMN IF NOT EXISTS host_id UUID REFERENCES member(id) ON DELETE SET NULL;

COMMENT ON COLUMN "group".host_id IS 'Anfitrião que abriu a casa para o grupo (pode ser o mesmo que o líder)';

-- =====================================================
-- 2. ADICIONAR CAMPO DE MATERIAL NA TABELA GROUP_MEETING
-- =====================================================

-- Adicionar coluna material_url (material ministrado)
ALTER TABLE group_meeting 
ADD COLUMN IF NOT EXISTS material_url TEXT;

COMMENT ON COLUMN group_meeting.material_url IS 'URL do material ministrado na reunião (PDF, imagem, etc.)';

-- Adicionar coluna material_title (título do material)
ALTER TABLE group_meeting 
ADD COLUMN IF NOT EXISTS material_title TEXT;

COMMENT ON COLUMN group_meeting.material_title IS 'Título do material ministrado';

-- =====================================================
-- 3. CRIAR TABELA DE VISITANTES
-- =====================================================

CREATE TABLE IF NOT EXISTS group_visitor (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  meeting_id UUID NOT NULL REFERENCES group_meeting(id) ON DELETE CASCADE,
  
  -- Dados do visitante
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  address TEXT,
  
  -- Informações adicionais
  age INTEGER,
  gender TEXT,
  how_found_us TEXT, -- Como conheceu o grupo
  
  -- Interesse
  wants_contact BOOLEAN DEFAULT true,
  wants_to_return BOOLEAN DEFAULT false,
  notes TEXT,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES user_account(id) ON DELETE SET NULL
);

COMMENT ON TABLE group_visitor IS 'Visitantes que participaram de reuniões de grupos';
COMMENT ON COLUMN group_visitor.how_found_us IS 'Como o visitante conheceu o grupo (indicação, redes sociais, etc.)';
COMMENT ON COLUMN group_visitor.wants_contact IS 'Se o visitante deseja ser contatado';
COMMENT ON COLUMN group_visitor.wants_to_return IS 'Se o visitante demonstrou interesse em retornar';

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_group_visitor_meeting ON group_visitor(meeting_id);
CREATE INDEX IF NOT EXISTS idx_group_visitor_created_at ON group_visitor(created_at);

-- =====================================================
-- 4. CRIAR TABELA DE ALMAS SALVAS
-- =====================================================

CREATE TABLE IF NOT EXISTS salvation_record (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  meeting_id UUID NOT NULL REFERENCES group_meeting(id) ON DELETE CASCADE,
  
  -- Dados da pessoa
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  address TEXT,
  age INTEGER,
  gender TEXT,
  
  -- Informações da salvação
  salvation_date DATE NOT NULL DEFAULT CURRENT_DATE,
  testimony TEXT, -- Testemunho breve
  
  -- Acompanhamento
  wants_baptism BOOLEAN DEFAULT false,
  wants_discipleship BOOLEAN DEFAULT false,
  assigned_mentor_id UUID REFERENCES member(id) ON DELETE SET NULL,
  
  -- Status de acompanhamento
  follow_up_status TEXT DEFAULT 'pending', -- pending, in_progress, completed
  last_contact_date DATE,
  notes TEXT,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES user_account(id) ON DELETE SET NULL
);

COMMENT ON TABLE salvation_record IS 'Registro de almas salvas nos grupos de comunhão';
COMMENT ON COLUMN salvation_record.salvation_date IS 'Data em que a pessoa aceitou Jesus';
COMMENT ON COLUMN salvation_record.assigned_mentor_id IS 'Membro designado para acompanhar a pessoa';
COMMENT ON COLUMN salvation_record.follow_up_status IS 'Status do acompanhamento: pending, in_progress, completed';

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_salvation_record_meeting ON salvation_record(meeting_id);
CREATE INDEX IF NOT EXISTS idx_salvation_record_date ON salvation_record(salvation_date);
CREATE INDEX IF NOT EXISTS idx_salvation_record_status ON salvation_record(follow_up_status);
CREATE INDEX IF NOT EXISTS idx_salvation_record_mentor ON salvation_record(assigned_mentor_id);

-- =====================================================
-- 5. ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Habilitar RLS nas novas tabelas
ALTER TABLE group_visitor ENABLE ROW LEVEL SECURITY;
ALTER TABLE salvation_record ENABLE ROW LEVEL SECURITY;

-- Políticas para group_visitor
CREATE POLICY "Usuários autenticados podem ver visitantes"
  ON group_visitor FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Usuários autenticados podem inserir visitantes"
  ON group_visitor FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Usuários autenticados podem atualizar visitantes"
  ON group_visitor FOR UPDATE
  TO authenticated
  USING (true);

CREATE POLICY "Usuários autenticados podem deletar visitantes"
  ON group_visitor FOR DELETE
  TO authenticated
  USING (true);

-- Políticas para salvation_record
CREATE POLICY "Usuários autenticados podem ver registros de salvação"
  ON salvation_record FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Usuários autenticados podem inserir registros de salvação"
  ON salvation_record FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Usuários autenticados podem atualizar registros de salvação"
  ON salvation_record FOR UPDATE
  TO authenticated
  USING (true);

CREATE POLICY "Usuários autenticados podem deletar registros de salvação"
  ON salvation_record FOR DELETE
  TO authenticated
  USING (true);

-- =====================================================
-- 6. TRIGGERS PARA UPDATED_AT
-- =====================================================

-- Trigger para atualizar updated_at na tabela group
CREATE OR REPLACE FUNCTION update_group_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_group_updated_at ON "group";
CREATE TRIGGER trigger_update_group_updated_at
  BEFORE UPDATE ON "group"
  FOR EACH ROW
  EXECUTE FUNCTION update_group_updated_at();

-- =====================================================
-- 7. DADOS DE EXEMPLO (OPCIONAL)
-- =====================================================

-- Exemplo de grupo com líder e anfitrião diferentes
-- UPDATE "group" 
-- SET host_id = (SELECT id FROM member WHERE first_name = 'Maria' LIMIT 1)
-- WHERE name = 'Célula Jovens - Centro';

-- =====================================================
-- FIM DO SCRIPT
-- =====================================================

-- Verificar estrutura
SELECT 
  'group' as table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'group'
  AND column_name IN ('host_id')
ORDER BY ordinal_position;

SELECT 
  'group_meeting' as table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'group_meeting'
  AND column_name IN ('material_url', 'material_title')
ORDER BY ordinal_position;

SELECT 
  table_name,
  COUNT(*) as column_count
FROM information_schema.columns
WHERE table_name IN ('group_visitor', 'salvation_record')
GROUP BY table_name;

