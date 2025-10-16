-- =====================================================
-- CHURCH 360 - SISTEMA DE GRUPOS DE ESTUDO BÍBLICO
-- =====================================================

-- =====================================================
-- 1. ENUMS
-- =====================================================

-- Status do grupo de estudo
DO $$ BEGIN
  CREATE TYPE study_group_status AS ENUM (
    'active',      -- Ativo
    'paused',      -- Pausado
    'completed',   -- Concluído
    'cancelled'    -- Cancelado
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Status da lição
DO $$ BEGIN
  CREATE TYPE lesson_status AS ENUM (
    'draft',       -- Rascunho
    'published',   -- Publicada
    'archived'     -- Arquivada
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Papel do participante
DO $$ BEGIN
  CREATE TYPE participant_role AS ENUM (
    'leader',      -- Líder
    'co_leader',   -- Co-líder
    'participant'  -- Participante
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Status de presença
DO $$ BEGIN
  CREATE TYPE attendance_status AS ENUM (
    'present',     -- Presente
    'absent',      -- Ausente
    'justified'    -- Falta justificada
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- =====================================================
-- 2. TABELA: study_groups
-- =====================================================

CREATE TABLE IF NOT EXISTS study_groups (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Informações básicas
  name TEXT NOT NULL,
  description TEXT,
  
  -- Tema/Livro de estudo
  study_topic TEXT, -- Ex: "Evangelho de João", "Romanos", "Vida de Davi"
  
  -- Status
  status study_group_status DEFAULT 'active',
  
  -- Datas
  start_date DATE NOT NULL,
  end_date DATE,
  
  -- Horário das reuniões
  meeting_day TEXT, -- Ex: "Quarta-feira"
  meeting_time TIME, -- Ex: 19:30
  meeting_location TEXT, -- Ex: "Sala 3", "Online - Zoom"
  
  -- Configurações
  max_participants INTEGER, -- Limite de participantes (null = sem limite)
  is_public BOOLEAN DEFAULT true, -- Qualquer um pode se inscrever?
  
  -- Imagem de capa
  cover_image_url TEXT,
  
  -- Metadados
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT study_groups_name_not_empty CHECK (LENGTH(TRIM(name)) > 0),
  CONSTRAINT study_groups_dates_valid CHECK (end_date IS NULL OR end_date >= start_date)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_study_groups_status ON study_groups(status);
CREATE INDEX IF NOT EXISTS idx_study_groups_created_by ON study_groups(created_by);
CREATE INDEX IF NOT EXISTS idx_study_groups_start_date ON study_groups(start_date);

-- =====================================================
-- 3. TABELA: study_lessons
-- =====================================================

CREATE TABLE IF NOT EXISTS study_lessons (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Relacionamento
  study_group_id UUID NOT NULL REFERENCES study_groups(id) ON DELETE CASCADE,
  
  -- Informações da lição
  lesson_number INTEGER NOT NULL, -- Ordem da lição (1, 2, 3...)
  title TEXT NOT NULL,
  description TEXT,
  
  -- Conteúdo
  bible_references TEXT, -- Ex: "João 3:16-21, Romanos 8:1-11"
  content TEXT, -- Conteúdo da lição em Markdown
  
  -- Perguntas para discussão
  discussion_questions JSONB, -- Array de perguntas
  
  -- Status
  status lesson_status DEFAULT 'draft',
  
  -- Data da aula
  scheduled_date DATE,
  
  -- Recursos
  video_url TEXT,
  audio_url TEXT,
  pdf_url TEXT,
  
  -- Metadados
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT study_lessons_title_not_empty CHECK (LENGTH(TRIM(title)) > 0),
  CONSTRAINT study_lessons_lesson_number_positive CHECK (lesson_number > 0),
  CONSTRAINT study_lessons_unique_lesson_number UNIQUE (study_group_id, lesson_number)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_study_lessons_group ON study_lessons(study_group_id);
CREATE INDEX IF NOT EXISTS idx_study_lessons_status ON study_lessons(status);
CREATE INDEX IF NOT EXISTS idx_study_lessons_scheduled_date ON study_lessons(scheduled_date);

-- =====================================================
-- 4. TABELA: study_participants
-- =====================================================

CREATE TABLE IF NOT EXISTS study_participants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Relacionamentos
  study_group_id UUID NOT NULL REFERENCES study_groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Papel no grupo
  role participant_role DEFAULT 'participant',
  
  -- Status
  is_active BOOLEAN DEFAULT true,
  
  -- Datas
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  left_at TIMESTAMPTZ,
  
  -- Metadados
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT study_participants_unique UNIQUE (study_group_id, user_id)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_study_participants_group ON study_participants(study_group_id);
CREATE INDEX IF NOT EXISTS idx_study_participants_user ON study_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_study_participants_role ON study_participants(role);

-- =====================================================
-- 5. TABELA: study_attendance
-- =====================================================

CREATE TABLE IF NOT EXISTS study_attendance (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Relacionamentos
  study_lesson_id UUID NOT NULL REFERENCES study_lessons(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Status de presença
  status attendance_status NOT NULL,
  
  -- Justificativa (se ausente justificado)
  justification TEXT,
  
  -- Anotações pessoais da aula
  notes TEXT,
  
  -- Metadados
  marked_by UUID REFERENCES auth.users(id), -- Quem marcou a presença
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT study_attendance_unique UNIQUE (study_lesson_id, user_id)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_study_attendance_lesson ON study_attendance(study_lesson_id);
CREATE INDEX IF NOT EXISTS idx_study_attendance_user ON study_attendance(user_id);
CREATE INDEX IF NOT EXISTS idx_study_attendance_status ON study_attendance(status);

-- =====================================================
-- 6. TABELA: study_comments
-- =====================================================

CREATE TABLE IF NOT EXISTS study_comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Relacionamento
  study_lesson_id UUID NOT NULL REFERENCES study_lessons(id) ON DELETE CASCADE,
  
  -- Autor
  author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Conteúdo
  content TEXT NOT NULL,
  
  -- Resposta a outro comentário (thread)
  parent_comment_id UUID REFERENCES study_comments(id) ON DELETE CASCADE,
  
  -- Metadados
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT study_comments_content_not_empty CHECK (LENGTH(TRIM(content)) > 0)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_study_comments_lesson ON study_comments(study_lesson_id);
CREATE INDEX IF NOT EXISTS idx_study_comments_author ON study_comments(author_id);
CREATE INDEX IF NOT EXISTS idx_study_comments_parent ON study_comments(parent_comment_id);

-- =====================================================
-- 7. TABELA: study_resources
-- =====================================================

CREATE TABLE IF NOT EXISTS study_resources (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Relacionamento
  study_group_id UUID NOT NULL REFERENCES study_groups(id) ON DELETE CASCADE,
  
  -- Informações do recurso
  title TEXT NOT NULL,
  description TEXT,
  
  -- Tipo de recurso
  resource_type TEXT, -- 'pdf', 'video', 'audio', 'link', 'image', 'other'
  
  -- URL ou arquivo
  url TEXT NOT NULL,
  file_size BIGINT, -- Tamanho em bytes
  
  -- Metadados
  uploaded_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT study_resources_title_not_empty CHECK (LENGTH(TRIM(title)) > 0),
  CONSTRAINT study_resources_url_not_empty CHECK (LENGTH(TRIM(url)) > 0)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_study_resources_group ON study_resources(study_group_id);
CREATE INDEX IF NOT EXISTS idx_study_resources_type ON study_resources(resource_type);

-- =====================================================
-- 8. TRIGGERS: updated_at
-- =====================================================

-- Trigger para study_groups
CREATE OR REPLACE FUNCTION update_study_groups_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_study_groups_updated_at ON study_groups;
CREATE TRIGGER trigger_update_study_groups_updated_at
  BEFORE UPDATE ON study_groups
  FOR EACH ROW
  EXECUTE FUNCTION update_study_groups_updated_at();

-- Trigger para study_lessons
CREATE OR REPLACE FUNCTION update_study_lessons_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_study_lessons_updated_at ON study_lessons;
CREATE TRIGGER trigger_update_study_lessons_updated_at
  BEFORE UPDATE ON study_lessons
  FOR EACH ROW
  EXECUTE FUNCTION update_study_lessons_updated_at();

-- Trigger para study_participants
CREATE OR REPLACE FUNCTION update_study_participants_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_study_participants_updated_at ON study_participants;
CREATE TRIGGER trigger_update_study_participants_updated_at
  BEFORE UPDATE ON study_participants
  FOR EACH ROW
  EXECUTE FUNCTION update_study_participants_updated_at();

-- Trigger para study_attendance
CREATE OR REPLACE FUNCTION update_study_attendance_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_study_attendance_updated_at ON study_attendance;
CREATE TRIGGER trigger_update_study_attendance_updated_at
  BEFORE UPDATE ON study_attendance
  FOR EACH ROW
  EXECUTE FUNCTION update_study_attendance_updated_at();

-- Trigger para study_comments
CREATE OR REPLACE FUNCTION update_study_comments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_study_comments_updated_at ON study_comments;
CREATE TRIGGER trigger_update_study_comments_updated_at
  BEFORE UPDATE ON study_comments
  FOR EACH ROW
  EXECUTE FUNCTION update_study_comments_updated_at();

-- Trigger para study_resources
CREATE OR REPLACE FUNCTION update_study_resources_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_study_resources_updated_at ON study_resources;
CREATE TRIGGER trigger_update_study_resources_updated_at
  BEFORE UPDATE ON study_resources
  FOR EACH ROW
  EXECUTE FUNCTION update_study_resources_updated_at();

-- =====================================================
-- 9. TRIGGER: Adicionar criador como líder do grupo
-- =====================================================

CREATE OR REPLACE FUNCTION add_creator_as_leader()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO study_participants (study_group_id, user_id, role)
  VALUES (NEW.id, NEW.created_by, 'leader')
  ON CONFLICT (study_group_id, user_id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_add_creator_as_leader ON study_groups;
CREATE TRIGGER trigger_add_creator_as_leader
  AFTER INSERT ON study_groups
  FOR EACH ROW
  EXECUTE FUNCTION add_creator_as_leader();

-- =====================================================
-- 10. TRIGGER: Notificar participantes sobre nova lição
-- =====================================================

CREATE OR REPLACE FUNCTION notify_new_lesson()
RETURNS TRIGGER AS $$
DECLARE
  group_name TEXT;
  participant_record RECORD;
BEGIN
  -- Apenas notificar quando lição é publicada
  IF NEW.status != 'published' OR (OLD.status IS NOT NULL AND OLD.status = 'published') THEN
    RETURN NEW;
  END IF;

  -- Buscar nome do grupo
  SELECT name INTO group_name
  FROM study_groups
  WHERE id = NEW.study_group_id;

  -- Notificar todos os participantes ativos
  FOR participant_record IN
    SELECT user_id
    FROM study_participants
    WHERE study_group_id = NEW.study_group_id
    AND is_active = true
  LOOP
    INSERT INTO notifications (
      user_id,
      type,
      title,
      body,
      data,
      route,
      status
    ) VALUES (
      participant_record.user_id,
      'general',
      'Nova Lição Publicada! 📖',
      'Nova lição disponível no grupo "' || group_name || '": ' || NEW.title,
      jsonb_build_object('study_group_id', NEW.study_group_id, 'study_lesson_id', NEW.id),
      '/study-groups/' || NEW.study_group_id || '/lessons/' || NEW.id,
      'pending'
    );
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_notify_new_lesson ON study_lessons;
CREATE TRIGGER trigger_notify_new_lesson
  AFTER INSERT OR UPDATE ON study_lessons
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_lesson();

-- =====================================================
-- 11. RLS POLICIES: study_groups
-- =====================================================

ALTER TABLE study_groups ENABLE ROW LEVEL SECURITY;

-- Ver grupos públicos ou grupos que o usuário participa
DROP POLICY IF EXISTS "Usuários podem ver grupos públicos ou seus grupos" ON study_groups;
CREATE POLICY "Usuários podem ver grupos públicos ou seus grupos"
  ON study_groups
  FOR SELECT
  USING (
    is_public = true
    OR
    EXISTS (
      SELECT 1 FROM study_participants
      WHERE study_participants.study_group_id = study_groups.id
      AND study_participants.user_id = auth.uid()
    )
  );

-- Coordenadores+ podem criar grupos
DROP POLICY IF EXISTS "Coordenadores podem criar grupos" ON study_groups;
CREATE POLICY "Coordenadores podem criar grupos"
  ON study_groups
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM members
      WHERE members.user_id = auth.uid()
      AND members.access_level >= 4
    )
  );

-- Líderes do grupo ou Coordenadores+ podem atualizar
DROP POLICY IF EXISTS "Líderes podem atualizar grupos" ON study_groups;
CREATE POLICY "Líderes podem atualizar grupos"
  ON study_groups
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM study_participants
      WHERE study_participants.study_group_id = study_groups.id
      AND study_participants.user_id = auth.uid()
      AND study_participants.role IN ('leader', 'co_leader')
    )
    OR
    EXISTS (
      SELECT 1 FROM members
      WHERE members.user_id = auth.uid()
      AND members.access_level >= 4
    )
  );

-- Líderes do grupo ou Coordenadores+ podem deletar
DROP POLICY IF EXISTS "Líderes podem deletar grupos" ON study_groups;
CREATE POLICY "Líderes podem deletar grupos"
  ON study_groups
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM study_participants
      WHERE study_participants.study_group_id = study_groups.id
      AND study_participants.user_id = auth.uid()
      AND study_participants.role = 'leader'
    )
    OR
    EXISTS (
      SELECT 1 FROM members
      WHERE members.user_id = auth.uid()
      AND members.access_level >= 4
    )
  );

-- =====================================================
-- 12. RLS POLICIES: study_lessons
-- =====================================================

ALTER TABLE study_lessons ENABLE ROW LEVEL SECURITY;

-- Participantes podem ver lições publicadas, líderes veem todas
DROP POLICY IF EXISTS "Participantes podem ver lições" ON study_lessons;
CREATE POLICY "Participantes podem ver lições"
  ON study_lessons
  FOR SELECT
  USING (
    (
      status = 'published'
      AND
      EXISTS (
        SELECT 1 FROM study_participants
        WHERE study_participants.study_group_id = study_lessons.study_group_id
        AND study_participants.user_id = auth.uid()
      )
    )
    OR
    EXISTS (
      SELECT 1 FROM study_participants
      WHERE study_participants.study_group_id = study_lessons.study_group_id
      AND study_participants.user_id = auth.uid()
      AND study_participants.role IN ('leader', 'co_leader')
    )
  );

-- Líderes podem criar lições
DROP POLICY IF EXISTS "Líderes podem criar lições" ON study_lessons;
CREATE POLICY "Líderes podem criar lições"
  ON study_lessons
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM study_participants
      WHERE study_participants.study_group_id = study_lessons.study_group_id
      AND study_participants.user_id = auth.uid()
      AND study_participants.role IN ('leader', 'co_leader')
    )
  );

-- Líderes podem atualizar lições
DROP POLICY IF EXISTS "Líderes podem atualizar lições" ON study_lessons;
CREATE POLICY "Líderes podem atualizar lições"
  ON study_lessons
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM study_participants
      WHERE study_participants.study_group_id = study_lessons.study_group_id
      AND study_participants.user_id = auth.uid()
      AND study_participants.role IN ('leader', 'co_leader')
    )
  );

