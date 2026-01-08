-- Fix function_search_path_mutable warnings - Batch 17 (v2)
-- Functions: has_role
-- Note: Skipping pg_net extension move due to "does not support SET SCHEMA" error.
--       To fix the 'extension_in_public' warning for pg_net, it must be dropped and recreated,
--       which requires careful handling of dependent objects (like process_dispatch_jobs).
--
-- STILL MISSING FUNCTIONS (Please provide definitions via SQL query):
-- 1. detectar_ausencias_consecutivas
-- 2. processar_alertas_ausencias
-- 3. trg_dispatch_job_after_insert
-- 4. trg_dispatch_job_after_update

-- 1. has_role
CREATE OR REPLACE FUNCTION public.has_role(user_id uuid, role_name text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.user_roles ur
    JOIN public.roles r ON r.id = ur.role_id
    WHERE ur.user_id = has_role.user_id 
      AND r.name = has_role.role_name
      AND ur.is_active = true
      AND (ur.expires_at IS NULL OR ur.expires_at > now())
  );
END;
$function$;
