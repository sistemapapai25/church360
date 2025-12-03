WITH ua AS (
  SELECT id, email, first_name, last_name FROM public.user_account
),
au AS (
  SELECT id, email FROM auth.users
),
mm AS (
  SELECT id, ministry_id, user_id FROM public.ministry_member
),
ur AS (
  SELECT id, user_id, role_id, role_context_id FROM public.user_roles
),
ual AS (
  SELECT user_id, access_level, access_level_number FROM public.user_access_level
)
SELECT ua.email, ua.id AS user_account_id
FROM ua
LEFT JOIN au ON lower(ua.email) = lower(au.email)
WHERE au.id IS NULL;

SELECT au.email, au.id AS auth_user_id
FROM au
LEFT JOIN ua ON lower(ua.email) = lower(au.email)
WHERE ua.id IS NULL;

SELECT mm.id AS ministry_member_id, mm.ministry_id, mm.user_id
FROM mm
LEFT JOIN ua ON ua.id = mm.user_id
WHERE ua.id IS NULL;

SELECT ur.id AS user_role_id, ur.user_id, ur.role_id, ur.role_context_id
FROM ur
LEFT JOIN ua ON ua.id = ur.user_id
WHERE ua.id IS NULL;

SELECT ual.user_id, ual.access_level, ual.access_level_number
FROM ual
LEFT JOIN ua ON ua.id = ual.user_id
WHERE ua.id IS NULL;

SELECT email, COUNT(*) AS count, array_agg(id) AS user_account_ids
FROM ua
GROUP BY email
HAVING COUNT(*) > 1;

SELECT email, COUNT(*) AS count, array_agg(id) AS auth_user_ids
FROM au
GROUP BY email
HAVING COUNT(*) > 1;

SELECT ua.email, ua.id AS user_account_id, au.id AS auth_user_id
FROM ua
JOIN au ON lower(ua.email) = lower(au.email)
WHERE ua.id <> au.id;