-- Líderes podem deletar lições
DROP POLICY IF EXISTS "Líderes podem deletar lições" ON study_lessons;
CREATE POLICY "Líderes podem deletar lições"
  ON study_lessons
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM study_participants
      WHERE study_participants.study_group_id = study_lessons.study_group_id
      AND study_participants.user_id = auth.uid()
      AND study_participants.role IN ('leader', 'co_leader')
    )
  );

-- =====================================================
-- 13. RLS POLICIES: study_participants
-- =====================================================

ALTER TABLE study_participants ENABLE ROW LEVEL SECURITY;

-- Participantes podem ver outros participantes do mesmo grupo
DROP POLICY IF EXISTS "Participantes podem ver membros do grupo" ON study_participants;
CREATE POLICY "Participantes podem ver membros do grupo"
  ON study_participants
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM study_participants sp
      WHERE sp.study_group_id = study_participants.study_group_id
      AND sp.user_id = auth.uid()
    )
  );

-- Usuários podem se inscrever em grupos públicos
DROP POLICY IF EXISTS "Usuários podem se inscrever" ON study_participants;
CREATE POLICY "Usuários podem se inscrever"
  ON study_participants
  FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND
    EXISTS (
      SELECT 1 FROM study_groups
      WHERE study_groups.id = study_participants.study_group_id
      AND study_groups.is_public = true
    )
  );

