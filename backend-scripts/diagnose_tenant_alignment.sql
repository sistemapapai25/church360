\echo '== TENANTS =='
SELECT id, name, slug, created_at
FROM public.tenant
ORDER BY created_at;

\echo '== DEFAULT TENANT ID (APP) =='
SELECT id, name, slug
FROM public.tenant
WHERE id = 'd8b6be47-f99f-45b8-a3f4-b7ca3cca9645';

\echo '== USER_ACCOUNT WITH MISSING TENANT_ID OR AUTH_USER_ID =='
SELECT id, email, tenant_id, auth_user_id, created_at
FROM public.user_account
WHERE tenant_id IS NULL OR auth_user_id IS NULL
ORDER BY created_at DESC;

\echo '== USER_ACCOUNT WITH TENANT_ID NOT FOUND IN TENANT TABLE =='
SELECT ua.id, ua.email, ua.tenant_id
FROM public.user_account ua
LEFT JOIN public.tenant t ON t.id = ua.tenant_id
WHERE ua.tenant_id IS NOT NULL AND t.id IS NULL;

\echo '== USER_TENANT_MEMBERSHIP MISSING FOR USER_ACCOUNT =='
SELECT ua.id, ua.email, ua.tenant_id, ua.auth_user_id
FROM public.user_account ua
LEFT JOIN public.user_tenant_membership utm
  ON utm.user_id = COALESCE(ua.auth_user_id, ua.id)
WHERE utm.user_id IS NULL
ORDER BY ua.created_at DESC;

\echo '== USER_TENANT_MEMBERSHIP TENANT MISMATCH WITH USER_ACCOUNT =='
SELECT ua.id, ua.email, ua.tenant_id AS ua_tenant_id, utm.tenant_id AS utm_tenant_id,
       utm.access_level_number, utm.is_active
FROM public.user_account ua
JOIN public.user_tenant_membership utm
  ON utm.user_id = COALESCE(ua.auth_user_id, ua.id)
WHERE ua.tenant_id IS NOT NULL
  AND utm.tenant_id IS DISTINCT FROM ua.tenant_id
ORDER BY utm.updated_at DESC;

\echo '== USER_TENANT_MEMBERSHIP ACCESS LEVEL < 4 (FINANCIAL LOCK) =='
SELECT ua.id, ua.email, utm.tenant_id, utm.access_level, utm.access_level_number, utm.is_active
FROM public.user_account ua
JOIN public.user_tenant_membership utm
  ON utm.user_id = COALESCE(ua.auth_user_id, ua.id)
WHERE utm.access_level_number < 4
ORDER BY utm.access_level_number ASC, utm.updated_at DESC;

\echo '== USER_ACCESS_LEVEL WITHOUT TENANT_ID =='
SELECT user_id, tenant_id, access_level, access_level_number
FROM public.user_access_level
WHERE tenant_id IS NULL
ORDER BY updated_at DESC;

\echo '== USER_ACCESS_LEVEL ACCESS LEVEL < 4 =='
SELECT user_id, tenant_id, access_level, access_level_number
FROM public.user_access_level
WHERE access_level_number < 4
ORDER BY access_level_number ASC, updated_at DESC;

\echo '== FINANCIAL PERMISSIONS ASSIGNED BY ROLE =='
SELECT ur.user_id, ur.tenant_id, p.code AS permission_code, r.name AS role_name
FROM public.user_roles ur
JOIN public.role_permissions rp ON rp.role_id = ur.role_id
JOIN public.permissions p ON p.id = rp.permission_id
JOIN public.roles r ON r.id = ur.role_id
WHERE p.code LIKE 'financial.%'
ORDER BY ur.user_id, p.code;

\echo '== FINANCIAL CUSTOM PERMISSIONS =='
SELECT ucp.user_id, ucp.tenant_id, p.code AS permission_code, ucp.is_granted
FROM public.user_custom_permissions ucp
JOIN public.permissions p ON p.id = ucp.permission_id
WHERE p.code LIKE 'financial.%'
ORDER BY ucp.user_id, p.code;
