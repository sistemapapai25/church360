-- =====================================================
-- UNIFICAR TODOS OS VISITANTES EM UMA ÚNICA TABELA
-- =====================================================
-- Este script unifica visitantes da igreja e visitantes de grupos
-- em uma única tabela 'visitor' com campos adicionais

-- 1. Criar enum para origem do visitante
CREATE TYPE visitor_source AS ENUM (
  'church',           -- Veio da igreja (culto)
  'house',            -- Veio da casa (reunião de grupo)
  'evangelism',       -- Evangelismo de rua
  'event',            -- Evento especial
  'online',           -- Online (redes sociais, site)
  'other'             -- Outro
);

-- 2. Adicionar novos campos na tabela visitor
ALTER TABLE visitor
  -- Origem do visitante
  ADD COLUMN visitor_source visitor_source DEFAULT 'church',
  
  -- Vinculação com reunião de grupo (se veio de uma reunião)
  ADD COLUMN meeting_id UUID REFERENCES group_meeting(id) ON DELETE SET NULL,
  
  -- Campos de salvação
  ADD COLUMN is_salvation BOOLEAN DEFAULT false,
  ADD COLUMN salvation_date DATE,
  ADD COLUMN testimony TEXT,
  
  -- Campos de batismo
  ADD COLUMN wants_baptism BOOLEAN DEFAULT false,
  ADD COLUMN baptism_event_id UUID, -- Será vinculado quando criar evento
  ADD COLUMN baptism_course_id UUID, -- Será vinculado quando criar curso
  
  -- Campos de discipulado
  ADD COLUMN wants_discipleship BOOLEAN DEFAULT false,
  ADD COLUMN discipleship_course_id UUID, -- Será vinculado quando criar curso
  ADD COLUMN assigned_mentor_id UUID REFERENCES member(id) ON DELETE SET NULL,
  
  -- Campos de acompanhamento
  ADD COLUMN follow_up_status TEXT DEFAULT 'pending', -- pending, in_progress, completed
  ADD COLUMN last_contact_date DATE,
  
  -- Campos adicionais para compatibilidade com group_visitor
  ADD COLUMN age INTEGER,
  ADD COLUMN gender VARCHAR(1), -- M, F
  ADD COLUMN how_found_us TEXT, -- Como conheceu (texto livre para grupos)
  ADD COLUMN wants_contact BOOLEAN DEFAULT true,
  ADD COLUMN wants_to_return BOOLEAN DEFAULT false;

-- 3. Criar índices para os novos campos
CREATE INDEX idx_visitor_source ON visitor(visitor_source);
CREATE INDEX idx_visitor_meeting_id ON visitor(meeting_id);
CREATE INDEX idx_visitor_is_salvation ON visitor(is_salvation);
CREATE INDEX idx_visitor_salvation_date ON visitor(salvation_date);
CREATE INDEX idx_visitor_wants_baptism ON visitor(wants_baptism);
CREATE INDEX idx_visitor_wants_discipleship ON visitor(wants_discipleship);
CREATE INDEX idx_visitor_assigned_mentor_id ON visitor(assigned_mentor_id);
CREATE INDEX idx_visitor_follow_up_status ON visitor(follow_up_status);

