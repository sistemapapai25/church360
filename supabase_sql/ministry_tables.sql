-- =====================================================
-- TABELAS DE MINISTÉRIOS
-- =====================================================

-- Tabela de Ministérios
CREATE TABLE IF NOT EXISTS public.ministry (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  icon TEXT NOT NULL, -- Nome do ícone Font Awesome (ex: 'music', 'hands-praying')
  color TEXT NOT NULL, -- Cor em hexadecimal (ex: '#FF5722')
  leader_id UUID REFERENCES public.member(id) ON DELETE SET NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela de Membros dos Ministérios
CREATE TABLE IF NOT EXISTS public.ministry_member (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ministry_id UUID NOT NULL REFERENCES public.ministry(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES public.member(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'Membro', -- Ex: "Líder", "Vice-líder", "Coordenador", "Membro"
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(ministry_id, member_id) -- Um membro não pode estar duplicado no mesmo ministério
);

-- =====================================================
-- ÍNDICES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_ministry_active ON public.ministry(is_active);
CREATE INDEX IF NOT EXISTS idx_ministry_leader ON public.ministry(leader_id);
CREATE INDEX IF NOT EXISTS idx_ministry_member_ministry ON public.ministry_member(ministry_id);
CREATE INDEX IF NOT EXISTS idx_ministry_member_member ON public.ministry_member(member_id);

-- =====================================================
-- RLS POLICIES
-- =====================================================

-- Habilitar RLS
ALTER TABLE public.ministry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ministry_member ENABLE ROW LEVEL SECURITY;

-- Policies para ministry
-- Todos podem ver ministérios
CREATE POLICY "Todos podem ver ministérios"
  ON public.ministry
  FOR SELECT
  USING (true);

-- Apenas admins podem inserir ministérios
CREATE POLICY "Apenas admins podem inserir ministérios"
  ON public.ministry
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.member
      WHERE id = auth.uid()
      AND role IN ('admin', 'pastor')
    )
  );

-- Apenas admins podem atualizar ministérios
CREATE POLICY "Apenas admins podem atualizar ministérios"
  ON public.ministry
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.member
      WHERE id = auth.uid()
      AND role IN ('admin', 'pastor')
    )
  );

-- Apenas admins podem deletar ministérios
CREATE POLICY "Apenas admins podem deletar ministérios"
  ON public.ministry
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.member
      WHERE id = auth.uid()
      AND role IN ('admin', 'pastor')
    )
  );

-- Policies para ministry_member
-- Todos podem ver membros dos ministérios
CREATE POLICY "Todos podem ver membros dos ministérios"
  ON public.ministry_member
  FOR SELECT
  USING (true);

-- Apenas admins e líderes podem adicionar membros
CREATE POLICY "Admins e líderes podem adicionar membros"
  ON public.ministry_member
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.member
      WHERE id = auth.uid()
      AND role IN ('admin', 'pastor', 'leader')
    )
  );

-- Apenas admins e líderes podem remover membros
CREATE POLICY "Admins e líderes podem remover membros"
  ON public.ministry_member
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.member
      WHERE id = auth.uid()
      AND role IN ('admin', 'pastor', 'leader')
    )
  );

-- =====================================================
-- DADOS INICIAIS - MINISTÉRIOS
-- =====================================================

-- ADORAÇÃO & ENSINO
INSERT INTO public.ministry (name, description, icon, color, is_active) VALUES
('Louvor e Adoração', 'Ministério responsável pela música e adoração nos cultos e eventos da igreja.', 'music', '#E91E63', true),
('Intercessão', 'Ministério dedicado à oração e intercessão pela igreja, líderes e necessidades.', 'hands-praying', '#9C27B0', true),
('Ensino/Escola Bíblica', 'Ministério focado no ensino da Palavra de Deus através de aulas e estudos bíblicos.', 'book-open', '#3F51B5', true),
('Discipulado', 'Ministério que acompanha novos convertidos e membros em seu crescimento espiritual.', 'users', '#2196F3', true),
('Teatro/Artes', 'Ministério que usa teatro, dramatizações e artes para comunicar o evangelho.', 'masks-theater', '#FF5722', true),
('Dança', 'Ministério de dança profética e coreografias para adoração.', 'person-running', '#FF9800', true);

