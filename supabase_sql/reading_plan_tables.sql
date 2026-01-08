-- =====================================================
-- TABELA: PLANOS DE LEITURA
-- =====================================================

-- Criar tabela de planos de leitura
CREATE TABLE IF NOT EXISTS public.reading_plan (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  duration_days INTEGER NOT NULL,
  image_url TEXT,
  status TEXT DEFAULT 'active', -- 'active', 'inactive'
  category TEXT, -- 'complete_bible', 'new_testament', 'old_testament', 'devotional'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  tenant_id UUID REFERENCES public.tenant(id) ON DELETE CASCADE
);

-- Garantir coluna tenant_id em tabelas já existentes e realizar backfill
ALTER TABLE public.reading_plan ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenant(id) ON DELETE CASCADE;
ALTER TABLE public.reading_plan ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
UPDATE public.reading_plan rp
  SET tenant_id = (SELECT id FROM public.tenant LIMIT 1)
WHERE rp.tenant_id IS NULL;

-- Habilitar RLS
ALTER TABLE public.reading_plan ENABLE ROW LEVEL SECURITY;

-- Criar políticas
DROP POLICY IF EXISTS tenant_select_reading_plan ON public.reading_plan;
CREATE POLICY tenant_select_reading_plan
  ON public.reading_plan
  FOR SELECT
  USING (tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS tenant_insert_reading_plan ON public.reading_plan;
CREATE POLICY tenant_insert_reading_plan
  ON public.reading_plan
  FOR INSERT
  WITH CHECK (tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS tenant_update_reading_plan ON public.reading_plan;
CREATE POLICY tenant_update_reading_plan
  ON public.reading_plan
  FOR UPDATE
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS tenant_delete_reading_plan ON public.reading_plan;
CREATE POLICY tenant_delete_reading_plan
  ON public.reading_plan
  FOR DELETE
  USING (tenant_id = public.current_tenant_id());

-- Criar índices
CREATE INDEX IF NOT EXISTS idx_reading_plan_status ON public.reading_plan(status);
CREATE INDEX IF NOT EXISTS idx_reading_plan_category ON public.reading_plan(category);
CREATE INDEX IF NOT EXISTS idx_reading_plan_tenant_id ON public.reading_plan(tenant_id);

-- =====================================================
-- TABELA: PROGRESSO DO USUÁRIO NOS PLANOS
-- =====================================================

-- Criar tabela de progresso do usuário
CREATE TABLE IF NOT EXISTS public.reading_plan_progress (
  plan_id UUID NOT NULL REFERENCES public.reading_plan(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.user_account(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  current_day INTEGER DEFAULT 1,
  completed_at TIMESTAMPTZ,
  last_read_at TIMESTAMPTZ,
  tenant_id UUID REFERENCES public.tenant(id) ON DELETE CASCADE,
  PRIMARY KEY (plan_id, user_id)
);

-- Garantir coluna tenant_id e backfill a partir do plano
ALTER TABLE public.reading_plan_progress ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenant(id) ON DELETE CASCADE;
ALTER TABLE public.reading_plan_progress ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
UPDATE public.reading_plan_progress rpp
  SET tenant_id = rp.tenant_id
FROM public.reading_plan rp
WHERE rpp.plan_id = rp.id AND rpp.tenant_id IS NULL;

-- Habilitar RLS
ALTER TABLE public.reading_plan_progress ENABLE ROW LEVEL SECURITY;

-- Criar políticas
DROP POLICY IF EXISTS tenant_select_reading_plan_progress ON public.reading_plan_progress;
CREATE POLICY tenant_select_reading_plan_progress
  ON public.reading_plan_progress
  FOR SELECT
  USING (auth.uid() = user_id AND tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS tenant_insert_reading_plan_progress ON public.reading_plan_progress;
CREATE POLICY tenant_insert_reading_plan_progress
  ON public.reading_plan_progress
  FOR INSERT
  WITH CHECK (auth.uid() = user_id AND tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS tenant_update_reading_plan_progress ON public.reading_plan_progress;
CREATE POLICY tenant_update_reading_plan_progress
  ON public.reading_plan_progress
  FOR UPDATE
  USING (auth.uid() = user_id AND tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS tenant_delete_reading_plan_progress ON public.reading_plan_progress;
CREATE POLICY tenant_delete_reading_plan_progress
  ON public.reading_plan_progress
  FOR DELETE
  USING (auth.uid() = user_id AND tenant_id = public.current_tenant_id());

-- Criar índices
CREATE INDEX IF NOT EXISTS idx_reading_plan_progress_user ON public.reading_plan_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_reading_plan_progress_completed ON public.reading_plan_progress(completed_at);
CREATE INDEX IF NOT EXISTS idx_reading_plan_progress_tenant_id ON public.reading_plan_progress(tenant_id);

-- =====================================================
-- DADOS DE EXEMPLO
-- =====================================================

-- Inserir planos de leitura de exemplo
INSERT INTO public.reading_plan (title, description, duration_days, category, status)
VALUES
  (
    'Leia a Bíblia em 1 Ano',
    'Um plano completo para ler toda a Bíblia em 365 dias. Você lerá aproximadamente 3-4 capítulos por dia, incluindo passagens do Antigo e Novo Testamento, Salmos e Provérbios.',
    365,
    'complete_bible',
    'active'
  ),
  (
    'Leia a Bíblia em 90 Dias',
    'Um plano intensivo para ler toda a Bíblia em apenas 90 dias. Ideal para quem quer uma imersão profunda nas Escrituras. Você lerá aproximadamente 12 capítulos por dia.',
    90,
    'complete_bible',
    'active'
  ),
  (
    'Leia a Bíblia em 6 Meses',
    'Um plano equilibrado para ler toda a Bíblia em 180 dias. Você lerá aproximadamente 6-7 capítulos por dia, com um ritmo confortável e sustentável.',
    180,
    'complete_bible',
    'active'
  ),
  (
    'Novo Testamento em 30 Dias',
    'Leia todo o Novo Testamento em apenas um mês. Perfeito para quem quer conhecer melhor a vida de Jesus e os ensinamentos dos apóstolos. Aproximadamente 9 capítulos por dia.',
    30,
    'new_testament',
    'active'
  ),
  (
    'Salmos e Provérbios',
    'Um plano devocional focado em Salmos e Provérbios. Leia um Salmo e um capítulo de Provérbios por dia durante 150 dias. Ideal para meditação e sabedoria diária.',
    150,
    'devotional',
    'active'
  ),
  (
    'Evangelhos em 40 Dias',
    'Leia os quatro Evangelhos (Mateus, Marcos, Lucas e João) em 40 dias. Conheça a vida e os ensinamentos de Jesus através de diferentes perspectivas.',
    40,
    'new_testament',
    'active'
  ),
  (
    'Pentateuco em 60 Dias',
    'Leia os cinco primeiros livros da Bíblia (Gênesis, Êxodo, Levítico, Números e Deuteronômio) em 60 dias. Descubra as origens da fé e a história do povo de Deus.',
    60,
    'old_testament',
    'active'
  )
ON CONFLICT DO NOTHING;
