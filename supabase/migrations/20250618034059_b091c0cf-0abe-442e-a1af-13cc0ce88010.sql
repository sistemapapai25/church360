
-- Criar tabela para alertas de frequência
CREATE TABLE public.alertas_frequencia (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  tipo_alerta TEXT NOT NULL DEFAULT 'ausencia_consecutiva',
  eventos_ausentes INTEGER NOT NULL DEFAULT 0,
  ultimo_evento_perdido UUID,
  data_ultimo_alerta TIMESTAMP WITH TIME ZONE,
  status TEXT NOT NULL DEFAULT 'ativo',
  resolvido_por UUID,
  data_resolucao TIMESTAMP WITH TIME ZONE,
  observacoes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Criar tabela para configurações de alertas
CREATE TABLE public.configuracoes_alertas (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  limite_ausencias INTEGER NOT NULL DEFAULT 3,
  notificar_lideranca BOOLEAN NOT NULL DEFAULT true,
  notificar_pastores BOOLEAN NOT NULL DEFAULT true,
  intervalos_notificacao INTEGER[] DEFAULT ARRAY[1, 3, 7],
  tipos_eventos_monitorados TEXT[] DEFAULT ARRAY['culto', 'evento_especial'],
  ativo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Criar tabela para configurações de geolocalização
CREATE TABLE public.configuracoes_geolocalizacao (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  evento_id UUID REFERENCES public.eventos(id) ON DELETE CASCADE NOT NULL,
  latitude DECIMAL(10, 8) NOT NULL,
  longitude DECIMAL(11, 8) NOT NULL,
  raio_metros INTEGER NOT NULL DEFAULT 100,
  checkin_automatico_ativo BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Adicionar campos de geolocalização às presenças (se não existirem)
ALTER TABLE public.evento_presencas 
ADD COLUMN IF NOT EXISTS latitude DECIMAL(10, 8),
ADD COLUMN IF NOT EXISTS longitude DECIMAL(11, 8),
ADD COLUMN IF NOT EXISTS checkin_automatico BOOLEAN DEFAULT false;

-- Criar índices para performance
CREATE INDEX IF NOT EXISTS idx_alertas_frequencia_user_id ON public.alertas_frequencia(user_id);
CREATE INDEX IF NOT EXISTS idx_alertas_frequencia_status ON public.alertas_frequencia(status);
CREATE INDEX IF NOT EXISTS idx_configuracoes_geolocalizacao_evento_id ON public.configuracoes_geolocalizacao(evento_id);

-- Habilitar RLS nas novas tabelas
ALTER TABLE public.alertas_frequencia ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.configuracoes_alertas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.configuracoes_geolocalizacao ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para alertas_frequencia
CREATE POLICY "Admins e pastores podem ver todos os alertas"
  ON public.alertas_frequencia
  FOR SELECT
  TO authenticated
  USING (public.is_admin_or_pastor(auth.uid()));

CREATE POLICY "Líderes podem ver alertas de seus ministérios"
  ON public.alertas_frequencia
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.ministerio_membros mm
      JOIN public.ministerios m ON mm.ministerio_id = m.id
      WHERE m.lider_id = auth.uid() 
      AND mm.user_id = alertas_frequencia.user_id
      AND mm.ativo = true
    )
  );

CREATE POLICY "Admins e pastores podem gerenciar alertas"
  ON public.alertas_frequencia
  FOR ALL
  TO authenticated
  USING (public.is_admin_or_pastor(auth.uid()));

-- Políticas RLS para configuracoes_alertas
CREATE POLICY "Admins e pastores podem gerenciar configurações de alertas"
  ON public.configuracoes_alertas
  FOR ALL
  TO authenticated
  USING (public.is_admin_or_pastor(auth.uid()));

-- Políticas RLS para configuracoes_geolocalizacao
CREATE POLICY "Todos podem ver configurações de geolocalização de eventos públicos"
  ON public.configuracoes_geolocalizacao
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins e pastores podem gerenciar configurações de geolocalização"
  ON public.configuracoes_geolocalizacao
  FOR ALL
  TO authenticated
  USING (public.is_admin_or_pastor(auth.uid()));

-- Função para detectar membros com ausências consecutivas
CREATE OR REPLACE FUNCTION public.detectar_ausencias_consecutivas()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  limite_ausencias INTEGER := 3;
  eventos_recentes UUID[];
  eventos_perdidos INTEGER := 0;
  ultimo_evento UUID;
  alerta_existente UUID;
BEGIN
  -- Buscar configuração de limite
  SELECT ca.limite_ausencias INTO limite_ausencias
  FROM public.configuracoes_alertas ca
  WHERE ca.ativo = true
  LIMIT 1;

  -- Buscar últimos eventos do tipo monitorado
  SELECT ARRAY_AGG(e.id ORDER BY e.data_inicio DESC) INTO eventos_recentes
  FROM public.eventos e
  WHERE e.data_inicio <= NOW()
  AND e.tipo IN ('culto', 'evento_especial')
  LIMIT limite_ausencias + 1;

  -- Contar quantos eventos o usuário perdeu consecutivamente
  FOR i IN 1..array_length(eventos_recentes, 1) LOOP
    IF NOT EXISTS (
      SELECT 1 FROM public.evento_presencas ep
      WHERE ep.evento_id = eventos_recentes[i]
      AND ep.user_id = NEW.user_id
      AND ep.presente = true
    ) THEN
      eventos_perdidos := eventos_perdidos + 1;
      IF ultimo_evento IS NULL THEN
        ultimo_evento := eventos_recentes[i];
      END IF;
    ELSE
      EXIT; -- Para na primeira presença encontrada
    END IF;
  END LOOP;

  -- Se atingiu o limite, criar ou atualizar alerta
  IF eventos_perdidos >= limite_ausencias THEN
    -- Verificar se já existe alerta ativo
    SELECT id INTO alerta_existente
    FROM public.alertas_frequencia
    WHERE user_id = NEW.user_id
    AND status = 'ativo'
    AND tipo_alerta = 'ausencia_consecutiva';

    IF alerta_existente IS NOT NULL THEN
      -- Atualizar alerta existente
      UPDATE public.alertas_frequencia
      SET eventos_ausentes = eventos_perdidos,
          ultimo_evento_perdido = ultimo_evento,
          updated_at = NOW()
      WHERE id = alerta_existente;
    ELSE
      -- Criar novo alerta
      INSERT INTO public.alertas_frequencia (
        user_id,
        tipo_alerta,
        eventos_ausentes,
        ultimo_evento_perdido
      ) VALUES (
        NEW.user_id,
        'ausencia_consecutiva',
        eventos_perdidos,
        ultimo_evento
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Trigger para detectar ausências após inserção de presença
CREATE OR REPLACE TRIGGER trigger_detectar_ausencias
  AFTER INSERT ON public.evento_presencas
  FOR EACH ROW
  EXECUTE FUNCTION public.detectar_ausencias_consecutivas();

-- Função para processar alertas de ausências em lote
CREATE OR REPLACE FUNCTION public.processar_alertas_ausencias()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  membro_record RECORD;
  limite_ausencias INTEGER := 3;
  eventos_recentes UUID[];
  eventos_perdidos INTEGER;
  ultimo_evento UUID;
BEGIN
  -- Buscar configuração
  SELECT ca.limite_ausencias INTO limite_ausencias
  FROM public.configuracoes_alertas ca
  WHERE ca.ativo = true
  LIMIT 1;

  -- Para cada membro ativo
  FOR membro_record IN
    SELECT DISTINCT p.user_id
    FROM public.profiles p
    WHERE p.user_id IS NOT NULL
  LOOP
    eventos_perdidos := 0;
    ultimo_evento := NULL;

    -- Buscar últimos eventos
    SELECT ARRAY_AGG(e.id ORDER BY e.data_inicio DESC) INTO eventos_recentes
    FROM public.eventos e
    WHERE e.data_inicio <= NOW()
    AND e.data_inicio >= NOW() - INTERVAL '30 days'
    AND e.tipo IN ('culto', 'evento_especial')
    LIMIT limite_ausencias + 1;

    -- Contar ausências consecutivas
    FOR i IN 1..array_length(eventos_recentes, 1) LOOP
      IF NOT EXISTS (
        SELECT 1 FROM public.evento_presencas ep
        WHERE ep.evento_id = eventos_recentes[i]
        AND ep.user_id = membro_record.user_id
        AND ep.presente = true
      ) THEN
        eventos_perdidos := eventos_perdidos + 1;
        IF ultimo_evento IS NULL THEN
          ultimo_evento := eventos_recentes[i];
        END IF;
      ELSE
        EXIT;
      END IF;
    END LOOP;

    -- Processar alerta se necessário
    IF eventos_perdidos >= limite_ausencias THEN
      INSERT INTO public.alertas_frequencia (
        user_id,
        tipo_alerta,
        eventos_ausentes,
        ultimo_evento_perdido
      ) VALUES (
        membro_record.user_id,
        'ausencia_consecutiva',
        eventos_perdidos,
        ultimo_evento
      )
      ON CONFLICT (user_id, tipo_alerta) 
      WHERE status = 'ativo'
      DO UPDATE SET
        eventos_ausentes = EXCLUDED.eventos_ausentes,
        ultimo_evento_perdido = EXCLUDED.ultimo_evento_perdido,
        updated_at = NOW();
    END IF;
  END LOOP;
END;
$$;

-- Inserir configuração padrão de alertas
INSERT INTO public.configuracoes_alertas (limite_ausencias, notificar_lideranca, notificar_pastores)
VALUES (3, true, true)
ON CONFLICT DO NOTHING;

-- Triggers para updated_at
CREATE TRIGGER update_alertas_frequencia_updated_at
  BEFORE UPDATE ON public.alertas_frequencia
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER update_configuracoes_alertas_updated_at
  BEFORE UPDATE ON public.configuracoes_alertas
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER update_configuracoes_geolocalizacao_updated_at
  BEFORE UPDATE ON public.configuracoes_geolocalizacao
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();
;
