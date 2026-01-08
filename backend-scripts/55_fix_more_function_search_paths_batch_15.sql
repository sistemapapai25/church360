-- =====================================================
-- FIX SECURITY ADVISOR ISSUES: FUNCTION SEARCH PATH MUTABLE (BATCH 15)
-- =====================================================
-- This script fixes "function_search_path_mutable" warnings for:
-- 1. get_schedulers
-- 2. manage_scheduler
--
-- We explicitly set search_path to '' and fully qualify all object references.

-- 1. get_schedulers
CREATE OR REPLACE FUNCTION public.get_schedulers()
 RETURNS TABLE(jobid integer, jobname text, schedule text)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select j.jobid, j.jobname, j.schedule
  from cron.job j
  order by j.jobid;
$function$;

-- 2. manage_scheduler
CREATE OR REPLACE FUNCTION public.manage_scheduler(
  jobname text,
  schedule text,
  url text,
  headers jsonb DEFAULT '{}'::jsonb,
  body jsonb DEFAULT '{}'::jsonb
)
 RETURNS TABLE(ret_jobid integer, ret_name text, ret_schedule text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  existing_id int;
  cmd text;
  headers_txt text := coalesce(headers::text, '{}');
  body_txt text := coalesce(body::text, '{}');
begin
  if not public.is_owner() then
    raise exception 'forbidden';
  end if;

  select j.jobid into existing_id
  from cron.job j
  where j.jobname = manage_scheduler.jobname;

  if existing_id is not null then
    perform cron.unschedule(existing_id);
  end if;

  cmd := format(
    $q$select net.http_post(
      url := %L,
      headers := %s::jsonb,
      body := %s::jsonb
    );$q$,
    url,
    headers_txt,
    body_txt
  );

  return query
    select cron.schedule(manage_scheduler.jobname, manage_scheduler.schedule, cmd),
           manage_scheduler.jobname,
           manage_scheduler.schedule;
end;
$function$;
