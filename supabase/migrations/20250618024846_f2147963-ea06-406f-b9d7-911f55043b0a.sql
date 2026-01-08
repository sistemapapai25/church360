
-- Criar tabela para banners do carrossel da home
CREATE TABLE public.banners_home (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  titulo TEXT NOT NULL,
  subtitulo TEXT,
  imagem_url TEXT,
  tipo TEXT NOT NULL DEFAULT 'evento',
  icone TEXT,
  ordem INTEGER NOT NULL DEFAULT 0,
  ativo BOOLEAN NOT NULL DEFAULT true,
  link TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  criado_por UUID REFERENCES auth.users(id)
);

-- Adicionar RLS
ALTER TABLE public.banners_home ENABLE ROW LEVEL SECURITY;

-- Política para visualização - todos podem ver banners ativos
CREATE POLICY "Todos podem ver banners ativos" 
  ON public.banners_home 
  FOR SELECT 
  USING (ativo = true);

-- Política para admins/pastores gerenciarem banners
CREATE POLICY "Admins e pastores podem gerenciar banners" 
  ON public.banners_home 
  FOR ALL 
  USING (public.is_admin_or_pastor(auth.uid()))
  WITH CHECK (public.is_admin_or_pastor(auth.uid()));

-- Inserir alguns banners de exemplo
INSERT INTO public.banners_home (titulo, subtitulo, imagem_url, tipo, icone, ordem, ativo) VALUES
('Série: Transforme Sua Mente', 'Uma jornada de renovação espiritual', 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=400&h=200&fit=crop', 'series', 'Play', 1, true),
('Conferência da Família', 'Fortalecendo os laços familiares', 'https://images.unsplash.com/photo-1517022812141-23620dba5c23?w=400&h=200&fit=crop', 'event', 'Calendar', 2, true),
('Culto Ao Vivo', 'Clique para assistir agora', 'https://images.unsplash.com/photo-1466442929976-97f336a657be?w=400&h=200&fit=crop', 'live', 'Heart', 3, true);

-- Adicionar trigger para updated_at
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.banners_home 
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
;
