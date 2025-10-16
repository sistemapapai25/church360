-- =====================================================
-- CHURCH 360 - SISTEMA DE NÍVEIS DE ACESSO
-- =====================================================
-- Descrição: Sistema progressivo de níveis de acesso
-- Níveis: 0=Visitante, 1=Frequentador, 2=Membro, 
--         3=Líder, 4=Coordenador, 5=Administrativo
-- =====================================================

-- =====================================================
-- 1. ENUM: ACCESS_LEVEL_TYPE
-- =====================================================

DO $$ BEGIN
  CREATE TYPE access_level_type AS ENUM (
    'visitor',        -- 0: Visitante (sem login ou login básico)
    'attendee',       -- 1: Frequentador (após 2-3 visitas)
    'member',         -- 2: Membro (após conversão/batismo)
    'leader',         -- 3: Líder (líder de grupo/ministério)
    'coordinator',    -- 4: Coordenador (coordenador de área)
    'admin'           -- 5: Administrativo (pastor/admin/secretaria)
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- =====================================================
-- 2. TABELA: user_access_level
-- =====================================================

CREATE TABLE IF NOT EXISTS user_access_level (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Nível de acesso
  access_level access_level_type NOT NULL DEFAULT 'visitor',
  access_level_number INTEGER NOT NULL DEFAULT 0,

  -- Informações de promoção
  promoted_at TIMESTAMPTZ,
  promoted_by UUID REFERENCES auth.users(id),
  promotion_reason TEXT,

  -- Notas e observações
  notes TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraints
  CHECK (access_level_number >= 0 AND access_level_number <= 5)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_user_access_level_user_id ON user_access_level(user_id);
CREATE INDEX IF NOT EXISTS idx_user_access_level_level ON user_access_level(access_level);
CREATE INDEX IF NOT EXISTS idx_user_access_level_level_number ON user_access_level(access_level_number);

-- Comentários
COMMENT ON TABLE user_access_level IS 'Armazena o nível de acesso atual de cada usuário';
COMMENT ON COLUMN user_access_level.access_level IS 'Tipo de nível de acesso (ENUM)';
COMMENT ON COLUMN user_access_level.access_level_number IS 'Número do nível (0-5) para facilitar comparações';
COMMENT ON COLUMN user_access_level.promoted_at IS 'Data da última promoção';
COMMENT ON COLUMN user_access_level.promoted_by IS 'Usuário que promoveu';

-- =====================================================
-- 3. TABELA: access_level_history
-- =====================================================

CREATE TABLE IF NOT EXISTS access_level_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Mudança de nível
  from_level access_level_type,
  from_level_number INTEGER,
  to_level access_level_type NOT NULL,
  to_level_number INTEGER NOT NULL,

  -- Informações da mudança
  reason TEXT,
  promoted_by UUID REFERENCES auth.users(id),

  -- Timestamp
  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraints
  CHECK (from_level_number >= 0 AND from_level_number <= 5),
  CHECK (to_level_number >= 0 AND to_level_number <= 5)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_access_level_history_user_id ON access_level_history(user_id);
CREATE INDEX IF NOT EXISTS idx_access_level_history_created_at ON access_level_history(created_at DESC);

-- Comentários
COMMENT ON TABLE access_level_history IS 'Histórico de mudanças de nível de acesso';
COMMENT ON COLUMN access_level_history.from_level IS 'Nível anterior';
COMMENT ON COLUMN access_level_history.to_level IS 'Novo nível';

-- =====================================================
-- 4. FUNÇÃO: Converter ENUM para número
-- =====================================================

CREATE OR REPLACE FUNCTION access_level_to_number(level access_level_type)
RETURNS INTEGER AS $$
BEGIN
  RETURN CASE level
    WHEN 'visitor' THEN 0
    WHEN 'attendee' THEN 1
    WHEN 'member' THEN 2
    WHEN 'leader' THEN 3
    WHEN 'coordinator' THEN 4
    WHEN 'admin' THEN 5
    ELSE 0
  END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- =====================================================
-- 5. FUNÇÃO: Converter número para ENUM
-- =====================================================

CREATE OR REPLACE FUNCTION number_to_access_level(level_number INTEGER)
RETURNS access_level_type AS $$
BEGIN
  RETURN CASE level_number
    WHEN 0 THEN 'visitor'::access_level_type
    WHEN 1 THEN 'attendee'::access_level_type
    WHEN 2 THEN 'member'::access_level_type
    WHEN 3 THEN 'leader'::access_level_type
    WHEN 4 THEN 'coordinator'::access_level_type
    WHEN 5 THEN 'admin'::access_level_type
    ELSE 'visitor'::access_level_type
  END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- =====================================================
-- 6. TRIGGER: Sincronizar access_level_number
-- =====================================================

CREATE OR REPLACE FUNCTION sync_access_level_number()
RETURNS TRIGGER AS $$
BEGIN
  NEW.access_level_number := access_level_to_number(NEW.access_level);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_sync_access_level_number
  BEFORE INSERT OR UPDATE OF access_level ON user_access_level
  FOR EACH ROW
  EXECUTE FUNCTION sync_access_level_number();

-- =====================================================
-- 7. TRIGGER: Registrar histórico de mudanças
-- =====================================================

CREATE OR REPLACE FUNCTION log_access_level_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Só registra se o nível mudou
  IF (TG_OP = 'UPDATE' AND OLD.access_level != NEW.access_level) THEN
    INSERT INTO access_level_history (
      user_id,
      from_level,
      from_level_number,
      to_level,
      to_level_number,
      reason,
      promoted_by
    ) VALUES (
      NEW.user_id,
      OLD.access_level,
      OLD.access_level_number,
      NEW.access_level,
      NEW.access_level_number,
      NEW.promotion_reason,
      NEW.promoted_by
    );
  ELSIF (TG_OP = 'INSERT') THEN
    -- Registra criação inicial
    INSERT INTO access_level_history (
      user_id,
      from_level,
      from_level_number,
      to_level,
      to_level_number,
      reason,
      promoted_by
    ) VALUES (
      NEW.user_id,
      NULL,
      NULL,
      NEW.access_level,
      NEW.access_level_number,
      'Criação inicial',
      NEW.promoted_by
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_log_access_level_change
  AFTER INSERT OR UPDATE OF access_level ON user_access_level
  FOR EACH ROW
  EXECUTE FUNCTION log_access_level_change();

-- =====================================================
-- 8. TRIGGER: Atualizar updated_at
-- =====================================================

CREATE TRIGGER trigger_user_access_level_updated_at
  BEFORE UPDATE ON user_access_level
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 9. RLS POLICIES
-- =====================================================

-- Habilitar RLS
ALTER TABLE user_access_level ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_level_history ENABLE ROW LEVEL SECURITY;

-- Policy: SELECT - Todos podem ver todos os níveis
CREATE POLICY "Users can view all access levels"
  ON user_access_level FOR SELECT
  USING (true);

-- Policy: INSERT - Apenas admins podem criar níveis
CREATE POLICY "Only admins can create access levels"
  ON user_access_level FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_access_level ual
      WHERE ual.user_id = auth.uid()
      AND ual.access_level_number >= 5
    )
  );

-- Policy: UPDATE - Apenas admins podem atualizar níveis
CREATE POLICY "Only admins can update access levels"
  ON user_access_level FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_access_level ual
      WHERE ual.user_id = auth.uid()
      AND ual.access_level_number >= 5
    )
  );

-- Policy: DELETE - Apenas admins podem deletar níveis
CREATE POLICY "Only admins can delete access levels"
  ON user_access_level FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_access_level ual
      WHERE ual.user_id = auth.uid()
      AND ual.access_level_number >= 5
    )
  );

-- Policy: SELECT histórico - Todos podem ver histórico
CREATE POLICY "Users can view all access level history"
  ON access_level_history FOR SELECT
  USING (true);

-- =====================================================
-- 10. SEED: Criar nível admin para usuários existentes
-- =====================================================

-- Criar nível admin para usuários com role_global = 'owner' ou 'admin'
INSERT INTO user_access_level (user_id, access_level, access_level_number, promoted_at, promotion_reason)
SELECT
  id,
  'admin'::access_level_type,
  5,
  NOW(),
  'Usuário administrativo inicial'
FROM user_account
WHERE role_global IN ('owner', 'admin')
ON CONFLICT (user_id) DO NOTHING;

-- =====================================================
-- FIM DO SCRIPT
-- =====================================================

