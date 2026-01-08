-- Fix function_search_path_mutable warnings - Batch 16 (Final Part)
-- Functions/Procedures: process_dispatch_jobs, prune_dispatch_log, update_profile_completion

-- 1. process_dispatch_jobs
CREATE OR REPLACE PROCEDURE public.process_dispatch_jobs()
 LANGUAGE plpgsql
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

    -- Requires pg_net extension
    req_id := net.http_post(
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

-- 2. prune_dispatch_log
CREATE OR REPLACE PROCEDURE public.prune_dispatch_log(IN days integer DEFAULT 30)
 LANGUAGE plpgsql
 SET search_path TO ''
AS $procedure$
begin
  delete from public.dispatch_log
  where created_at < now() - make_interval(days => days)
    and action in ('status_change','scheduled');
end;
$procedure$;

-- 3. update_profile_completion
CREATE OR REPLACE FUNCTION public.update_profile_completion()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  NEW.profile_completion_percentage := public.calculate_profile_completion(NEW);
  RETURN NEW;
END;
$function$;
