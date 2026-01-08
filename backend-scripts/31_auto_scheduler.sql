-- =====================================================
-- AUTO SCHEDULER: Configuração de relatórios automáticos via WhatsApp
-- Cria tabela de configuração e índices
-- =====================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS whatsapp_relatorios_automaticos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  dispatch_rule_id UUID NOT NULL REFERENCES dispatch_rule(id) ON DELETE CASCADE,
  active BOOLEAN NOT NULL DEFAULT true,
  send_time TEXT NOT NULL, -- formato HH:mm
  timezone TEXT NOT NULL DEFAULT 'America/Sao_Paulo',
  next_run TIMESTAMPTZ,
  last_run TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_whatsapp_auto_active ON whatsapp_relatorios_automaticos(active);
CREATE INDEX IF NOT EXISTS idx_whatsapp_auto_next_run ON whatsapp_relatorios_automaticos(next_run);
CREATE INDEX IF NOT EXISTS idx_whatsapp_auto_rule ON whatsapp_relatorios_automaticos(dispatch_rule_id);

COMMENT ON TABLE whatsapp_relatorios_automaticos IS 'Configurações de disparos automáticos por horário';
COMMENT ON COLUMN whatsapp_relatorios_automaticos.send_time IS 'Horário local HH:mm';
COMMENT ON COLUMN whatsapp_relatorios_automaticos.next_run IS 'Próxima execução programada';
COMMENT ON COLUMN whatsapp_relatorios_automaticos.last_run IS 'Última execução realizada';

-- Garantir apenas um agendamento por regra
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'unique_dispatch_rule_schedule'
  ) THEN
    ALTER TABLE whatsapp_relatorios_automaticos
    ADD CONSTRAINT unique_dispatch_rule_schedule UNIQUE (dispatch_rule_id);
  END IF;
END$$;

-- Trigger para updated_at
CREATE OR REPLACE FUNCTION update_whatsapp_relatorios_automaticos_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_whatsapp_relatorios_automaticos_updated_at ON whatsapp_relatorios_automaticos;
CREATE TRIGGER trigger_update_whatsapp_relatorios_automaticos_updated_at
  BEFORE UPDATE ON whatsapp_relatorios_automaticos
  FOR EACH ROW
  EXECUTE FUNCTION update_whatsapp_relatorios_automaticos_updated_at();

-- Função: calcular próxima execução (next_run) a partir de send_time/timezone
CREATE OR REPLACE FUNCTION compute_whatsapp_auto_next_run(send_time TEXT, tz TEXT)
RETURNS TIMESTAMPTZ AS $$
DECLARE
  base_date DATE := (NOW() AT TIME ZONE tz)::DATE;
  local_ts TIMESTAMP := to_timestamp(to_char(base_date, 'YYYY-MM-DD') || ' ' || send_time, 'YYYY-MM-DD HH24:MI');
  next_run TIMESTAMPTZ := local_ts AT TIME ZONE tz;
BEGIN
  IF next_run <= NOW() THEN
    next_run := (local_ts + INTERVAL '1 day') AT TIME ZONE tz;
  END IF;
  RETURN next_run;
END;
$$ LANGUAGE plpgsql;

-- Trigger: setar next_run automaticamente em INSERT quando nulo
CREATE OR REPLACE FUNCTION set_whatsapp_auto_next_run()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.next_run IS NULL THEN
    NEW.next_run = compute_whatsapp_auto_next_run(NEW.send_time, NEW.timezone);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_whatsapp_auto_next_run ON whatsapp_relatorios_automaticos;
CREATE TRIGGER trigger_set_whatsapp_auto_next_run
  BEFORE INSERT ON whatsapp_relatorios_automaticos
  FOR EACH ROW
  EXECUTE FUNCTION set_whatsapp_auto_next_run();

-- RLS
ALTER TABLE whatsapp_relatorios_automaticos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Somente admins/owner podem gerenciar auto scheduler" ON whatsapp_relatorios_automaticos;
CREATE POLICY "Somente admins/owner podem gerenciar auto scheduler"
  ON whatsapp_relatorios_automaticos
  FOR ALL
  USING (
    EXISTS (
      SELECT 1
      FROM user_account ua
      WHERE ua.id = auth.uid()
        AND (ua.role_global = 'owner' OR ua.role_global = 'admin')
    )
  );

DROP POLICY IF EXISTS "Todos podem visualizar auto scheduler" ON whatsapp_relatorios_automaticos;
CREATE POLICY "Todos podem visualizar auto scheduler"
  ON whatsapp_relatorios_automaticos
  FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Seed opcional (comentado)
-- INSERT INTO whatsapp_relatorios_automaticos (title, dispatch_rule_id, send_time, timezone, next_run)
-- VALUES ('Relatório diário escalas', '<RULE_UUID>', '08:00', 'America/Sao_Paulo', NOW());
