
-- Verificar e criar a tabela pedidos_oracao se necessário
-- (A tabela já existe no schema, mas vamos garantir que tem todas as colunas necessárias)

-- Habilitar RLS na tabela pedidos_oracao
ALTER TABLE public.pedidos_oracao ENABLE ROW LEVEL SECURITY;

-- Política para membros verem seus próprios pedidos
CREATE POLICY "Membros podem ver seus próprios pedidos"
ON public.pedidos_oracao
FOR SELECT
USING (auth.uid() = user_id);

-- Política para membros criarem seus próprios pedidos
CREATE POLICY "Membros podem criar pedidos"
ON public.pedidos_oracao
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Política para membros atualizarem seus próprios pedidos
CREATE POLICY "Membros podem atualizar seus pedidos"
ON public.pedidos_oracao
FOR UPDATE
USING (auth.uid() = user_id);

-- Política para pastores e admins verem todos os pedidos
CREATE POLICY "Pastores podem ver todos os pedidos"
ON public.pedidos_oracao
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.user_roles ur 
    WHERE ur.user_id = auth.uid() 
    AND ur.role IN ('pastor', 'admin')
  )
);
;
