-- Inventario: storage (buckets e objetos)

select id, name, public, created_at
from storage.buckets
order by name;

select bucket_id, count(*) as total
from storage.objects
group by 1
order by 1;

select bucket_id,
       sum(coalesce((metadata->>'size')::bigint, 0)) as total_bytes
from storage.objects
group by 1
order by 1;

-- Policies do storage.objects
select schemaname, tablename, policyname, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'storage' and tablename = 'objects'
order by 1,2,3;

-- Status de RLS no schema storage
select schemaname, tablename, rowsecurity, forcerowsecurity
from pg_tables
where schemaname = 'storage'
order by 1,2;
