-- Inventario: grants em tabelas e funcoes

select table_schema, table_name, grantee, privilege_type
from information_schema.role_table_grants
where table_schema not in ('pg_catalog', 'information_schema')
order by 1,2,3,4;

select routine_schema, routine_name, grantee, privilege_type
from information_schema.role_routine_grants
where routine_schema not in ('pg_catalog', 'information_schema')
order by 1,2,3,4;
