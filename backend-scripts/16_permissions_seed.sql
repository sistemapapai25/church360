-- =====================================================
-- CHURCH 360 - SEED DE PERMISSÕES INICIAIS
-- =====================================================
-- Descrição: Catálogo completo de permissões do Dashboard
-- Autor: Church 360 Team
-- Data: 2025-01-23
-- =====================================================

-- =====================================================
-- CATEGORIA: MEMBROS
-- =====================================================
INSERT INTO permissions (code, name, description, category, subcategory, requires_context) VALUES
('members.view', 'Ver Membros', 'Visualizar lista de membros', 'members', 'view', false),
('members.view_details', 'Ver Detalhes de Membros', 'Ver informações detalhadas de membros', 'members', 'view', false),
('members.create', 'Criar Membro', 'Cadastrar novos membros', 'members', 'create', false),
('members.edit', 'Editar Membro', 'Editar dados de membros', 'members', 'edit', false),
('members.delete', 'Deletar Membro', 'Remover membros do sistema', 'members', 'delete', false),
('members.export', 'Exportar Membros', 'Exportar dados de membros', 'members', 'export', false)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- CATEGORIA: GRUPOS
-- =====================================================
INSERT INTO permissions (code, name, description, category, subcategory, requires_context) VALUES
('groups.view', 'Ver Grupos', 'Visualizar grupos', 'groups', 'view', false),
('groups.view_details', 'Ver Detalhes de Grupos', 'Ver informações detalhadas de grupos', 'groups', 'view', false),
('groups.create', 'Criar Grupo', 'Criar novos grupos', 'groups', 'create', false),
('groups.edit', 'Editar Grupo', 'Editar grupos', 'groups', 'edit', false),
('groups.delete', 'Deletar Grupo', 'Remover grupos', 'groups', 'delete', false),
('groups.manage_own', 'Gerenciar Próprio Grupo', 'Gerenciar apenas grupos atribuídos', 'groups', 'manage', true),
('groups.manage_all', 'Gerenciar Todos Grupos', 'Gerenciar todos os grupos', 'groups', 'manage', false),
('groups.manage_members', 'Gerenciar Membros do Grupo', 'Adicionar/remover membros de grupos', 'groups', 'manage', false),
('groups.manage_meetings', 'Gerenciar Reuniões', 'Criar e gerenciar reuniões de grupos', 'groups', 'manage', false)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- CATEGORIA: EVENTOS
-- =====================================================
INSERT INTO permissions (code, name, description, category, subcategory, requires_context) VALUES
('events.view', 'Ver Eventos', 'Visualizar eventos', 'events', 'view', false),
('events.view_details', 'Ver Detalhes de Eventos', 'Ver informações detalhadas de eventos', 'events', 'view', false),
('events.create', 'Criar Evento', 'Criar novos eventos', 'events', 'create', false),
('events.edit', 'Editar Evento', 'Editar eventos', 'events', 'edit', false),
('events.delete', 'Deletar Evento', 'Remover eventos', 'events', 'delete', false),
('events.checkin', 'Check-in Eventos', 'Fazer check-in em eventos', 'events', 'checkin', false),
('events.manage_registrations', 'Gerenciar Inscrições', 'Gerenciar inscrições de eventos', 'events', 'manage', false),
('events.view_statistics', 'Ver Estatísticas de Eventos', 'Visualizar estatísticas de eventos', 'events', 'view', false)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- CATEGORIA: FINANÇAS
-- =====================================================
INSERT INTO permissions (code, name, description, category, subcategory, requires_context) VALUES
('financial.view', 'Ver Finanças', 'Visualizar dados financeiros', 'financial', 'view', false),
('financial.view_reports', 'Ver Relatórios Financeiros', 'Acessar relatórios financeiros', 'financial', 'view', false),
('financial.create_contribution', 'Registrar Contribuição', 'Registrar contribuições', 'financial', 'create', false),
('financial.create_expense', 'Registrar Despesa', 'Registrar despesas', 'financial', 'create', false),
('financial.edit', 'Editar Finanças', 'Editar registros financeiros', 'financial', 'edit', false),
('financial.delete', 'Deletar Finanças', 'Remover registros financeiros', 'financial', 'delete', false),
('financial.approve', 'Aprovar Despesas', 'Aprovar despesas pendentes', 'financial', 'approve', false),
('financial.manage_goals', 'Gerenciar Metas Financeiras', 'Criar e gerenciar metas financeiras', 'financial', 'manage', false),
('financial.export', 'Exportar Dados Financeiros', 'Exportar relatórios financeiros', 'financial', 'export', false)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- CATEGORIA: VISITANTES
-- =====================================================
INSERT INTO permissions (code, name, description, category, subcategory, requires_context) VALUES
('visitors.view', 'Ver Visitantes', 'Visualizar visitantes', 'visitors', 'view', false),
('visitors.view_details', 'Ver Detalhes de Visitantes', 'Ver informações detalhadas de visitantes', 'visitors', 'view', false),
('visitors.create', 'Registrar Visitante', 'Cadastrar visitantes', 'visitors', 'create', false),
('visitors.edit', 'Editar Visitante', 'Editar dados de visitantes', 'visitors', 'edit', false),
('visitors.delete', 'Deletar Visitante', 'Remover visitantes', 'visitors', 'delete', false),
('visitors.followup', 'Acompanhar Visitante', 'Fazer acompanhamento de visitantes', 'visitors', 'followup', false),
('visitors.view_statistics', 'Ver Estatísticas de Visitantes', 'Visualizar estatísticas de visitantes', 'visitors', 'view', false)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- CATEGORIA: MINISTÉRIOS
-- =====================================================
INSERT INTO permissions (code, name, description, category, subcategory, requires_context) VALUES
('ministries.view', 'Ver Ministérios', 'Visualizar ministérios', 'ministries', 'view', false),
('ministries.view_details', 'Ver Detalhes de Ministérios', 'Ver informações detalhadas de ministérios', 'ministries', 'view', false),
('ministries.create', 'Criar Ministério', 'Criar novos ministérios', 'ministries', 'create', false),
('ministries.edit', 'Editar Ministério', 'Editar ministérios', 'ministries', 'edit', false),
('ministries.delete', 'Deletar Ministério', 'Remover ministérios', 'ministries', 'delete', false),
('ministries.manage_members', 'Gerenciar Membros do Ministério', 'Gerenciar membros do ministério', 'ministries', 'manage', true),
('ministries.manage_schedule', 'Gerenciar Escalas', 'Gerenciar escalas do ministério', 'ministries', 'manage', true),
('ministries.manage_own', 'Gerenciar Próprio Ministério', 'Gerenciar apenas ministérios atribuídos', 'ministries', 'manage', true)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- CATEGORIA: CULTOS
-- =====================================================
INSERT INTO permissions (code, name, description, category, subcategory, requires_context) VALUES
('worship.view', 'Ver Cultos', 'Visualizar cultos', 'worship', 'view', false),
('worship.view_details', 'Ver Detalhes de Cultos', 'Ver informações detalhadas de cultos', 'worship', 'view', false),
('worship.create', 'Criar Culto', 'Criar registros de cultos', 'worship', 'create', false),
('worship.edit', 'Editar Culto', 'Editar cultos', 'worship', 'edit', false),
('worship.delete', 'Deletar Culto', 'Remover cultos', 'worship', 'delete', false),
('worship.attendance', 'Registrar Presença', 'Registrar presença em cultos', 'worship', 'manage', false),
('worship.view_statistics', 'Ver Estatísticas de Cultos', 'Visualizar estatísticas de cultos', 'worship', 'view', false)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- CATEGORIA: RELATÓRIOS
-- =====================================================
INSERT INTO permissions (code, name, description, category, subcategory, requires_context) VALUES
('reports.view', 'Ver Relatórios', 'Visualizar relatórios', 'reports', 'view', false),
('reports.create', 'Criar Relatórios', 'Criar relatórios customizados', 'reports', 'create', false),
('reports.edit', 'Editar Relatórios', 'Editar relatórios customizados', 'reports', 'edit', false),
('reports.delete', 'Deletar Relatórios', 'Remover relatórios customizados', 'reports', 'delete', false),
('reports.export', 'Exportar Relatórios', 'Exportar relatórios', 'reports', 'export', false),
('reports.view_analytics', 'Ver Analytics', 'Acessar dashboard de analytics', 'reports', 'view', false)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- CATEGORIA: DEVOCIONAIS
-- =====================================================
INSERT INTO permissions (code, name, description, category, subcategory, requires_context) VALUES
('devotionals.view', 'Ver Devocionais', 'Visualizar devocionais', 'devotionals', 'view', false),
('devotionals.create', 'Criar Devocional', 'Criar novos devocionais', 'devotionals', 'create', false),
('devotionals.edit', 'Editar Devocional', 'Editar devocionais', 'devotionals', 'edit', false),
('devotionals.delete', 'Deletar Devocional', 'Remover devocionais', 'devotionals', 'delete', false)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- CATEGORIA: PEDIDOS DE ORAÇÃO
-- =====================================================
INSERT INTO permissions (code, name, description, category, subcategory, requires_context) VALUES
('prayer_requests.view', 'Ver Pedidos de Oração', 'Visualizar pedidos de oração', 'prayer_requests', 'view', false),
('prayer_requests.create', 'Criar Pedido de Oração', 'Criar novos pedidos', 'prayer_requests', 'create', false),
('prayer_requests.edit', 'Editar Pedido de Oração', 'Editar pedidos', 'prayer_requests', 'edit', false),
('prayer_requests.delete', 'Deletar Pedido de Oração', 'Remover pedidos', 'prayer_requests', 'delete', false),
('prayer_requests.moderate', 'Moderar Pedidos', 'Aprovar/reprovar pedidos de oração', 'prayer_requests', 'manage', false)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- CATEGORIA: TESTEMUNHOS
-- =====================================================
INSERT INTO permissions (code, name, description, category, subcategory, requires_context) VALUES
('testimonies.view', 'Ver Testemunhos', 'Visualizar testemunhos', 'testimonies', 'view', false),
('testimonies.create', 'Criar Testemunho', 'Criar novos testemunhos', 'testimonies', 'create', false),
('testimonies.edit', 'Editar Testemunho', 'Editar testemunhos', 'testimonies', 'edit', false),
('testimonies.delete', 'Deletar Testemunho', 'Remover testemunhos', 'testimonies', 'delete', false),
('testimonies.moderate', 'Moderar Testemunhos', 'Aprovar/reprovar testemunhos', 'testimonies', 'manage', false)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- CATEGORIA: GRUPOS DE ESTUDO
-- =====================================================
INSERT INTO permissions (code, name, description, category, subcategory, requires_context) VALUES
('study_groups.view', 'Ver Grupos de Estudo', 'Visualizar grupos de estudo', 'study_groups', 'view', false),
('study_groups.create', 'Criar Grupo de Estudo', 'Criar novos grupos de estudo', 'study_groups', 'create', false),
('study_groups.edit', 'Editar Grupo de Estudo', 'Editar grupos de estudo', 'study_groups', 'edit', false),
('study_groups.delete', 'Deletar Grupo de Estudo', 'Remover grupos de estudo', 'study_groups', 'delete', false),
('study_groups.manage_own', 'Gerenciar Próprio Grupo de Estudo', 'Gerenciar apenas grupos atribuídos', 'study_groups', 'manage', true),
('study_groups.manage_lessons', 'Gerenciar Lições', 'Criar e gerenciar lições', 'study_groups', 'manage', false)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- CATEGORIA: CURSOS
-- =====================================================
INSERT INTO permissions (code, name, description, category, subcategory, requires_context) VALUES
('courses.view', 'Ver Cursos', 'Visualizar cursos', 'courses', 'view', false),
('courses.create', 'Criar Curso', 'Criar novos cursos', 'courses', 'create', false),
('courses.edit', 'Editar Curso', 'Editar cursos', 'courses', 'edit', false),
('courses.delete', 'Deletar Curso', 'Remover cursos', 'courses', 'delete', false),
('courses.manage_lessons', 'Gerenciar Aulas', 'Criar e gerenciar aulas de cursos', 'courses', 'manage', false),
('courses.view_progress', 'Ver Progresso de Alunos', 'Visualizar progresso dos alunos', 'courses', 'view', false)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- CATEGORIA: MATERIAIS DE APOIO
-- =====================================================
INSERT INTO permissions (code, name, description, category, subcategory, requires_context) VALUES
('support_materials.view', 'Ver Materiais de Apoio', 'Visualizar materiais', 'support_materials', 'view', false),
('support_materials.create', 'Criar Material', 'Criar novos materiais', 'support_materials', 'create', false),
('support_materials.edit', 'Editar Material', 'Editar materiais', 'support_materials', 'edit', false),
('support_materials.delete', 'Deletar Material', 'Remover materiais', 'support_materials', 'delete', false),
('support_materials.manage_modules', 'Gerenciar Módulos', 'Criar e gerenciar módulos de materiais', 'support_materials', 'manage', false)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- CATEGORIA: BANNERS
-- =====================================================
INSERT INTO permissions (code, name, description, category, subcategory, requires_context) VALUES
('banners.view', 'Ver Banners', 'Visualizar banners', 'banners', 'view', false),
('banners.create', 'Criar Banner', 'Criar novos banners', 'banners', 'create', false),
('banners.edit', 'Editar Banner', 'Editar banners', 'banners', 'edit', false),
('banners.delete', 'Deletar Banner', 'Remover banners', 'banners', 'delete', false)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- CATEGORIA: NOTÍCIAS
-- =====================================================
INSERT INTO permissions (code, name, description, category, subcategory, requires_context) VALUES
('news.view', 'Ver Notícias', 'Visualizar notícias', 'news', 'view', false),
('news.create', 'Criar Notícia', 'Criar novas notícias', 'news', 'create', false),
('news.edit', 'Editar Notícia', 'Editar notícias', 'news', 'edit', false),
('news.delete', 'Deletar Notícia', 'Remover notícias', 'news', 'delete', false)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- CATEGORIA: INFORMAÇÕES DA IGREJA
-- =====================================================
INSERT INTO permissions (code, name, description, category, subcategory, requires_context) VALUES
('church_info.view', 'Ver Informações da Igreja', 'Visualizar informações', 'church_info', 'view', false),
('church_info.edit', 'Editar Informações da Igreja', 'Editar informações da igreja', 'church_info', 'edit', false)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- CATEGORIA: CONFIGURAÇÕES
-- =====================================================
INSERT INTO permissions (code, name, description, category, subcategory, requires_context) VALUES
('settings.view', 'Ver Configurações', 'Acessar configurações', 'settings', 'view', false),
('settings.edit', 'Editar Configurações', 'Modificar configurações', 'settings', 'edit', false),
('settings.manage_users', 'Gerenciar Usuários', 'Gerenciar usuários do sistema', 'settings', 'manage', false),
('settings.manage_permissions', 'Gerenciar Permissões', 'Gerenciar permissões e atribuições', 'settings', 'manage', false),
('settings.manage_roles', 'Gerenciar Cargos', 'Criar e editar cargos', 'settings', 'manage', false),
('settings.manage_access_levels', 'Gerenciar Níveis de Acesso', 'Promover/rebaixar usuários', 'settings', 'manage', false),
('settings.view_audit_log', 'Ver Log de Auditoria', 'Visualizar histórico de mudanças', 'settings', 'view', false)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- CATEGORIA: DASHBOARD
-- =====================================================
INSERT INTO permissions (code, name, description, category, subcategory, requires_context) VALUES
('dashboard.access', 'Acessar Dashboard', 'Acessar área administrativa', 'dashboard', 'access', false),
('dashboard.configure', 'Configurar Dashboard', 'Configurar widgets do dashboard', 'dashboard', 'manage', false)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- CATEGORIA: TAGS
-- =====================================================
INSERT INTO permissions (code, name, description, category, subcategory, requires_context) VALUES
('tags.view', 'Ver Tags', 'Visualizar tags', 'tags', 'view', false),
('tags.create', 'Criar Tag', 'Criar novas tags', 'tags', 'create', false),
('tags.edit', 'Editar Tag', 'Editar tags', 'tags', 'edit', false),
('tags.delete', 'Deletar Tag', 'Remover tags', 'tags', 'delete', false)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- MENSAGEM DE SUCESSO
-- =====================================================
DO $$
BEGIN
  RAISE NOTICE '✅ Seed de permissões concluído com sucesso!';
  RAISE NOTICE 'Total de permissões cadastradas: %', (SELECT COUNT(*) FROM permissions);
END $$;