-- 4. Migrar dados de group_visitor para visitor
-- Primeiro, vamos inserir os visitantes de grupos que não existem na tabela visitor
INSERT INTO visitor (
  first_name,
  last_name,
  email,
  phone,
  address,
  age,
  gender,
  first_visit_date,
  status,
  how_found_us,
  notes,
  visitor_source,
  meeting_id,
  is_salvation,
  salvation_date,
  testimony,
  wants_baptism,
  baptism_event_id,
  baptism_course_id,
  wants_discipleship,
  discipleship_course_id,
  assigned_mentor_id,
  follow_up_status,
  last_contact_date,
  wants_contact,
  wants_to_return,
  created_at,
  created_by
)
SELECT 
  -- Separar nome completo em first_name e last_name
  SPLIT_PART(gv.name, ' ', 1) as first_name,
  CASE 
    WHEN ARRAY_LENGTH(STRING_TO_ARRAY(gv.name, ' '), 1) > 1 
    THEN SUBSTRING(gv.name FROM POSITION(' ' IN gv.name) + 1)
    ELSE ''
  END as last_name,
  gv.email,
  gv.phone,
  gv.address,
  gv.age,
  gv.gender,
  gv.created_at::date as first_visit_date,
  CASE 
    WHEN gv.is_salvation THEN 'converted'::visitor_status
    WHEN gv.wants_to_return THEN 'returning'::visitor_status
    ELSE 'first_visit'::visitor_status
  END as status,
  gv.how_found_us,
  gv.notes,
  'house'::visitor_source as visitor_source,
  gv.meeting_id,
  gv.is_salvation,
  gv.salvation_date,
  gv.testimony,
  gv.wants_baptism,
  gv.baptism_event_id,
  gv.baptism_course_id,
  gv.wants_discipleship,
  gv.discipleship_course_id,
  gv.assigned_mentor_id,
  gv.follow_up_status,
  gv.last_contact_date,
  gv.wants_contact,
  gv.wants_to_return,
  gv.created_at,
  gv.created_by
FROM group_visitor gv;

-- 5. Remover tabela group_visitor (após confirmar que os dados foram migrados)
-- IMPORTANTE: Só execute isso após verificar que os dados foram migrados corretamente!
DROP TABLE IF EXISTS group_visitor CASCADE;

-- 6. Comentários nas colunas para documentação
COMMENT ON COLUMN visitor.visitor_source IS 'Origem do visitante: church (igreja), house (casa/grupo), evangelism, event, online, other';
COMMENT ON COLUMN visitor.meeting_id IS 'ID da reunião de grupo (se veio de uma reunião de grupo de comunhão)';
COMMENT ON COLUMN visitor.is_salvation IS 'Indica se esta pessoa aceitou Jesus como salvador';
COMMENT ON COLUMN visitor.salvation_date IS 'Data em que a pessoa aceitou Jesus';
COMMENT ON COLUMN visitor.testimony IS 'Testemunho da salvação';
COMMENT ON COLUMN visitor.wants_baptism IS 'Indica se a pessoa deseja ser batizada';
COMMENT ON COLUMN visitor.baptism_event_id IS 'ID do evento de batismo (quando agendado)';
COMMENT ON COLUMN visitor.baptism_course_id IS 'ID do curso de batismo (quando inscrito)';
COMMENT ON COLUMN visitor.wants_discipleship IS 'Indica se a pessoa deseja fazer discipulado';
COMMENT ON COLUMN visitor.discipleship_course_id IS 'ID do curso de discipulado (quando inscrito)';
COMMENT ON COLUMN visitor.assigned_mentor_id IS 'ID do mentor/discipulador responsável';
COMMENT ON COLUMN visitor.follow_up_status IS 'Status do acompanhamento: pending, in_progress, completed';
COMMENT ON COLUMN visitor.last_contact_date IS 'Data do último contato com a pessoa';
COMMENT ON COLUMN visitor.age IS 'Idade da pessoa';
COMMENT ON COLUMN visitor.gender IS 'Gênero: M (masculino), F (feminino)';
COMMENT ON COLUMN visitor.how_found_us IS 'Como conheceu (texto livre)';
COMMENT ON COLUMN visitor.wants_contact IS 'Deseja ser contatado';
COMMENT ON COLUMN visitor.wants_to_return IS 'Demonstrou interesse em retornar';

-- 7. Atualizar visitor_source dos visitantes existentes para 'church'
UPDATE visitor 
SET visitor_source = 'church'::visitor_source
WHERE visitor_source IS NULL;

COMMIT;

