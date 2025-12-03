-- =====================================================
-- Script: 20_support_materials.sql
-- Descrição: Sistema de Material de Apoio
-- =====================================================

-- =====================================================
-- 1. ENUM PARA TIPO DE MATERIAL
-- =====================================================

CREATE TYPE material_type AS ENUM (
  'pdf',           -- Arquivo PDF
  'powerpoint',    -- Apresentação PowerPoint
  'video',         -- Vídeo (URL do YouTube, Vimeo, etc)
  'text',          -- Texto transcrito
  'audio',         -- Áudio
  'link',          -- Link externo
  'other'          -- Outro tipo
);

COMMENT ON TYPE material_type IS 'Tipo de material de apoio';

-- =====================================================
-- 2. ENUM PARA TIPO DE VINCULAÇÃO
-- =====================================================

CREATE TYPE material_link_type AS ENUM (
  'communion_group',  -- Grupos de Comunhão
  'course',           -- Cursos
  'event',            -- Eventos
  'ministry',         -- Ministérios
  'study_group',      -- Grupos de Estudo
  'general'           -- Geral (disponível para todos)
);

COMMENT ON TYPE material_link_type IS 'Tipo de entidade à qual o material está vinculado';

-- =====================================================
-- 3. TABELA PRINCIPAL DE MATERIAIS
-- =====================================================

CREATE TABLE IF NOT EXISTS support_material (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Informações básicas
  title TEXT NOT NULL,
  description TEXT,
  author TEXT, -- Autor do material
  
  -- Tipo e conteúdo
  material_type material_type NOT NULL DEFAULT 'text',
  
  -- Arquivo (se for PDF, PowerPoint, etc)
  file_url TEXT, -- URL do arquivo no storage
  file_name TEXT,
  file_size BIGINT, -- Tamanho em bytes
  
  -- Vídeo (se for vídeo)
  video_url TEXT, -- URL do YouTube, Vimeo, etc
  video_duration INTEGER, -- Duração em segundos
  
  -- Texto transcrito (se for texto)
  content TEXT, -- Conteúdo transcrito
  
  -- Link externo (se for link)
  external_link TEXT,
  
  -- Organização
  category TEXT, -- Categoria do material (ex: "Discipulado", "Batismo", etc)
  tags TEXT[], -- Tags para busca
  
  -- Status
  is_active BOOLEAN DEFAULT true,
  is_public BOOLEAN DEFAULT false, -- Se é público ou restrito
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES user_account(id) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID REFERENCES user_account(id) ON DELETE SET NULL
);

COMMENT ON TABLE support_material IS 'Materiais de apoio (PDFs, vídeos, textos, etc)';
COMMENT ON COLUMN support_material.material_type IS 'Tipo do material (pdf, video, text, etc)';
COMMENT ON COLUMN support_material.file_url IS 'URL do arquivo no Supabase Storage';
COMMENT ON COLUMN support_material.video_url IS 'URL do vídeo (YouTube, Vimeo, etc)';
COMMENT ON COLUMN support_material.content IS 'Conteúdo transcrito (se material_type = text)';
COMMENT ON COLUMN support_material.is_public IS 'Se true, disponível para todos; se false, apenas para vinculações específicas';

-- Índices
CREATE INDEX IF NOT EXISTS idx_support_material_type ON support_material(material_type);
CREATE INDEX IF NOT EXISTS idx_support_material_category ON support_material(category);
CREATE INDEX IF NOT EXISTS idx_support_material_is_active ON support_material(is_active);
CREATE INDEX IF NOT EXISTS idx_support_material_created_at ON support_material(created_at);

-- =====================================================
-- 4. TABELA DE MÓDULOS/CAPÍTULOS
-- =====================================================

CREATE TABLE IF NOT EXISTS support_material_module (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  material_id UUID NOT NULL REFERENCES support_material(id) ON DELETE CASCADE,
  
  -- Informações do módulo
  title TEXT NOT NULL, -- Ex: "Tema 1: Salvação"
  description TEXT,
  order_index INTEGER NOT NULL DEFAULT 0, -- Ordem do módulo
  
  -- Conteúdo do módulo
  content TEXT, -- Conteúdo transcrito do módulo
  
  -- Arquivo específico do módulo (opcional)
  file_url TEXT,
  file_name TEXT,
  
  -- Vídeo específico do módulo (opcional)
  video_url TEXT,
  video_duration INTEGER,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES user_account(id) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID REFERENCES user_account(id) ON DELETE SET NULL
);

