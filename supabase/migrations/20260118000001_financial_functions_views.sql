-- Financial functions, triggers, and views

DO $$
BEGIN
  CREATE TYPE public.contribution_type AS ENUM (
    'tithe',
    'offering',
    'missions',
    'building',
    'special',
    'other'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE public.payment_method AS ENUM (
    'cash',
    'debit',
    'credit',
    'pix',
    'transfer',
    'check',
    'other'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  IF to_regclass('public.contribution') IS NULL THEN
    CREATE TABLE public.contribution (
      id uuid primary key default gen_random_uuid(),
      user_id uuid references public.user_account(id) on delete set null,
      type public.contribution_type not null default 'offering',
      amount numeric(10, 2) not null check (amount > 0),
      payment_method public.payment_method not null default 'cash',
      date date not null default current_date,
      description text,
      notes text,
      created_at timestamptz default now(),
      created_by uuid references public.user_account(id) on delete set null,
      tenant_id uuid not null default public.current_tenant_id() references public.tenant(id) on delete cascade
    );
  END IF;

  IF to_regclass('public.contribution') IS NOT NULL THEN
    ALTER TABLE public.contribution
      ADD COLUMN IF NOT EXISTS user_id uuid references public.user_account(id) on delete set null,
      ADD COLUMN IF NOT EXISTS type public.contribution_type,
      ADD COLUMN IF NOT EXISTS amount numeric(10, 2),
      ADD COLUMN IF NOT EXISTS payment_method public.payment_method,
      ADD COLUMN IF NOT EXISTS date date,
      ADD COLUMN IF NOT EXISTS description text,
      ADD COLUMN IF NOT EXISTS notes text,
      ADD COLUMN IF NOT EXISTS created_at timestamptz,
      ADD COLUMN IF NOT EXISTS created_by uuid references public.user_account(id) on delete set null,
      ADD COLUMN IF NOT EXISTS tenant_id uuid references public.tenant(id) on delete cascade;
    ALTER TABLE public.contribution
      ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.financial_goal') IS NULL THEN
    CREATE TABLE public.financial_goal (
      id uuid primary key default gen_random_uuid(),
      name varchar(200) not null,
      description text,
      target_amount numeric(10, 2) not null check (target_amount > 0),
      current_amount numeric(10, 2) not null default 0 check (current_amount >= 0),
      start_date date not null,
      end_date date not null,
      is_active boolean default true,
      created_at timestamptz default now(),
      updated_at timestamptz default now(),
      created_by uuid references public.user_account(id) on delete set null,
      tenant_id uuid not null default public.current_tenant_id() references public.tenant(id) on delete cascade,
      constraint financial_goal_valid_date_range check (end_date >= start_date)
    );
  END IF;

  IF to_regclass('public.financial_goal') IS NOT NULL THEN
    ALTER TABLE public.financial_goal
      ADD COLUMN IF NOT EXISTS name varchar(200),
      ADD COLUMN IF NOT EXISTS description text,
      ADD COLUMN IF NOT EXISTS target_amount numeric(10, 2),
      ADD COLUMN IF NOT EXISTS current_amount numeric(10, 2),
      ADD COLUMN IF NOT EXISTS start_date date,
      ADD COLUMN IF NOT EXISTS end_date date,
      ADD COLUMN IF NOT EXISTS is_active boolean,
      ADD COLUMN IF NOT EXISTS created_at timestamptz,
      ADD COLUMN IF NOT EXISTS updated_at timestamptz,
      ADD COLUMN IF NOT EXISTS created_by uuid references public.user_account(id) on delete set null,
      ADD COLUMN IF NOT EXISTS tenant_id uuid references public.tenant(id) on delete cascade;
    ALTER TABLE public.financial_goal
      ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.expense') IS NULL THEN
    CREATE TABLE public.expense (
      id uuid primary key default gen_random_uuid(),
      category varchar(100) not null,
      amount numeric(10, 2) not null check (amount > 0),
      payment_method public.payment_method not null default 'cash',
      date date not null default current_date,
      description text not null,
      notes text,
      created_at timestamptz default now(),
      created_by uuid references public.user_account(id) on delete set null,
      tenant_id uuid not null default public.current_tenant_id() references public.tenant(id) on delete cascade
    );
  END IF;

  IF to_regclass('public.expense') IS NOT NULL THEN
    ALTER TABLE public.expense
      ADD COLUMN IF NOT EXISTS category varchar(100),
      ADD COLUMN IF NOT EXISTS amount numeric(10, 2),
      ADD COLUMN IF NOT EXISTS payment_method public.payment_method,
      ADD COLUMN IF NOT EXISTS date date,
      ADD COLUMN IF NOT EXISTS description text,
      ADD COLUMN IF NOT EXISTS notes text,
      ADD COLUMN IF NOT EXISTS created_at timestamptz,
      ADD COLUMN IF NOT EXISTS created_by uuid references public.user_account(id) on delete set null,
      ADD COLUMN IF NOT EXISTS tenant_id uuid references public.tenant(id) on delete cascade;
    ALTER TABLE public.expense
      ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.contribution_info') IS NULL THEN
    CREATE TABLE public.contribution_info (
      id uuid primary key default gen_random_uuid(),
      church_name text not null,
      pix_key text,
      pix_type text,
      bank_name text,
      bank_code text,
      agency text,
      account_number text,
      account_type text,
      account_holder text,
      account_holder_document text,
      instructions text,
      is_active boolean not null default true,
      created_at timestamptz not null default now(),
      updated_at timestamptz not null default now(),
      created_by uuid references public.user_account(id) on delete set null,
      tenant_id uuid not null default public.current_tenant_id() references public.tenant(id) on delete cascade
    );
  END IF;

  IF to_regclass('public.contribution_info') IS NOT NULL THEN
    ALTER TABLE public.contribution_info
      ADD COLUMN IF NOT EXISTS church_name text,
      ADD COLUMN IF NOT EXISTS pix_key text,
      ADD COLUMN IF NOT EXISTS pix_type text,
      ADD COLUMN IF NOT EXISTS bank_name text,
      ADD COLUMN IF NOT EXISTS bank_code text,
      ADD COLUMN IF NOT EXISTS agency text,
      ADD COLUMN IF NOT EXISTS account_number text,
      ADD COLUMN IF NOT EXISTS account_type text,
      ADD COLUMN IF NOT EXISTS account_holder text,
      ADD COLUMN IF NOT EXISTS account_holder_document text,
      ADD COLUMN IF NOT EXISTS instructions text,
      ADD COLUMN IF NOT EXISTS is_active boolean,
      ADD COLUMN IF NOT EXISTS created_at timestamptz,
      ADD COLUMN IF NOT EXISTS updated_at timestamptz,
      ADD COLUMN IF NOT EXISTS created_by uuid references public.user_account(id) on delete set null,
      ADD COLUMN IF NOT EXISTS tenant_id uuid references public.tenant(id) on delete cascade;
    ALTER TABLE public.contribution_info
      ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
  END IF;
END $$;

DO $$
BEGIN
  CREATE TYPE public.worship_type AS ENUM (
    'sunday_morning',
    'sunday_evening',
    'wednesday',
    'friday',
    'special',
    'other'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  IF to_regclass('public.worship_service') IS NULL THEN
    CREATE TABLE public.worship_service (
      id uuid primary key default gen_random_uuid(),
      service_date date not null,
      service_time time,
      service_type public.worship_type default 'sunday_morning',
      theme text,
      speaker text,
      total_attendance integer not null default 0,
      notes text,
      created_at timestamptz not null default now(),
      updated_at timestamptz not null default now(),
      created_by uuid references public.user_account(id) on delete set null,
      tenant_id uuid not null default public.current_tenant_id() references public.tenant(id) on delete cascade,
      date date generated always as (service_date) stored,
      attendance_count integer generated always as (total_attendance) stored
    );
  END IF;

  IF to_regclass('public.worship_service') IS NOT NULL THEN
    ALTER TABLE public.worship_service
      ADD COLUMN IF NOT EXISTS service_date date,
      ADD COLUMN IF NOT EXISTS service_time time,
      ADD COLUMN IF NOT EXISTS service_type public.worship_type,
      ADD COLUMN IF NOT EXISTS theme text,
      ADD COLUMN IF NOT EXISTS speaker text,
      ADD COLUMN IF NOT EXISTS total_attendance integer,
      ADD COLUMN IF NOT EXISTS notes text,
      ADD COLUMN IF NOT EXISTS created_at timestamptz,
      ADD COLUMN IF NOT EXISTS updated_at timestamptz,
      ADD COLUMN IF NOT EXISTS created_by uuid references public.user_account(id) on delete set null,
      ADD COLUMN IF NOT EXISTS tenant_id uuid references public.tenant(id) on delete cascade;
    ALTER TABLE public.worship_service
      ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.worship_service') IS NOT NULL THEN
    ALTER TABLE public.worship_service
      ADD COLUMN IF NOT EXISTS date date generated always as (service_date) stored,
      ADD COLUMN IF NOT EXISTS attendance_count integer generated always as (total_attendance) stored;
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.worship_attendance') IS NULL THEN
    CREATE TABLE public.worship_attendance (
      id uuid primary key default gen_random_uuid(),
      worship_service_id uuid references public.worship_service(id) on delete cascade,
      user_id uuid references public.user_account(id) on delete cascade,
      checked_in_at timestamptz not null default now(),
      notes text,
      created_at timestamptz not null default now(),
      tenant_id uuid not null default public.current_tenant_id() references public.tenant(id) on delete cascade,
      constraint worship_attendance_unique unique (worship_service_id, user_id)
    );
  END IF;

  IF to_regclass('public.worship_attendance') IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'worship_attendance'
        AND column_name = 'member_id'
    ) AND NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'worship_attendance'
        AND column_name = 'user_id'
    ) THEN
      ALTER TABLE public.worship_attendance RENAME COLUMN member_id TO user_id;
    END IF;

    ALTER TABLE public.worship_attendance
      ADD COLUMN IF NOT EXISTS worship_service_id uuid references public.worship_service(id) on delete cascade,
      ADD COLUMN IF NOT EXISTS user_id uuid,
      ADD COLUMN IF NOT EXISTS checked_in_at timestamptz,
      ADD COLUMN IF NOT EXISTS notes text,
      ADD COLUMN IF NOT EXISTS created_at timestamptz,
      ADD COLUMN IF NOT EXISTS tenant_id uuid references public.tenant(id) on delete cascade;
    ALTER TABLE public.worship_attendance
      ALTER COLUMN tenant_id SET DEFAULT public.current_tenant_id();

    ALTER TABLE public.worship_attendance
      DROP CONSTRAINT IF EXISTS worship_attendance_member_id_fkey,
      DROP CONSTRAINT IF EXISTS worship_attendance_user_id_fkey;
    ALTER TABLE public.worship_attendance
      ADD CONSTRAINT worship_attendance_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES public.user_account(id) on delete cascade;

    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint
      WHERE conname = 'worship_attendance_unique'
        AND conrelid = 'public.worship_attendance'::regclass
    ) THEN
      ALTER TABLE public.worship_attendance
        ADD CONSTRAINT worship_attendance_unique UNIQUE (worship_service_id, user_id);
    END IF;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_contribution_tenant_id ON public.contribution(tenant_id);
