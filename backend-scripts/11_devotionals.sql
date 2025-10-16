-- =====================================================
-- CHURCH 360 - SISTEMA DE DEVOCIONAIS DIÁRIOS
-- =====================================================
-- Descrição: Sistema de devocionais diários com leituras
-- Features: CRUD de devocionais, histórico de leituras,
--           anotações pessoais, estatísticas
-- =====================================================

-- =====================================================
-- 1. TABELA: devotionals
-- =====================================================

CREATE TABLE IF NOT EXISTS devotionals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Informações do devocional
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  scripture_reference TEXT, -- Ex: "João 3:16-17"
  devotional_date DATE NOT NULL,
  
  -- Autor e publicação
  author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  is_published BOOLEAN DEFAULT false,
  
  -- Metadados
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Índices
  CONSTRAINT devotionals_date_unique UNIQUE (devotional_date)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_devotionals_date ON devotionals(devotional_date DESC);
CREATE INDEX IF NOT EXISTS idx_devotionals_author ON devotionals(author_id);
CREATE INDEX IF NOT EXISTS idx_devotionals_published ON devotionals(is_published);

-- =====================================================
-- 2. TABELA: devotional_readings
-- =====================================================

CREATE TABLE IF NOT EXISTS devotional_readings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Relacionamentos
  devotional_id UUID NOT NULL REFERENCES devotionals(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Informações da leitura
  read_at TIMESTAMPTZ DEFAULT NOW(),
  notes TEXT, -- Anotações pessoais do usuário
  
  -- Metadados
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraint: um usuário só pode marcar como lido uma vez
  CONSTRAINT devotional_readings_unique UNIQUE (devotional_id, user_id)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_devotional_readings_devotional ON devotional_readings(devotional_id);
CREATE INDEX IF NOT EXISTS idx_devotional_readings_user ON devotional_readings(user_id);
CREATE INDEX IF NOT EXISTS idx_devotional_readings_date ON devotional_readings(read_at DESC);

-- =====================================================
-- 3. TRIGGERS: updated_at
-- =====================================================

-- Trigger para devotionals
CREATE OR REPLACE FUNCTION update_devotionals_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_devotionals_updated_at ON devotionals;
CREATE TRIGGER trigger_update_devotionals_updated_at
  BEFORE UPDATE ON devotionals
  FOR EACH ROW
  EXECUTE FUNCTION update_devotionals_updated_at();

-- Trigger para devotional_readings
CREATE OR REPLACE FUNCTION update_devotional_readings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_devotional_readings_updated_at ON devotional_readings;
CREATE TRIGGER trigger_update_devotional_readings_updated_at
  BEFORE UPDATE ON devotional_readings
  FOR EACH ROW
  EXECUTE FUNCTION update_devotional_readings_updated_at();

-- =====================================================
-- 4. RLS POLICIES: devotionals
-- =====================================================

-- Habilitar RLS
ALTER TABLE devotionals ENABLE ROW LEVEL SECURITY;

-- Policy: Todos podem VER devocionais publicados
DROP POLICY IF EXISTS "Todos podem ver devocionais publicados" ON devotionals;
CREATE POLICY "Todos podem ver devocionais publicados"
  ON devotionals
  FOR SELECT
  USING (is_published = true);

-- Policy: Coordenadores+ podem VER todos (incluindo rascunhos)
DROP POLICY IF EXISTS "Coordenadores podem ver todos os devocionais" ON devotionals;
CREATE POLICY "Coordenadores podem ver todos os devocionais"
  ON devotionals
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_access_level
      WHERE user_id = auth.uid()
      AND access_level_number >= 4 -- Coordenador ou superior
    )
  );

-- Policy: Coordenadores+ podem CRIAR devocionais
DROP POLICY IF EXISTS "Coordenadores podem criar devocionais" ON devotionals;
CREATE POLICY "Coordenadores podem criar devocionais"
  ON devotionals
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_access_level
      WHERE user_id = auth.uid()
      AND access_level_number >= 4 -- Coordenador ou superior
    )
  );

-- Policy: Coordenadores+ podem ATUALIZAR devocionais
DROP POLICY IF EXISTS "Coordenadores podem atualizar devocionais" ON devotionals;
CREATE POLICY "Coordenadores podem atualizar devocionais"
  ON devotionals
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_access_level
      WHERE user_id = auth.uid()
      AND access_level_number >= 4 -- Coordenador ou superior
    )
  );

-- Policy: Coordenadores+ podem DELETAR devocionais
DROP POLICY IF EXISTS "Coordenadores podem deletar devocionais" ON devotionals;
CREATE POLICY "Coordenadores podem deletar devocionais"
  ON devotionals
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_access_level
      WHERE user_id = auth.uid()
      AND access_level_number >= 4 -- Coordenador ou superior
    )
  );

-- =====================================================
-- 5. RLS POLICIES: devotional_readings
-- =====================================================

