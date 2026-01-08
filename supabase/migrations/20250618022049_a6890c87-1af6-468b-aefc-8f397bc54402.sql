
-- Criar tabela para conteúdo da página inicial
CREATE TABLE public.conteudo_home (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  titulo TEXT NOT NULL,
  tipo TEXT NOT NULL CHECK (tipo IN ('vídeo', 'campanha', 'série', 'evento')),
  categoria TEXT NOT NULL CHECK (categoria IN ('edificacao', 'fique_por_dentro')),
  pregador TEXT,
  imagem_url TEXT,
  link TEXT,
  ordem INTEGER NOT NULL DEFAULT 0,
  ativo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  criado_por UUID REFERENCES auth.users(id)
);

-- Adicionar índices para melhor performance
CREATE INDEX idx_conteudo_home_categoria_ativo ON public.conteudo_home(categoria, ativo);
CREATE INDEX idx_conteudo_home_ordem ON public.conteudo_home(ordem);

-- Habilitar Row Level Security
ALTER TABLE public.conteudo_home ENABLE ROW LEVEL SECURITY;

-- Política para visualizar conteúdo (todos podem ver conteúdo ativo)
CREATE POLICY "Todos podem ver conteúdo ativo" 
  ON public.conteudo_home 
  FOR SELECT 
  USING (ativo = true);

-- Política para admins e pastores gerenciarem conteúdo
CREATE POLICY "Admins e pastores podem gerenciar conteúdo" 
  ON public.conteudo_home 
  FOR ALL 
  TO authenticated
  USING (public.is_admin_or_pastor(auth.uid()))
  WITH CHECK (public.is_admin_or_pastor(auth.uid()));

-- Trigger para atualizar updated_at
CREATE TRIGGER handle_updated_at_conteudo_home
  BEFORE UPDATE ON public.conteudo_home
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();
;
