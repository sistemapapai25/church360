CREATE TABLE IF NOT EXISTS public.dashboard_widget (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT public.current_tenant_id() REFERENCES public.tenant(id) ON DELETE CASCADE,
  widget_key text NOT NULL,
  widget_name text NOT NULL,
  description text,
  category text NOT NULL,
  icon_name text,
  is_enabled boolean NOT NULL DEFAULT true,
  display_order integer NOT NULL DEFAULT 0,
  is_default boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT dashboard_widget_key_not_empty CHECK (length(trim(widget_key)) > 0),
  CONSTRAINT dashboard_widget_name_not_empty CHECK (length(trim(widget_name)) > 0),
  CONSTRAINT dashboard_widget_unique_key UNIQUE (tenant_id, widget_key)
);

CREATE INDEX IF NOT EXISTS idx_dashboard_widget_tenant_id ON public.dashboard_widget(tenant_id);
CREATE INDEX IF NOT EXISTS idx_dashboard_widget_is_enabled ON public.dashboard_widget(is_enabled);
CREATE INDEX IF NOT EXISTS idx_dashboard_widget_display_order ON public.dashboard_widget(display_order);
CREATE INDEX IF NOT EXISTS idx_dashboard_widget_category ON public.dashboard_widget(category);

ALTER TABLE public.dashboard_widget ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS dashboard_widget_select_all ON public.dashboard_widget;
CREATE POLICY dashboard_widget_select_all
  ON public.dashboard_widget
  FOR SELECT
  USING (tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS dashboard_widget_insert_admin ON public.dashboard_widget;
CREATE POLICY dashboard_widget_insert_admin
  ON public.dashboard_widget
  FOR INSERT
  WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND EXISTS (
      SELECT 1 FROM public.user_account
      WHERE user_account.id = auth.uid()
      AND user_account.role_global IN ('admin', 'owner', 'leader')
    )
  );

DROP POLICY IF EXISTS dashboard_widget_update_admin ON public.dashboard_widget;
CREATE POLICY dashboard_widget_update_admin
  ON public.dashboard_widget
  FOR UPDATE
  USING (
    tenant_id = public.current_tenant_id()
    AND EXISTS (
      SELECT 1 FROM public.user_account
      WHERE user_account.id = auth.uid()
      AND user_account.role_global IN ('admin', 'owner', 'leader')
    )
  )
  WITH CHECK (tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS dashboard_widget_delete_admin ON public.dashboard_widget;
CREATE POLICY dashboard_widget_delete_admin
  ON public.dashboard_widget
  FOR DELETE
  USING (
    tenant_id = public.current_tenant_id()
    AND is_default = false
    AND EXISTS (
      SELECT 1 FROM public.user_account
      WHERE user_account.id = auth.uid()
      AND user_account.role_global IN ('admin', 'owner', 'leader')
    )
  );

DROP TRIGGER IF EXISTS trigger_dashboard_widget_updated_at ON public.dashboard_widget;
CREATE TRIGGER trigger_dashboard_widget_updated_at
  BEFORE UPDATE ON public.dashboard_widget
  FOR EACH ROW
  EXECUTE FUNCTION public.update_dashboard_widget_updated_at();

INSERT INTO public.dashboard_widget (
  tenant_id,
  widget_key,
  widget_name,
  description,
  category,
  icon_name,
  is_enabled,
  display_order,
  is_default
)
SELECT
  t.id,
  w.widget_key,
  w.widget_name,
  w.description,
  w.category,
  w.icon_name,
  w.is_enabled,
  w.display_order,
  w.is_default
FROM public.tenant t
CROSS JOIN (
  VALUES
    ('birthdays_month', 'Aniversariantes do Mes', 'Lista dos proximos aniversariantes', 'members', 'cake', true, 1, true),
    ('recent_members', 'Novos Membros', 'Membros cadastrados nos ultimos 30 dias', 'members', 'person_add', true, 2, true),
    ('member_growth', 'Crescimento de Membros', 'Grafico de crescimento nos ultimos 6 meses', 'members', 'trending_up', true, 5, true),
    ('top_tags', 'Tags Mais Usadas', 'Top 5 tags mais utilizadas', 'members', 'label', true, 9, true),
    ('upcoming_events', 'Proximos Eventos', 'Eventos dos proximos 7 dias', 'events', 'event', true, 3, true),
    ('events_stats', 'Estatisticas de Eventos', 'Proximos, ativos e finalizados', 'events', 'calendar_today', true, 6, true),
    ('top_active_groups', 'Grupos Mais Ativos', 'Top 5 grupos com mais reunioes', 'groups', 'groups', true, 7, true),
    ('average_attendance', 'Frequencia nas Reunioes', 'Media de presenca nos ultimos 3 meses', 'attendance', 'people', true, 8, true),
    ('upcoming_expenses', 'Proximas Contas a Pagar', 'Despesas dos proximos 30 dias', 'financial', 'payments', true, 4, true),
    ('financial_summary', 'Resumo Financeiro', 'Total de contribuicoes vs despesas', 'financial', 'account_balance', true, 10, true),
    ('contributions_by_type', 'Contribuicoes por Tipo', 'Grafico de pizza das contribuicoes', 'financial', 'pie_chart', true, 11, true),
    ('financial_goals', 'Metas Financeiras', 'Progresso das metas ativas', 'financial', 'flag', true, 12, true)
) AS w(widget_key, widget_name, description, category, icon_name, is_enabled, display_order, is_default)
ON CONFLICT (tenant_id, widget_key) DO NOTHING;
