
-- Create enum for transaction types
CREATE TYPE public.tipo_transacao AS ENUM ('receita', 'despesa');

-- Create enum for payment methods
CREATE TYPE public.metodo_pagamento AS ENUM ('dinheiro', 'pix', 'cartao_credito', 'cartao_debito', 'transferencia', 'boleto', 'cheque');

-- Create enum for transaction status
CREATE TYPE public.status_transacao AS ENUM ('pendente', 'confirmada', 'cancelada');

-- Create categories table
CREATE TABLE public.categorias_financeiras (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  nome TEXT NOT NULL,
  descricao TEXT,
  tipo public.tipo_transacao NOT NULL,
  ativa BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create financial transactions table
CREATE TABLE public.transacoes_financeiras (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  tipo public.tipo_transacao NOT NULL,
  valor NUMERIC(10,2) NOT NULL,
  descricao TEXT NOT NULL,
  observacoes TEXT,
  data_transacao DATE NOT NULL DEFAULT CURRENT_DATE,
  metodo_pagamento public.metodo_pagamento NOT NULL,
  categoria_id UUID REFERENCES public.categorias_financeiras(id),
  status public.status_transacao NOT NULL DEFAULT 'pendente',
  user_id UUID,
  aprovado_por UUID,
  data_aprovacao TIMESTAMP WITH TIME ZONE,
  comprovante_url TEXT,
  numero_documento TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create budgets table
CREATE TABLE public.orcamentos (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  nome TEXT NOT NULL,
  descricao TEXT,
  ano INTEGER NOT NULL,
  mes INTEGER CHECK (mes >= 1 AND mes <= 12),
  valor_previsto NUMERIC(10,2) NOT NULL,
  valor_realizado NUMERIC(10,2) DEFAULT 0,
  categoria_id UUID REFERENCES public.categorias_financeiras(id),
  ativo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create tithes and offerings table
CREATE TABLE public.dizimos_ofertas (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID,
  tipo TEXT NOT NULL CHECK (tipo IN ('dizimo', 'oferta')),
  valor NUMERIC(10,2) NOT NULL,
  data_doacao DATE NOT NULL DEFAULT CURRENT_DATE,
  metodo_pagamento public.metodo_pagamento NOT NULL,
  observacoes TEXT,
  anonimo BOOLEAN DEFAULT false,
  transacao_id UUID REFERENCES public.transacoes_financeiras(id),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS on all tables
ALTER TABLE public.categorias_financeiras ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transacoes_financeiras ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orcamentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dizimos_ofertas ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for categorias_financeiras
CREATE POLICY "Anyone can view active categories" 
  ON public.categorias_financeiras 
  FOR SELECT 
  USING (ativa = true);

CREATE POLICY "Admins and pastors can manage categories" 
  ON public.categorias_financeiras 
  FOR ALL 
  USING (public.is_admin_or_pastor(auth.uid()));

-- Create RLS policies for transacoes_financeiras
CREATE POLICY "Admins and pastors can view all transactions" 
  ON public.transacoes_financeiras 
  FOR SELECT 
  USING (public.is_admin_or_pastor(auth.uid()));

CREATE POLICY "Admins and pastors can manage transactions" 
  ON public.transacoes_financeiras 
  FOR ALL 
  USING (public.is_admin_or_pastor(auth.uid()));

-- Create RLS policies for orcamentos
CREATE POLICY "Admins and pastors can view budgets" 
  ON public.orcamentos 
  FOR SELECT 
  USING (public.is_admin_or_pastor(auth.uid()));

CREATE POLICY "Admins and pastors can manage budgets" 
  ON public.orcamentos 
  FOR ALL 
  USING (public.is_admin_or_pastor(auth.uid()));

-- Create RLS policies for dizimos_ofertas
CREATE POLICY "Admins and pastors can view all tithes" 
  ON public.dizimos_ofertas 
  FOR SELECT 
  USING (public.is_admin_or_pastor(auth.uid()));

CREATE POLICY "Users can view their own tithes" 
  ON public.dizimos_ofertas 
  FOR SELECT 
  USING (auth.uid() = user_id AND NOT anonimo);

CREATE POLICY "Admins and pastors can manage tithes" 
  ON public.dizimos_ofertas 
  FOR ALL 
  USING (public.is_admin_or_pastor(auth.uid()));

-- Insert default categories
INSERT INTO public.categorias_financeiras (nome, descricao, tipo) VALUES
('Dízimos', 'Dízimos dos membros', 'receita'),
('Ofertas', 'Ofertas especiais e campanhas', 'receita'),
('Doações', 'Doações diversas', 'receita'),
('Eventos', 'Receitas de eventos e conferências', 'receita'),
('Aluguel', 'Despesas com aluguel do templo', 'despesa'),
('Energia Elétrica', 'Conta de luz', 'despesa'),
('Água', 'Conta de água', 'despesa'),
('Internet/Telefone', 'Telecomunicações', 'despesa'),
('Material de Limpeza', 'Produtos de limpeza e higiene', 'despesa'),
('Equipamentos', 'Compra e manutenção de equipamentos', 'despesa'),
('Ministério', 'Gastos com ministérios', 'despesa'),
('Missões', 'Investimento em missões', 'despesa');

-- Create triggers for updated_at
CREATE TRIGGER update_categorias_financeiras_updated_at
  BEFORE UPDATE ON public.categorias_financeiras
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER update_transacoes_financeiras_updated_at
  BEFORE UPDATE ON public.transacoes_financeiras
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER update_orcamentos_updated_at
  BEFORE UPDATE ON public.orcamentos
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();
;
