-- =====================================================
-- CHURCH 360 - SISTEMA DE NOTIFICAÇÕES
-- =====================================================
-- Descrição: Sistema de notificações push e in-app
-- Features: FCM tokens, preferências, histórico,
--           notificações automáticas
-- =====================================================

-- =====================================================
-- 1. ENUMS
-- =====================================================

-- Tipo de notificação
DO $$ BEGIN
  CREATE TYPE notification_type AS ENUM (
    'devotional_daily',        -- Novo devocional diário
    'prayer_request_prayed',   -- Alguém orou por seu pedido
    'prayer_request_answered', -- Pedido marcado como respondido
    'event_reminder',          -- Lembrete de evento (24h antes)
    'meeting_reminder',        -- Lembrete de reunião (1h antes)
    'worship_reminder',        -- Lembrete de culto (1h antes)
    'group_new_member',        -- Novo membro no grupo
    'financial_goal_reached',  -- Meta financeira atingida
    'birthday_reminder',       -- Aniversário de membro
    'general'                  -- Notificação geral
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Status da notificação
DO $$ BEGIN
  CREATE TYPE notification_status AS ENUM (
    'pending',   -- Pendente (não enviada)
    'sent',      -- Enviada
    'read',      -- Lida
    'failed'     -- Falha no envio
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- =====================================================
-- 2. TABELA: fcm_tokens
-- =====================================================

CREATE TABLE IF NOT EXISTS fcm_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Relacionamento
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Token FCM
  token TEXT NOT NULL,
  device_id TEXT, -- Identificador do dispositivo
  device_name TEXT, -- Nome do dispositivo (ex: "iPhone 13", "Samsung Galaxy")
  platform TEXT, -- 'ios', 'android', 'web'
  
  -- Status
  is_active BOOLEAN DEFAULT true,
  
  -- Metadados
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  last_used_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraint: um token por dispositivo
  CONSTRAINT fcm_tokens_unique UNIQUE (user_id, device_id)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user ON fcm_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_active ON fcm_tokens(is_active);

-- =====================================================
-- 3. TABELA: notification_preferences
-- =====================================================

CREATE TABLE IF NOT EXISTS notification_preferences (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Relacionamento
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Preferências por tipo
  devotional_daily BOOLEAN DEFAULT true,
  prayer_request_prayed BOOLEAN DEFAULT true,
  prayer_request_answered BOOLEAN DEFAULT true,
  event_reminder BOOLEAN DEFAULT true,
  meeting_reminder BOOLEAN DEFAULT true,
  worship_reminder BOOLEAN DEFAULT true,
  group_new_member BOOLEAN DEFAULT true,
  financial_goal_reached BOOLEAN DEFAULT true,
  birthday_reminder BOOLEAN DEFAULT true,
  general BOOLEAN DEFAULT true,
  
  -- Horário de silêncio (não enviar notificações)
  quiet_hours_enabled BOOLEAN DEFAULT false,
  quiet_hours_start TIME, -- Ex: 22:00
  quiet_hours_end TIME,   -- Ex: 07:00
  
  -- Metadados
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraint: uma preferência por usuário
  CONSTRAINT notification_preferences_unique UNIQUE (user_id)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_notification_preferences_user ON notification_preferences(user_id);

-- =====================================================
-- 4. TABELA: notifications
-- =====================================================

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Destinatário
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Informações da notificação
  type notification_type NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  
  -- Dados adicionais (JSON)
  data JSONB, -- Ex: {"event_id": "...", "prayer_request_id": "..."}
  
  -- Status
  status notification_status DEFAULT 'pending',
  
  -- Navegação (para onde ir ao clicar)
  route TEXT, -- Ex: "/events/123", "/prayer-requests/456"
  
  -- Metadados
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  sent_at TIMESTAMPTZ,
  read_at TIMESTAMPTZ,
  
  -- Constraint
  CONSTRAINT notifications_title_not_empty CHECK (LENGTH(TRIM(title)) > 0),
  CONSTRAINT notifications_body_not_empty CHECK (LENGTH(TRIM(body)) > 0)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_status ON notifications(status);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(created_at DESC);

-- =====================================================
-- 5. TRIGGERS: updated_at
-- =====================================================

-- Trigger para fcm_tokens
CREATE OR REPLACE FUNCTION update_fcm_tokens_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_fcm_tokens_updated_at ON fcm_tokens;
CREATE TRIGGER trigger_update_fcm_tokens_updated_at
  BEFORE UPDATE ON fcm_tokens
  FOR EACH ROW
  EXECUTE FUNCTION update_fcm_tokens_updated_at();

-- Trigger para notification_preferences
CREATE OR REPLACE FUNCTION update_notification_preferences_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_notification_preferences_updated_at ON notification_preferences;
CREATE TRIGGER trigger_update_notification_preferences_updated_at
  BEFORE UPDATE ON notification_preferences
  FOR EACH ROW
  EXECUTE FUNCTION update_notification_preferences_updated_at();

-- Trigger para notifications
CREATE OR REPLACE FUNCTION update_notifications_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  
  -- Se status mudou para 'sent', atualizar sent_at
  IF NEW.status = 'sent' AND OLD.status != 'sent' THEN
    NEW.sent_at = NOW();
  END IF;
  
  -- Se status mudou para 'read', atualizar read_at
  IF NEW.status = 'read' AND OLD.status != 'read' THEN
    NEW.read_at = NOW();
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_notifications_updated_at ON notifications;
CREATE TRIGGER trigger_update_notifications_updated_at
  BEFORE UPDATE ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION update_notifications_updated_at();

-- =====================================================
-- 6. TRIGGER: Criar preferências padrão ao criar usuário
-- =====================================================

CREATE OR REPLACE FUNCTION create_default_notification_preferences()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO notification_preferences (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_create_default_notification_preferences ON auth.users;
CREATE TRIGGER trigger_create_default_notification_preferences
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION create_default_notification_preferences();

-- =====================================================
-- 7. TRIGGER: Notificar quando alguém ora por pedido
-- =====================================================

CREATE OR REPLACE FUNCTION notify_prayer_request_prayed()
RETURNS TRIGGER AS $$
DECLARE
  request_author_id UUID;
  request_title TEXT;
  praying_user_name TEXT;
BEGIN
  -- Buscar autor do pedido
  SELECT author_id, title INTO request_author_id, request_title
  FROM prayer_requests
  WHERE id = NEW.prayer_request_id;
  
  -- Não notificar se o autor orou pelo próprio pedido
  IF request_author_id = NEW.user_id THEN
    RETURN NEW;
  END IF;
  
  -- Buscar nome do usuário que orou (se disponível)
  -- Por enquanto, usar "Alguém" como placeholder
  praying_user_name := 'Alguém';
  
  -- Criar notificação
  INSERT INTO notifications (
    user_id,
    type,
    title,
    body,
    data,
    route,
    status
  ) VALUES (
    request_author_id,
    'prayer_request_prayed',
    'Alguém orou por você! 🙏',
    praying_user_name || ' orou pelo seu pedido: "' || request_title || '"',
    jsonb_build_object('prayer_request_id', NEW.prayer_request_id),
    '/prayer-requests/' || NEW.prayer_request_id,
    'pending'
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_notify_prayer_request_prayed ON prayer_request_prayers;
CREATE TRIGGER trigger_notify_prayer_request_prayed
  AFTER INSERT ON prayer_request_prayers
  FOR EACH ROW
  EXECUTE FUNCTION notify_prayer_request_prayed();

-- =====================================================
-- 8. RLS POLICIES: fcm_tokens
-- =====================================================

-- Habilitar RLS
ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Policy: Usuário pode VER seus próprios tokens
DROP POLICY IF EXISTS "Usuário pode ver seus tokens" ON fcm_tokens;
CREATE POLICY "Usuário pode ver seus tokens"
  ON fcm_tokens
  FOR SELECT
  USING (user_id = auth.uid());

-- Policy: Usuário pode CRIAR seus tokens
DROP POLICY IF EXISTS "Usuário pode criar tokens" ON fcm_tokens;
CREATE POLICY "Usuário pode criar tokens"
  ON fcm_tokens
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Policy: Usuário pode ATUALIZAR seus tokens
DROP POLICY IF EXISTS "Usuário pode atualizar seus tokens" ON fcm_tokens;
CREATE POLICY "Usuário pode atualizar seus tokens"
  ON fcm_tokens
  FOR UPDATE
  USING (user_id = auth.uid());

-- Policy: Usuário pode DELETAR seus tokens
DROP POLICY IF EXISTS "Usuário pode deletar seus tokens" ON fcm_tokens;
CREATE POLICY "Usuário pode deletar seus tokens"
  ON fcm_tokens
  FOR DELETE
  USING (user_id = auth.uid());

-- =====================================================
-- 9. RLS POLICIES: notification_preferences
-- =====================================================

-- Habilitar RLS
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

-- Policy: Usuário pode VER suas preferências
DROP POLICY IF EXISTS "Usuário pode ver suas preferências" ON notification_preferences;
CREATE POLICY "Usuário pode ver suas preferências"
  ON notification_preferences
  FOR SELECT
  USING (user_id = auth.uid());

-- Policy: Usuário pode CRIAR suas preferências
DROP POLICY IF EXISTS "Usuário pode criar preferências" ON notification_preferences;
CREATE POLICY "Usuário pode criar preferências"
  ON notification_preferences
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Policy: Usuário pode ATUALIZAR suas preferências
DROP POLICY IF EXISTS "Usuário pode atualizar preferências" ON notification_preferences;
CREATE POLICY "Usuário pode atualizar preferências"
  ON notification_preferences
  FOR UPDATE
  USING (user_id = auth.uid());

-- Policy: Usuário pode DELETAR suas preferências
DROP POLICY IF EXISTS "Usuário pode deletar preferências" ON notification_preferences;
CREATE POLICY "Usuário pode deletar preferências"
  ON notification_preferences
  FOR DELETE
  USING (user_id = auth.uid());

-- =====================================================
-- 10. RLS POLICIES: notifications
-- =====================================================

-- Habilitar RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Policy: Usuário pode VER suas notificações
DROP POLICY IF EXISTS "Usuário pode ver suas notificações" ON notifications;
CREATE POLICY "Usuário pode ver suas notificações"
  ON notifications
  FOR SELECT
  USING (user_id = auth.uid());

-- Policy: Sistema pode CRIAR notificações (SECURITY DEFINER functions)
DROP POLICY IF EXISTS "Sistema pode criar notificações" ON notifications;
CREATE POLICY "Sistema pode criar notificações"
  ON notifications
  FOR INSERT
  WITH CHECK (true); -- Será controlado por SECURITY DEFINER functions

-- Policy: Usuário pode ATUALIZAR suas notificações (marcar como lida)
DROP POLICY IF EXISTS "Usuário pode atualizar notificações" ON notifications;
CREATE POLICY "Usuário pode atualizar notificações"
  ON notifications
  FOR UPDATE
  USING (user_id = auth.uid());

-- Policy: Usuário pode DELETAR suas notificações
DROP POLICY IF EXISTS "Usuário pode deletar notificações" ON notifications;
CREATE POLICY "Usuário pode deletar notificações"
  ON notifications
  FOR DELETE
  USING (user_id = auth.uid());

-- =====================================================
-- 11. FUNÇÕES AUXILIARES
-- =====================================================

-- Função: Obter notificações não lidas
CREATE OR REPLACE FUNCTION get_unread_notifications_count(target_user_id UUID)
RETURNS BIGINT AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)
    FROM notifications
    WHERE user_id = target_user_id
    AND status != 'read'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função: Marcar todas as notificações como lidas
CREATE OR REPLACE FUNCTION mark_all_notifications_as_read(target_user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE notifications
  SET status = 'read', read_at = NOW()
  WHERE user_id = target_user_id
  AND status != 'read';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função: Criar notificação de devocional diário
CREATE OR REPLACE FUNCTION create_devotional_notification(devotional_id UUID)
RETURNS VOID AS $$
DECLARE
  devotional_title TEXT;
  user_record RECORD;
BEGIN
  -- Buscar título do devocional
  SELECT title INTO devotional_title
  FROM devotionals
  WHERE id = devotional_id;

  -- Criar notificação para todos os usuários que têm preferência ativada
  FOR user_record IN
    SELECT np.user_id
    FROM notification_preferences np
    WHERE np.devotional_daily = true
  LOOP
    INSERT INTO notifications (
      user_id,
      type,
      title,
      body,
      data,
      route,
      status
    ) VALUES (
      user_record.user_id,
      'devotional_daily',
      'Novo Devocional Diário 📖',
      devotional_title,
      jsonb_build_object('devotional_id', devotional_id),
      '/devotionals/' || devotional_id,
      'pending'
    );
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função: Criar notificação de evento próximo
CREATE OR REPLACE FUNCTION create_event_reminder_notification(event_id UUID)
RETURNS VOID AS $$
DECLARE
  event_title TEXT;
  event_date TIMESTAMPTZ;
  user_record RECORD;
BEGIN
  -- Buscar informações do evento
  SELECT title, start_date INTO event_title, event_date
  FROM events
  WHERE id = event_id;

  -- Criar notificação para todos os usuários que têm preferência ativada
  FOR user_record IN
    SELECT np.user_id
    FROM notification_preferences np
    WHERE np.event_reminder = true
  LOOP
    INSERT INTO notifications (
      user_id,
      type,
      title,
      body,
      data,
      route,
      status
    ) VALUES (
      user_record.user_id,
      'event_reminder',
      'Lembrete de Evento 📅',
      'O evento "' || event_title || '" acontece amanhã!',
      jsonb_build_object('event_id', event_id),
      '/events/' || event_id,
      'pending'
    );
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 12. SEED DATA
-- =====================================================

-- Criar preferências padrão para usuários existentes
INSERT INTO notification_preferences (user_id)
SELECT id FROM auth.users
ON CONFLICT (user_id) DO NOTHING;

