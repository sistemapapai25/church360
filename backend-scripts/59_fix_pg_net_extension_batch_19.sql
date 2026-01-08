-- Fix pg_net extension location and has_role - Batch 19 (Advanced)
-- WARNING: This script DROPS the pg_net extension and dependent objects (CASCADE).
-- It then recreates them in the correct schema ('extensions').
--
-- Steps:
-- 1. Create 'extensions' schema if not exists.
-- 2. Drop pg_net extension (CASCADE will drop dependent functions like process_dispatch_jobs).
-- 3. Create pg_net extension in 'extensions' schema.
-- 4. Recreate dropped functions (process_dispatch_jobs) with correct references.
-- 5. Fix has_role function (ensure search_path is secure).

BEGIN;

-- 1. Create schema
CREATE SCHEMA IF NOT EXISTS extensions;

-- 2. Drop extension (and dependents)
-- This will DROP public.process_dispatch_jobs automatically due to CASCADE
DROP EXTENSION IF EXISTS pg_net CASCADE;

-- 3. Reinstall extension in correct schema
CREATE EXTENSION IF NOT EXISTS pg_net SCHEMA extensions;

-- 4. Recreate dependent function: process_dispatch_jobs
-- Updated to use extensions.http_post and fully qualified names
CREATE OR REPLACE PROCEDURE public.process_dispatch_jobs()
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $procedure$
declare
  j record;
  base text;
  token_inst text;
  path text;
  req_id bigint;
  number text;
  text_msg text;
begin
  select coalesce((select base_url from public.integration_settings where provider='uazapi' limit 1),'') into base;
  select coalesce((select instance_token from public.integration_settings where provider='uazapi' limit 1),'') into token_inst;
  select coalesce((select send_path from public.integration_settings where provider='uazapi' limit 1), '/send/text') into path;

  base := regexp_replace(base, '/+$', '');
  path := case when left(path,1) = '/' then path else '/' || path end;

  for j in
    select *
    from public.dispatch_job
    where status in ('pending'::public.dispatch_status,'failed'::public.dispatch_status)
      and coalesce(retries,0) < 3
      and coalesce(scheduled_at, now()) <= now()
    order by scheduled_at nulls last, created_at
    limit 1
  loop
    update public.dispatch_job set status='processing'::public.dispatch_status where id=j.id;

    number := regexp_replace(coalesce(j.recipient_phone,''),'[^0-9]','','g');
    text_msg := coalesce(j.payload->>'text','');

    if number = '' or text_msg = '' or base = '' or token_inst = '' then
      update public.dispatch_job
        set status='failed'::public.dispatch_status,
            retries=coalesce(retries,0)+1,
            scheduled_at=now() + make_interval(mins => 5 * (1 << least(coalesce(retries,0),10))),
            last_error=case
              when number = '' then 'invalid_recipient_phone'
              when text_msg = '' then 'empty_payload_text'
              when base = '' or token_inst = '' then 'missing_uazapi_config'
              else 'invalid_job'
            end
      where id=j.id;
      continue;
    end if;

    -- Using extensions.http_post now
    req_id := extensions.http_post(
      url := base || path,
      body := jsonb_build_object('number', number, 'text', text_msg),
      headers := jsonb_build_object(
        'token', token_inst,
        'Content-Type', 'application/json'
      )
    );

    insert into public.dispatch_log(job_id, status, action, detail, payload)
    values (j.id, 'processing'::public.dispatch_status, 'submitted', 'request_queued', jsonb_build_object('request_id', req_id, 'number', number));
  end loop;
end;
$procedure$;

-- 5. Ensure has_role is fixed (just in case)
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

COMMIT;
