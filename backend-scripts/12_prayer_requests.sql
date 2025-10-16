-- =====================================================
-- CHURCH 360 - SISTEMA DE PEDIDOS DE ORAÇÃO
-- =====================================================
-- Descrição: Sistema de pedidos de oração com categorias,
--            status, privacidade, contador de orações e testemunhos
-- Features: CRUD de pedidos, marcar "eu orei", testemunhos,
--           compartilhar com grupos, estatísticas
-- =====================================================

-- =====================================================
-- 1. ENUMS
-- =====================================================

-- Categoria do pedido
CREATE TYPE prayer_category AS ENUM (
  'personal',      -- Pessoal
  'family',        -- Família
  'health',        -- Saúde
  'work',          -- Trabalho
  'ministry',      -- Ministério
  'church',        -- Igreja
  'other'          -- Outro
);

-- Status do pedido
CREATE TYPE prayer_status AS ENUM (
  'pending',       -- Pendente
  'praying',       -- Em oração
  'answered',      -- Respondido
  'cancelled'      -- Cancelado
);

-- Nível de privacidade
CREATE TYPE prayer_privacy AS ENUM (
  'public',        -- Público (todos veem)
  'members_only',  -- Apenas membros
  'leaders_only',  -- Apenas líderes
  'private'        -- Privado (apenas autor)
);

-- =====================================================
-- 2. TABELA: prayer_requests
-- =====================================================

CREATE TABLE IF NOT EXISTS prayer_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Informações do pedido
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  category prayer_category NOT NULL DEFAULT 'personal',
  status prayer_status NOT NULL DEFAULT 'pending',
  privacy prayer_privacy NOT NULL DEFAULT 'public',
  
  -- Autor
  author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Datas
  answered_at TIMESTAMPTZ, -- Data em que foi marcado como respondido
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Índices
  CONSTRAINT prayer_requests_title_not_empty CHECK (LENGTH(TRIM(title)) > 0),
  CONSTRAINT prayer_requests_description_not_empty CHECK (LENGTH(TRIM(description)) > 0)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_prayer_requests_author ON prayer_requests(author_id);
CREATE INDEX IF NOT EXISTS idx_prayer_requests_status ON prayer_requests(status);
CREATE INDEX IF NOT EXISTS idx_prayer_requests_category ON prayer_requests(category);
CREATE INDEX IF NOT EXISTS idx_prayer_requests_privacy ON prayer_requests(privacy);
CREATE INDEX IF NOT EXISTS idx_prayer_requests_created ON prayer_requests(created_at DESC);

-- =====================================================
-- 3. TABELA: prayer_request_prayers
-- =====================================================

