
-- Criar tabela para devocionais
CREATE TABLE public.devocionais (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  titulo TEXT NOT NULL,
  texto TEXT NOT NULL,
  versiculo TEXT,
  referencia_biblica TEXT,
  data_devocional DATE NOT NULL DEFAULT CURRENT_DATE,
  ativo BOOLEAN NOT NULL DEFAULT true,
  criado_por UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Adicionar campo categoria_acesso na tabela eventos
ALTER TABLE public.eventos 
ADD COLUMN categoria_acesso TEXT DEFAULT 'membro' 
CHECK (categoria_acesso IN ('visitante', 'membro', 'lider', 'pastor'));

-- Adicionar índices para melhor performance
CREATE INDEX idx_devocionais_data_ativo ON public.devocionais(data_devocional, ativo);
CREATE INDEX idx_eventos_categoria_acesso ON public.eventos(categoria_acesso);

-- Habilitar Row Level Security
ALTER TABLE public.devocionais ENABLE ROW LEVEL SECURITY;

-- Política para visualizar devocionais (todos podem ver devocionais ativos)
CREATE POLICY "Todos podem ver devocionais ativos" 
  ON public.devocionais 
  FOR SELECT 
  USING (ativo = true);

-- Política para admins e pastores gerenciarem devocionais
CREATE POLICY "Admins e pastores podem gerenciar devocionais" 
  ON public.devocionais 
  FOR ALL 
  TO authenticated
  USING (public.is_admin_or_pastor(auth.uid()))
  WITH CHECK (public.is_admin_or_pastor(auth.uid()));

-- Trigger para atualizar updated_at
CREATE TRIGGER handle_updated_at_devocionais
  BEFORE UPDATE ON public.devocionais
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();
;
