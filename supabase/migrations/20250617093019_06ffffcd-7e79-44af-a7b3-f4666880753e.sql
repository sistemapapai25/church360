
-- Criar tabela para configurações gerais da igreja
CREATE TABLE public.configuracoes_igreja (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  nome TEXT NOT NULL,
  endereco TEXT,
  telefone TEXT,
  email TEXT,
  site TEXT,
  cnpj TEXT,
  pastor_principal TEXT,
  horarios_culto JSONB,
  redes_sociais JSONB,
  logo_url TEXT,
  banner_url TEXT,
  configuracoes_gerais JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Criar tabela para configurações do sistema
CREATE TABLE public.configuracoes_sistema (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  chave TEXT NOT NULL UNIQUE,
  valor TEXT,
  tipo TEXT DEFAULT 'texto' CHECK (tipo IN ('texto', 'numero', 'boolean', 'json')),
  descricao TEXT,
  categoria TEXT DEFAULT 'geral',
  editavel BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Criar tabela para logs de auditoria
CREATE TABLE public.logs_auditoria (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id),
  acao TEXT NOT NULL,
  tabela TEXT,
  registro_id TEXT,
  dados_anteriores JSONB,
  dados_novos JSONB,
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Habilitar RLS nas novas tabelas
ALTER TABLE public.configuracoes_igreja ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.configuracoes_sistema ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logs_auditoria ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para configurações da igreja
CREATE POLICY "Todos podem visualizar configurações da igreja"
  ON public.configuracoes_igreja
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins e pastores podem gerenciar configurações da igreja"
  ON public.configuracoes_igreja
  FOR ALL
  TO authenticated
  USING (public.is_admin_or_pastor(auth.uid()));

-- Políticas RLS para configurações do sistema
CREATE POLICY "Admins podem gerenciar configurações do sistema"
  ON public.configuracoes_sistema
  FOR ALL
  TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

-- Políticas RLS para logs de auditoria
CREATE POLICY "Admins podem visualizar logs de auditoria"
  ON public.logs_auditoria
  FOR SELECT
  TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

-- Inserir configurações padrão do sistema
INSERT INTO public.configuracoes_sistema (chave, valor, tipo, descricao, categoria) VALUES
('max_upload_size', '10', 'numero', 'Tamanho máximo de upload em MB', 'arquivos'),
('backup_automatico', 'true', 'boolean', 'Ativar backup automático', 'sistema'),
('manutencao_modo', 'false', 'boolean', 'Modo de manutenção', 'sistema'),
('notificacoes_email', 'true', 'boolean', 'Enviar notificações por email', 'notificacoes'),
('limite_eventos_mes', '50', 'numero', 'Limite de eventos por mês', 'eventos'),
('aprovacao_membros', 'true', 'boolean', 'Requer aprovação para novos membros', 'membros');

-- Inserir configuração padrão da igreja
INSERT INTO public.configuracoes_igreja (nome) VALUES ('Igreja Local');

-- Triggers para updated_at
CREATE TRIGGER handle_configuracoes_igreja_updated_at
  BEFORE UPDATE ON public.configuracoes_igreja
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_configuracoes_sistema_updated_at
  BEFORE UPDATE ON public.configuracoes_sistema
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- Função para registrar logs de auditoria
CREATE OR REPLACE FUNCTION public.registrar_log_auditoria()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.logs_auditoria (
    user_id,
    acao,
    tabela,
    registro_id,
    dados_anteriores,
    dados_novos
  ) VALUES (
    auth.uid(),
    TG_OP,
    TG_TABLE_NAME,
    COALESCE(NEW.id::text, OLD.id::text),
    CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN to_jsonb(NEW) ELSE NULL END
  );
  
  RETURN COALESCE(NEW, OLD);
END;
$$;
;
