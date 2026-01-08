-- =====================================================
-- FIX SECURITY ADVISOR ISSUES: FUNCTION SEARCH PATH MUTABLE (BATCH 14)
-- =====================================================
-- This script fixes "function_search_path_mutable" warnings for:
-- 1. collect_dispatch_responses
-- 2. finalize_dispatch_responses
--
-- These are PROCEDURES, not FUNCTIONS, but the fix is the same.
-- We explicitly set search_path to '' and fully qualify all object references.

-- 1. collect_dispatch_responses
CREATE OR REPLACE PROCEDURE public.collect_dispatch_responses()
 LANGUAGE plpgsql
 SET search_path TO ''
AS $procedure$
declare
  l record;
  rec net.http_response_result;
begin
  perform set_config('statement_timeout','5000', true);

  for l in
    select job_id, (payload->>'request_id')::bigint as req_id
    from public.dispatch_log
    where action = 'submitted'
      and status = 'processing'::public.dispatch_status
      and payload ? 'request_id'
    order by created_at desc
    limit 10
  loop
    select net.http_collect_response(l.req_id, async := false) into rec;

    if rec.status = 'SUCCESS' and (rec.response).status_code between 200 and 299 then
      update public.dispatch_job
        set status = 'sent'::public.dispatch_status, processed_at = now(), last_error = null
        where id = l.job_id;

      insert into public.dispatch_log(job_id, status, action, detail, payload)
      values (l.job_id, 'sent'::public.dispatch_status, 'sent', 'message_sent', '{}'::jsonb);

    elsif rec.status = 'ERROR' then
      update public.dispatch_job
        set status = 'failed'::public.dispatch_status,
            last_error = left(coalesce((rec.response).body, rec.message), 300)
        where id = l.job_id;

      insert into public.dispatch_log(job_id, status, action, detail, payload)
      values (l.job_id, 'failed'::public.dispatch_status, 'error', left(coalesce((rec.response).body, rec.message), 300), '{}'::jsonb);
    end if;
  end loop;
end;
$procedure$;

-- 2. finalize_dispatch_responses
CREATE OR REPLACE PROCEDURE public.finalize_dispatch_responses()
 LANGUAGE plpgsql
 SET search_path TO ''
AS $procedure$
declare r record;
begin
  for r in
    select dj.id as job_id, resp.status_code, resp.content
    from public.dispatch_job dj
    join public.dispatch_log l on l.job_id = dj.id and l.action = 'submitted'
    join net._http_response resp on resp.id = (l.payload->>'request_id')::bigint
    where dj.status = 'processing'::public.dispatch_status
      and not exists (
        select 1 from public.dispatch_log dl2
        where dl2.job_id = dj.id and dl2.action in ('sent','error')
      )
  loop
    if r.status_code between 200 and 299 then
      update public.dispatch_job
        set status='sent'::public.dispatch_status, processed_at=now(), last_error=null
        where id=r.job_id;
      begin
        insert into public.dispatch_log(job_id, status, action, detail, payload)
        values (r.job_id, 'sent'::public.dispatch_status, 'sent', 'message_sent', '{}'::jsonb);
      exception when unique_violation then null; end;

    elsif r.status_code in (401,403) then
      update public.dispatch_job
        set status='failed'::public.dispatch_status,
            retries=3,
            processed_at=now(),
            last_error='auth_error'
        where id=r.job_id;
      begin
        insert into public.dispatch_log(job_id, status, action, detail, payload)
        values (r.job_id, 'failed'::public.dispatch_status, 'error', 'auth_error', '{}'::jsonb);
      exception when unique_violation then null; end;

    elsif r.status_code = 404 then
      update public.dispatch_job
        set status='failed'::public.dispatch_status,
            retries=3,
            processed_at=now(),
            last_error='endpoint_not_found'
        where id=r.job_id;
      begin
        insert into public.dispatch_log(job_id, status, action, detail, payload)
        values (r.job_id, 'failed'::public.dispatch_status, 'error', 'endpoint_not_found', '{}'::jsonb);
      exception when unique_violation then null; end;

    elsif r.status_code = 405 then
      update public.dispatch_job
        set status='failed'::public.dispatch_status,
            retries=3,
            processed_at=now(),
            last_error='endpoint_method_not_allowed'
        where id=r.job_id;
      begin
        insert into public.dispatch_log(job_id, status, action, detail, payload)
        values (r.job_id, 'failed'::public.dispatch_status, 'error', 'endpoint_method_not_allowed', '{}'::jsonb);
      exception when unique_violation then null; end;

    elsif r.status_code = 429 or r.status_code between 500 and 599 then
      update public.dispatch_job
        set status='failed'::public.dispatch_status,
            retries=coalesce(retries,0)+1,
            scheduled_at=now() + make_interval(mins => 5 * (1 << least(coalesce(retries,0),10))),
            last_error=left(coalesce(r.content,''),300)
        where id=r.job_id;
      begin
        insert into public.dispatch_log(job_id, status, action, detail, payload)
        values (r.job_id, 'failed'::public.dispatch_status, 'error', left(coalesce(r.content,''),300), '{}'::jsonb);
      exception when unique_violation then null; end;

    else
      update public.dispatch_job
        set status='failed'::public.dispatch_status,
            retries=coalesce(retries,0)+1,
            scheduled_at=now() + make_interval(mins => 5 * (1 << least(coalesce(retries,0),10))),
            last_error=left(coalesce(r.content,''),300)
        where id=r.job_id;
      begin
        insert into public.dispatch_log(job_id, status, action, detail, payload)
        values (r.job_id, 'failed'::public.dispatch_status, 'error', left(coalesce(r.content,''),300), '{}'::jsonb);
      exception when unique_violation then null; end;
    end if;
  end loop;
end;
$procedure$;