CREATE INDEX IF NOT EXISTS idx_contribution_user_id ON public.contribution(user_id);
CREATE INDEX IF NOT EXISTS idx_contribution_date ON public.contribution(date);
CREATE INDEX IF NOT EXISTS idx_financial_goal_tenant_id ON public.financial_goal(tenant_id);
CREATE INDEX IF NOT EXISTS idx_expense_tenant_id ON public.expense(tenant_id);
CREATE INDEX IF NOT EXISTS idx_expense_date ON public.expense(date);
CREATE INDEX IF NOT EXISTS idx_contribution_info_tenant_id ON public.contribution_info(tenant_id);
CREATE INDEX IF NOT EXISTS idx_worship_service_date ON public.worship_service(service_date DESC);
CREATE INDEX IF NOT EXISTS idx_worship_service_type ON public.worship_service(service_type);
CREATE INDEX IF NOT EXISTS idx_worship_service_tenant_id ON public.worship_service(tenant_id);
CREATE INDEX IF NOT EXISTS idx_worship_attendance_service_id ON public.worship_attendance(worship_service_id);
CREATE INDEX IF NOT EXISTS idx_worship_attendance_user_id ON public.worship_attendance(user_id);
CREATE INDEX IF NOT EXISTS idx_worship_attendance_tenant_id ON public.worship_attendance(tenant_id);