CREATE TABLE IF NOT EXISTS prayer_request_prayers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Relacionamentos
  prayer_request_id UUID NOT NULL REFERENCES prayer_requests(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Informações
  prayed_at TIMESTAMPTZ DEFAULT NOW(),
  note TEXT, -- Nota opcional (ex: "Orei por você hoje!")
  
  -- Metadados
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraint: um usuário pode marcar várias vezes que orou
  -- (não há UNIQUE constraint aqui)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_prayer_request_prayers_request ON prayer_request_prayers(prayer_request_id);
CREATE INDEX IF NOT EXISTS idx_prayer_request_prayers_user ON prayer_request_prayers(user_id);
CREATE INDEX IF NOT EXISTS idx_prayer_request_prayers_date ON prayer_request_prayers(prayed_at DESC);

-- =====================================================
-- 4. TABELA: prayer_request_testimonies
-- =====================================================

CREATE TABLE IF NOT EXISTS prayer_request_testimonies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Relacionamento
  prayer_request_id UUID NOT NULL REFERENCES prayer_requests(id) ON DELETE CASCADE,
  
  -- Informações do testemunho
  testimony TEXT NOT NULL,
  
  -- Metadados
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraint: apenas um testemunho por pedido
  CONSTRAINT prayer_request_testimonies_unique UNIQUE (prayer_request_id),
  CONSTRAINT prayer_request_testimonies_not_empty CHECK (LENGTH(TRIM(testimony)) > 0)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_prayer_request_testimonies_request ON prayer_request_testimonies(prayer_request_id);

-- =====================================================
-- 5. TABELA: prayer_request_groups (compartilhar com grupos)
-- =====================================================

CREATE TABLE IF NOT EXISTS prayer_request_groups (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Relacionamentos
  prayer_request_id UUID NOT NULL REFERENCES prayer_requests(id) ON DELETE CASCADE,
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  
  -- Metadados
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraint: um pedido só pode ser compartilhado uma vez com cada grupo
  CONSTRAINT prayer_request_groups_unique UNIQUE (prayer_request_id, group_id)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_prayer_request_groups_request ON prayer_request_groups(prayer_request_id);
CREATE INDEX IF NOT EXISTS idx_prayer_request_groups_group ON prayer_request_groups(group_id);

-- =====================================================
-- 6. TRIGGERS: updated_at
-- =====================================================

-- Trigger para prayer_requests
CREATE OR REPLACE FUNCTION update_prayer_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  
  -- Se status mudou para 'answered', atualizar answered_at
  IF NEW.status = 'answered' AND OLD.status != 'answered' THEN
    NEW.answered_at = NOW();
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_prayer_requests_updated_at ON prayer_requests;
CREATE TRIGGER trigger_update_prayer_requests_updated_at
  BEFORE UPDATE ON prayer_requests
  FOR EACH ROW
  EXECUTE FUNCTION update_prayer_requests_updated_at();

-- Trigger para prayer_request_prayers
CREATE OR REPLACE FUNCTION update_prayer_request_prayers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_prayer_request_prayers_updated_at ON prayer_request_prayers;
CREATE TRIGGER trigger_update_prayer_request_prayers_updated_at
  BEFORE UPDATE ON prayer_request_prayers
  FOR EACH ROW
  EXECUTE FUNCTION update_prayer_request_prayers_updated_at();

-- Trigger para prayer_request_testimonies
CREATE OR REPLACE FUNCTION update_prayer_request_testimonies_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_prayer_request_testimonies_updated_at ON prayer_request_testimonies;
CREATE TRIGGER trigger_update_prayer_request_testimonies_updated_at
  BEFORE UPDATE ON prayer_request_testimonies
  FOR EACH ROW
  EXECUTE FUNCTION update_prayer_request_testimonies_updated_at();

-- =====================================================
-- 7. RLS POLICIES: prayer_requests
-- =====================================================

-- Habilitar RLS
ALTER TABLE prayer_requests ENABLE ROW LEVEL SECURITY;

-- Policy: Ver pedidos PÚBLICOS
DROP POLICY IF EXISTS "Todos podem ver pedidos públicos" ON prayer_requests;
CREATE POLICY "Todos podem ver pedidos públicos"
  ON prayer_requests
  FOR SELECT
  USING (privacy = 'public');

-- Policy: MEMBROS+ podem ver pedidos "members_only"
DROP POLICY IF EXISTS "Membros podem ver pedidos members_only" ON prayer_requests;
CREATE POLICY "Membros podem ver pedidos members_only"
  ON prayer_requests
  FOR SELECT
  USING (
    privacy = 'members_only'
    AND EXISTS (
      SELECT 1 FROM user_access_level
      WHERE user_id = auth.uid()
      AND access_level_number >= 2 -- Membro ou superior
    )
  );

-- Policy: LÍDERES+ podem ver pedidos "leaders_only"
DROP POLICY IF EXISTS "Líderes podem ver pedidos leaders_only" ON prayer_requests;
CREATE POLICY "Líderes podem ver pedidos leaders_only"
  ON prayer_requests
  FOR SELECT
  USING (
    privacy = 'leaders_only'
    AND EXISTS (
      SELECT 1 FROM user_access_level
      WHERE user_id = auth.uid()
      AND access_level_number >= 3 -- Líder ou superior
    )
  );

-- Policy: Autor pode ver seus próprios pedidos (incluindo privados)
DROP POLICY IF EXISTS "Autor pode ver seus pedidos" ON prayer_requests;
CREATE POLICY "Autor pode ver seus pedidos"
  ON prayer_requests
  FOR SELECT
  USING (author_id = auth.uid());

-- Policy: Usuários autenticados podem CRIAR pedidos
DROP POLICY IF EXISTS "Usuários podem criar pedidos" ON prayer_requests;
CREATE POLICY "Usuários podem criar pedidos"
  ON prayer_requests
  FOR INSERT
  WITH CHECK (author_id = auth.uid());

-- Policy: Autor pode ATUALIZAR seus pedidos
DROP POLICY IF EXISTS "Autor pode atualizar seus pedidos" ON prayer_requests;
CREATE POLICY "Autor pode atualizar seus pedidos"
  ON prayer_requests
  FOR UPDATE
  USING (author_id = auth.uid());

-- Policy: Autor pode DELETAR seus pedidos
DROP POLICY IF EXISTS "Autor pode deletar seus pedidos" ON prayer_requests;
CREATE POLICY "Autor pode deletar seus pedidos"
  ON prayer_requests
  FOR DELETE
  USING (author_id = auth.uid());

-- =====================================================
-- 8. RLS POLICIES: prayer_request_prayers
-- =====================================================

-- Habilitar RLS
ALTER TABLE prayer_request_prayers ENABLE ROW LEVEL SECURITY;

-- Policy: Usuários podem VER orações de pedidos que eles podem ver
DROP POLICY IF EXISTS "Usuários podem ver orações" ON prayer_request_prayers;
CREATE POLICY "Usuários podem ver orações"
  ON prayer_request_prayers
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM prayer_requests pr
      WHERE pr.id = prayer_request_id
      -- Usar as mesmas regras de visibilidade dos pedidos
    )
  );

