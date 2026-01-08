
-- Remover políticas RLS antigas/conflitantes da tabela pedidos_oracao
DROP POLICY IF EXISTS "Membros podem ver seus próprios pedidos" ON public.pedidos_oracao;
DROP POLICY IF EXISTS "Membros podem criar pedidos" ON public.pedidos_oracao;
DROP POLICY IF EXISTS "Membros podem atualizar seus pedidos" ON public.pedidos_oracao;
DROP POLICY IF EXISTS "Pastores podem ver todos os pedidos" ON public.pedidos_oracao;

-- Criar políticas RLS corretas e otimizadas
CREATE POLICY "Usuários podem ver seus próprios pedidos"
ON public.pedidos_oracao
FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Usuários podem criar seus pedidos"
ON public.pedidos_oracao
FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuários podem atualizar seus pedidos"
ON public.pedidos_oracao
FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Usuários podem deletar seus pedidos"
ON public.pedidos_oracao
FOR DELETE
USING (auth.uid() = user_id);

-- Política para pastores e admins verem e gerenciarem todos os pedidos
CREATE POLICY "Pastores e admins podem gerenciar todos os pedidos"
ON public.pedidos_oracao
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.user_roles ur 
    WHERE ur.user_id = auth.uid() 
    AND ur.role IN ('pastor', 'admin')
  )
);

-- Política para pastores e admins verem pedidos públicos
CREATE POLICY "Todos podem ver pedidos públicos"
ON public.pedidos_oracao
FOR SELECT
USING (publico = true);
;