-- Habilitar RLS
ALTER TABLE devotional_readings ENABLE ROW LEVEL SECURITY;

-- Policy: Usuários podem VER suas próprias leituras
DROP POLICY IF EXISTS "Usuários podem ver suas leituras" ON devotional_readings;
CREATE POLICY "Usuários podem ver suas leituras"
  ON devotional_readings
  FOR SELECT
  USING (user_id = auth.uid());

-- Policy: Coordenadores+ podem VER todas as leituras (estatísticas)
DROP POLICY IF EXISTS "Coordenadores podem ver todas as leituras" ON devotional_readings;
CREATE POLICY "Coordenadores podem ver todas as leituras"
  ON devotional_readings
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_access_level
      WHERE user_id = auth.uid()
      AND access_level_number >= 4 -- Coordenador ou superior
    )
  );

-- Policy: Usuários podem CRIAR suas próprias leituras
DROP POLICY IF EXISTS "Usuários podem criar leituras" ON devotional_readings;
CREATE POLICY "Usuários podem criar leituras"
  ON devotional_readings
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Policy: Usuários podem ATUALIZAR suas próprias leituras (anotações)
DROP POLICY IF EXISTS "Usuários podem atualizar suas leituras" ON devotional_readings;
CREATE POLICY "Usuários podem atualizar suas leituras"
  ON devotional_readings
  FOR UPDATE
  USING (user_id = auth.uid());

-- Policy: Usuários podem DELETAR suas próprias leituras
DROP POLICY IF EXISTS "Usuários podem deletar suas leituras" ON devotional_readings;
CREATE POLICY "Usuários podem deletar suas leituras"
  ON devotional_readings
  FOR DELETE
  USING (user_id = auth.uid());

-- =====================================================
-- 6. FUNÇÕES AUXILIARES
-- =====================================================

-- Função: Obter devocional do dia
CREATE OR REPLACE FUNCTION get_today_devotional()
RETURNS TABLE (
  id UUID,
  title TEXT,
  content TEXT,
  scripture_reference TEXT,
  devotional_date DATE,
  author_id UUID,
  is_published BOOLEAN,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    d.id,
    d.title,
    d.content,
    d.scripture_reference,
    d.devotional_date,
    d.author_id,
    d.is_published,
    d.created_at,
    d.updated_at
  FROM devotionals d
  WHERE d.devotional_date = CURRENT_DATE
  AND d.is_published = true
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função: Obter estatísticas de leitura de um devocional
CREATE OR REPLACE FUNCTION get_devotional_stats(devotional_uuid UUID)
RETURNS TABLE (
  total_reads BIGINT,
  unique_readers BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::BIGINT as total_reads,
    COUNT(DISTINCT user_id)::BIGINT as unique_readers
  FROM devotional_readings
  WHERE devotional_id = devotional_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função: Obter streak de leituras de um usuário
CREATE OR REPLACE FUNCTION get_user_reading_streak(user_uuid UUID)
RETURNS INTEGER AS $$
DECLARE
  streak INTEGER := 0;
  current_date_check DATE := CURRENT_DATE;
  has_reading BOOLEAN;
BEGIN
  LOOP
    -- Verificar se há leitura nesta data
    SELECT EXISTS (
      SELECT 1 
      FROM devotional_readings dr
      JOIN devotionals d ON dr.devotional_id = d.id
      WHERE dr.user_id = user_uuid
      AND d.devotional_date = current_date_check
    ) INTO has_reading;
    
    -- Se não há leitura, parar
    IF NOT has_reading THEN
      EXIT;
    END IF;
    
    -- Incrementar streak e voltar um dia
    streak := streak + 1;
    current_date_check := current_date_check - INTERVAL '1 day';
  END LOOP;
  
  RETURN streak;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 7. SEED DATA (Exemplo de devocional)
-- =====================================================

-- Inserir devocional de exemplo (apenas se não existir)
DO $$
DECLARE
  admin_user_id UUID;
BEGIN
  -- Buscar um usuário admin
  SELECT user_id INTO admin_user_id
  FROM user_access_level
  WHERE access_level = 'admin'
  LIMIT 1;
  
  -- Se encontrou admin, criar devocional de exemplo
  IF admin_user_id IS NOT NULL THEN
    INSERT INTO devotionals (
      title,
      content,
      scripture_reference,
      devotional_date,
      author_id,
      is_published
    ) VALUES (
      'Bem-vindo ao Church 360!',
      E'Hoje é um dia especial! Estamos inaugurando o sistema de devocionais diários.\n\nQue este espaço seja um lugar de crescimento espiritual e comunhão com Deus.\n\n"Lâmpada para os meus pés é a tua palavra e luz, para o meu caminho." - Salmos 119:105\n\nQue a Palavra de Deus ilumine seus caminhos todos os dias!',
      'Salmos 119:105',
      CURRENT_DATE,
      admin_user_id,
      true
    )
    ON CONFLICT (devotional_date) DO NOTHING;
  END IF;
END $$;

