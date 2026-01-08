
-- Criar tabela para agenda pastoral
CREATE TABLE public.agenda_pastoral (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  pastor_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  membro_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  titulo TEXT NOT NULL,
  descricao TEXT,
  tipo TEXT NOT NULL CHECK (tipo IN ('visita', 'aconselhamento', 'reuniao', 'casamento', 'batismo', 'outro')),
  data_agendamento TIMESTAMP WITH TIME ZONE NOT NULL,
  duracao_minutos INTEGER DEFAULT 60,
  local TEXT,
  status TEXT NOT NULL DEFAULT 'agendado' CHECK (status IN ('agendado', 'confirmado', 'realizado', 'cancelado', 'reagendado')),
  observacoes TEXT,
  urgente BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Criar tabela para acompanhamento pastoral
CREATE TABLE public.acompanhamento_pastoral (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  membro_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  pastor_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  tipo_acompanhamento TEXT NOT NULL CHECK (tipo_acompanhamento IN ('visita', 'aconselhamento', 'discipulado', 'pastoral', 'outro')),
  assunto TEXT NOT NULL,
  descricao TEXT NOT NULL,
  data_acompanhamento TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  proxima_acao TEXT,
  data_proxima_acao DATE,
  status TEXT NOT NULL DEFAULT 'ativo' CHECK (status IN ('ativo', 'concluido', 'pausado')),
  confidencial BOOLEAN DEFAULT true,
  tags TEXT[],
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Criar tabela para visitação
CREATE TABLE public.visitacao (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  visitador_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  visitado_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  nome_visitado TEXT, -- Para quando não é membro cadastrado
  endereco TEXT NOT NULL,
  tipo_visita TEXT NOT NULL CHECK (tipo_visita IN ('evangelistica', 'pastoral', 'hospitalar', 'luto', 'nova_familia', 'outro')),
  data_visita TIMESTAMP WITH TIME ZONE NOT NULL,
  resultado TEXT NOT NULL CHECK (resultado IN ('positivo', 'neutro', 'negativo', 'nao_encontrou')),
  observacoes TEXT,
  decisoes TEXT, -- Para registrar decisões tomadas durante a visita
  oracao_feita BOOLEAN DEFAULT false,
  material_entregue TEXT[],
  necessidades_identificadas TEXT,
  acompanhamento_necessario BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Criar tabela para relatórios pastorais
CREATE TABLE public.relatorios_pastorais (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  pastor_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  periodo_inicio DATE NOT NULL,
  periodo_fim DATE NOT NULL,
  total_visitas INTEGER DEFAULT 0,
  total_aconselhamentos INTEGER DEFAULT 0,
  total_batismos INTEGER DEFAULT 0,
  total_casamentos INTEGER DEFAULT 0,
  total_funerais INTEGER DEFAULT 0,
  novos_membros INTEGER DEFAULT 0,
  membros_transferidos INTEGER DEFAULT 0,
  principais_desafios TEXT,
  principais_conquistas TEXT,
  planos_futuro TEXT,
  observacoes_gerais TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Habilitar RLS nas novas tabelas
ALTER TABLE public.agenda_pastoral ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.acompanhamento_pastoral ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visitacao ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.relatorios_pastorais ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para agenda_pastoral
CREATE POLICY "Pastores e admins podem gerenciar agenda pastoral"
  ON public.agenda_pastoral
  FOR ALL
  TO authenticated
  USING (public.is_admin_or_pastor(auth.uid()) OR pastor_id = auth.uid());

CREATE POLICY "Membros podem ver seus próprios agendamentos"
  ON public.agenda_pastoral
  FOR SELECT
  TO authenticated
  USING (membro_id = auth.uid());

-- Políticas RLS para acompanhamento_pastoral
CREATE POLICY "Pastores e admins podem gerenciar acompanhamento"
  ON public.acompanhamento_pastoral
  FOR ALL
  TO authenticated
  USING (public.is_admin_or_pastor(auth.uid()) OR pastor_id = auth.uid());

-- Políticas RLS para visitacao
CREATE POLICY "Visitadores podem gerenciar suas visitações"
  ON public.visitacao
  FOR ALL
  TO authenticated
  USING (visitador_id = auth.uid() OR public.is_admin_or_pastor(auth.uid()));

-- Políticas RLS para relatorios_pastorais
CREATE POLICY "Pastores podem gerenciar seus relatórios"
  ON public.relatorios_pastorais
  FOR ALL
  TO authenticated
  USING (pastor_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

-- Criar índices para performance
CREATE INDEX idx_agenda_pastoral_pastor_id ON public.agenda_pastoral(pastor_id);
CREATE INDEX idx_agenda_pastoral_membro_id ON public.agenda_pastoral(membro_id);
CREATE INDEX idx_agenda_pastoral_data ON public.agenda_pastoral(data_agendamento);
CREATE INDEX idx_acompanhamento_membro_id ON public.acompanhamento_pastoral(membro_id);
CREATE INDEX idx_acompanhamento_pastor_id ON public.acompanhamento_pastoral(pastor_id);
CREATE INDEX idx_visitacao_visitador_id ON public.visitacao(visitador_id);
CREATE INDEX idx_visitacao_data ON public.visitacao(data_visita);
CREATE INDEX idx_relatorios_pastor_id ON public.relatorios_pastorais(pastor_id);

-- Triggers para updated_at
CREATE TRIGGER handle_agenda_pastoral_updated_at
  BEFORE UPDATE ON public.agenda_pastoral
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_acompanhamento_pastoral_updated_at
  BEFORE UPDATE ON public.acompanhamento_pastoral
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_visitacao_updated_at
  BEFORE UPDATE ON public.visitacao
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_relatorios_pastorais_updated_at
  BEFORE UPDATE ON public.relatorios_pastorais
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();
;
