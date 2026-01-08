
-- Criar enum para tipos de roles
CREATE TYPE public.app_role AS ENUM ('admin', 'pastor', 'lider', 'diacono', 'membro');

-- Criar enum para status de membro
CREATE TYPE public.member_status AS ENUM ('ativo', 'inativo', 'visitante', 'transferido');

-- Criar enum para tipos de evento
CREATE TYPE public.event_type AS ENUM ('culto', 'evento_especial', 'reuniao', 'conferencia', 'curso');

-- Tabela de roles dos usuários
CREATE TABLE public.user_roles (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role app_role NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(user_id, role)
);

-- Tabela de ministérios
CREATE TABLE public.ministerios (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  nome TEXT NOT NULL,
  descricao TEXT,
  lider_id UUID REFERENCES auth.users(id),
  ativo BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Tabela de participação em ministérios
CREATE TABLE public.ministerio_membros (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  ministerio_id UUID REFERENCES public.ministerios(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  data_entrada DATE DEFAULT CURRENT_DATE,
  ativo BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(ministerio_id, user_id)
);

-- Tabela de eventos
CREATE TABLE public.eventos (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  titulo TEXT NOT NULL,
  descricao TEXT,
  tipo event_type NOT NULL,
  data_inicio TIMESTAMP WITH TIME ZONE NOT NULL,
  data_fim TIMESTAMP WITH TIME ZONE,
  local TEXT,
  vagas_limitadas BOOLEAN DEFAULT false,
  max_vagas INTEGER,
  inscricoes_abertas BOOLEAN DEFAULT true,
  valor DECIMAL(10,2),
  criado_por UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Tabela de inscrições em eventos
CREATE TABLE public.evento_inscricoes (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  evento_id UUID REFERENCES public.eventos(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'confirmado' CHECK (status IN ('confirmado', 'cancelado', 'lista_espera')),
  data_inscricao TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(evento_id, user_id)
);

-- Tabela de presença em eventos
CREATE TABLE public.evento_presencas (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  evento_id UUID REFERENCES public.eventos(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  presente BOOLEAN DEFAULT false,
  data_presenca TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE(evento_id, user_id)
);

-- Tabela de doações
CREATE TABLE public.doacoes (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id),
  valor DECIMAL(10,2) NOT NULL,
  tipo TEXT DEFAULT 'dizimo' CHECK (tipo IN ('dizimo', 'oferta', 'campanha', 'missoes')),
  descricao TEXT,
  data_doacao TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  metodo_pagamento TEXT,
  status TEXT DEFAULT 'confirmado' CHECK (status IN ('pendente', 'confirmado', 'cancelado'))
);

-- Tabela de pedidos de oração
CREATE TABLE public.pedidos_oracao (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  titulo TEXT NOT NULL,
  descricao TEXT,
  categoria TEXT,
  urgente BOOLEAN DEFAULT false,
  publico BOOLEAN DEFAULT false,
  respondido BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Habilitar Row Level Security
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ministerios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ministerio_membros ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eventos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evento_inscricoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evento_presencas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pedidos_oracao ENABLE ROW LEVEL SECURITY;

-- Função para verificar se usuário tem role específico
CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role app_role)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id
      AND role = _role
  )
$$;

-- Função para verificar se usuário é admin ou pastor
CREATE OR REPLACE FUNCTION public.is_admin_or_pastor(_user_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id
      AND role IN ('admin', 'pastor')
  )
$$;

-- Políticas RLS para user_roles
CREATE POLICY "Admins e pastores podem ver todos os roles" 
  ON public.user_roles 
  FOR SELECT 
  USING (public.is_admin_or_pastor(auth.uid()));

CREATE POLICY "Usuários podem ver seus próprios roles" 
  ON public.user_roles 
  FOR SELECT 
  USING (auth.uid() = user_id);

CREATE POLICY "Admins podem gerenciar roles" 
  ON public.user_roles 
  FOR ALL 
  USING (public.has_role(auth.uid(), 'admin'));

-- Políticas RLS para ministérios
CREATE POLICY "Todos podem ver ministérios ativos" 
  ON public.ministerios 
  FOR SELECT 
  USING (ativo = true);

CREATE POLICY "Líderes podem gerenciar ministérios" 
  ON public.ministerios 
  FOR ALL 
  USING (public.is_admin_or_pastor(auth.uid()) OR lider_id = auth.uid());

-- Políticas RLS para participação em ministérios
CREATE POLICY "Membros podem ver participações em ministérios" 
  ON public.ministerio_membros 
  FOR SELECT 
  USING (true);

CREATE POLICY "Usuários podem se inscrever em ministérios" 
  ON public.ministerio_membros 
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Líderes podem gerenciar membros do ministério" 
  ON public.ministerio_membros 
  FOR ALL 
  USING (
    public.is_admin_or_pastor(auth.uid()) OR 
    EXISTS (SELECT 1 FROM public.ministerios WHERE id = ministerio_id AND lider_id = auth.uid())
  );

-- Políticas RLS para eventos
CREATE POLICY "Todos podem ver eventos" 
  ON public.eventos 
  FOR SELECT 
  USING (true);

CREATE POLICY "Líderes podem criar eventos" 
  ON public.eventos 
  FOR INSERT 
  WITH CHECK (
    public.has_role(auth.uid(), 'admin') OR 
    public.has_role(auth.uid(), 'pastor') OR 
    public.has_role(auth.uid(), 'lider')
  );

CREATE POLICY "Criadores podem editar seus eventos" 
  ON public.eventos 
  FOR UPDATE 
  USING (criado_por = auth.uid() OR public.is_admin_or_pastor(auth.uid()));

-- Políticas RLS para inscrições em eventos
CREATE POLICY "Usuários podem ver suas inscrições" 
  ON public.evento_inscricoes 
  FOR SELECT 
  USING (auth.uid() = user_id OR public.is_admin_or_pastor(auth.uid()));

CREATE POLICY "Usuários podem se inscrever em eventos" 
  ON public.evento_inscricoes 
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

-- Políticas RLS para presenças
CREATE POLICY "Líderes podem gerenciar presenças" 
  ON public.evento_presencas 
  FOR ALL 
  USING (public.is_admin_or_pastor(auth.uid()));

-- Políticas RLS para doações
CREATE POLICY "Usuários podem ver suas doações" 
  ON public.doacoes 
  FOR SELECT 
  USING (auth.uid() = user_id OR public.is_admin_or_pastor(auth.uid()));

CREATE POLICY "Usuários podem registrar doações" 
  ON public.doacoes 
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

-- Políticas RLS para pedidos de oração
CREATE POLICY "Usuários podem ver pedidos públicos ou seus próprios" 
  ON public.pedidos_oracao 
  FOR SELECT 
  USING (publico = true OR auth.uid() = user_id OR public.is_admin_or_pastor(auth.uid()));

CREATE POLICY "Usuários podem criar pedidos de oração" 
  ON public.pedidos_oracao 
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuários podem editar seus pedidos" 
  ON public.pedidos_oracao 
  FOR UPDATE 
  USING (auth.uid() = user_id OR public.is_admin_or_pastor(auth.uid()));

-- Triggers para updated_at
CREATE TRIGGER handle_ministerios_updated_at
  BEFORE UPDATE ON public.ministerios
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_eventos_updated_at
  BEFORE UPDATE ON public.eventos
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_pedidos_oracao_updated_at
  BEFORE UPDATE ON public.pedidos_oracao
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();
;