-- Líderes podem adicionar participantes
DROP POLICY IF EXISTS "Líderes podem adicionar participantes" ON study_participants;
CREATE POLICY "Líderes podem adicionar participantes"
  ON study_participants
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM study_participants sp
      WHERE sp.study_group_id = study_participants.study_group_id
      AND sp.user_id = auth.uid()
      AND sp.role IN ('leader', 'co_leader')
    )
  );

-- Líderes podem atualizar participantes
DROP POLICY IF EXISTS "Líderes podem atualizar participantes" ON study_participants;
CREATE POLICY "Líderes podem atualizar participantes"
  ON study_participants
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM study_participants sp
      WHERE sp.study_group_id = study_participants.study_group_id
      AND sp.user_id = auth.uid()
      AND sp.role IN ('leader', 'co_leader')
    )
  );

-- Usuários podem sair do grupo
DROP POLICY IF EXISTS "Usuários podem sair do grupo" ON study_participants;
CREATE POLICY "Usuários podem sair do grupo"
  ON study_participants
  FOR DELETE
  USING (user_id = auth.uid());

-- =====================================================
-- 14. RLS POLICIES: study_attendance
-- =====================================================

ALTER TABLE study_attendance ENABLE ROW LEVEL SECURITY;

-- Participantes podem ver presença do grupo
DROP POLICY IF EXISTS "Participantes podem ver presença" ON study_attendance;
CREATE POLICY "Participantes podem ver presença"
  ON study_attendance
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM study_lessons sl
      JOIN study_participants sp ON sp.study_group_id = sl.study_group_id
      WHERE sl.id = study_attendance.study_lesson_id
      AND sp.user_id = auth.uid()
    )
  );

