-- Inventario: indexes, constraints e sequences

select schemaname, tablename, indexname, indexdef
from pg_indexes
where schemaname not in ('pg_catalog', 'information_schema')
order by 1,2,3;

select
  n.nspname as schema,
  c.relname as table,
  con.conname as constraint,
  con.contype as type,
  pg_get_constraintdef(con.oid) as definition
from pg_constraint con
join pg_class c on c.oid = con.conrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname not in ('pg_catalog', 'information_schema')
order by 1,2,3;

select sequence_schema, sequence_name, data_type, start_value, increment, minimum_value, maximum_value, cycle_option
from information_schema.sequences
where sequence_schema not in ('pg_catalog', 'information_schema')
order by 1,2;
