-- Inventario: funcoes e triggers

select
  n.nspname as schema,
  p.proname as function,
  pg_get_function_identity_arguments(p.oid) as args,
  pg_get_function_result(p.oid) as returns,
  p.prosecdef as security_definer,
  p.provolatile as volatility,
  array_to_string(p.proconfig, ',') as config
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname not in ('pg_catalog', 'information_schema')
order by 1,2,3;

select
  event_object_schema as schema,
  event_object_table as table,
  trigger_name,
  action_timing,
  event_manipulation as event
from information_schema.triggers
where event_object_schema not in ('pg_catalog', 'information_schema')
order by 1,2,3;