-- Líderes podem marcar presença
DROP POLICY IF EXISTS "Líderes podem marcar presença" ON study_attendance;
CREATE POLICY "Líderes podem marcar presença"
  ON study_attendance
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM study_lessons sl
      JOIN study_participants sp ON sp.study_group_id = sl.study_group_id
      WHERE sl.id = study_attendance.study_lesson_id
      AND sp.user_id = auth.uid()
      AND sp.role IN ('leader', 'co_leader')
    )
  );

-- Líderes podem atualizar presença
DROP POLICY IF EXISTS "Líderes podem atualizar presença" ON study_attendance;
CREATE POLICY "Líderes podem atualizar presença"
  ON study_attendance
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM study_lessons sl
      JOIN study_participants sp ON sp.study_group_id = sl.study_group_id
      WHERE sl.id = study_attendance.study_lesson_id
      AND sp.user_id = auth.uid()
      AND sp.role IN ('leader', 'co_leader')
    )
  );

-- =====================================================
-- 15. RLS POLICIES: study_comments
-- =====================================================

ALTER TABLE study_comments ENABLE ROW LEVEL SECURITY;

-- Participantes podem ver comentários
DROP POLICY IF EXISTS "Participantes podem ver comentários" ON study_comments;
CREATE POLICY "Participantes podem ver comentários"
  ON study_comments
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM study_lessons sl
      JOIN study_participants sp ON sp.study_group_id = sl.study_group_id
      WHERE sl.id = study_comments.study_lesson_id
      AND sp.user_id = auth.uid()
    )
  );

