-- =====================================================
-- FIX SECURITY ADVISOR ISSUES: FUNCTION SEARCH PATH MUTABLE (BATCH 13)
-- =====================================================
-- This script fixes "function_search_path_mutable" warnings for 2 functions
-- that could be safely inferred.
--
-- The following functions were NOT found in the codebase and require
-- the source code to be fixed safely:
-- - update_profile_completion
-- - process_dispatch_jobs
-- - manage_scheduler
-- - get_schedulers
-- - finalize_dispatch_responses
-- - prune_dispatch_log
-- - collect_dispatch_responses
--
-- Please provide the definitions of these functions so they can be fixed.
-- You can run the following query to get them:
-- SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname IN ('update_profile_completion', 'process_dispatch_jobs', 'manage_scheduler', 'get_schedulers', 'finalize_dispatch_responses', 'prune_dispatch_log', 'collect_dispatch_responses');

-- 1. handle_updated_at (Assumed to be a trigger function for updated_at)
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

-- 2. is_owner (Assumed to check if current user is owner)
CREATE OR REPLACE FUNCTION public.is_owner()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.user_account 
    WHERE id = auth.uid() 
    AND role_global = 'owner'
  );
END;
$function$;