-- Policy: Usuários autenticados podem CRIAR orações
DROP POLICY IF EXISTS "Usuários podem criar orações" ON prayer_request_prayers;
CREATE POLICY "Usuários podem criar orações"
  ON prayer_request_prayers
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Policy: Usuário pode ATUALIZAR suas próprias orações
DROP POLICY IF EXISTS "Usuário pode atualizar suas orações" ON prayer_request_prayers;
CREATE POLICY "Usuário pode atualizar suas orações"
  ON prayer_request_prayers
  FOR UPDATE
  USING (user_id = auth.uid());

-- Policy: Usuário pode DELETAR suas próprias orações
DROP POLICY IF EXISTS "Usuário pode deletar suas orações" ON prayer_request_prayers;
CREATE POLICY "Usuário pode deletar suas orações"
  ON prayer_request_prayers
  FOR DELETE
  USING (user_id = auth.uid());

-- =====================================================
-- 9. RLS POLICIES: prayer_request_testimonies
-- =====================================================

-- Habilitar RLS
ALTER TABLE prayer_request_testimonies ENABLE ROW LEVEL SECURITY;

-- Policy: Usuários podem VER testemunhos de pedidos que eles podem ver
DROP POLICY IF EXISTS "Usuários podem ver testemunhos" ON prayer_request_testimonies;
CREATE POLICY "Usuários podem ver testemunhos"
  ON prayer_request_testimonies
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM prayer_requests pr
      WHERE pr.id = prayer_request_id
      -- Usar as mesmas regras de visibilidade dos pedidos
    )
  );

-- Policy: Autor do pedido pode CRIAR testemunho
DROP POLICY IF EXISTS "Autor pode criar testemunho" ON prayer_request_testimonies;
CREATE POLICY "Autor pode criar testemunho"
  ON prayer_request_testimonies
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM prayer_requests pr
      WHERE pr.id = prayer_request_id
      AND pr.author_id = auth.uid()
    )
  );

-- Policy: Autor do pedido pode ATUALIZAR testemunho
DROP POLICY IF EXISTS "Autor pode atualizar testemunho" ON prayer_request_testimonies;
CREATE POLICY "Autor pode atualizar testemunho"
  ON prayer_request_testimonies
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM prayer_requests pr
      WHERE pr.id = prayer_request_id
      AND pr.author_id = auth.uid()
    )
  );

-- Policy: Autor do pedido pode DELETAR testemunho
DROP POLICY IF EXISTS "Autor pode deletar testemunho" ON prayer_request_testimonies;
CREATE POLICY "Autor pode deletar testemunho"
  ON prayer_request_testimonies
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM prayer_requests pr
      WHERE pr.id = prayer_request_id
      AND pr.author_id = auth.uid()
    )
  );

-- =====================================================
-- 10. RLS POLICIES: prayer_request_groups
-- =====================================================