-- Participantes podem criar comentários
DROP POLICY IF EXISTS "Participantes podem comentar" ON study_comments;
CREATE POLICY "Participantes podem comentar"
  ON study_comments
  FOR INSERT
  WITH CHECK (
    author_id = auth.uid()
    AND
    EXISTS (
      SELECT 1 FROM study_lessons sl
      JOIN study_participants sp ON sp.study_group_id = sl.study_group_id
      WHERE sl.id = study_comments.study_lesson_id
      AND sp.user_id = auth.uid()
    )
  );

-- Autor pode atualizar seu comentário
DROP POLICY IF EXISTS "Autor pode atualizar comentário" ON study_comments;
CREATE POLICY "Autor pode atualizar comentário"
  ON study_comments
  FOR UPDATE
  USING (author_id = auth.uid());

-- Autor ou líderes podem deletar comentários
DROP POLICY IF EXISTS "Autor ou líderes podem deletar" ON study_comments;
CREATE POLICY "Autor ou líderes podem deletar"
  ON study_comments
  FOR DELETE
  USING (
    author_id = auth.uid()
    OR
    EXISTS (
      SELECT 1 FROM study_lessons sl
      JOIN study_participants sp ON sp.study_group_id = sl.study_group_id
      WHERE sl.id = study_comments.study_lesson_id
      AND sp.user_id = auth.uid()
      AND sp.role IN ('leader', 'co_leader')
    )
  );

