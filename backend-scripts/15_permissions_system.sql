-- =====================================================
-- CHURCH 360 - SISTEMA DE PERMISSÕES GRANULARES
-- =====================================================
-- Descrição: Sistema completo de permissões com cargos customizáveis,
--            contextos específicos, hierarquia e auditoria
-- Autor: Church 360 Team
-- Data: 2025-01-23
-- =====================================================

-- =====================================================
-- 1. TABELAS PRINCIPAIS
-- =====================================================

-- Tabela: roles (Cargos/Funções)
-- Armazena todos os cargos customizáveis do sistema
CREATE TABLE IF NOT EXISTS roles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Informações básicas
  name TEXT NOT NULL,
  description TEXT,
  
  -- Hierarquia
  parent_role_id UUID REFERENCES roles(id) ON DELETE SET NULL,
  hierarchy_level INTEGER DEFAULT 0,
  
  -- Configurações
  allows_context BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  
  -- Auditoria
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_roles_parent ON roles(parent_role_id);
CREATE INDEX IF NOT EXISTS idx_roles_active ON roles(is_active);
CREATE INDEX IF NOT EXISTS idx_roles_name ON roles(name);

-- Comentários
COMMENT ON TABLE roles IS 'Cargos/funções customizáveis do sistema';
COMMENT ON COLUMN roles.allows_context IS 'Se true, permite criar contextos específicos para este cargo';
COMMENT ON COLUMN roles.hierarchy_level IS 'Nível hierárquico: 0=raiz, 1=sub, 2=sub-sub, etc';

-- =====================================================

-- Tabela: role_contexts (Contextos dos Cargos)
-- Armazena contextos específicos para cargos
-- Ex: "Casa de Oração - Dona Joana", "Hospital Santa Casa"
CREATE TABLE IF NOT EXISTS role_contexts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Relacionamento
  role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  
  -- Informações do contexto
  context_name TEXT NOT NULL,
  description TEXT,
  
  -- Dados específicos do contexto (JSON flexível)
  metadata JSONB DEFAULT '{}'::jsonb,
  
  -- Status
  is_active BOOLEAN DEFAULT true,
  
  -- Auditoria
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_role_contexts_role ON role_contexts(role_id);
CREATE INDEX IF NOT EXISTS idx_role_contexts_active ON role_contexts(is_active);
CREATE INDEX IF NOT EXISTS idx_role_contexts_name ON role_contexts(context_name);

-- Comentários
COMMENT ON TABLE role_contexts IS 'Contextos específicos para cargos (ex: Casa de Oração - Dona Joana)';
COMMENT ON COLUMN role_contexts.metadata IS 'Dados adicionais em JSON (endereço, telefone, etc)';

-- =====================================================

-- Tabela: permissions (Permissões do Sistema)
-- Catálogo de todas as permissões disponíveis
CREATE TABLE IF NOT EXISTS permissions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Identificação
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  
  -- Categorização
  category TEXT NOT NULL,
  subcategory TEXT,
  
  -- Configurações
  is_active BOOLEAN DEFAULT true,
  requires_context BOOLEAN DEFAULT false,
  
  -- Auditoria
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_permissions_code ON permissions(code);
CREATE INDEX IF NOT EXISTS idx_permissions_category ON permissions(category);
CREATE INDEX IF NOT EXISTS idx_permissions_active ON permissions(is_active);

-- Comentários
COMMENT ON TABLE permissions IS 'Catálogo de todas as permissões do sistema';
COMMENT ON COLUMN permissions.code IS 'Código único da permissão (ex: members.view, financial.edit)';
COMMENT ON COLUMN permissions.requires_context IS 'Se true, permissão requer contexto específico';

-- =====================================================

-- Tabela: role_permissions (Permissões por Cargo)
-- Define quais permissões cada cargo possui
CREATE TABLE IF NOT EXISTS role_permissions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Relacionamentos
  role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  
  -- Concessão
  is_granted BOOLEAN DEFAULT true,
  
  -- Auditoria
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  
  -- Constraint: uma permissão por cargo
  UNIQUE(role_id, permission_id)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_role_permissions_role ON role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_permission ON role_permissions(permission_id);

