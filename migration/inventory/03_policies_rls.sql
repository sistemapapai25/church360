-- Inventario: RLS e policies

select schemaname, tablename, rowsecurity, forcerowsecurity
from pg_tables
where schemaname not in ('pg_catalog', 'information_schema')
order by 1,2;

select schemaname, tablename, policyname, roles, cmd, qual, with_check
from pg_policies
where schemaname not in ('pg_catalog', 'information_schema')
order by 1,2,3;
