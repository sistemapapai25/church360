-- ============================================
-- CHURCH 360 - MÓDULO KIDS
-- ============================================
-- Data: 19/12/2025
-- Descrição: Tabelas para gestão do ministério infantil (Check-in, Segurança, Presença)
-- Dependências: user_account, worship_service
-- ============================================

-- ============================================
-- 1. TABELA DE GUARDIÕES AUTORIZADOS
-- ============================================
-- Vincula crianças a responsáveis extras (além dos pais que já estão no household)
-- Ex: Tios, Avós, Vizinhos autorizados a buscar a criança
CREATE TABLE IF NOT EXISTS kids_authorized_guardian (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    child_id UUID NOT NULL REFERENCES user_account(id) ON DELETE CASCADE,
    guardian_id UUID NOT NULL REFERENCES user_account(id) ON DELETE CASCADE,
    relationship TEXT NOT NULL, -- Ex: "Tio", "Avó", "Vizinho"
    can_checkin BOOLEAN DEFAULT TRUE,
    can_checkout BOOLEAN DEFAULT TRUE,
    is_temporary BOOLEAN DEFAULT FALSE,
    valid_until DATE, -- Se temporário, até quando vale
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES user_account(id) ON DELETE SET NULL,
    
    -- Evitar duplicidade do mesmo guardião para a mesma criança
    UNIQUE(child_id, guardian_id)
);

-- ============================================
-- 2. TABELA DE TOKENS DE CHECK-IN (QR CODE)
-- ============================================
-- Armazena os tokens efêmeros gerados para o QR Code
CREATE TABLE IF NOT EXISTS kids_checkin_token (
    token UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    child_id UUID NOT NULL REFERENCES user_account(id) ON DELETE CASCADE,
    event_id UUID REFERENCES worship_service(id) ON DELETE CASCADE, -- Vinculado a um culto específico
    generated_by UUID REFERENCES user_account(id) ON DELETE SET NULL, -- Quem gerou (Pai/Mãe)
    token_type TEXT CHECK (token_type IN ('checkin', 'checkout')) DEFAULT 'checkin',
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ, -- Se preenchido, o token já foi usado e é inválido
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índice para busca rápida de tokens válidos
CREATE INDEX IF NOT EXISTS idx_kids_token_lookup ON kids_checkin_token(token) WHERE used_at IS NULL;

-- ============================================
-- 3. TABELA DE PRESENÇA KIDS (ATTENDANCE)
-- ============================================
-- Histórico de entrada e saída das crianças nos cultos
CREATE TABLE IF NOT EXISTS kids_attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    child_id UUID NOT NULL REFERENCES user_account(id) ON DELETE CASCADE,
    worship_service_id UUID NOT NULL REFERENCES worship_service(id) ON DELETE CASCADE,
    
    -- Check-in
    checkin_time TIMESTAMPTZ DEFAULT NOW(),
    checkin_by UUID REFERENCES user_account(id) ON DELETE SET NULL, -- Voluntário que bipou
    checkin_token_id UUID REFERENCES kids_checkin_token(token), -- Token usado (auditoria)
    
    -- Check-out
    checkout_time TIMESTAMPTZ,
    checkout_by UUID REFERENCES user_account(id) ON DELETE SET NULL, -- Voluntário que liberou
    picked_up_by UUID REFERENCES user_account(id) ON DELETE SET NULL, -- Responsável que levou (Pai/Guardião)
    checkout_token_id UUID REFERENCES kids_checkin_token(token), -- Token usado na saída (auditoria)
    
    -- Sala/Turma (Opcional por enquanto, futuro módulo de turmas)
    room_name TEXT, 
    notes TEXT, -- Observações do dia (ex: "Chorou um pouco", "Comeu tudo")
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para relatórios
CREATE INDEX IF NOT EXISTS idx_kids_attendance_service ON kids_attendance(worship_service_id);
CREATE INDEX IF NOT EXISTS idx_kids_attendance_child ON kids_attendance(child_id);

-- ============================================
-- 4. TRIGGERS DE AUDITORIA
-- ============================================

-- Atualizar updated_at em kids_attendance
CREATE TRIGGER update_kids_attendance_updated_at
    BEFORE UPDATE ON kids_attendance
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 5. POLÍTICAS RLS (Row Level Security)
-- ============================================
-- Habilitar RLS
ALTER TABLE kids_authorized_guardian ENABLE ROW LEVEL SECURITY;
ALTER TABLE kids_checkin_token ENABLE ROW LEVEL SECURITY;
ALTER TABLE kids_attendance ENABLE ROW LEVEL SECURITY;

-- Políticas (Simplificadas para início - Refinar depois)

-- GUARDIÕES:
-- Pais podem ver e gerenciar guardiões de seus filhos (via household ou permissão direta)
-- Voluntários/Admin podem ver tudo
CREATE POLICY "Guardians visible to staff and parents" ON kids_authorized_guardian
    FOR ALL
    USING (
        -- É Staff/Admin
        EXISTS (
            SELECT 1 FROM user_account ua 
            WHERE ua.id = auth.uid() 
            AND ua.role_global IN ('admin', 'leader')
        )
        OR
        -- É o próprio usuário (criador) ou pai da criança (lógica simplificada: user pode ver o que criou)
        created_by = auth.uid()
    );

-- TOKENS:
-- Pais veem seus tokens gerados
-- Staff vê todos para validar
CREATE POLICY "Tokens visible to creator and staff" ON kids_checkin_token
    FOR ALL
    USING (
        generated_by = auth.uid()
        OR
        EXISTS (
            SELECT 1 FROM user_account ua 
            WHERE ua.id = auth.uid() 
            AND ua.role_global IN ('admin', 'leader')
        )
    );

-- ATTENDANCE:
-- Pais veem histórico dos filhos
-- Staff vê tudo
CREATE POLICY "Attendance visible to staff" ON kids_attendance
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM user_account ua 
            WHERE ua.id = auth.uid() 
            AND ua.role_global IN ('admin', 'leader')
        )
    );

-- ============================================
-- FIM DO SCRIPT
-- ============================================
