-- ============================================
-- CHURCH 360 - REMOVER TRIGGERS ANTIGOS
-- ============================================
-- Remove triggers e funções de projetos anteriores
-- ============================================

-- Remover trigger de notificações (se existir)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Remover função de notificações (se existir)
DROP FUNCTION IF EXISTS create_default_notification_settings() CASCADE;

-- Remover outros triggers comuns que podem existir
DROP TRIGGER IF EXISTS on_user_created ON auth.users;
DROP TRIGGER IF EXISTS handle_new_user ON auth.users;
DROP TRIGGER IF EXISTS create_profile_for_user ON auth.users;

-- Remover funções relacionadas
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS create_profile_for_user() CASCADE;

-- Listar triggers restantes em auth.users (para verificação)
SELECT 
  trigger_name,
  event_manipulation,
  action_statement
FROM information_schema.triggers
WHERE event_object_table = 'users'
  AND event_object_schema = 'auth';

-- ============================================
-- TRIGGERS REMOVIDOS!
-- ============================================
-- Agora você pode criar usuários sem conflitos

