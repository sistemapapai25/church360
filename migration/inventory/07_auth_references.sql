-- Inventario: colunas relacionadas a usuario (Auth)

-- FKs formais para auth.users
select
  n.nspname as schema,
  c.relname as table,
  a.attname as column,
  con.conname as fk_name
from pg_constraint con
join pg_class c on c.oid = con.conrelid
join pg_namespace n on n.oid = c.relnamespace
join pg_attribute a on a.attrelid = con.conrelid and a.attnum = any(con.conkey)
join pg_class cf on cf.oid = con.confrelid
join pg_namespace nf on nf.oid = cf.relnamespace
where con.contype = 'f'
  and nf.nspname = 'auth'
  and cf.relname = 'users'
order by 1,2,3;

-- Heuristica: colunas UUID com nomes tipicos de usuario (apenas BASE TABLE)
select c.table_schema, c.table_name, c.column_name, c.data_type
from information_schema.columns c
join information_schema.tables t
  on t.table_schema = c.table_schema
 and t.table_name = c.table_name
where c.table_schema not in ('pg_catalog', 'information_schema', 'auth', 'storage')
  and t.table_type = 'BASE TABLE'
  and c.data_type = 'uuid'
  and (
    c.column_name in (
      'user_id','created_by','updated_by','auth_user_id','owner','member_id',
      'author_id','assignee_id','created_user_id','updated_user_id',
      'created_by_user_id','updated_by_user_id'
    )
    or c.column_name like '%_user_id'
    or c.column_name like '%_by'
    or c.column_name like '%owner%'
  )
order by 1,2,3;
