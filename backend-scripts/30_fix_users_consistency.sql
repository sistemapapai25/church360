BEGIN;

-- ==========================================================
-- 1) Construir mapeamento legacy(member) -> user_account
-- ==========================================================
DROP TABLE IF EXISTS tmp_member_user_map;
CREATE TEMP TABLE tmp_member_user_map AS
WITH by_email AS (
  SELECT m.id AS legacy_member_id,
         ua.id AS user_account_id,
         'email' AS match_type
  FROM public.member m
  JOIN public.user_account ua
    ON ua.email IS NOT NULL
   AND m.email IS NOT NULL
   AND lower(ua.email) = lower(m.email)
), by_name AS (
  SELECT m.id AS legacy_member_id,
         ua.id AS user_account_id,
         'name' AS match_type
  FROM public.member m
  JOIN public.user_account ua
    ON lower(coalesce(ua.first_name,'')) = lower(coalesce(m.first_name,''))
   AND lower(coalesce(ua.last_name,''))  = lower(coalesce(m.last_name,''))
)
SELECT * FROM by_email
UNION
SELECT * FROM by_name;

-- ==========================================================
-- 2) Corrigir ministry_member.user_id que aponta para member.id
-- ==========================================================
WITH updated AS (
  UPDATE public.ministry_member mm
     SET user_id = map.user_account_id
  FROM tmp_member_user_map map
  WHERE mm.user_id = map.legacy_member_id
  RETURNING mm.id
)
SELECT COUNT(*) AS ministry_member_fixed FROM updated;

-- ==========================================================
-- 3) Corrigir user_roles.user_id que aponta para member.id
-- ==========================================================
WITH updated AS (
  UPDATE public.user_roles ur
     SET user_id = map.user_account_id
  FROM tmp_member_user_map map
  WHERE ur.user_id = map.legacy_member_id
  RETURNING ur.id
)
SELECT COUNT(*) AS user_roles_fixed FROM updated;

-- ==========================================================
-- 4) Corrigir user_access_level.user_id que aponta para member.id
-- ==========================================================
WITH updated AS (
  UPDATE public.user_access_level ual
     SET user_id = map.user_account_id
  FROM tmp_member_user_map map
  WHERE ual.user_id = map.legacy_member_id
  RETURNING ual.user_id
)
SELECT COUNT(*) AS user_access_level_fixed FROM updated;

-- ==========================================================
-- 5) Relatório de pendências restantes (sem user_account)
-- ==========================================================
SELECT mm.id AS ministry_member_id, mm.ministry_id, mm.user_id
FROM public.ministry_member mm
WHERE NOT EXISTS (SELECT 1 FROM public.user_account ua WHERE ua.id = mm.user_id);

SELECT ur.id AS user_role_id, ur.user_id, ur.role_id
FROM public.user_roles ur
WHERE NOT EXISTS (SELECT 1 FROM public.user_account ua WHERE ua.id = ur.user_id);

SELECT ual.user_id, ual.access_level, ual.access_level_number
FROM public.user_access_level ual
WHERE NOT EXISTS (SELECT 1 FROM public.user_account ua WHERE ua.id = ual.user_id);

-- ==========================================================
-- 6) Alinhamento de IDs por e‑mail (somente relatório)
--    A correção de auth.users deve ser feita via script 27/28
-- ==========================================================
SELECT ua.email, ua.id AS user_account_id, au.id AS auth_user_id
FROM public.user_account ua
JOIN auth.users au ON lower(ua.email) = lower(au.email)
WHERE ua.id <> au.id;

COMMIT;

-- Observações:
-- - Este script corrige referências que ficaram com IDs da tabela legacy member.
-- - Ele NÃO cria usuários em auth.users. Use os scripts 27/28 para isso.
-- - Os três SELECTs de pendências ajudam a decidir ajustes manuais caso não haja mapeamento por e‑mail/nome.
