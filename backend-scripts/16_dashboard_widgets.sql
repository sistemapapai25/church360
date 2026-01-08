-- =====================================================
-- CHURCH 360 - SISTEMA DE CONFIGURAÇÃO DA DASHBOARD
-- =====================================================
-- Descrição: Permite configurar quais widgets aparecem na Dashboard
-- Features: Ativar/desativar widgets, reordenar, restaurar padrão
-- =====================================================

-- =====================================================
-- 1. TABELA: dashboard_widget
-- =====================================================

CREATE TABLE IF NOT EXISTS dashboard_widget (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Identificador único do widget (usado no código)
  widget_key TEXT NOT NULL UNIQUE,
  
  -- Nome amigável do widget
  widget_name TEXT NOT NULL,
  
  -- Descrição do widget
  description TEXT,
  
  -- Categoria do widget
  category TEXT NOT NULL, -- 'members', 'events', 'groups', 'financial', 'attendance'
  
  -- Ícone (nome do ícone do Material Icons)
  icon_name TEXT,
  
  -- Status
  is_enabled BOOLEAN NOT NULL DEFAULT true,
  
  -- Ordem de exibição (menor = aparece primeiro)
  display_order INTEGER NOT NULL DEFAULT 0,
  
  -- Se é um widget padrão (não pode ser deletado)
  is_default BOOLEAN NOT NULL DEFAULT true,
  
  -- Datas
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT dashboard_widget_key_not_empty CHECK (LENGTH(TRIM(widget_key)) > 0),
  CONSTRAINT dashboard_widget_name_not_empty CHECK (LENGTH(TRIM(widget_name)) > 0)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_dashboard_widget_is_enabled ON dashboard_widget(is_enabled);
CREATE INDEX IF NOT EXISTS idx_dashboard_widget_display_order ON dashboard_widget(display_order);
CREATE INDEX IF NOT EXISTS idx_dashboard_widget_category ON dashboard_widget(category);

-- =====================================================
-- 2. RLS (ROW LEVEL SECURITY)
-- =====================================================

-- Habilitar RLS
ALTER TABLE dashboard_widget ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "dashboard_widget_select_all" ON dashboard_widget;
-- Policy: Todos podem visualizar widgets
CREATE POLICY "dashboard_widget_select_all" ON dashboard_widget
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "dashboard_widget_insert_admin" ON dashboard_widget;
-- Policy: Apenas admins podem inserir
CREATE POLICY "dashboard_widget_insert_admin" ON dashboard_widget
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_account
      WHERE user_account.id = auth.uid()
      AND user_account.role_global IN ('admin', 'owner', 'leader')
    )
  );

DROP POLICY IF EXISTS "dashboard_widget_update_admin" ON dashboard_widget;
-- Policy: Apenas admins podem atualizar
CREATE POLICY "dashboard_widget_update_admin" ON dashboard_widget
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_account
      WHERE user_account.id = auth.uid()
      AND user_account.role_global IN ('admin', 'owner', 'leader')
    )
  );

DROP POLICY IF EXISTS "dashboard_widget_delete_admin" ON dashboard_widget;
-- Policy: Apenas admins podem deletar widgets não-padrão
CREATE POLICY "dashboard_widget_delete_admin" ON dashboard_widget
  FOR DELETE
  USING (
    is_default = false
    AND EXISTS (
      SELECT 1 FROM user_account
      WHERE user_account.id = auth.uid()
      AND user_account.role_global IN ('admin', 'owner', 'leader')
    )
  );

-- =====================================================
-- 3. TRIGGER: updated_at
-- =====================================================

CREATE OR REPLACE FUNCTION update_dashboard_widget_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_dashboard_widget_updated_at ON dashboard_widget;
CREATE TRIGGER trigger_dashboard_widget_updated_at
  BEFORE UPDATE ON dashboard_widget
  FOR EACH ROW
  EXECUTE FUNCTION update_dashboard_widget_updated_at();