-- Comentários
COMMENT ON TABLE role_permissions IS 'Permissões atribuídas a cada cargo';

-- =====================================================

-- Tabela: user_roles (Atribuição de Cargos aos Usuários)
-- Relaciona usuários com seus cargos (um usuário pode ter múltiplos cargos)
CREATE TABLE IF NOT EXISTS user_roles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Relacionamentos
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  role_context_id UUID REFERENCES role_contexts(id) ON DELETE SET NULL,
  
  -- Temporalidade
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  
  -- Status
  is_active BOOLEAN DEFAULT true,
  
  -- Auditoria
  assigned_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  notes TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_user_roles_user ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role ON user_roles(role_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_context ON user_roles(role_context_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_active ON user_roles(is_active);
CREATE INDEX IF NOT EXISTS idx_user_roles_expires ON user_roles(expires_at);

-- Comentários
COMMENT ON TABLE user_roles IS 'Atribuição de cargos aos usuários (múltiplos cargos por usuário)';
COMMENT ON COLUMN user_roles.expires_at IS 'Data de expiração do cargo (NULL = permanente)';

-- =====================================================

-- Tabela: user_custom_permissions (Permissões Customizadas)
-- Permissões específicas atribuídas diretamente a usuários (override)
CREATE TABLE IF NOT EXISTS user_custom_permissions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Relacionamentos
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  
  -- Concessão
  is_granted BOOLEAN DEFAULT true,
  
  -- Temporalidade
  granted_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  
  -- Auditoria
  granted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reason TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraint: uma permissão customizada por usuário
  UNIQUE(user_id, permission_id)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_user_custom_permissions_user ON user_custom_permissions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_custom_permissions_permission ON user_custom_permissions(permission_id);
CREATE INDEX IF NOT EXISTS idx_user_custom_permissions_expires ON user_custom_permissions(expires_at);

-- Comentários
COMMENT ON TABLE user_custom_permissions IS 'Permissões customizadas atribuídas diretamente a usuários';
COMMENT ON COLUMN user_custom_permissions.is_granted IS 'true = adiciona permissão, false = remove permissão';

-- =====================================================

-- Tabela: permission_audit_log (Log de Auditoria)
-- Registra todas as mudanças de permissões e cargos
CREATE TABLE IF NOT EXISTS permission_audit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Tipo de ação
  action_type TEXT NOT NULL,
  
  -- Relacionamentos
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  role_id UUID REFERENCES roles(id) ON DELETE SET NULL,
  permission_id UUID REFERENCES permissions(id) ON DELETE SET NULL,
  
  -- Detalhes
  details JSONB DEFAULT '{}'::jsonb,
  
  -- Auditoria
  performed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  performed_at TIMESTAMPTZ DEFAULT NOW(),
  ip_address INET
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_permission_audit_user ON permission_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_permission_audit_performed_by ON permission_audit_log(performed_by);
CREATE INDEX IF NOT EXISTS idx_permission_audit_date ON permission_audit_log(performed_at);
CREATE INDEX IF NOT EXISTS idx_permission_audit_action ON permission_audit_log(action_type);

-- Comentários
COMMENT ON TABLE permission_audit_log IS 'Log de auditoria de todas as mudanças de permissões';
COMMENT ON COLUMN permission_audit_log.action_type IS 'Tipo: role_assigned, role_removed, permission_granted, etc';

-- =====================================================
-- 2. TRIGGERS
-- =====================================================

-- Trigger: Atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Aplicar trigger nas tabelas
DROP TRIGGER IF EXISTS update_roles_updated_at ON roles;
CREATE TRIGGER update_roles_updated_at
  BEFORE UPDATE ON roles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_role_contexts_updated_at ON role_contexts;
CREATE TRIGGER update_role_contexts_updated_at
  BEFORE UPDATE ON role_contexts
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_user_roles_updated_at ON user_roles;
CREATE TRIGGER update_user_roles_updated_at
  BEFORE UPDATE ON user_roles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 3. FUNCTIONS PRINCIPAIS
-- =====================================================

-- =====================================================
-- FUNCTION: get_user_effective_permissions
-- Retorna todas as permissões efetivas de um usuário
-- (combinação de permissões dos cargos + customizações)
-- =====================================================
CREATE OR REPLACE FUNCTION get_user_effective_permissions(p_user_id UUID)
RETURNS TABLE(
  permission_code TEXT,
  permission_name TEXT,
  source TEXT,
  role_name TEXT,
  context_name TEXT,
  is_granted BOOLEAN
) AS $$
BEGIN
  RETURN QUERY

  -- Permissões dos cargos
  SELECT DISTINCT
    p.code,
    p.name,
    'role'::TEXT,
    r.name,
    rc.context_name,
    rp.is_granted
  FROM user_roles ur
  JOIN roles r ON r.id = ur.role_id
  JOIN role_permissions rp ON rp.role_id = r.id
  JOIN permissions p ON p.id = rp.permission_id
  LEFT JOIN role_contexts rc ON rc.id = ur.role_context_id
  WHERE ur.user_id = p_user_id
    AND ur.is_active = true
    AND (ur.expires_at IS NULL OR ur.expires_at > NOW())
    AND r.is_active = true
    AND p.is_active = true

  UNION

  -- Permissões customizadas
  SELECT
    p.code,
    p.name,
    'custom'::TEXT,
    NULL,
    NULL,
    ucp.is_granted
  FROM user_custom_permissions ucp
  JOIN permissions p ON p.id = ucp.permission_id
  WHERE ucp.user_id = p_user_id
    AND (ucp.expires_at IS NULL OR ucp.expires_at > NOW())
    AND p.is_active = true;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_user_effective_permissions IS 'Retorna todas as permissões efetivas de um usuário';

-- =====================================================
-- FUNCTION: check_user_permission
-- Verifica se usuário tem uma permissão específica
-- Prioridade: customizações > cargos
-- =====================================================
CREATE OR REPLACE FUNCTION check_user_permission(
  p_user_id UUID,
  p_permission_code TEXT
) RETURNS BOOLEAN AS $$
DECLARE
  v_has_permission BOOLEAN;
BEGIN
  -- Verifica se tem permissão customizada (prioridade)
  SELECT is_granted INTO v_has_permission
  FROM user_custom_permissions ucp
  JOIN permissions p ON p.id = ucp.permission_id
  WHERE ucp.user_id = p_user_id
    AND p.code = p_permission_code
    AND (ucp.expires_at IS NULL OR ucp.expires_at > NOW())
  LIMIT 1;

  -- Se encontrou customização, retorna
  IF FOUND THEN
    RETURN v_has_permission;
  END IF;

  -- Senão, verifica permissões dos cargos
  SELECT EXISTS(
    SELECT 1
    FROM user_roles ur
    JOIN role_permissions rp ON rp.role_id = ur.role_id
    JOIN permissions p ON p.id = rp.permission_id
    WHERE ur.user_id = p_user_id
      AND p.code = p_permission_code
      AND ur.is_active = true
      AND (ur.expires_at IS NULL OR ur.expires_at > NOW())
      AND rp.is_granted = true
  ) INTO v_has_permission;

  RETURN COALESCE(v_has_permission, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION check_user_permission IS 'Verifica se usuário tem permissão específica';

-- =====================================================
-- FUNCTION: can_access_dashboard
-- Verifica se usuário pode acessar o Dashboard
-- Regra: Nível de acesso >= 2 (Membro ou superior)
-- =====================================================
CREATE OR REPLACE FUNCTION can_access_dashboard(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_access_level INTEGER;
BEGIN
  -- Busca nível de acesso do usuário
  SELECT access_level_number INTO v_access_level
  FROM user_access_level
  WHERE user_id = p_user_id;

  -- Nível 2+ pode acessar Dashboard
  RETURN COALESCE(v_access_level, 0) >= 2;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION can_access_dashboard IS 'Verifica se usuário pode acessar Dashboard (nível >= 2)';

-- =====================================================
-- FUNCTION: get_user_role_contexts
-- Retorna todos os contextos que o usuário tem acesso
-- =====================================================
CREATE OR REPLACE FUNCTION get_user_role_contexts(
  p_user_id UUID,
  p_role_id UUID DEFAULT NULL
) RETURNS TABLE(
  context_id UUID,
  context_name TEXT,
  role_name TEXT,
  role_id UUID
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    rc.id,
    rc.context_name,
    r.name,
    r.id
  FROM user_roles ur
  JOIN roles r ON r.id = ur.role_id
  LEFT JOIN role_contexts rc ON rc.id = ur.role_context_id
  WHERE ur.user_id = p_user_id
    AND ur.is_active = true
    AND (ur.expires_at IS NULL OR ur.expires_at > NOW())
    AND (p_role_id IS NULL OR r.id = p_role_id)
    AND rc.id IS NOT NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_user_role_contexts IS 'Retorna contextos que o usuário tem acesso';

-- =====================================================
-- FUNCTION: assign_role_to_user
-- Atribui um cargo a um usuário
-- =====================================================
CREATE OR REPLACE FUNCTION assign_role_to_user(
  p_user_id UUID,
  p_role_id UUID,
  p_context_id UUID DEFAULT NULL,
  p_assigned_by UUID DEFAULT NULL,
  p_expires_at TIMESTAMPTZ DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_user_role_id UUID;
BEGIN
  -- Insere atribuição
  INSERT INTO user_roles (
    user_id, role_id, role_context_id,
    assigned_by, expires_at, notes
  ) VALUES (
    p_user_id, p_role_id, p_context_id,
    p_assigned_by, p_expires_at, p_notes
  ) RETURNING id INTO v_user_role_id;

  -- Log de auditoria
  INSERT INTO permission_audit_log (
    action_type, user_id, role_id,
    performed_by, details
  ) VALUES (
    'role_assigned', p_user_id, p_role_id,
    p_assigned_by, jsonb_build_object(
      'context_id', p_context_id,
      'expires_at', p_expires_at,
      'user_role_id', v_user_role_id
    )
  );

  RETURN v_user_role_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION assign_role_to_user IS 'Atribui cargo a usuário com auditoria';

-- =====================================================
-- FUNCTION: remove_user_role
-- Remove um cargo de um usuário
-- =====================================================
CREATE OR REPLACE FUNCTION remove_user_role(
  p_user_role_id UUID,
  p_removed_by UUID DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
  v_user_id UUID;
  v_role_id UUID;
BEGIN
  -- Busca dados antes de remover
  SELECT user_id, role_id INTO v_user_id, v_role_id
  FROM user_roles
  WHERE id = p_user_role_id;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- Desativa o cargo
  UPDATE user_roles
  SET is_active = false,
      updated_at = NOW()
  WHERE id = p_user_role_id;

  -- Log de auditoria
  INSERT INTO permission_audit_log (
    action_type, user_id, role_id,
    performed_by, details
  ) VALUES (
    'role_removed', v_user_id, v_role_id,
    p_removed_by, jsonb_build_object(
      'user_role_id', p_user_role_id
    )
  );

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION remove_user_role IS 'Remove cargo de usuário com auditoria';

-- =====================================================
-- 4. ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Habilitar RLS em todas as tabelas
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_contexts ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_custom_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE permission_audit_log ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- POLICIES: roles
-- =====================================================

-- Todos podem ver cargos ativos
DROP POLICY IF EXISTS "Todos podem ver cargos ativos" ON roles;
CREATE POLICY "Todos podem ver cargos ativos"
  ON roles FOR SELECT
  USING (is_active = true);

-- Apenas quem tem permissão pode criar cargos
DROP POLICY IF EXISTS "Gerenciar cargos requer permissão" ON roles;
CREATE POLICY "Gerenciar cargos requer permissão"
  ON roles FOR ALL
  USING (
    check_user_permission(auth.uid(), 'settings.manage_roles')
  );

-- =====================================================
-- POLICIES: role_contexts
-- =====================================================

-- Todos podem ver contextos ativos
DROP POLICY IF EXISTS "Todos podem ver contextos ativos" ON role_contexts;
CREATE POLICY "Todos podem ver contextos ativos"
  ON role_contexts FOR SELECT
  USING (is_active = true);

-- Apenas quem tem permissão pode gerenciar contextos
DROP POLICY IF EXISTS "Gerenciar contextos requer permissão" ON role_contexts;
CREATE POLICY "Gerenciar contextos requer permissão"
  ON role_contexts FOR ALL
  USING (
    check_user_permission(auth.uid(), 'settings.manage_roles')
  );

-- =====================================================
-- POLICIES: permissions
-- =====================================================

-- Todos podem ver permissões ativas
DROP POLICY IF EXISTS "Todos podem ver permissões" ON permissions;
CREATE POLICY "Todos podem ver permissões"
  ON permissions FOR SELECT
  USING (is_active = true);

-- Apenas admins podem gerenciar permissões (nível 5)
DROP POLICY IF EXISTS "Apenas admins gerenciam permissões" ON permissions;
CREATE POLICY "Apenas admins gerenciam permissões"
  ON permissions FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_access_level
      WHERE user_id = auth.uid()
      AND access_level_number >= 5
    )
  );

-- =====================================================
-- POLICIES: role_permissions
-- =====================================================

-- Todos podem ver permissões dos cargos
DROP POLICY IF EXISTS "Todos podem ver permissões dos cargos" ON role_permissions;
CREATE POLICY "Todos podem ver permissões dos cargos"
  ON role_permissions FOR SELECT
  USING (true);

-- Apenas quem tem permissão pode gerenciar
DROP POLICY IF EXISTS "Gerenciar permissões de cargos requer permissão" ON role_permissions;
CREATE POLICY "Gerenciar permissões de cargos requer permissão"
  ON role_permissions FOR ALL
  USING (
    check_user_permission(auth.uid(), 'settings.manage_roles')
  );

-- =====================================================
-- POLICIES: user_roles
-- =====================================================

-- Usuários podem ver seus próprios cargos
DROP POLICY IF EXISTS "Usuários veem próprios cargos" ON user_roles;
CREATE POLICY "Usuários veem próprios cargos"
  ON user_roles FOR SELECT
  USING (user_id = auth.uid());

-- Quem tem permissão pode ver todos os cargos
DROP POLICY IF EXISTS "Ver todos cargos requer permissão" ON user_roles;
CREATE POLICY "Ver todos cargos requer permissão"
  ON user_roles FOR SELECT
  USING (
    check_user_permission(auth.uid(), 'settings.manage_permissions')
  );

-- Apenas quem tem permissão pode atribuir/remover cargos
DROP POLICY IF EXISTS "Gerenciar atribuições requer permissão" ON user_roles;
CREATE POLICY "Gerenciar atribuições requer permissão"
  ON user_roles FOR ALL
  USING (
    check_user_permission(auth.uid(), 'settings.manage_permissions')
  );

-- =====================================================
-- POLICIES: user_custom_permissions
-- =====================================================

-- Usuários podem ver suas próprias permissões customizadas
DROP POLICY IF EXISTS "Usuários veem próprias permissões" ON user_custom_permissions;
CREATE POLICY "Usuários veem próprias permissões"
  ON user_custom_permissions FOR SELECT
  USING (user_id = auth.uid());

-- Quem tem permissão pode ver todas
DROP POLICY IF EXISTS "Ver todas permissões customizadas requer permissão" ON user_custom_permissions;
CREATE POLICY "Ver todas permissões customizadas requer permissão"
  ON user_custom_permissions FOR SELECT
  USING (
    check_user_permission(auth.uid(), 'settings.manage_permissions')
  );

-- Apenas quem tem permissão pode gerenciar
DROP POLICY IF EXISTS "Gerenciar permissões customizadas requer permissão" ON user_custom_permissions;
CREATE POLICY "Gerenciar permissões customizadas requer permissão"
  ON user_custom_permissions FOR ALL
  USING (
    check_user_permission(auth.uid(), 'settings.manage_permissions')
  );

-- =====================================================
-- POLICIES: permission_audit_log
-- =====================================================

-- Apenas quem tem permissão pode ver logs
DROP POLICY IF EXISTS "Ver logs requer permissão" ON permission_audit_log;
CREATE POLICY "Ver logs requer permissão"
  ON permission_audit_log FOR SELECT
  USING (
    check_user_permission(auth.uid(), 'settings.manage_permissions')
  );

-- Inserção é sempre permitida (via functions)
DROP POLICY IF EXISTS "Sistema pode inserir logs" ON permission_audit_log;
CREATE POLICY "Sistema pode inserir logs"
  ON permission_audit_log FOR INSERT
  WITH CHECK (true);

