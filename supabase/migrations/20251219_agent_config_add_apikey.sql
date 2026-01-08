alter table public.agent_config 
add column if not exists openai_api_key text;
