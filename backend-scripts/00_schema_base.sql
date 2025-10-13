-- ============================================
-- CHURCH 360 - SCHEMA BASE
-- ============================================
-- Versão: 1.0
-- Data: 13/10/2025
-- Descrição: Schema completo para MVP do Church 360
-- ============================================

-- Habilitar extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- ENUMS
-- ============================================

CREATE TYPE member_status AS ENUM (
  'visitor',
  'new_convert',
  'member_active',
  'member_inactive',
  'transferred',
  'deceased'
);

CREATE TYPE member_gender AS ENUM ('male', 'female', 'other');

CREATE TYPE marital_status AS ENUM (
  'single',
  'married',
  'divorced',
  'widowed',
  'other'
);

CREATE TYPE user_role AS ENUM (
  'owner',
  'admin',
  'leader',
  'member',
  'viewer'
);

CREATE TYPE event_status AS ENUM (
  'draft',
  'published',
  'ongoing',
  'completed',
  'cancelled'
);

CREATE TYPE registration_status AS ENUM (
  'pending',
  'confirmed',
  'checked_in',
  'cancelled',
  'no_show'
);

CREATE TYPE donation_method AS ENUM (
  'cash',
  'check',
  'bank_transfer',
  'pix',
  'credit_card',
  'debit_card',
  'other'
);

-- ============================================
-- TABELAS PRINCIPAIS
-- ============================================