-- =====================================================
-- 4. DADOS INICIAIS (WIDGETS PADRÃO)
-- =====================================================

INSERT INTO dashboard_widget (widget_key, widget_name, description, category, icon_name, is_enabled, display_order, is_default) VALUES
  -- Widgets de Membros
  ('birthdays_month', 'Aniversariantes do Mês', 'Lista dos próximos aniversariantes', 'members', 'cake', true, 1, true),
  ('recent_members', 'Novos Membros', 'Membros cadastrados nos últimos 30 dias', 'members', 'person_add', true, 2, true),
  ('member_growth', 'Crescimento de Membros', 'Gráfico de crescimento nos últimos 6 meses', 'members', 'trending_up', true, 5, true),
  ('top_tags', 'Tags Mais Usadas', 'Top 5 tags mais utilizadas', 'members', 'label', true, 9, true),
  
  -- Widgets de Eventos
  ('upcoming_events', 'Próximos Eventos', 'Eventos dos próximos 7 dias', 'events', 'event', true, 3, true),
  ('events_stats', 'Estatísticas de Eventos', 'Próximos, ativos e finalizados', 'events', 'calendar_today', true, 6, true),
  
  -- Widgets de Grupos
  ('top_active_groups', 'Grupos Mais Ativos', 'Top 5 grupos com mais reuniões', 'groups', 'groups', true, 7, true),
  
  -- Widgets de Presença
  ('average_attendance', 'Frequência nas Reuniões', 'Média de presença nos últimos 3 meses', 'attendance', 'people', true, 8, true),
  
  -- Widgets Financeiros
  ('upcoming_expenses', 'Próximas Contas a Pagar', 'Despesas dos próximos 30 dias', 'financial', 'payments', true, 4, true),
  ('financial_summary', 'Resumo Financeiro', 'Total de contribuições vs despesas', 'financial', 'account_balance', true, 10, true),
  ('contributions_by_type', 'Contribuições por Tipo', 'Gráfico de pizza das contribuições', 'financial', 'pie_chart', true, 11, true),
  ('financial_goals', 'Metas Financeiras', 'Progresso das metas ativas', 'financial', 'flag', true, 12, true)
ON CONFLICT (widget_key) DO NOTHING;

-- =====================================================
-- 5. FUNÇÃO: Restaurar Configuração Padrão
-- =====================================================

CREATE OR REPLACE FUNCTION restore_default_dashboard_widgets()
RETURNS void AS $$
BEGIN
  -- Reativar todos os widgets padrão
  UPDATE dashboard_widget
  SET is_enabled = true
  WHERE is_default = true;
  
  -- Restaurar ordem padrão
  UPDATE dashboard_widget SET display_order = 1 WHERE widget_key = 'birthdays_month';
  UPDATE dashboard_widget SET display_order = 2 WHERE widget_key = 'recent_members';
  UPDATE dashboard_widget SET display_order = 3 WHERE widget_key = 'upcoming_events';
  UPDATE dashboard_widget SET display_order = 4 WHERE widget_key = 'upcoming_expenses';
  UPDATE dashboard_widget SET display_order = 5 WHERE widget_key = 'member_growth';
  UPDATE dashboard_widget SET display_order = 6 WHERE widget_key = 'events_stats';
  UPDATE dashboard_widget SET display_order = 7 WHERE widget_key = 'top_active_groups';
  UPDATE dashboard_widget SET display_order = 8 WHERE widget_key = 'average_attendance';
  UPDATE dashboard_widget SET display_order = 9 WHERE widget_key = 'top_tags';
  UPDATE dashboard_widget SET display_order = 10 WHERE widget_key = 'financial_summary';
  UPDATE dashboard_widget SET display_order = 11 WHERE widget_key = 'contributions_by_type';
  UPDATE dashboard_widget SET display_order = 12 WHERE widget_key = 'financial_goals';
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FIM DO SCRIPT
-- =====================================================
