
-- Criar tabela para códigos QR dos eventos
CREATE TABLE public.evento_qr_codes (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  evento_id UUID REFERENCES public.eventos(id) ON DELETE CASCADE NOT NULL,
  codigo TEXT NOT NULL UNIQUE,
  ativo BOOLEAN NOT NULL DEFAULT true,
  data_expiracao TIMESTAMP WITH TIME ZONE,
  criado_por UUID,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Criar tabela para configurações de presença
CREATE TABLE public.configuracoes_presenca (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  evento_id UUID REFERENCES public.eventos(id) ON DELETE CASCADE NOT NULL,
  checkin_automatico BOOLEAN NOT NULL DEFAULT false,
  permite_checkin_manual BOOLEAN NOT NULL DEFAULT true,
  janela_checkin_minutos INTEGER NOT NULL DEFAULT 30,
  requer_checkout BOOLEAN NOT NULL DEFAULT false,
  notificar_ausencias BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Atualizar tabela de presenças existente para incluir mais campos
ALTER TABLE public.evento_presencas 
ADD COLUMN IF NOT EXISTS tipo_checkin TEXT DEFAULT 'qr_code',
ADD COLUMN IF NOT EXISTS checkout_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS duracao_minutos INTEGER,
ADD COLUMN IF NOT EXISTS dispositivo TEXT,
ADD COLUMN IF NOT EXISTS localizacao JSONB;

-- Criar índices para performance
CREATE INDEX IF NOT EXISTS idx_evento_qr_codes_evento_id ON public.evento_qr_codes(evento_id);
CREATE INDEX IF NOT EXISTS idx_evento_qr_codes_codigo ON public.evento_qr_codes(codigo);
CREATE INDEX IF NOT EXISTS idx_configuracoes_presenca_evento_id ON public.configuracoes_presenca(evento_id);
CREATE INDEX IF NOT EXISTS idx_evento_presencas_evento_user ON public.evento_presencas(evento_id, user_id);
CREATE INDEX IF NOT EXISTS idx_evento_presencas_data ON public.evento_presencas(data_presenca);

-- Habilitar RLS nas novas tabelas
ALTER TABLE public.evento_qr_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.configuracoes_presenca ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para evento_qr_codes
CREATE POLICY "Todos podem visualizar QR codes ativos"
  ON public.evento_qr_codes
  FOR SELECT
  TO authenticated
  USING (ativo = true);

CREATE POLICY "Admins e pastores podem gerenciar QR codes"
  ON public.evento_qr_codes
  FOR ALL
  TO authenticated
  USING (public.is_admin_or_pastor(auth.uid()));

-- Políticas RLS para configuracoes_presenca
CREATE POLICY "Admins e pastores podem gerenciar configurações de presença"
  ON public.configuracoes_presenca
  FOR ALL
  TO authenticated
  USING (public.is_admin_or_pastor(auth.uid()));

-- Função para gerar código QR único
CREATE OR REPLACE FUNCTION public.gerar_codigo_qr()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  codigo TEXT;
BEGIN
  LOOP
    codigo := upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 8));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.evento_qr_codes WHERE codigo = codigo);
  END LOOP;
  RETURN codigo;
END;
$$;

-- Função para calcular duração da presença
CREATE OR REPLACE FUNCTION public.calcular_duracao_presenca()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.checkout_at IS NOT NULL AND NEW.data_presenca IS NOT NULL THEN
    NEW.duracao_minutos := EXTRACT(EPOCH FROM (NEW.checkout_at - NEW.data_presenca)) / 60;
  END IF;
  RETURN NEW;
END;
$$;

-- Trigger para calcular duração automaticamente
DROP TRIGGER IF EXISTS trigger_calcular_duracao ON public.evento_presencas;
CREATE TRIGGER trigger_calcular_duracao
  BEFORE UPDATE ON public.evento_presencas
  FOR EACH ROW
  EXECUTE FUNCTION public.calcular_duracao_presenca();

-- Trigger para atualizar updated_at
DROP TRIGGER IF EXISTS trigger_updated_at_evento_qr_codes ON public.evento_qr_codes;
CREATE TRIGGER trigger_updated_at_evento_qr_codes
  BEFORE UPDATE ON public.evento_qr_codes
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS trigger_updated_at_configuracoes_presenca ON public.configuracoes_presenca;
CREATE TRIGGER trigger_updated_at_configuracoes_presenca
  BEFORE UPDATE ON public.configuracoes_presenca
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();
;
