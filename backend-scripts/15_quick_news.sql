-- =====================================================
-- CHURCH 360 - SISTEMA DE AVISOS RÁPIDOS (FIQUE POR DENTRO)
-- =====================================================
-- Descrição: Sistema de avisos e notícias rápidas para a home
-- Features: CRUD de avisos, prioridade, expiração
-- =====================================================

-- =====================================================
-- 1. TABELA: quick_news
-- =====================================================

CREATE TABLE IF NOT EXISTS quick_news (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Informações do aviso
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  
  -- Imagem (opcional)
  image_url TEXT,
  
  -- Link externo (opcional)
  link_url TEXT,
  
  -- Prioridade (para ordenação)
  priority INTEGER DEFAULT 0, -- Maior = mais importante
  
  -- Status
  is_active BOOLEAN NOT NULL DEFAULT true,
  
  -- Data de expiração (opcional)
  expires_at TIMESTAMPTZ,
  
  -- Autor
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Datas
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT quick_news_title_not_empty CHECK (LENGTH(TRIM(title)) > 0),
  CONSTRAINT quick_news_description_not_empty CHECK (LENGTH(TRIM(description)) > 0)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_quick_news_is_active ON quick_news(is_active);
CREATE INDEX IF NOT EXISTS idx_quick_news_priority ON quick_news(priority DESC);
CREATE INDEX IF NOT EXISTS idx_quick_news_created_at ON quick_news(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_quick_news_expires_at ON quick_news(expires_at);

-- =====================================================
-- 2. RLS (ROW LEVEL SECURITY)
-- =====================================================

-- Habilitar RLS
ALTER TABLE quick_news ENABLE ROW LEVEL SECURITY;

-- Policy: Todos podem visualizar avisos ativos e não expirados
CREATE POLICY "quick_news_select_public" ON quick_news
  FOR SELECT
  USING (
    is_active = true 
    AND (expires_at IS NULL OR expires_at > NOW())
  );

-- Policy: Apenas admins podem inserir
CREATE POLICY "quick_news_insert_admin" ON quick_news
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_account
      WHERE user_account.id = auth.uid()
      AND user_account.role_global IN ('admin', 'owner', 'leader')
    )
  );

-- Policy: Apenas admins podem atualizar
CREATE POLICY "quick_news_update_admin" ON quick_news
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_account
      WHERE user_account.id = auth.uid()
      AND user_account.role_global IN ('admin', 'owner', 'leader')
    )
  );

-- Policy: Apenas admins podem deletar
CREATE POLICY "quick_news_delete_admin" ON quick_news
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_account
      WHERE user_account.id = auth.uid()
      AND user_account.role_global IN ('admin', 'owner', 'leader')
    )
  );

-- =====================================================
-- 3. TRIGGER: updated_at
-- =====================================================

CREATE OR REPLACE FUNCTION update_quick_news_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_quick_news_updated_at
  BEFORE UPDATE ON quick_news
  FOR EACH ROW
  EXECUTE FUNCTION update_quick_news_updated_at();

-- =====================================================
-- FIM DO SCRIPT
-- =====================================================