-- Habilitar RLS
ALTER TABLE prayer_request_groups ENABLE ROW LEVEL SECURITY;

-- Policy: Membros do grupo podem VER pedidos compartilhados
DROP POLICY IF EXISTS "Membros do grupo podem ver pedidos compartilhados" ON prayer_request_groups;
CREATE POLICY "Membros do grupo podem ver pedidos compartilhados"
  ON prayer_request_groups
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM group_members gm
      WHERE gm.group_id = prayer_request_groups.group_id
      AND gm.member_id IN (
        SELECT id FROM members WHERE user_id = auth.uid()
      )
    )
  );

-- Policy: Autor do pedido pode CRIAR compartilhamento
DROP POLICY IF EXISTS "Autor pode compartilhar pedido" ON prayer_request_groups;
CREATE POLICY "Autor pode compartilhar pedido"
  ON prayer_request_groups
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM prayer_requests pr
      WHERE pr.id = prayer_request_id
      AND pr.author_id = auth.uid()
    )
  );

-- Policy: Autor do pedido pode DELETAR compartilhamento
DROP POLICY IF EXISTS "Autor pode remover compartilhamento" ON prayer_request_groups;
CREATE POLICY "Autor pode remover compartilhamento"
  ON prayer_request_groups
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM prayer_requests pr
      WHERE pr.id = prayer_request_id
      AND pr.author_id = auth.uid()
    )
  );

-- =====================================================
-- 11. FUNÇÕES AUXILIARES
-- =====================================================

-- Função: Obter estatísticas de um pedido
CREATE OR REPLACE FUNCTION get_prayer_request_stats(request_uuid UUID)
RETURNS TABLE (
  total_prayers BIGINT,
  unique_prayers BIGINT,
  has_testimony BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(prp.id)::BIGINT as total_prayers,
    COUNT(DISTINCT prp.user_id)::BIGINT as unique_prayers,
    EXISTS (
      SELECT 1 FROM prayer_request_testimonies prt
      WHERE prt.prayer_request_id = request_uuid
    ) as has_testimony
  FROM prayer_request_prayers prp
  WHERE prp.prayer_request_id = request_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função: Obter pedidos por categoria
CREATE OR REPLACE FUNCTION get_prayer_requests_by_category()
RETURNS TABLE (
  category prayer_category,
  total_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    pr.category,
    COUNT(*)::BIGINT as total_count
  FROM prayer_requests pr
  GROUP BY pr.category
  ORDER BY total_count DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função: Obter pedidos por status
CREATE OR REPLACE FUNCTION get_prayer_requests_by_status()
RETURNS TABLE (
  status prayer_status,
  total_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    pr.status,
    COUNT(*)::BIGINT as total_count
  FROM prayer_requests pr
  GROUP BY pr.status
  ORDER BY total_count DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 12. SEED DATA (Exemplo de pedido)
-- =====================================================

-- Inserir pedido de exemplo (apenas se não existir nenhum)
DO $$
DECLARE
  admin_user_id UUID;
  example_request_id UUID;
BEGIN
  -- Buscar um usuário admin
  SELECT user_id INTO admin_user_id
  FROM user_access_level
  WHERE access_level = 'admin'
  LIMIT 1;

  -- Se encontrou admin e não há pedidos, criar exemplo
  IF admin_user_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM prayer_requests LIMIT 1) THEN
    -- Criar pedido de exemplo
    INSERT INTO prayer_requests (
      title,
      description,
      category,
      status,
      privacy,
      author_id
    ) VALUES (
      'Bem-vindo ao Sistema de Pedidos de Oração!',
      E'Este é um exemplo de pedido de oração.\n\nAqui você pode compartilhar suas necessidades de oração com a igreja e receber apoio espiritual da comunidade.\n\n"Confessai as vossas culpas uns aos outros, e orai uns pelos outros, para que sareis. A oração feita por um justo pode muito em seus efeitos." - Tiago 5:16',
      'church',
      'pending',
      'public',
      admin_user_id
    )
    RETURNING id INTO example_request_id;

    -- Marcar que o admin orou
    INSERT INTO prayer_request_prayers (
      prayer_request_id,
      user_id,
      note
    ) VALUES (
      example_request_id,
      admin_user_id,
      'Orando por nossa igreja!'
    );
  END IF;
END $$;


