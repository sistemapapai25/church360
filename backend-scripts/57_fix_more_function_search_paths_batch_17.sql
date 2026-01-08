-- Fix function_search_path_mutable warnings - Batch 17
-- Functions: has_role
-- Extensions: pg_net (move to extensions schema)
--
-- MISSING FUNCTIONS (Please provide definitions for these):
-- 1. detectar_ausencias_consecutivas
-- 2. processar_alertas_ausencias
-- 3. trg_dispatch_job_after_insert
-- 4. trg_dispatch_job_after_update
--
-- These functions were not found in the codebase. To fix them, I need their SQL definitions.
-- You can get them by running:
-- select pg_get_functiondef('public.detectar_ausencias_consecutivas'::regproc);
-- select pg_get_functiondef('public.processar_alertas_ausencias'::regproc);
-- select pg_get_functiondef('public.trg_dispatch_job_after_insert'::regproc); -- (if it's a function)
-- select pg_get_triggerdef(oid) from pg_trigger where tgname = 'trg_dispatch_job_after_insert';

-- 1. Move pg_net extension to 'extensions' schema
CREATE SCHEMA IF NOT EXISTS extensions;

DO $$
BEGIN
  -- Move pg_net to extensions schema if it's in public
  IF EXISTS (
    SELECT 1 FROM pg_extension 
    WHERE extname = 'pg_net' AND extnamespace = 'public'::regnamespace
  ) THEN
    ALTER EXTENSION pg_net SET SCHEMA extensions;
  END IF;
END $$;

-- 2. has_role
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
