-- Inventario: schemas e extensoes

-- Schemas (nao-system)
select nspname
from pg_namespace
where nspname not like 'pg_%'
  and nspname <> 'information_schema'
order by 1;

-- Extensoes e schema
select e.extname, n.nspname as schema
from pg_extension e
join pg_namespace n on n.oid = e.extnamespace
order by 1;