-- =====================================================
-- 16. RLS POLICIES: study_resources
-- =====================================================

ALTER TABLE study_resources ENABLE ROW LEVEL SECURITY;

-- Participantes podem ver recursos
DROP POLICY IF EXISTS "Participantes podem ver recursos" ON study_resources;
CREATE POLICY "Participantes podem ver recursos"
  ON study_resources
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM study_participants
      WHERE study_participants.study_group_id = study_resources.study_group_id
      AND study_participants.user_id = auth.uid()
    )
  );

-- Líderes podem adicionar recursos
DROP POLICY IF EXISTS "Líderes podem adicionar recursos" ON study_resources;
CREATE POLICY "Líderes podem adicionar recursos"
  ON study_resources
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM study_participants
      WHERE study_participants.study_group_id = study_resources.study_group_id
      AND study_participants.user_id = auth.uid()
      AND study_participants.role IN ('leader', 'co_leader')
    )
  );

-- Líderes podem atualizar recursos
DROP POLICY IF EXISTS "Líderes podem atualizar recursos" ON study_resources;
CREATE POLICY "Líderes podem atualizar recursos"
  ON study_resources
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM study_participants
      WHERE study_participants.study_group_id = study_resources.study_group_id
      AND study_participants.user_id = auth.uid()
      AND study_participants.role IN ('leader', 'co_leader')
    )
  );

-- Líderes podem deletar recursos
DROP POLICY IF EXISTS "Líderes podem deletar recursos" ON study_resources;
CREATE POLICY "Líderes podem deletar recursos"
  ON study_resources
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM study_participants
      WHERE study_participants.study_group_id = study_resources.study_group_id
      AND study_participants.user_id = auth.uid()
      AND study_participants.role IN ('leader', 'co_leader')
    )
  );

-- =====================================================
-- 17. FUNÇÕES AUXILIARES
-- =====================================================

