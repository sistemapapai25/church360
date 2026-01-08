-- Fix function_search_path_mutable warnings - Batch 18 (Missing Functions)
-- Functions:
-- 1. detectar_ausencias_consecutivas
-- 2. processar_alertas_ausencias
-- 3. trg_dispatch_job_after_insert
-- 4. trg_dispatch_job_after_update

-- 1. detectar_ausencias_consecutivas
CREATE OR REPLACE FUNCTION public.detectar_ausencias_consecutivas()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$;

-- 2. processar_alertas_ausencias
CREATE OR REPLACE FUNCTION public.processar_alertas_ausencias()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$;

-- 3. trg_dispatch_job_after_insert
CREATE OR REPLACE FUNCTION public.trg_dispatch_job_after_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  PERFORM public.log_dispatch(NEW.id, 'scheduled', 'pending', NULL, NEW.payload);
  RETURN NEW;
END $function$;

-- 4. trg_dispatch_job_after_update
CREATE OR REPLACE FUNCTION public.trg_dispatch_job_after_update()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    PERFORM public.log_dispatch(NEW.id, 'status_change', NEW.status, NEW.last_error, NEW.payload);
  END IF;
  IF NEW.uazapi_message_id IS DISTINCT FROM OLD.uazapi_message_id AND NEW.uazapi_message_id IS NOT NULL THEN
    PERFORM public.log_dispatch(NEW.id, 'message_id_set', NULL, NEW.uazapi_message_id, '{}'::jsonb);
  END IF;
  RETURN NEW;
END $function$;