DROP TRIGGER IF EXISTS update_contribution_info_updated_at ON public.contribution_info;
CREATE TRIGGER update_contribution_info_updated_at
  BEFORE UPDATE ON public.contribution_info
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_worship_service_updated_at ON public.worship_service;
CREATE TRIGGER update_worship_service_updated_at
  BEFORE UPDATE ON public.worship_service
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE OR REPLACE FUNCTION public.update_worship_attendance_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.worship_service
    SET total_attendance = (
      SELECT COUNT(*) FROM public.worship_attendance
      WHERE worship_service_id = NEW.worship_service_id
    )
    WHERE id = NEW.worship_service_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.worship_service
    SET total_attendance = (
      SELECT COUNT(*) FROM public.worship_attendance
      WHERE worship_service_id = OLD.worship_service_id
    )
    WHERE id = OLD.worship_service_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trigger_update_worship_attendance_count_insert ON public.worship_attendance;
CREATE TRIGGER trigger_update_worship_attendance_count_insert
  AFTER INSERT ON public.worship_attendance
  FOR EACH ROW
  EXECUTE FUNCTION public.update_worship_attendance_count();

DROP TRIGGER IF EXISTS trigger_update_worship_attendance_count_delete ON public.worship_attendance;
CREATE TRIGGER trigger_update_worship_attendance_count_delete
  AFTER DELETE ON public.worship_attendance
  FOR EACH ROW
  EXECUTE FUNCTION public.update_worship_attendance_count();

