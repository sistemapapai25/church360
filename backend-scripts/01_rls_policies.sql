-- ============================================
-- CHURCH 360 - ROW LEVEL SECURITY (RLS)
-- ============================================
-- Versão: 1.0
-- Data: 13/10/2025
-- Descrição: Políticas de segurança para single-tenant
-- ============================================

-- IMPORTANTE: Como estamos em arquitetura single-tenant (cada igreja = 1 DB),
-- as políticas RLS são permissivas. A segurança principal vem do isolamento por DB.
-- RLS aqui serve como camada extra de proteção.

-- ============================================
-- HABILITAR RLS EM TODAS AS TABELAS
-- ============================================

ALTER TABLE user_account ENABLE ROW LEVEL SECURITY;
ALTER TABLE church_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE campus ENABLE ROW LEVEL SECURITY;
ALTER TABLE household ENABLE ROW LEVEL SECURITY;
ALTER TABLE member ENABLE ROW LEVEL SECURITY;
ALTER TABLE tag ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_tag ENABLE ROW LEVEL SECURITY;
ALTER TABLE step ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_step ENABLE ROW LEVEL SECURITY;
ALTER TABLE "group" ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_member ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_meeting ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE event ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_registration ENABLE ROW LEVEL SECURITY;
ALTER TABLE fund ENABLE ROW LEVEL SECURITY;
ALTER TABLE donation ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant ENABLE ROW LEVEL SECURITY;

-- ============================================
-- POLÍTICAS BÁSICAS (PERMISSIVAS)
-- ============================================
-- Como cada igreja tem seu próprio DB, usuários autenticados
-- podem acessar todos os dados do seu DB.

-- user_account
CREATE POLICY "Users can view all users in their DB"
  ON user_account FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can update their own profile"
  ON user_account FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can view tenants"
  ON tenant FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admins can manage tenants"
  ON tenant FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_account
      WHERE id = auth.uid()
      AND role_global IN ('owner', 'admin')
    )
  );
-- church_settings
CREATE POLICY "Users can view church settings"
  ON church_settings FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admins can update church settings"
  ON church_settings FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_account
      WHERE id = auth.uid()
      AND role_global IN ('owner', 'admin')
    )
  );

-- campus
CREATE POLICY "Users can view all campus"
  ON campus FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admins can manage campus"
  ON campus FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_account
      WHERE id = auth.uid()
      AND role_global IN ('owner', 'admin', 'leader')
    )
  );

-- household
CREATE POLICY "Users can view all households"
  ON household FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can manage households"
  ON household FOR ALL
  USING (auth.uid() IS NOT NULL);

-- member
CREATE POLICY "Users can view all members"
  ON member FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can manage members"
  ON member FOR ALL
  USING (auth.uid() IS NOT NULL);

-- tag
CREATE POLICY "Users can view all tags"
  ON tag FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admins can manage tags"
  ON tag FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_account
      WHERE id = auth.uid()
      AND role_global IN ('owner', 'admin', 'leader')
    )
  );

-- member_tag
CREATE POLICY "Users can view member tags"
  ON member_tag FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can manage member tags"
  ON member_tag FOR ALL
  USING (auth.uid() IS NOT NULL);

-- step
CREATE POLICY "Users can view all steps"
  ON step FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admins can manage steps"
  ON step FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_account
      WHERE id = auth.uid()
      AND role_global IN ('owner', 'admin')
    )
  );

-- member_step
CREATE POLICY "Users can view member steps"
  ON member_step FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can manage member steps"
  ON member_step FOR ALL
  USING (auth.uid() IS NOT NULL);

-- group
CREATE POLICY "Users can view all groups"
  ON "group" FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can manage groups"
  ON "group" FOR ALL
  USING (auth.uid() IS NOT NULL);

-- group_member
CREATE POLICY "Users can view group members"
  ON group_member FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can manage group members"
  ON group_member FOR ALL
  USING (auth.uid() IS NOT NULL);

-- group_meeting
CREATE POLICY "Users can view group meetings"
  ON group_meeting FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can manage group meetings"
  ON group_meeting FOR ALL
  USING (auth.uid() IS NOT NULL);

-- group_attendance
CREATE POLICY "Users can view attendance"
  ON group_attendance FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can manage attendance"
  ON group_attendance FOR ALL
  USING (auth.uid() IS NOT NULL);

-- event
CREATE POLICY "Users can view all events"
  ON event FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can manage events"
  ON event FOR ALL
  USING (auth.uid() IS NOT NULL);

-- event_registration
CREATE POLICY "Users can view registrations"
  ON event_registration FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can manage registrations"
  ON event_registration FOR ALL
  USING (auth.uid() IS NOT NULL);

-- fund
CREATE POLICY "Users can view all funds"
  ON fund FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admins can manage funds"
  ON fund FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_account
      WHERE id = auth.uid()
      AND role_global IN ('owner', 'admin')
    )
  );

-- donation
CREATE POLICY "Users can view all donations"
  ON donation FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can manage donations"
  ON donation FOR ALL
  USING (auth.uid() IS NOT NULL);

-- ============================================
-- FIM DAS POLÍTICAS RLS
-- ============================================
