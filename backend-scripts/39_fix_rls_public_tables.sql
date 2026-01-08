-- =====================================================
-- CORREÇÃO: RLS Disabled in Public Tables
-- =====================================================
-- Descrição: Corrige o problema "RLS Disabled in Public" apontado pelo Security Advisor.
-- Habilita o RLS e cria políticas padrão de acesso para as tabelas:
-- 1. ministry_function
-- 2. member_function
-- 3. user_account_sync_log
-- =====================================================

-- 1. ministry_function
ALTER TABLE public.ministry_function ENABLE ROW LEVEL SECURITY;

-- Política de Leitura: Todos os usuários autenticados podem ver funções ministeriais
CREATE POLICY "Leitura permitida para autenticados"
ON public.ministry_function FOR SELECT
TO authenticated
USING (true);

-- Política de Escrita (Admin): Apenas admins podem gerenciar funções
-- (Assumindo que admin/lider tem role_global 'admin' ou permissão equivalente. 
--  Ajuste conforme seu modelo de permissões. Aqui, uso permissão básica de admin)
CREATE POLICY "Gerenciamento apenas para admins"
ON public.ministry_function FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_access_level ual
    WHERE ual.user_id = auth.uid()
    AND ual.access_level_number >= 3 -- Nível Líder/Admin
  )
);

-- 2. member_function
-- (Verifique se essa tabela é realmente usada ou legado. Vou proteger por precaução)
ALTER TABLE public.member_function ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Leitura permitida para autenticados"
ON public.member_function FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Gerenciamento apenas para admins"
ON public.member_function FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_access_level ual
    WHERE ual.user_id = auth.uid()
    AND ual.access_level_number >= 3
  )
);

-- 3. user_account_sync_log
-- Tabela de log de sistema, geralmente apenas leitura para admins ou interna.
ALTER TABLE public.user_account_sync_log ENABLE ROW LEVEL SECURITY;

-- Política: Apenas admins podem ver logs de sincronização
CREATE POLICY "Apenas admins podem ver logs"
ON public.user_account_sync_log FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_access_level ual
    WHERE ual.user_id = auth.uid()
    AND ual.access_level_number >= 4 -- Nível Admin/Pastor
  )
);

-- Política: Ninguém insere manualmente (apenas triggers/functions do sistema - SECURITY DEFINER)
-- Mas se precisar de insert via API (raro para log), restrinja a admins.
-- Vou bloquear INSERT/UPDATE/DELETE direto via API para logs (boa prática).
-- (Sem policies de write = Ninguém escreve via API, apenas via functions do banco)
