-- =====================================================
-- CHURCH 360 - SISTEMA DE TESTEMUNHOS
-- =====================================================
-- Descrição: Sistema de testemunhos independentes
-- Features: CRUD de testemunhos, privacidade, contato WhatsApp
-- =====================================================

-- =====================================================
-- 1. TABELA: testimonies
-- =====================================================

CREATE TABLE IF NOT EXISTS testimonies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Informações do testemunho
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  
  -- Autor
  author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Privacidade e contato
  is_public BOOLEAN NOT NULL DEFAULT true,
  allow_whatsapp_contact BOOLEAN NOT NULL DEFAULT false,
  
  -- Datas
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT testimonies_title_not_empty CHECK (LENGTH(TRIM(title)) > 0),
  CONSTRAINT testimonies_description_not_empty CHECK (LENGTH(TRIM(description)) > 0)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_testimonies_author_id ON testimonies(author_id);
CREATE INDEX IF NOT EXISTS idx_testimonies_created_at ON testimonies(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_testimonies_is_public ON testimonies(is_public);

-- =====================================================
-- 2. ADICIONAR CAMPOS EM prayer_requests
-- =====================================================

-- Adicionar campo allow_whatsapp_contact
ALTER TABLE prayer_requests 
ADD COLUMN IF NOT EXISTS allow_whatsapp_contact BOOLEAN NOT NULL DEFAULT false;

-- Adicionar campo is_public (simplificado, além do privacy)
ALTER TABLE prayer_requests 
ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT true;

-- =====================================================
-- 3. TRIGGERS
-- =====================================================

-- Trigger: Atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_testimonies_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_testimonies_updated_at ON testimonies;
CREATE TRIGGER trigger_update_testimonies_updated_at
  BEFORE UPDATE ON testimonies
  FOR EACH ROW
  EXECUTE FUNCTION update_testimonies_updated_at();

-- =====================================================
-- 4. RLS POLICIES: testimonies
-- =====================================================

-- Habilitar RLS
ALTER TABLE testimonies ENABLE ROW LEVEL SECURITY;

-- Policy: Ver testemunhos PÚBLICOS
DROP POLICY IF EXISTS "Todos podem ver testemunhos públicos" ON testimonies;
CREATE POLICY "Todos podem ver testemunhos públicos"
  ON testimonies
  FOR SELECT
  USING (is_public = true);

-- Policy: Ver PRÓPRIOS testemunhos (públicos ou privados)
DROP POLICY IF EXISTS "Usuários podem ver próprios testemunhos" ON testimonies;
CREATE POLICY "Usuários podem ver próprios testemunhos"
  ON testimonies
  FOR SELECT
  USING (auth.uid() = author_id);

-- Policy: Criar testemunhos
DROP POLICY IF EXISTS "Usuários autenticados podem criar testemunhos" ON testimonies;
CREATE POLICY "Usuários autenticados podem criar testemunhos"
  ON testimonies
  FOR INSERT
  WITH CHECK (auth.uid() = author_id);

-- Policy: Atualizar PRÓPRIOS testemunhos
DROP POLICY IF EXISTS "Usuários podem atualizar próprios testemunhos" ON testimonies;
CREATE POLICY "Usuários podem atualizar próprios testemunhos"
  ON testimonies
  FOR UPDATE
  USING (auth.uid() = author_id)
  WITH CHECK (auth.uid() = author_id);

-- Policy: Deletar PRÓPRIOS testemunhos
DROP POLICY IF EXISTS "Usuários podem deletar próprios testemunhos" ON testimonies;
CREATE POLICY "Usuários podem deletar próprios testemunhos"
  ON testimonies
  FOR DELETE
  USING (auth.uid() = author_id);

-- =====================================================
-- 5. FUNÇÕES ÚTEIS
-- =====================================================

-- Função: Obter testemunhos públicos recentes
CREATE OR REPLACE FUNCTION get_recent_public_testimonies(limit_count INT DEFAULT 10)
RETURNS TABLE (
  id UUID,
  title TEXT,
  description TEXT,
  author_id UUID,
  allow_whatsapp_contact BOOLEAN,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    t.id,
    t.title,
    t.description,
    t.author_id,
    t.allow_whatsapp_contact,
    t.created_at
  FROM testimonies t
  WHERE t.is_public = true
  ORDER BY t.created_at DESC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função: Contar testemunhos por usuário
CREATE OR REPLACE FUNCTION count_user_testimonies(user_id UUID)
RETURNS INT AS $$
DECLARE
  total_count INT;
BEGIN
  SELECT COUNT(*)::INT INTO total_count
  FROM testimonies
  WHERE author_id = user_id;
  
  RETURN total_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 6. COMENTÁRIOS
-- =====================================================

COMMENT ON TABLE testimonies IS 'Testemunhos independentes dos membros';
COMMENT ON COLUMN testimonies.is_public IS 'Se true, todos podem ver. Se false, apenas o autor';
COMMENT ON COLUMN testimonies.allow_whatsapp_contact IS 'Se true, permite contato via WhatsApp';
COMMENT ON COLUMN prayer_requests.allow_whatsapp_contact IS 'Se true, permite contato via WhatsApp';
COMMENT ON COLUMN prayer_requests.is_public IS 'Simplificação do campo privacy para facilitar queries';

