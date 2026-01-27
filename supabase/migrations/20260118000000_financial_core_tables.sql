-- Financial core types and tables for finance module

DO $$
BEGIN
  CREATE TYPE public.tipo_lancamento AS ENUM ('DESPESA', 'RECEITA');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE public.status_lancamento AS ENUM ('EM_ABERTO', 'PAGO', 'CANCELADO');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE public.forma_pagamento AS ENUM (
    'PIX',
    'DINHEIRO',
    'CARTAO',
    'BOLETO',
    'TRANSFERENCIA',
    'OUTRO'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE public.tipo_categoria AS ENUM ('DESPESA', 'RECEITA', 'TRANSFERENCIA');
EXCEPTION
  WHEN duplicate_object THEN
    BEGIN
      ALTER TYPE public.tipo_categoria ADD VALUE IF NOT EXISTS 'TRANSFERENCIA';
    EXCEPTION
      WHEN OTHERS THEN NULL;
    END;
END $$;

DO $$
BEGIN
  CREATE TYPE public.acao_auditoria AS ENUM ('CREATE', 'UPDATE', 'DELETE', 'STATUS_CHANGE');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  tipo public.tipo_categoria not null default 'DESPESA',
  parent_id uuid references public.categories(id) on delete set null,
  ordem integer not null default 0,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  tenant_id uuid not null default public.current_tenant_id() references public.tenant(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null,
  constraint categories_unique_name unique (tenant_id, name)
);

CREATE TABLE IF NOT EXISTS public.beneficiaries (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  documento text,
  phone text,
  email text,
  observacoes text,
  assinatura_path text,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  tenant_id uuid not null default public.current_tenant_id() references public.tenant(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null,
  constraint beneficiaries_unique_name unique (tenant_id, name)
);

CREATE TABLE IF NOT EXISTS public.contas_financeiras (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  tipo text not null,
  instituicao text,
  agencia text,
  numero text,
  saldo_inicial numeric(12, 2) not null default 0,
  saldo_inicial_em date,
  logo text,
  created_at timestamptz not null default now(),
  tenant_id uuid not null default public.current_tenant_id() references public.tenant(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null
);

CREATE TABLE IF NOT EXISTS public.lancamentos (
  id uuid primary key default gen_random_uuid(),
  tipo public.tipo_lancamento not null,
  beneficiario_id uuid references public.beneficiaries(id) on delete restrict,
  categoria_id uuid references public.categories(id) on delete restrict not null,
  descricao text,
  valor numeric(14, 2) not null check (valor > 0),
  forma_pagamento public.forma_pagamento,
  vencimento date not null,
  status public.status_lancamento default 'EM_ABERTO',
  data_pagamento date,
  valor_pago numeric(14, 2) check (valor_pago > 0 or valor_pago is null),
  observacoes text,
  boleto_url text,
  comprovante_url text,
  recibo_numero integer,
  recibo_ano integer,
  recibo_pdf_path text,
  recibo_gerado_em timestamptz,
  conta_id uuid references public.contas_financeiras(id) on delete set null,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz,
  tenant_id uuid not null default public.current_tenant_id() references public.tenant(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null,
  constraint lancamentos_beneficiario_required check (
    (tipo = 'DESPESA' and beneficiario_id is not null) or tipo = 'RECEITA'
  ),
  constraint lancamentos_pagamento_consistente check (
    (status = 'PAGO' and data_pagamento is not null and valor_pago is not null)
    or (status <> 'PAGO' and data_pagamento is null and valor_pago is null)
  )
);

CREATE TABLE IF NOT EXISTS public.movimentos_financeiros (
  id uuid primary key default gen_random_uuid(),
  conta_id uuid not null references public.contas_financeiras(id) on delete cascade,
  data date not null,
  tipo text not null,
  valor numeric(14, 2) not null,
  descricao text,
  origem text,
  ref_id uuid,
  comprovante_url text,
  categoria_id uuid references public.categories(id) on delete restrict,
  beneficiario_id uuid references public.beneficiaries(id) on delete restrict,
  created_at timestamptz not null default now(),
  tenant_id uuid not null default public.current_tenant_id() references public.tenant(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null
);

CREATE TABLE IF NOT EXISTS public.classification_rules (
  id uuid primary key default gen_random_uuid(),
  term text not null,
  category_id uuid references public.categories(id),
  beneficiary_id uuid references public.beneficiaries(id),
  created_at timestamptz not null default now(),
  tenant_id uuid not null default public.current_tenant_id() references public.tenant(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null
);

CREATE TABLE IF NOT EXISTS public.auditoria (
  id uuid primary key default gen_random_uuid(),
  entidade text not null default 'lancamentos',
  entidade_id uuid not null,
  acao public.acao_auditoria not null,
  antes jsonb,
  depois jsonb,
  motivo text,
  user_id uuid,
  timestamp timestamptz not null default now(),
  tenant_id uuid not null default public.current_tenant_id() references public.tenant(id) on delete cascade
);

CREATE TABLE IF NOT EXISTS public.transferencias (
  id uuid primary key default gen_random_uuid(),
  conta_origem_id uuid not null references public.contas_financeiras(id) on delete restrict,
  conta_destino_id uuid not null references public.contas_financeiras(id) on delete restrict,
  data date not null,
  descricao text,
  valor numeric(14, 2) not null,
  created_at timestamptz default now(),
  tenant_id uuid not null default public.current_tenant_id() references public.tenant(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null
);

CREATE TABLE IF NOT EXISTS public.recibos_sequencia (
  tenant_id uuid not null references public.tenant(id) on delete cascade,
  ano integer not null,
  ultimo_numero integer not null default 0,
  created_by uuid references auth.users(id) on delete set null,
  primary key (tenant_id, ano)
);

CREATE TABLE IF NOT EXISTS public.saldos_mensais (
  id uuid primary key default gen_random_uuid(),
  conta_id uuid not null references public.contas_financeiras(id) on delete cascade,
  mes date not null,
  saldo_inicial numeric(14, 2) not null default 0,
  created_at timestamptz not null default now(),
  tenant_id uuid not null default public.current_tenant_id() references public.tenant(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null,
  constraint saldos_mensais_unique unique (tenant_id, conta_id, mes)
);

CREATE TABLE IF NOT EXISTS public.pessoas (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  nome text not null,
  telefone text,
  email text,
  ativo boolean not null default true,
  auth_user_id uuid references auth.users(id) on delete set null,
  tenant_id uuid not null default public.current_tenant_id() references public.tenant(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null
);

CREATE TABLE IF NOT EXISTS public.desafios (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  titulo text not null,
  descricao text,
  valor_mensal numeric(12, 2) not null default 50,
  qtd_parcelas int not null default 12,
  data_inicio date not null,
  dia_vencimento int not null default 10,
  ativo boolean not null default true,
  lembrete_dias_antes integer[] not null default array[0, 1],
  tenant_id uuid not null default public.current_tenant_id() references public.tenant(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null,
  constraint desafios_dia_vencimento_check check (dia_vencimento >= 1 and dia_vencimento <= 31),
  constraint desafios_qtd_parcelas_check check (qtd_parcelas >= 1 and qtd_parcelas <= 240),
  constraint desafios_valor_mensal_check check (valor_mensal > 0)
);

CREATE TABLE IF NOT EXISTS public.desafio_participantes (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  desafio_id uuid not null references public.desafios(id) on delete cascade,
  pessoa_id uuid not null references public.pessoas(id) on delete restrict,
  participant_user_id uuid references auth.users(id) on delete set null,
  status text not null default 'ATIVO' check (status in ('ATIVO', 'INATIVO')),
  token_link uuid not null default gen_random_uuid(),
  token_expires_at timestamptz,
  valor_personalizado numeric(12, 2),
  tenant_id uuid not null default public.current_tenant_id() references public.tenant(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null,
  constraint desafio_participantes_unique unique (desafio_id, pessoa_id)
);

CREATE TABLE IF NOT EXISTS public.desafio_parcelas (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  participante_id uuid not null references public.desafio_participantes(id) on delete cascade,
  competencia date not null,
  vencimento date not null,
  valor numeric(12, 2) not null,
  status text not null default 'ABERTO' check (status in ('ABERTO', 'PAGO', 'CANCELADO')),
  pago_em timestamptz,
  pago_valor numeric(12, 2),
  pago_obs text,
  tenant_id uuid not null default public.current_tenant_id() references public.tenant(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null,
  constraint desafio_parcelas_unique unique (participante_id, competencia),
  constraint desafio_parcelas_valor_check check (valor > 0)
);

CREATE INDEX IF NOT EXISTS idx_categories_tenant_tipo ON public.categories(tenant_id, tipo);
CREATE INDEX IF NOT EXISTS idx_categories_tenant_parent ON public.categories(tenant_id, parent_id);
CREATE INDEX IF NOT EXISTS idx_categories_tenant_ordem ON public.categories(tenant_id, ordem);
CREATE INDEX IF NOT EXISTS idx_beneficiaries_tenant_name ON public.beneficiaries(tenant_id, name);
CREATE INDEX IF NOT EXISTS idx_contas_financeiras_tenant_nome ON public.contas_financeiras(tenant_id, nome);
CREATE INDEX IF NOT EXISTS idx_lancamentos_tenant_status ON public.lancamentos(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_lancamentos_tenant_vencimento ON public.lancamentos(tenant_id, vencimento);
CREATE INDEX IF NOT EXISTS idx_lancamentos_tenant_data_pagamento ON public.lancamentos(tenant_id, data_pagamento);
CREATE INDEX IF NOT EXISTS idx_lancamentos_tenant_categoria ON public.lancamentos(tenant_id, categoria_id);
CREATE INDEX IF NOT EXISTS idx_lancamentos_tenant_conta ON public.lancamentos(tenant_id, conta_id);
CREATE INDEX IF NOT EXISTS idx_movimentos_tenant_data ON public.movimentos_financeiros(tenant_id, data);
CREATE INDEX IF NOT EXISTS idx_movimentos_tenant_conta ON public.movimentos_financeiros(tenant_id, conta_id);
CREATE INDEX IF NOT EXISTS idx_movimentos_tenant_categoria ON public.movimentos_financeiros(tenant_id, categoria_id);
CREATE INDEX IF NOT EXISTS idx_movimentos_tenant_beneficiario ON public.movimentos_financeiros(tenant_id, beneficiario_id);
CREATE INDEX IF NOT EXISTS idx_movimentos_tenant_ref_id ON public.movimentos_financeiros(tenant_id, ref_id);
CREATE INDEX IF NOT EXISTS idx_classification_rules_tenant_term ON public.classification_rules(tenant_id, term);
CREATE INDEX IF NOT EXISTS idx_auditoria_tenant_timestamp ON public.auditoria(tenant_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_desafios_tenant_ativo ON public.desafios(tenant_id, ativo);
CREATE INDEX IF NOT EXISTS idx_desafios_tenant_titulo ON public.desafios(tenant_id, titulo);
CREATE UNIQUE INDEX IF NOT EXISTS idx_desafio_participantes_token_link ON public.desafio_participantes(token_link);
CREATE INDEX IF NOT EXISTS idx_desafio_participantes_tenant_desafio ON public.desafio_participantes(tenant_id, desafio_id);
CREATE INDEX IF NOT EXISTS idx_desafio_participantes_tenant_pessoa ON public.desafio_participantes(tenant_id, pessoa_id);
CREATE INDEX IF NOT EXISTS idx_desafio_parcelas_tenant_vencimento ON public.desafio_parcelas(tenant_id, vencimento);
CREATE INDEX IF NOT EXISTS idx_desafio_parcelas_tenant_status ON public.desafio_parcelas(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_desafio_parcelas_tenant_participante ON public.desafio_parcelas(tenant_id, participante_id);
CREATE INDEX IF NOT EXISTS idx_transferencias_tenant_data ON public.transferencias(tenant_id, data);
CREATE INDEX IF NOT EXISTS idx_saldos_mensais_tenant_mes ON public.saldos_mensais(tenant_id, mes);
CREATE INDEX IF NOT EXISTS idx_recibos_sequencia_tenant_ano ON public.recibos_sequencia(tenant_id, ano);
