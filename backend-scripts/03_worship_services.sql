-- ============================================
-- CHURCH 360 - WORSHIP SERVICES (CULTOS)
-- ============================================
-- Descrição: Tabelas para gerenciar cultos e presença
-- ============================================

-- Enum para tipos de culto
DO $$
BEGIN
  CREATE TYPE worship_type AS ENUM (
    'sunday_morning',
    'sunday_evening',
    'wednesday',
    'friday',
    'special',
    'other'
  );
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
END $$;

-- ============================================
-- TABELAS
-- ============================================

-- Cultos/serviços religiosos
CREATE TABLE IF NOT EXISTS worship_service (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Data e hora
  service_date DATE NOT NULL,
  service_time TIME,
  
  -- Tipo de culto
  service_type worship_type DEFAULT 'sunday_morning',
  
  -- Informações do culto
  theme TEXT,
  speaker TEXT,
  
  -- Estatísticas
  total_attendance INTEGER DEFAULT 0,
  
  -- Notas
  notes TEXT,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES user_account(id) ON DELETE SET NULL
);

-- Presença em cultos
CREATE TABLE IF NOT EXISTS worship_attendance (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Relacionamentos
  worship_service_id UUID REFERENCES worship_service(id) ON DELETE CASCADE,
  member_id UUID REFERENCES member(id) ON DELETE CASCADE,
  
  -- Check-in
  checked_in_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Notas
  notes TEXT,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Garantir que um membro só pode ter uma presença por culto
  UNIQUE(worship_service_id, member_id)
);

-- ============================================
-- ÍNDICES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_worship_service_date ON worship_service(service_date DESC);
CREATE INDEX IF NOT EXISTS idx_worship_service_type ON worship_service(service_type);
CREATE INDEX IF NOT EXISTS idx_worship_attendance_service ON worship_attendance(worship_service_id);
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='worship_attendance' AND column_name='member_id'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_worship_attendance_member ON public.worship_attendance(member_id)';
  ELSIF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='worship_attendance' AND column_name='user_id'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_worship_attendance_user ON public.worship_attendance(user_id)';
  END IF;
END $$;

-- ============================================
-- TRIGGERS
-- ============================================

-- Trigger para atualizar updated_at
DROP TRIGGER IF EXISTS update_worship_service_updated_at ON worship_service;
CREATE TRIGGER update_worship_service_updated_at
  BEFORE UPDATE ON worship_service
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Trigger para atualizar total_attendance quando presença é adicionada/removida
CREATE OR REPLACE FUNCTION update_worship_attendance_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE worship_service
    SET total_attendance = (
      SELECT COUNT(*) FROM worship_attendance
      WHERE worship_service_id = NEW.worship_service_id
    )
    WHERE id = NEW.worship_service_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE worship_service
    SET total_attendance = (
      SELECT COUNT(*) FROM worship_attendance
      WHERE worship_service_id = OLD.worship_service_id
    )
    WHERE id = OLD.worship_service_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_worship_attendance_count_insert ON worship_attendance;
CREATE TRIGGER trigger_update_worship_attendance_count_insert
  AFTER INSERT ON worship_attendance
  FOR EACH ROW
  EXECUTE FUNCTION update_worship_attendance_count();

DROP TRIGGER IF EXISTS trigger_update_worship_attendance_count_delete ON worship_attendance;
CREATE TRIGGER trigger_update_worship_attendance_count_delete
  AFTER DELETE ON worship_attendance
  FOR EACH ROW
  EXECUTE FUNCTION update_worship_attendance_count();

-- ============================================
-- RLS POLICIES
-- ============================================

ALTER TABLE worship_service ENABLE ROW LEVEL SECURITY;
ALTER TABLE worship_attendance ENABLE ROW LEVEL SECURITY;

-- worship_service
DROP POLICY IF EXISTS "Users can view worship services" ON worship_service;
CREATE POLICY "Users can view worship services"
  ON worship_service FOR SELECT
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Users can manage worship services" ON worship_service;
CREATE POLICY "Users can manage worship services"
  ON worship_service FOR ALL
  USING (auth.uid() IS NOT NULL);

-- worship_attendance
DROP POLICY IF EXISTS "Users can view worship attendance" ON worship_attendance;
CREATE POLICY "Users can view worship attendance"
  ON worship_attendance FOR SELECT
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Users can manage worship attendance" ON worship_attendance;
CREATE POLICY "Users can manage worship attendance"
  ON worship_attendance FOR ALL
  USING (auth.uid() IS NOT NULL);

-- ============================================
-- DADOS DE EXEMPLO (SEED)
-- ============================================

-- Inserir alguns cultos de exemplo
INSERT INTO worship_service (service_date, service_time, service_type, theme, speaker, notes)
VALUES
  (CURRENT_DATE - INTERVAL '7 days', '10:00', 'sunday_morning', 'O Amor de Deus', 'Pastor João Silva', 'Culto com Santa Ceia'),
  (CURRENT_DATE - INTERVAL '7 days', '19:00', 'sunday_evening', 'Fé que Move Montanhas', 'Pastor João Silva', NULL),
  (CURRENT_DATE - INTERVAL '4 days', '19:30', 'wednesday', 'Estudo: Livro de Atos', 'Pr. Maria Santos', 'Culto de Oração'),
  (CURRENT_DATE, '10:00', 'sunday_morning', 'A Graça Salvadora', 'Pastor João Silva', 'Culto de Celebração'),
  (CURRENT_DATE, '19:00', 'sunday_evening', 'Vencendo o Medo', 'Pr. Carlos Oliveira', NULL);

-- Nota: As presenças serão registradas através do app
