
-- Criar enum para tipos de notificação
CREATE TYPE public.notification_type AS ENUM ('geral', 'evento', 'ministerio', 'financeiro', 'oracao', 'pastoral');

-- Criar enum para status de notificação
CREATE TYPE public.notification_status AS ENUM ('enviada', 'lida', 'arquivada');

-- Criar enum para tipos de mensagem
CREATE TYPE public.message_type AS ENUM ('individual', 'grupo', 'broadcast', 'ministerio');

-- Tabela de notificações
CREATE TABLE public.notificacoes (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  titulo TEXT NOT NULL,
  conteudo TEXT NOT NULL,
  tipo notification_type NOT NULL DEFAULT 'geral',
  status notification_status NOT NULL DEFAULT 'enviada',
  urgente BOOLEAN DEFAULT false,
  data_expiracao TIMESTAMP WITH TIME ZONE,
  metadata JSONB,
  criado_por UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Tabela de mensagens
CREATE TABLE public.mensagens (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  remetente_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  destinatario_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  grupo_id UUID,
  ministerio_id UUID REFERENCES public.ministerios(id),
  tipo message_type NOT NULL,
  assunto TEXT,
  conteudo TEXT NOT NULL,
  lida BOOLEAN DEFAULT false,
  arquivada BOOLEAN DEFAULT false,
  data_leitura TIMESTAMP WITH TIME ZONE,
  anexos JSONB,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Tabela de grupos de mensagem
CREATE TABLE public.grupos_mensagem (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  nome TEXT NOT NULL,
  descricao TEXT,
  criado_por UUID REFERENCES auth.users(id) NOT NULL,
  ativo BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Tabela de membros de grupos
CREATE TABLE public.grupo_membros (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  grupo_id UUID REFERENCES public.grupos_mensagem(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  admin BOOLEAN DEFAULT false,
  ativo BOOLEAN DEFAULT true,
  data_entrada TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(grupo_id, user_id)
);

-- Tabela de configurações de notificação por usuário
CREATE TABLE public.configuracoes_notificacao (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  email_enabled BOOLEAN DEFAULT true,
  push_enabled BOOLEAN DEFAULT true,
  tipos_habilitados notification_type[] DEFAULT ARRAY['geral', 'evento', 'ministerio']::notification_type[],
  horario_silencioso_inicio TIME,
  horario_silencioso_fim TIME,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(user_id)
);

-- Habilitar Row Level Security
ALTER TABLE public.notificacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mensagens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grupos_mensagem ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grupo_membros ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.configuracoes_notificacao ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para notificações
CREATE POLICY "Usuários podem ver suas notificações" 
  ON public.notificacoes 
  FOR SELECT 
  USING (auth.uid() = user_id);

CREATE POLICY "Líderes podem criar notificações" 
  ON public.notificacoes 
  FOR INSERT 
  WITH CHECK (
    public.has_role(auth.uid(), 'admin') OR 
    public.has_role(auth.uid(), 'pastor') OR 
    public.has_role(auth.uid(), 'lider')
  );

CREATE POLICY "Usuários podem atualizar suas notificações" 
  ON public.notificacoes 
  FOR UPDATE 
  USING (auth.uid() = user_id);

-- Políticas RLS para mensagens
CREATE POLICY "Usuários podem ver mensagens relacionadas a eles" 
  ON public.mensagens 
  FOR SELECT 
  USING (
    auth.uid() = remetente_id OR 
    auth.uid() = destinatario_id OR
    EXISTS (SELECT 1 FROM public.grupo_membros WHERE grupo_id = mensagens.grupo_id AND user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.ministerio_membros WHERE ministerio_id = mensagens.ministerio_id AND user_id = auth.uid())
  );

CREATE POLICY "Usuários podem enviar mensagens" 
  ON public.mensagens 
  FOR INSERT 
  WITH CHECK (auth.uid() = remetente_id);

CREATE POLICY "Destinatários podem atualizar status de leitura" 
  ON public.mensagens 
  FOR UPDATE 
  USING (
    auth.uid() = destinatario_id OR 
    EXISTS (SELECT 1 FROM public.grupo_membros WHERE grupo_id = mensagens.grupo_id AND user_id = auth.uid())
  );

-- Políticas RLS para grupos de mensagem
CREATE POLICY "Membros podem ver grupos que participam" 
  ON public.grupos_mensagem 
  FOR SELECT 
  USING (
    EXISTS (SELECT 1 FROM public.grupo_membros WHERE grupo_id = grupos_mensagem.id AND user_id = auth.uid()) OR
    public.is_admin_or_pastor(auth.uid())
  );

CREATE POLICY "Líderes podem criar grupos" 
  ON public.grupos_mensagem 
  FOR INSERT 
  WITH CHECK (
    public.has_role(auth.uid(), 'admin') OR 
    public.has_role(auth.uid(), 'pastor') OR 
    public.has_role(auth.uid(), 'lider')
  );

-- Políticas RLS para membros de grupos
CREATE POLICY "Membros podem ver participação em grupos" 
  ON public.grupo_membros 
  FOR SELECT 
  USING (
    auth.uid() = user_id OR
    EXISTS (SELECT 1 FROM public.grupo_membros gm WHERE gm.grupo_id = grupo_membros.grupo_id AND gm.user_id = auth.uid() AND gm.admin = true) OR
    public.is_admin_or_pastor(auth.uid())
  );

-- Políticas RLS para configurações de notificação
CREATE POLICY "Usuários podem gerenciar suas configurações" 
  ON public.configuracoes_notificacao 
  FOR ALL 
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Triggers para updated_at
CREATE TRIGGER handle_notificacoes_updated_at
  BEFORE UPDATE ON public.notificacoes
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_configuracoes_notificacao_updated_at
  BEFORE UPDATE ON public.configuracoes_notificacao
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- Função para criar configuração padrão de notificação
CREATE OR REPLACE FUNCTION public.create_default_notification_settings()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.configuracoes_notificacao (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Trigger para criar configurações padrão quando usuário é criado
CREATE TRIGGER on_auth_user_created_notification_settings
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.create_default_notification_settings();

-- Índices para performance
CREATE INDEX idx_notificacoes_user_id ON public.notificacoes(user_id);
CREATE INDEX idx_notificacoes_status ON public.notificacoes(status);
CREATE INDEX idx_notificacoes_tipo ON public.notificacoes(tipo);
CREATE INDEX idx_mensagens_remetente ON public.mensagens(remetente_id);
CREATE INDEX idx_mensagens_destinatario ON public.mensagens(destinatario_id);
CREATE INDEX idx_mensagens_tipo ON public.mensagens(tipo);
CREATE INDEX idx_grupo_membros_user_id ON public.grupo_membros(user_id);
CREATE INDEX idx_grupo_membros_grupo_id ON public.grupo_membros(grupo_id);
;