-- Tabela: user_account
-- Usuários do sistema (vinculados ao Supabase Auth)
CREATE TABLE user_account (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  role_global user_role DEFAULT 'member',
  avatar_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela: church_settings
-- Configurações gerais da igreja
CREATE TABLE church_settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  church_name TEXT NOT NULL,
  church_logo_url TEXT,
  primary_color TEXT DEFAULT '#3B82F6',
  secondary_color TEXT DEFAULT '#10B981',
  timezone TEXT DEFAULT 'America/Sao_Paulo',
  currency TEXT DEFAULT 'BRL',
  language TEXT DEFAULT 'pt-BR',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela: campus
-- Locais/campus da igreja
CREATE TABLE campus (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  address TEXT,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  phone TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela: household
-- Famílias/domicílios
CREATE TABLE household (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  address TEXT,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  phone TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela: member
-- Membros da igreja
CREATE TABLE member (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  birthdate DATE,
  gender member_gender,
  marital_status marital_status,
  status member_status DEFAULT 'visitor',
  photo_url TEXT,
  
  -- Endereço
  address TEXT,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  
  -- Relacionamentos
  household_id UUID REFERENCES household(id) ON DELETE SET NULL,
  campus_id UUID REFERENCES campus(id) ON DELETE SET NULL,
  
  -- Datas importantes
  conversion_date DATE,
  baptism_date DATE,
  membership_date DATE,
  
  -- Notas
  notes TEXT,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES user_account(id) ON DELETE SET NULL
);

-- Tabela: tag
-- Tags para categorização
CREATE TABLE tag (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT UNIQUE NOT NULL,
  color TEXT DEFAULT '#6B7280',
  category TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela: member_tag
-- Relacionamento muitos-para-muitos entre membros e tags
CREATE TABLE member_tag (
  member_id UUID REFERENCES member(id) ON DELETE CASCADE,
  tag_id UUID REFERENCES tag(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (member_id, tag_id)
);

-- Tabela: step
-- Passos da jornada espiritual
CREATE TABLE step (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  sequence_order INTEGER NOT NULL,
  icon TEXT,
  color TEXT DEFAULT '#3B82F6',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela: member_step
-- Progresso dos membros nos passos
CREATE TABLE member_step (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID REFERENCES member(id) ON DELETE CASCADE,
  step_id UUID REFERENCES step(id) ON DELETE CASCADE,
  completed_date DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(member_id, step_id)
);

-- Tabela: group
-- Grupos/células
CREATE TABLE "group" (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  group_type TEXT,
  
  -- Líder
  leader_id UUID REFERENCES member(id) ON DELETE SET NULL,
  
  -- Local
  campus_id UUID REFERENCES campus(id) ON DELETE SET NULL,
  meeting_address TEXT,
  
  -- Horário
  meeting_day_of_week INTEGER, -- 0=Domingo, 6=Sábado
  meeting_time TIME,
  
  -- Status
  is_active BOOLEAN DEFAULT true,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES user_account(id) ON DELETE SET NULL
);

-- Tabela: group_member
-- Membros de grupos
CREATE TABLE group_member (
  group_id UUID REFERENCES "group"(id) ON DELETE CASCADE,
  member_id UUID REFERENCES member(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'member', -- member, co-leader, etc
  joined_date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (group_id, member_id)
);

-- Tabela: group_meeting
-- Encontros de grupos
CREATE TABLE group_meeting (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  group_id UUID REFERENCES "group"(id) ON DELETE CASCADE,
  meeting_date DATE NOT NULL,
  topic TEXT,
  notes TEXT,
  total_attendance INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES user_account(id) ON DELETE SET NULL
);

-- Tabela: group_attendance
-- Presença em encontros de grupos
CREATE TABLE group_attendance (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  meeting_id UUID REFERENCES group_meeting(id) ON DELETE CASCADE,
  member_id UUID REFERENCES member(id) ON DELETE CASCADE,
  was_present BOOLEAN DEFAULT true,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(meeting_id, member_id)
);

-- Tabela: event
-- Eventos da igreja
CREATE TABLE event (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  event_type TEXT,

  -- Data e hora
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ,

  -- Local
  campus_id UUID REFERENCES campus(id) ON DELETE SET NULL,
  location TEXT,

  -- Capacidade
  max_capacity INTEGER,
  requires_registration BOOLEAN DEFAULT false,

  -- Status
  status event_status DEFAULT 'draft',

  -- Imagem
  image_url TEXT,

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES user_account(id) ON DELETE SET NULL
);

-- Tabela: event_registration
-- Inscrições em eventos
CREATE TABLE event_registration (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID REFERENCES event(id) ON DELETE CASCADE,
  member_id UUID REFERENCES member(id) ON DELETE CASCADE,

  -- Status
  status registration_status DEFAULT 'pending',

  -- Check-in
  checked_in_at TIMESTAMPTZ,
  checked_in_by UUID REFERENCES user_account(id) ON DELETE SET NULL,

  -- QR Code
  qr_code TEXT UNIQUE,

  -- Metadata
  registered_at TIMESTAMPTZ DEFAULT NOW(),
  notes TEXT,

  UNIQUE(event_id, member_id)
);

-- Tabela: fund
-- Fundos financeiros (Dízimos, Ofertas, Missões, etc)
CREATE TABLE fund (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT UNIQUE NOT NULL,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela: donation
-- Doações/contribuições
CREATE TABLE donation (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- Doador
  member_id UUID REFERENCES member(id) ON DELETE SET NULL,
  donor_name TEXT, -- Para doações anônimas ou visitantes

  -- Valor e fundo
  amount DECIMAL(10,2) NOT NULL,
  fund_id UUID REFERENCES fund(id) ON DELETE SET NULL,

  -- Método de pagamento
  payment_method donation_method NOT NULL,

  -- Data
  donation_date DATE NOT NULL DEFAULT CURRENT_DATE,

  -- Recibo
  receipt_number TEXT UNIQUE,
  receipt_issued BOOLEAN DEFAULT false,

  -- Notas
  notes TEXT,

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES user_account(id) ON DELETE SET NULL
);

-- ============================================
-- ÍNDICES
-- ============================================

-- Índices para member
CREATE INDEX idx_member_status ON member(status);
CREATE INDEX idx_member_household ON member(household_id);
CREATE INDEX idx_member_campus ON member(campus_id);
CREATE INDEX idx_member_email ON member(email);
CREATE INDEX idx_member_name ON member(first_name, last_name);

-- Índices para group
CREATE INDEX idx_group_leader ON "group"(leader_id);
CREATE INDEX idx_group_campus ON "group"(campus_id);
CREATE INDEX idx_group_active ON "group"(is_active);

-- Índices para event
CREATE INDEX idx_event_start_date ON event(start_date);
CREATE INDEX idx_event_status ON event(status);
CREATE INDEX idx_event_campus ON event(campus_id);

-- Índices para donation
CREATE INDEX idx_donation_member ON donation(member_id);
CREATE INDEX idx_donation_fund ON donation(fund_id);
CREATE INDEX idx_donation_date ON donation(donation_date);

-- ============================================
-- TRIGGERS PARA UPDATED_AT
-- ============================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_user_account_updated_at BEFORE UPDATE ON user_account
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_church_settings_updated_at BEFORE UPDATE ON church_settings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_campus_updated_at BEFORE UPDATE ON campus
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_household_updated_at BEFORE UPDATE ON household
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_member_updated_at BEFORE UPDATE ON member
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_group_updated_at BEFORE UPDATE ON "group"
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_event_updated_at BEFORE UPDATE ON event
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- DADOS SEED
-- ============================================

-- Fundos padrão
INSERT INTO fund (name, description, display_order) VALUES
  ('Dízimos', 'Dízimos dos membros', 1),
  ('Ofertas', 'Ofertas gerais', 2),
  ('Missões', 'Contribuições para missões', 3),
  ('Construção', 'Fundo de construção e reformas', 4),
  ('Ação Social', 'Projetos sociais e assistência', 5);

-- Tags padrão
INSERT INTO tag (name, color, category) VALUES
  ('Novo Convertido', '#10B981', 'status'),
  ('Líder', '#3B82F6', 'role'),
  ('Voluntário', '#8B5CF6', 'role'),
  ('Músico', '#F59E0B', 'ministry'),
  ('Professor EBD', '#EF4444', 'ministry'),
  ('Intercessor', '#EC4899', 'ministry');

-- Steps padrão (jornada espiritual)
INSERT INTO step (name, description, sequence_order, icon, color) VALUES
  ('Visitante', 'Primeira visita à igreja', 1, 'person_add', '#6B7280'),
  ('Conversão', 'Aceitou Jesus como Salvador', 2, 'favorite', '#EF4444'),
  ('Batismo', 'Batizado nas águas', 3, 'water_drop', '#3B82F6'),
  ('Membro', 'Tornou-se membro oficial', 4, 'group', '#10B981'),
  ('Líder', 'Assumiu liderança', 5, 'star', '#F59E0B');

-- Configuração inicial da igreja (placeholder)
INSERT INTO church_settings (church_name) VALUES ('Minha Igreja');

-- Campus padrão
INSERT INTO campus (name, is_active) VALUES ('Campus Principal', true);

-- ============================================
-- FIM DO SCHEMA
-- ============================================

