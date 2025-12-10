-- =====================================================
-- RECONCILIAÇÃO: alinhar public.user_account com auth.users por email
-- Objetivo: resolver conflitos onde user_account.id difere de auth.users.id
--           para o mesmo email, atualizando FKs e consolidando perfis
-- =====================================================

BEGIN;

WITH conflicts AS (
  SELECT LOWER(u.email) AS email,
         ua.id AS old_id,
         u.id  AS new_id
  FROM auth.users u
  JOIN public.user_account ua ON LOWER(ua.email) = LOWER(u.email)
  WHERE ua.id <> u.id
)
-- Atualizar FKs nas tabelas que referenciam user_account.id
UPDATE public.ministry_member mm
SET user_id = c.new_id
FROM conflicts c
WHERE mm.user_id = c.old_id;

UPDATE public.member m
SET user_account_id = c.new_id
FROM conflicts c
WHERE m.user_account_id = c.old_id;

UPDATE public.ministry_schedule ms
SET user_id = c.new_id
FROM conflicts c
WHERE ms.user_id = c.old_id;

UPDATE public.member_function mf
SET user_id = c.new_id
FROM conflicts c
WHERE mf.user_id = c.old_id;

-- Remover perfis antigos em user_account para emails em conflito
DELETE FROM public.user_account ua
USING conflicts c
WHERE ua.id = c.old_id;

-- Garantir que exista um perfil para cada auth.users.id
INSERT INTO public.user_account (id, email, first_name, last_name)
SELECT u.id,
       u.email,
       COALESCE(NULLIF(u.raw_user_meta_data->>'first_name',''), split_part(u.email, '@', 1)) AS first_name,
       COALESCE(u.raw_user_meta_data->>'last_name','') AS last_name
FROM auth.users u
LEFT JOIN public.user_account ua ON ua.id = u.id
WHERE ua.id IS NULL;

COMMIT;

-- =====================================================
-- FIM
-- =====================================================
