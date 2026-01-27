ALTER TABLE public.church_settings
  ADD COLUMN IF NOT EXISTS igreja_cnpj text,
  ADD COLUMN IF NOT EXISTS responsavel_nome text,
  ADD COLUMN IF NOT EXISTS responsavel_cpf text,
  ADD COLUMN IF NOT EXISTS assinatura_path text;
