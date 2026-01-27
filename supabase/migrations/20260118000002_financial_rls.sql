-- Financial RLS policies

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS financial_categories_all ON public.categories;
CREATE POLICY financial_categories_all ON public.categories
  FOR ALL TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  )
  WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  );

ALTER TABLE public.beneficiaries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS financial_beneficiaries_all ON public.beneficiaries;
CREATE POLICY financial_beneficiaries_all ON public.beneficiaries
  FOR ALL TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  )
  WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  );

ALTER TABLE public.contas_financeiras ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS financial_contas_financeiras_all ON public.contas_financeiras;
CREATE POLICY financial_contas_financeiras_all ON public.contas_financeiras
  FOR ALL TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  )
  WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  );

ALTER TABLE public.lancamentos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS financial_lancamentos_all ON public.lancamentos;
CREATE POLICY financial_lancamentos_all ON public.lancamentos
  FOR ALL TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  )
  WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  );

ALTER TABLE public.movimentos_financeiros ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS financial_movimentos_all ON public.movimentos_financeiros;
CREATE POLICY financial_movimentos_all ON public.movimentos_financeiros
  FOR ALL TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  )
  WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  );

ALTER TABLE public.classification_rules ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS financial_classification_rules_all ON public.classification_rules;
CREATE POLICY financial_classification_rules_all ON public.classification_rules
  FOR ALL TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  )
  WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  );

ALTER TABLE public.auditoria ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS financial_auditoria_all ON public.auditoria;
CREATE POLICY financial_auditoria_all ON public.auditoria
  FOR ALL TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  )
  WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  );

ALTER TABLE public.transferencias ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS financial_transferencias_all ON public.transferencias;
CREATE POLICY financial_transferencias_all ON public.transferencias
  FOR ALL TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  )
  WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  );

ALTER TABLE public.recibos_sequencia ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS financial_recibos_sequencia_all ON public.recibos_sequencia;
CREATE POLICY financial_recibos_sequencia_all ON public.recibos_sequencia
  FOR ALL TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  )
  WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  );

ALTER TABLE public.saldos_mensais ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS financial_saldos_mensais_all ON public.saldos_mensais;
CREATE POLICY financial_saldos_mensais_all ON public.saldos_mensais
  FOR ALL TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  )
  WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  );

ALTER TABLE public.pessoas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS financial_pessoas_all ON public.pessoas;
CREATE POLICY financial_pessoas_all ON public.pessoas
  FOR ALL TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  )
  WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  );

ALTER TABLE public.desafios ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS financial_desafios_all ON public.desafios;
CREATE POLICY financial_desafios_all ON public.desafios
  FOR ALL TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  )
  WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  );

ALTER TABLE public.desafio_participantes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS financial_desafio_participantes_all ON public.desafio_participantes;
CREATE POLICY financial_desafio_participantes_all ON public.desafio_participantes
  FOR ALL TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  )
  WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  );

ALTER TABLE public.desafio_parcelas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS financial_desafio_parcelas_all ON public.desafio_parcelas;
CREATE POLICY financial_desafio_parcelas_all ON public.desafio_parcelas
  FOR ALL TO authenticated
  USING (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  )
  WITH CHECK (
    tenant_id = public.current_tenant_id()
    AND public.can_manage_financial(auth.uid(), tenant_id)
  );

DO $$
BEGIN
  IF to_regclass('public.contribution') IS NOT NULL THEN
    ALTER TABLE public.contribution ENABLE ROW LEVEL SECURITY;
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public' AND tablename = 'contribution'
    ) THEN
      CREATE POLICY financial_contribution_all ON public.contribution
        FOR ALL TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND public.can_manage_financial(auth.uid(), tenant_id)
        )
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND public.can_manage_financial(auth.uid(), tenant_id)
        );
    END IF;
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.financial_goal') IS NOT NULL THEN
    ALTER TABLE public.financial_goal ENABLE ROW LEVEL SECURITY;
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public' AND tablename = 'financial_goal'
    ) THEN
      CREATE POLICY financial_financial_goal_all ON public.financial_goal
        FOR ALL TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND public.can_manage_financial(auth.uid(), tenant_id)
        )
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND public.can_manage_financial(auth.uid(), tenant_id)
        );
    END IF;
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.expense') IS NOT NULL THEN
    ALTER TABLE public.expense ENABLE ROW LEVEL SECURITY;
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public' AND tablename = 'expense'
    ) THEN
      CREATE POLICY financial_expense_all ON public.expense
        FOR ALL TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND public.can_manage_financial(auth.uid(), tenant_id)
        )
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND public.can_manage_financial(auth.uid(), tenant_id)
        );
    END IF;
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.contribution_info') IS NOT NULL THEN
    ALTER TABLE public.contribution_info ENABLE ROW LEVEL SECURITY;
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public' AND tablename = 'contribution_info'
    ) THEN
      CREATE POLICY financial_contribution_info_all ON public.contribution_info
        FOR ALL TO authenticated
        USING (
          tenant_id = public.current_tenant_id()
          AND public.can_manage_financial(auth.uid(), tenant_id)
        )
        WITH CHECK (
          tenant_id = public.current_tenant_id()
          AND public.can_manage_financial(auth.uid(), tenant_id)
        );
    END IF;
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.worship_service') IS NOT NULL THEN
    ALTER TABLE public.worship_service ENABLE ROW LEVEL SECURITY;
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public' AND tablename = 'worship_service'
    ) THEN
      CREATE POLICY tenant_select_worship_service ON public.worship_service
        FOR SELECT USING (tenant_id = public.current_tenant_id());
      CREATE POLICY tenant_modify_worship_service ON public.worship_service
        FOR ALL USING (tenant_id = public.current_tenant_id())
        WITH CHECK (tenant_id = public.current_tenant_id());
    END IF;
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.worship_attendance') IS NOT NULL THEN
    ALTER TABLE public.worship_attendance ENABLE ROW LEVEL SECURITY;
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public' AND tablename = 'worship_attendance'
    ) THEN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'worship_attendance'
          AND column_name = 'tenant_id'
      ) THEN
        CREATE POLICY tenant_select_worship_attendance ON public.worship_attendance
          FOR SELECT USING (tenant_id = public.current_tenant_id());
        CREATE POLICY tenant_modify_worship_attendance ON public.worship_attendance
          FOR ALL USING (tenant_id = public.current_tenant_id())
          WITH CHECK (tenant_id = public.current_tenant_id());
      ELSE
        CREATE POLICY tenant_select_worship_attendance ON public.worship_attendance
          FOR SELECT USING (
            EXISTS (
              SELECT 1 FROM public.worship_service ws
              WHERE ws.id = public.worship_attendance.worship_service_id
                AND ws.tenant_id = public.current_tenant_id()
            )
          );
        CREATE POLICY tenant_modify_worship_attendance ON public.worship_attendance
          FOR ALL USING (
            EXISTS (
              SELECT 1 FROM public.worship_service ws
              WHERE ws.id = public.worship_attendance.worship_service_id
                AND ws.tenant_id = public.current_tenant_id()
            )
          )
          WITH CHECK (
            EXISTS (
              SELECT 1 FROM public.worship_service ws
              WHERE ws.id = public.worship_attendance.worship_service_id
                AND ws.tenant_id = public.current_tenant_id()
            )
          );
      END IF;
    END IF;
  END IF;
END $$;
