-- =====================================================
-- SCRIPT: Correção das FKs para user_account
-- Alvo principal: ministry_member.user_id → public.user_account(id)
-- Também sincroniza usuários de auth.users para public.user_account
-- =====================================================

-- Corrigir FK de ministry_member.user_id
ALTER TABLE public.ministry_member
  DROP CONSTRAINT IF EXISTS ministry_member_user_id_fkey;

ALTER TABLE public.ministry_member
  ADD CONSTRAINT ministry_member_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES public.user_account(id)
  ON UPDATE CASCADE
  ON DELETE CASCADE;

-- Sincronizar usuários ausentes de auth.users para public.user_account
INSERT INTO public.user_account (id, email, full_name, is_active)
SELECT u.id, u.email, u.raw_user_meta_data->>'full_name', true
FROM auth.users u
LEFT JOIN public.user_account ua ON ua.id = u.id
WHERE ua.id IS NULL;

-- Preencher first_name/last_name quando possível a partir de full_name
UPDATE public.user_account ua
SET first_name = COALESCE(ua.first_name, split_part(COALESCE(ua.full_name, ''), ' ', 1)),
    last_name  = COALESCE(ua.last_name, NULLIF(regexp_replace(COALESCE(ua.full_name, ''), '^[^ ]+\s*', ''), ''))
WHERE ua.full_name IS NOT NULL;

-- Auditoria opcional: listar FKs que ainda referenciam a tabela de backup
-- Execute para verificar se ainda há FKs apontando para user_account_backup
-- SELECT conrelid::regclass AS table_name,
--        conname AS constraint_name,
--        confrelid::regclass AS referenced_table,
--        pg_get_constraintdef(c.oid) AS definition
-- FROM pg_constraint c
-- WHERE contype = 'f'
--   AND confrelid = 'public.user_account_backup_2025_11_27'::regclass;

