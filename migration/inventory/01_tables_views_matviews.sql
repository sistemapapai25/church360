-- Inventario: tabelas, views, materialized views

select table_schema, table_name, table_type
from information_schema.tables
where table_schema not in ('pg_catalog', 'information_schema')
order by 1,2;

select schemaname as table_schema, matviewname as table_name, 'MATERIALIZED VIEW' as table_type
from pg_matviews
where schemaname not in ('pg_catalog', 'information_schema')
order by 1,2;
