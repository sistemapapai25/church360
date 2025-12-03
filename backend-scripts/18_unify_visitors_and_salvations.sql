-- =====================================================
-- Script: 18_unify_visitors_and_salvations.sql
-- Descrição: Unificar visitantes e salvações em uma única tabela
-- =====================================================

-- =====================================================
-- 1. ADICIONAR CAMPOS DE SALVAÇÃO NA TABELA GROUP_VISITOR
-- =====================================================

-- Adicionar campo is_salvation (indica se é uma salvação)
ALTER TABLE group_visitor 
ADD COLUMN IF NOT EXISTS is_salvation BOOLEAN DEFAULT false;

COMMENT ON COLUMN group_visitor.is_salvation IS 'Indica se este visitante teve uma experiência de salvação';

-- Adicionar campos de salvação
ALTER TABLE group_visitor 
ADD COLUMN IF NOT EXISTS salvation_date DATE;

COMMENT ON COLUMN group_visitor.salvation_date IS 'Data da salvação (se is_salvation = true)';

ALTER TABLE group_visitor 
ADD COLUMN IF NOT EXISTS testimony TEXT;

COMMENT ON COLUMN group_visitor.testimony IS 'Testemunho breve da salvação';

-- Adicionar campos de batismo
ALTER TABLE group_visitor 
ADD COLUMN IF NOT EXISTS wants_baptism BOOLEAN DEFAULT false;

COMMENT ON COLUMN group_visitor.wants_baptism IS 'Se deseja ser batizado';

ALTER TABLE group_visitor 
ADD COLUMN IF NOT EXISTS baptism_event_id UUID REFERENCES event(id) ON DELETE SET NULL;

COMMENT ON COLUMN group_visitor.baptism_event_id IS 'Evento de batismo ao qual foi inscrito';

ALTER TABLE group_visitor 
ADD COLUMN IF NOT EXISTS baptism_course_id UUID;

COMMENT ON COLUMN group_visitor.baptism_course_id IS 'Curso de batismo ao qual foi inscrito';

-- Adicionar campos de discipulado
ALTER TABLE group_visitor 
ADD COLUMN IF NOT EXISTS wants_discipleship BOOLEAN DEFAULT false;

COMMENT ON COLUMN group_visitor.wants_discipleship IS 'Se deseja fazer discipulado';

ALTER TABLE group_visitor 
ADD COLUMN IF NOT EXISTS discipleship_course_id UUID;

COMMENT ON COLUMN group_visitor.discipleship_course_id IS 'Curso de discipulado ao qual foi inscrito';

ALTER TABLE group_visitor 
ADD COLUMN IF NOT EXISTS assigned_mentor_id UUID REFERENCES member(id) ON DELETE SET NULL;

COMMENT ON COLUMN group_visitor.assigned_mentor_id IS 'Mentor/discipulador designado';

-- Adicionar campos de acompanhamento
ALTER TABLE group_visitor 
ADD COLUMN IF NOT EXISTS follow_up_status TEXT DEFAULT 'pending';

COMMENT ON COLUMN group_visitor.follow_up_status IS 'Status de acompanhamento: pending, in_progress, completed';

ALTER TABLE group_visitor 
ADD COLUMN IF NOT EXISTS last_contact_date DATE;

COMMENT ON COLUMN group_visitor.last_contact_date IS 'Data do último contato de acompanhamento';

-- =====================================================
-- 2. MIGRAR DADOS DA TABELA SALVATION_RECORD PARA GROUP_VISITOR
-- =====================================================

-- Inserir registros de salvação como visitantes
INSERT INTO group_visitor (
  id,
  meeting_id,
  name,
  phone,
  email,
  address,
  age,
  gender,
  is_salvation,
  salvation_date,
  testimony,
  wants_baptism,
  wants_discipleship,
  assigned_mentor_id,
  follow_up_status,
  last_contact_date,
  notes,
  created_at,
  created_by
)
SELECT 
  id,
  meeting_id,
  name,
  phone,
  email,
  address,
  age,
  gender,
  true as is_salvation,
  salvation_date,
  testimony,
  wants_baptism,
  wants_discipleship,
  assigned_mentor_id,
  follow_up_status,
  last_contact_date,
  notes,
  created_at,
  created_by
FROM salvation_record
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- 3. REMOVER TABELA SALVATION_RECORD
-- =====================================================

DROP TABLE IF EXISTS salvation_record CASCADE;

-- =====================================================
-- 4. CRIAR ÍNDICES PARA PERFORMANCE
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_group_visitor_is_salvation ON group_visitor(is_salvation);
CREATE INDEX IF NOT EXISTS idx_group_visitor_salvation_date ON group_visitor(salvation_date);
CREATE INDEX IF NOT EXISTS idx_group_visitor_wants_baptism ON group_visitor(wants_baptism);
CREATE INDEX IF NOT EXISTS idx_group_visitor_wants_discipleship ON group_visitor(wants_discipleship);
CREATE INDEX IF NOT EXISTS idx_group_visitor_follow_up_status ON group_visitor(follow_up_status);

-- =====================================================
-- 5. ATUALIZAR RLS POLICIES (se necessário)
-- =====================================================

-- As políticas RLS já existentes devem continuar funcionando
-- pois estamos apenas adicionando colunas à tabela existente

-- =====================================================
-- FIM DO SCRIPT
-- =====================================================