-- Função: Obter grupos do usuário
CREATE OR REPLACE FUNCTION get_user_study_groups(target_user_id UUID)
RETURNS TABLE (
  group_id UUID,
  group_name TEXT,
  group_status study_group_status,
  user_role participant_role,
  total_lessons BIGINT,
  completed_lessons BIGINT,
  attendance_rate NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    sg.id,
    sg.name,
    sg.status,
    sp.role,
    (SELECT COUNT(*) FROM study_lessons WHERE study_group_id = sg.id AND status = 'published'),
    (SELECT COUNT(*) FROM study_attendance sa
     JOIN study_lessons sl ON sl.id = sa.study_lesson_id
     WHERE sl.study_group_id = sg.id
     AND sa.user_id = target_user_id
     AND sa.status = 'present'),
    CASE
      WHEN (SELECT COUNT(*) FROM study_lessons WHERE study_group_id = sg.id AND status = 'published') = 0 THEN 0
      ELSE (
        SELECT ROUND(
          (COUNT(*) FILTER (WHERE sa.status = 'present')::NUMERIC /
           COUNT(*)::NUMERIC) * 100, 2
        )
        FROM study_attendance sa
        JOIN study_lessons sl ON sl.id = sa.study_lesson_id
        WHERE sl.study_group_id = sg.id
        AND sa.user_id = target_user_id
      )
    END
  FROM study_groups sg
  JOIN study_participants sp ON sp.study_group_id = sg.id
  WHERE sp.user_id = target_user_id
  AND sp.is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função: Obter progresso do grupo
CREATE OR REPLACE FUNCTION get_group_progress(target_group_id UUID)
RETURNS TABLE (
  total_lessons BIGINT,
  published_lessons BIGINT,
  total_participants BIGINT,
  active_participants BIGINT,
  average_attendance_rate NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM study_lessons WHERE study_group_id = target_group_id),
    (SELECT COUNT(*) FROM study_lessons WHERE study_group_id = target_group_id AND status = 'published'),
    (SELECT COUNT(*) FROM study_participants WHERE study_group_id = target_group_id),
    (SELECT COUNT(*) FROM study_participants WHERE study_group_id = target_group_id AND is_active = true),
    CASE
      WHEN (SELECT COUNT(*) FROM study_lessons WHERE study_group_id = target_group_id AND status = 'published') = 0 THEN 0
      ELSE (
        SELECT ROUND(AVG(attendance_rate), 2)
        FROM (
          SELECT
            (COUNT(*) FILTER (WHERE sa.status = 'present')::NUMERIC /
             NULLIF(COUNT(*)::NUMERIC, 0)) * 100 AS attendance_rate
          FROM study_participants sp
          LEFT JOIN study_attendance sa ON sa.user_id = sp.user_id
          LEFT JOIN study_lessons sl ON sl.id = sa.study_lesson_id AND sl.study_group_id = target_group_id
          WHERE sp.study_group_id = target_group_id
          AND sp.is_active = true
          GROUP BY sp.user_id
        ) AS rates
      )
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função: Obter taxa de presença do participante
CREATE OR REPLACE FUNCTION get_participant_attendance_rate(
  target_group_id UUID,
  target_user_id UUID
)
RETURNS NUMERIC AS $$
DECLARE
  total_lessons BIGINT;
  present_count BIGINT;
BEGIN
  -- Contar total de lições publicadas
  SELECT COUNT(*) INTO total_lessons
  FROM study_lessons
  WHERE study_group_id = target_group_id
  AND status = 'published';

  IF total_lessons = 0 THEN
    RETURN 0;
  END IF;

  -- Contar presenças
  SELECT COUNT(*) INTO present_count
  FROM study_attendance sa
  JOIN study_lessons sl ON sl.id = sa.study_lesson_id
  WHERE sl.study_group_id = target_group_id
  AND sa.user_id = target_user_id
  AND sa.status = 'present';

  RETURN ROUND((present_count::NUMERIC / total_lessons::NUMERIC) * 100, 2);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 18. SEED DATA
-- =====================================================

-- Criar grupo de exemplo (apenas se houver usuários)
DO $$
DECLARE
  first_user_id UUID;
  group_id UUID;
  lesson1_id UUID;
BEGIN
  -- Buscar primeiro usuário
  SELECT id INTO first_user_id FROM auth.users LIMIT 1;

  IF first_user_id IS NOT NULL THEN
    -- Criar grupo de exemplo
    INSERT INTO study_groups (
      name,
      description,
      study_topic,
      status,
      start_date,
      meeting_day,
      meeting_time,
      meeting_location,
      is_public,
      created_by
    ) VALUES (
      'Estudo do Evangelho de João',
      'Um estudo profundo sobre o Evangelho de João, explorando a divindade de Cristo e Seu amor pela humanidade.',
      'Evangelho de João',
      'active',
      CURRENT_DATE,
      'Quarta-feira',
      '19:30:00',
      'Sala 3 - Presencial',
      true,
      first_user_id
    ) RETURNING id INTO group_id;

    -- Criar primeira lição
    INSERT INTO study_lessons (
      study_group_id,
      lesson_number,
      title,
      description,
      bible_references,
      content,
      discussion_questions,
      status,
      scheduled_date,
      created_by
    ) VALUES (
      group_id,
      1,
      'No Princípio Era o Verbo',
      'Introdução ao Evangelho de João - A divindade de Cristo',
      'João 1:1-18',
      E'# No Princípio Era o Verbo\n\n## Introdução\n\nO Evangelho de João começa de forma única, apresentando Jesus como o Verbo eterno que estava com Deus e era Deus.\n\n## Texto Base\n\n> "No princípio era o Verbo, e o Verbo estava com Deus, e o Verbo era Deus." - João 1:1\n\n## Pontos Principais\n\n1. **A Eternidade do Verbo** - Jesus existia antes da criação\n2. **A Divindade do Verbo** - Jesus é Deus\n3. **O Verbo se Fez Carne** - A encarnação de Cristo\n\n## Aplicação Prática\n\nComo a divindade de Cristo impacta nossa vida diária?',
      jsonb_build_array(
        'O que significa "o Verbo era Deus"?',
        'Como a encarnação de Cristo demonstra o amor de Deus?',
        'De que forma podemos refletir a luz de Cristo em nossa vida?'
      ),
      'published',
      CURRENT_DATE + INTERVAL '7 days',
      first_user_id
    ) RETURNING id INTO lesson1_id;

  END IF;
END $$;

