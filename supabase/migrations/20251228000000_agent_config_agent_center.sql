alter table public.agent_config
add column if not exists display_name text;

alter table public.agent_config
add column if not exists subtitle text;

alter table public.agent_config
add column if not exists avatar_url text;

alter table public.agent_config
add column if not exists theme_color text;

alter table public.agent_config
add column if not exists show_on_home boolean default false;

alter table public.agent_config
add column if not exists show_on_dashboard boolean default false;

alter table public.agent_config
add column if not exists show_floating_button boolean default false;

alter table public.agent_config
add column if not exists floating_route text;

alter table public.agent_config
add column if not exists allowed_access_levels text[] default array[]::text[];

update public.agent_config
set display_name = coalesce(display_name, name)
where display_name is null;