ALTER TABLE public.contribution
  ADD COLUMN IF NOT EXISTS worship_service_id uuid references public.worship_service(id) on delete set null;

CREATE INDEX IF NOT EXISTS idx_contribution_tenant_worship_service
  ON public.contribution(tenant_id, worship_service_id);

CREATE OR REPLACE FUNCTION public.log_lancamento_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_action public.acao_auditoria;
  v_user uuid;
  v_tenant uuid;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_action := 'CREATE';
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
      v_action := 'STATUS_CHANGE';
    ELSE
      v_action := 'UPDATE';
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    v_action := 'DELETE';
  END IF;

  v_user := COALESCE(auth.uid(), NEW.created_by, OLD.created_by);
  v_tenant := COALESCE(NEW.tenant_id, OLD.tenant_id, public.current_tenant_id());

  IF TG_OP = 'DELETE' THEN
    INSERT INTO public.auditoria (entidade, entidade_id, acao, antes, user_id, tenant_id)
    VALUES ('lancamentos', OLD.id, v_action, to_jsonb(OLD), v_user, v_tenant);
    RETURN OLD;
  ELSE
    INSERT INTO public.auditoria (entidade, entidade_id, acao, antes, depois, user_id, tenant_id)
    VALUES (
      'lancamentos',
      NEW.id,
      v_action,
      CASE WHEN TG_OP = 'UPDATE' THEN to_jsonb(OLD) ELSE NULL END,
      to_jsonb(NEW),
      v_user,
      v_tenant
    );
    RETURN NEW;
  END IF;
END;
$$;

DROP TRIGGER IF EXISTS update_lancamentos_updated_at ON public.lancamentos;
CREATE TRIGGER update_lancamentos_updated_at
  BEFORE UPDATE ON public.lancamentos
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS lancamentos_audit_trigger ON public.lancamentos;
CREATE TRIGGER lancamentos_audit_trigger
  AFTER INSERT OR UPDATE OR DELETE ON public.lancamentos
  FOR EACH ROW EXECUTE FUNCTION public.log_lancamento_changes();