-- EVANGELISMO & MISSÕES
INSERT INTO public.ministry (name, description, icon, color, is_active) VALUES
('Evangelismo', 'Ministério focado em levar o evangelho às pessoas através de ações evangelísticas.', 'bullhorn', '#F44336', true),
('Missões', 'Ministério dedicado ao apoio e envio de missionários para outras regiões e países.', 'earth-americas', '#4CAF50', true),
('Visitação', 'Ministério que visita membros, enfermos e novos visitantes da igreja.', 'house-user', '#00BCD4', true),
('Células/Grupos Pequenos', 'Ministério que coordena e apoia os grupos pequenos e células da igreja.', 'people-group', '#009688', true);

-- FAIXAS ETÁRIAS
INSERT INTO public.ministry (name, description, icon, color, is_active) VALUES
('Crianças', 'Ministério dedicado ao ensino e cuidado das crianças da igreja.', 'child', '#FFC107', true),
('Terceira Idade', 'Ministério voltado para o cuidado e atividades com a melhor idade.', 'person-cane', '#795548', true);

-- GRUPOS ESPECÍFICOS
INSERT INTO public.ministry (name, description, icon, color, is_active) VALUES
('Adolescentes', 'Ministério focado no desenvolvimento espiritual e social dos adolescentes.', 'user-graduate', '#FF6F00', true),
('Jovens', 'Ministério dedicado aos jovens da igreja, promovendo comunhão e crescimento.', 'users-rays', '#00E676', true),
('Casais', 'Ministério que fortalece os casamentos através de encontros e aconselhamento.', 'heart', '#E91E63', true),
('Homens', 'Ministério voltado para o desenvolvimento espiritual e liderança dos homens.', 'person', '#1976D2', true),
('Mulheres', 'Ministério dedicado ao fortalecimento espiritual e comunhão entre as mulheres.', 'person-dress', '#D81B60', true);

-- SERVIÇOS & APOIO
INSERT INTO public.ministry (name, description, icon, color, is_active) VALUES
('Diaconia', 'Ministério de assistência social e apoio aos necessitados da igreja e comunidade.', 'hand-holding-heart', '#8BC34A', true),
('Recepção/Hospitalidade', 'Ministério responsável por receber e acolher visitantes e membros da igreja.', 'handshake', '#03A9F4', true),
('Mídia/Comunicação', 'Ministério que cuida da comunicação visual, redes sociais e transmissões.', 'video', '#673AB7', true),
('Aconselhamento', 'Ministério que oferece apoio e aconselhamento espiritual aos membros.', 'comments', '#607D8B', true),
('Segurança', 'Ministério responsável pela segurança e ordem durante os cultos e eventos.', 'shield-halved', '#455A64', true),
('Estacionamento', 'Ministério que organiza e auxilia no estacionamento da igreja.', 'car', '#546E7A', true),
('Limpeza/Manutenção', 'Ministério responsável pela limpeza e manutenção das instalações da igreja.', 'broom', '#78909C', true),
('Cozinha/Alimentação', 'Ministério que prepara e serve alimentos em eventos e confraternizações.', 'utensils', '#FF7043', true);

-- =====================================================
-- FUNÇÃO PARA ATUALIZAR updated_at
-- =====================================================

CREATE OR REPLACE FUNCTION update_ministry_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para atualizar updated_at automaticamente
DROP TRIGGER IF EXISTS ministry_updated_at_trigger ON public.ministry;
CREATE TRIGGER ministry_updated_at_trigger
  BEFORE UPDATE ON public.ministry
  FOR EACH ROW
  EXECUTE FUNCTION update_ministry_updated_at();

-- =====================================================
-- COMENTÁRIOS
-- =====================================================

COMMENT ON TABLE public.ministry IS 'Tabela de ministérios da igreja';
COMMENT ON TABLE public.ministry_member IS 'Tabela de membros dos ministérios';
COMMENT ON COLUMN public.ministry.icon IS 'Nome do ícone Font Awesome (sem prefixo fa-)';
COMMENT ON COLUMN public.ministry.color IS 'Cor em hexadecimal para identificação visual';
COMMENT ON COLUMN public.ministry_member.role IS 'Função do membro no ministério (Líder, Vice-líder, Coordenador, Membro)';