COMMENT ON TABLE support_material_module IS 'Módulos/capítulos de um material de apoio';
COMMENT ON COLUMN support_material_module.order_index IS 'Ordem de exibição do módulo';
COMMENT ON COLUMN support_material_module.content IS 'Conteúdo transcrito do módulo';
COMMENT ON COLUMN support_material_module.video_url IS 'URL do vídeo específico deste módulo';

-- Índices
CREATE INDEX IF NOT EXISTS idx_support_material_module_material ON support_material_module(material_id);
CREATE INDEX IF NOT EXISTS idx_support_material_module_order ON support_material_module(material_id, order_index);

-- =====================================================
-- 5. TABELA DE VINCULAÇÃO
-- =====================================================

CREATE TABLE IF NOT EXISTS support_material_link (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  material_id UUID NOT NULL REFERENCES support_material(id) ON DELETE CASCADE,
  
  -- Tipo de vinculação
  link_type material_link_type NOT NULL,
  
  -- ID da entidade vinculada (pode ser grupo, curso, evento, etc)
  linked_entity_id UUID NOT NULL,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES user_account(id) ON DELETE SET NULL,
  
  -- Constraint para evitar duplicatas
  UNIQUE(material_id, link_type, linked_entity_id)
);

COMMENT ON TABLE support_material_link IS 'Vinculação de materiais com grupos, cursos, eventos, etc';
COMMENT ON COLUMN support_material_link.link_type IS 'Tipo de entidade vinculada (communion_group, course, event, etc)';
COMMENT ON COLUMN support_material_link.linked_entity_id IS 'ID da entidade vinculada (group.id, course.id, etc)';

-- Índices
CREATE INDEX IF NOT EXISTS idx_support_material_link_material ON support_material_link(material_id);
CREATE INDEX IF NOT EXISTS idx_support_material_link_type ON support_material_link(link_type);
CREATE INDEX IF NOT EXISTS idx_support_material_link_entity ON support_material_link(linked_entity_id);
CREATE INDEX IF NOT EXISTS idx_support_material_link_type_entity ON support_material_link(link_type, linked_entity_id);

-- =====================================================
-- 6. TRIGGER PARA UPDATED_AT
-- =====================================================

CREATE OR REPLACE FUNCTION update_support_material_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_support_material_updated_at
  BEFORE UPDATE ON support_material
  FOR EACH ROW
  EXECUTE FUNCTION update_support_material_updated_at();

CREATE TRIGGER trigger_support_material_module_updated_at
  BEFORE UPDATE ON support_material_module
  FOR EACH ROW
  EXECUTE FUNCTION update_support_material_updated_at();

-- =====================================================
-- 7. RLS POLICIES (Row Level Security)
-- =====================================================

-- Habilitar RLS
ALTER TABLE support_material ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_material_module ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_material_link ENABLE ROW LEVEL SECURITY;

-- Políticas para support_material
CREATE POLICY "Todos podem ver materiais ativos"
  ON support_material FOR SELECT
  USING (is_active = true AND (is_public = true OR auth.uid() IS NOT NULL));

CREATE POLICY "Usuários autenticados podem criar materiais"
  ON support_material FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Criador pode atualizar seu material"
  ON support_material FOR UPDATE
  USING (created_by = auth.uid());

CREATE POLICY "Criador pode deletar seu material"
  ON support_material FOR DELETE
  USING (created_by = auth.uid());

-- Políticas para support_material_module
CREATE POLICY "Todos podem ver módulos de materiais ativos"
  ON support_material_module FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM support_material
      WHERE support_material.id = support_material_module.material_id
      AND support_material.is_active = true
    )
  );

CREATE POLICY "Usuários autenticados podem criar módulos"
  ON support_material_module FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Criador pode atualizar módulos"
  ON support_material_module FOR UPDATE
  USING (created_by = auth.uid());

CREATE POLICY "Criador pode deletar módulos"
  ON support_material_module FOR DELETE
  USING (created_by = auth.uid());

-- Políticas para support_material_link
CREATE POLICY "Todos podem ver vinculações"
  ON support_material_link FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Usuários autenticados podem criar vinculações"
  ON support_material_link FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Criador pode deletar vinculações"
  ON support_material_link FOR DELETE
  USING (created_by = auth.uid());

-- =====================================================
-- 8. DADOS DE EXEMPLO (OPCIONAL)
-- =====================================================

-- Exemplo de material: Leitinho na Fé
-- INSERT INTO support_material (title, description, material_type, category, is_public)
-- VALUES (
--   'Leitinho na Fé',
--   'Material de discipulado para novos convertidos',
--   'text',
--   'Discipulado',
--   true
-- );

-- =====================================================
-- FIM DO SCRIPT
-- =====================================================

