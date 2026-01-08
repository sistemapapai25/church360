create table if not exists public.agent_config (
    key text primary key,
    assistant_id text not null,
    name text,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

alter table public.agent_config enable row level security;

drop policy if exists "Enable read access for all users" on public.agent_config;
create policy "Enable read access for all users" on public.agent_config
    for select using (true);

drop policy if exists "Enable all access for authenticated users with role owner" on public.agent_config;
create policy "Enable all access for authenticated users with role owner" on public.agent_config
    for all using (
        auth.uid() in (
            select id from public.user_account where role_global = 'owner'
        )
    );

-- Insert default values (placeholders)
insert into public.agent_config (key, assistant_id, name)
values 
    ('default', 'asst_PLACEHOLDER_DEFAULT', 'Padrão'),
    ('kids', 'asst_PLACEHOLDER_KIDS', 'Infantil'),
    ('media', 'asst_PLACEHOLDER_MEDIA', 'Mídia')
on conflict (key) do nothing;
