-- =====================================================
-- TABELA: INFORMAÇÕES DA IGREJA
-- =====================================================

-- Criar tabela de informações da igreja
CREATE TABLE IF NOT EXISTS public.church_info (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  logo_url TEXT,
  mission TEXT,
  vision TEXT,
  values JSONB, -- Array de strings
  history TEXT,
  address TEXT,
  phone TEXT,
  email TEXT,
  website TEXT,
  social_media JSONB, -- Objeto com redes sociais: {'facebook': 'url', 'instagram': 'url', etc}
  service_times JSONB, -- Array de objetos: [{'day': 'Domingo', 'time': '10:00', 'description': 'Culto de Celebração'}]
  pastors JSONB, -- Array de objetos: [{'name': 'João Silva', 'title': 'Pastor Titular', 'photo_url': 'url', 'bio': 'texto'}]
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

-- Habilitar RLS (Row Level Security)
ALTER TABLE public.church_info ENABLE ROW LEVEL SECURITY;

-- Criar políticas (com DROP IF EXISTS para evitar duplicação)
DROP POLICY IF EXISTS "Todos podem visualizar informações da igreja" ON public.church_info;
CREATE POLICY "Todos podem visualizar informações da igreja"
  ON public.church_info
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Autenticados podem criar informações da igreja" ON public.church_info;
CREATE POLICY "Autenticados podem criar informações da igreja"
  ON public.church_info
  FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Autenticados podem atualizar informações da igreja" ON public.church_info;
CREATE POLICY "Autenticados podem atualizar informações da igreja"
  ON public.church_info
  FOR UPDATE
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Autenticados podem deletar informações da igreja" ON public.church_info;
CREATE POLICY "Autenticados podem deletar informações da igreja"
  ON public.church_info
  FOR DELETE
  USING (auth.role() = 'authenticated');

-- =====================================================
-- DADOS DE EXEMPLO (OPCIONAL)
-- =====================================================

-- Inserir dados de exemplo (você pode editar ou remover isso)
INSERT INTO public.church_info (
  name,
  mission,
  vision,
  values,
  history,
  address,
  phone,
  email,
  website,
  social_media,
  service_times,
  pastors
) VALUES (
  'Igreja Exemplo',
  'Nossa missão é proclamar o evangelho de Jesus Cristo e fazer discípulos em todas as nações.',
  'Ser uma igreja relevante, transformadora e que impacta vidas para a glória de Deus.',
  '["Amor a Deus", "Amor ao próximo", "Integridade", "Excelência", "Comunhão"]'::jsonb,
  'Fundada em 1990, nossa igreja tem uma história rica de fé e serviço à comunidade. Ao longo dos anos, temos crescido e nos desenvolvido, sempre mantendo nosso compromisso com o evangelho de Jesus Cristo.',
  'Rua Exemplo, 123 - Centro - Cidade/UF - CEP 12345-678',
  '(11) 1234-5678',
  'contato@igrejaexemplo.com.br',
  'https://www.igrejaexemplo.com.br',
  '{"facebook": "https://facebook.com/igrejaexemplo", "instagram": "https://instagram.com/igrejaexemplo", "youtube": "https://youtube.com/@igrejaexemplo"}'::jsonb,
  '[
    {"day": "Domingo", "time": "10:00", "description": "Culto de Celebração"},
    {"day": "Domingo", "time": "18:00", "description": "Culto da Família"},
    {"day": "Quarta-feira", "time": "20:00", "description": "Culto de Oração"}
  ]'::jsonb,
  '[
    {
      "name": "Pastor João Silva",
      "title": "Pastor Titular",
      "bio": "Servindo ao Senhor há mais de 20 anos"
    },
    {
      "name": "Pastora Maria Santos",
      "title": "Pastora Auxiliar",
      "bio": "Dedicada ao ministério de mulheres e crianças"
    }
  ]'::jsonb
)
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- COMENTÁRIOS
-- =====================================================

COMMENT ON TABLE public.church_info IS 'Informações gerais da igreja';
COMMENT ON COLUMN public.church_info.name IS 'Nome da igreja';
COMMENT ON COLUMN public.church_info.logo_url IS 'URL do logo da igreja';
COMMENT ON COLUMN public.church_info.mission IS 'Missão da igreja';
COMMENT ON COLUMN public.church_info.vision IS 'Visão da igreja';
COMMENT ON COLUMN public.church_info.values IS 'Valores da igreja (array de strings)';
COMMENT ON COLUMN public.church_info.history IS 'História da igreja';
COMMENT ON COLUMN public.church_info.address IS 'Endereço completo';
COMMENT ON COLUMN public.church_info.phone IS 'Telefone de contato';
COMMENT ON COLUMN public.church_info.email IS 'Email de contato';
COMMENT ON COLUMN public.church_info.website IS 'Website da igreja';
COMMENT ON COLUMN public.church_info.social_media IS 'Redes sociais (objeto JSON)';
COMMENT ON COLUMN public.church_info.service_times IS 'Horários de culto (array de objetos JSON)';
COMMENT ON COLUMN public.church_info.pastors IS 'Pastores e líderes (array de objetos JSON)';