CREATE OR REPLACE FUNCTION public.gerar_carne_para_participante(_participante_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_desafio public.desafios%rowtype;
  v_part public.desafio_participantes%rowtype;
  v_i int;
  v_comp date;
  v_venc date;
  v_last_day int;
  v_valor numeric(12, 2);
  v_tenant uuid;
  v_user uuid;
BEGIN
  SELECT * INTO v_part FROM public.desafio_participantes WHERE id = _participante_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'participante nao encontrado: %', _participante_id;
  END IF;

  SELECT * INTO v_desafio FROM public.desafios WHERE id = v_part.desafio_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'desafio nao encontrado: %', v_part.desafio_id;
  END IF;

  v_valor := COALESCE(v_part.valor_personalizado, v_desafio.valor_mensal);
  v_tenant := COALESCE(v_part.tenant_id, v_desafio.tenant_id, public.current_tenant_id());
  v_user := COALESCE(auth.uid(), v_part.created_by);

  FOR v_i IN 0..(v_desafio.qtd_parcelas - 1) LOOP
    v_comp := (date_trunc('month', v_desafio.data_inicio)::date + make_interval(months => v_i))::date;
    v_last_day := extract(day from (date_trunc('month', v_comp)::date + interval '1 month - 1 day'))::int;
    v_venc := make_date(
      extract(year from v_comp)::int,
      extract(month from v_comp)::int,
      least(v_desafio.dia_vencimento, v_last_day)
    );

    INSERT INTO public.desafio_parcelas (
      participante_id,
      competencia,
      vencimento,
      valor,
      status,
      tenant_id,
      created_by
    )
    VALUES (_participante_id, v_comp, v_venc, v_valor, 'ABERTO', v_tenant, v_user)
    ON CONFLICT (participante_id, competencia) DO NOTHING;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_gerar_carne_participante()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.gerar_carne_para_participante(NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_desafio_participante_created ON public.desafio_participantes;
CREATE TRIGGER on_desafio_participante_created
  AFTER INSERT ON public.desafio_participantes
  FOR EACH ROW EXECUTE PROCEDURE public.trg_gerar_carne_participante();

CREATE OR REPLACE FUNCTION public.atualizar_valor_participante(_participante_id uuid, _novo_valor numeric)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant uuid;
BEGIN
  v_tenant := public.current_tenant_id();
  IF auth.uid() IS NULL AND auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF auth.uid() IS NOT NULL AND NOT public.can_manage_financial(auth.uid(), v_tenant) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  UPDATE public.desafio_participantes
  SET valor_personalizado = _novo_valor
  WHERE id = _participante_id;

  UPDATE public.desafio_parcelas
  SET valor = _novo_valor
  WHERE participante_id = _participante_id
    AND status = 'ABERTO';
END;
$$;

CREATE OR REPLACE FUNCTION public.atualizar_valor_parcela(_parcela_id uuid, _novo_valor numeric)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant uuid;
BEGIN
  v_tenant := public.current_tenant_id();
  IF auth.uid() IS NULL AND auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF auth.uid() IS NOT NULL AND NOT public.can_manage_financial(auth.uid(), v_tenant) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  UPDATE public.desafio_parcelas
  SET valor = _novo_valor
  WHERE id = _parcela_id
    AND status = 'ABERTO';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'only open parcelas can be updated';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.atualizar_saldo_conta(conta_id uuid, valor numeric)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant uuid;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    SELECT tenant_id INTO v_tenant FROM public.contas_financeiras WHERE id = conta_id;
  END IF;
  IF v_tenant IS NULL THEN
    RAISE EXCEPTION 'tenant_id not resolved';
  END IF;

  IF auth.uid() IS NULL AND auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF auth.uid() IS NOT NULL AND NOT public.can_manage_financial(auth.uid(), v_tenant) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  INSERT INTO public.movimentos_financeiros (
    conta_id,
    data,
    tipo,
    valor,
    descricao,
    origem,
    tenant_id,
    created_by
  )
  VALUES (
    conta_id,
    CURRENT_DATE,
    'ENTRADA',
    valor,
    'Entrada de culto',
    'CULTO',
    v_tenant,
    auth.uid()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.registrar_transferencia(
  origem uuid,
  destino uuid,
  _data date,
  _descricao text,
  _valor numeric
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant uuid;
  v_id uuid;
  v_desc text;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL THEN
    SELECT tenant_id INTO v_tenant FROM public.contas_financeiras WHERE id = origem;
  END IF;
  IF v_tenant IS NULL THEN
    RAISE EXCEPTION 'tenant_id not resolved';
  END IF;

  IF auth.uid() IS NULL AND auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF auth.uid() IS NOT NULL AND NOT public.can_manage_financial(auth.uid(), v_tenant) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.contas_financeiras cf
    WHERE cf.id = origem AND cf.tenant_id = v_tenant
  ) THEN
    RAISE EXCEPTION 'conta origem invalida';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.contas_financeiras cf
    WHERE cf.id = destino AND cf.tenant_id = v_tenant
  ) THEN
    RAISE EXCEPTION 'conta destino invalida';
  END IF;

  v_desc := COALESCE(_descricao, 'Transferencia');

  INSERT INTO public.transferencias (
    conta_origem_id,
    conta_destino_id,
    data,
    descricao,
    valor,
    tenant_id,
    created_by
  )
  VALUES (origem, destino, _data, v_desc, _valor, v_tenant, auth.uid())
  RETURNING id INTO v_id;

  INSERT INTO public.movimentos_financeiros (
    conta_id,
    data,
    tipo,
    valor,
    descricao,
    origem,
    ref_id,
    tenant_id,
    created_by
  )
  VALUES (origem, _data, 'SAIDA', _valor, v_desc, 'TRANSFERENCIA', v_id, v_tenant, auth.uid());

  INSERT INTO public.movimentos_financeiros (
    conta_id,
    data,
    tipo,
    valor,
    descricao,
    origem,
    ref_id,
    tenant_id,
    created_by
  )
  VALUES (destino, _data, 'ENTRADA', _valor, v_desc, 'TRANSFERENCIA', v_id, v_tenant, auth.uid());

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.ensure_default_categories()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant uuid;
  v_user uuid;
BEGIN
  v_tenant := public.current_tenant_id();
  v_user := auth.uid();

  IF v_tenant IS NULL THEN
    RETURN;
  END IF;

  IF v_user IS NULL AND auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  IF v_user IS NOT NULL AND NOT public.can_manage_financial(v_user, v_tenant) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  INSERT INTO public.categories (tenant_id, created_by, name, tipo, ordem)
  VALUES
    (v_tenant, v_user, 'Dizimos', 'RECEITA', 10),
    (v_tenant, v_user, 'Ofertas', 'RECEITA', 20),
    (v_tenant, v_user, 'Transferencia Interna', 'TRANSFERENCIA', 30)
  ON CONFLICT (tenant_id, name) DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION public.next_recibo_num(_user_id uuid, _ano integer)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant uuid;
  v_next integer;
BEGIN
  v_tenant := public.current_tenant_id();
  IF v_tenant IS NULL AND _user_id IS NOT NULL THEN
    SELECT tenant_id INTO v_tenant
    FROM public.user_account
    WHERE auth_user_id = _user_id
    LIMIT 1;
  END IF;

  IF v_tenant IS NULL THEN
    RAISE EXCEPTION 'tenant_id not resolved';
  END IF;

  IF auth.uid() IS NULL AND auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF auth.uid() IS NOT NULL AND NOT public.can_manage_financial(auth.uid(), v_tenant) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  INSERT INTO public.recibos_sequencia (tenant_id, ano, ultimo_numero, created_by)
  VALUES (v_tenant, _ano, 1, auth.uid())
  ON CONFLICT (tenant_id, ano)
  DO UPDATE SET ultimo_numero = public.recibos_sequencia.ultimo_numero + 1
  RETURNING ultimo_numero INTO v_next;

  RETURN v_next;
END;
$$;

GRANT EXECUTE ON FUNCTION public.gerar_carne_para_participante(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.atualizar_valor_participante(uuid, numeric) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.atualizar_valor_parcela(uuid, numeric) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.atualizar_saldo_conta(uuid, numeric) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.registrar_transferencia(uuid, uuid, date, text, numeric) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.ensure_default_categories() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.next_recibo_num(uuid, integer) TO authenticated, service_role;

CREATE OR REPLACE VIEW public.vw_conciliacao AS
SELECT
  l.id AS lancamento_id,
  l.tipo AS lancamento_tipo,
  l.status AS status,
  l.vencimento AS vencimento,
  l.valor AS valor_previsto,
  m.id AS movimento_id,
  m.tipo AS movimento_tipo,
  m.data AS data_real,
  m.valor AS valor_real,
  l.conta_id AS conta_id,
  l.created_by AS user_id,
  l.descricao AS lancamento_descricao,
  m.descricao AS movimento_descricao
FROM public.lancamentos l
LEFT JOIN public.movimentos_financeiros m
  ON m.ref_id = l.id AND m.origem = 'LANCAMENTO';

CREATE OR REPLACE VIEW public.vw_lancamentos_whatsapp AS
SELECT
  l.id,
  l.beneficiario_id,
  l.descricao,
  l.valor,
  l.status,
  l.vencimento,
  b.name AS nomebenef,
  l.created_by AS user_id
FROM public.lancamentos l
LEFT JOIN public.beneficiaries b ON b.id = l.beneficiario_id;

CREATE OR REPLACE VIEW public.vw_culto_totais AS
SELECT
  ws.id AS culto_id,
  COALESCE(SUM(CASE WHEN c.type = 'tithe' THEN c.amount ELSE 0 END), 0) AS total_dizimos,
  COALESCE(SUM(CASE WHEN c.type = 'offering' THEN c.amount ELSE 0 END), 0) AS total_ofertas
FROM public.worship_service ws
LEFT JOIN public.contribution c ON c.worship_service_id = ws.id
GROUP BY ws.id;
