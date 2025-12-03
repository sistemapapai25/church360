-- Alterar tabela de eventos para incluir campo de obrigatoriedade
ALTER TABLE public.event
ADD COLUMN IF NOT EXISTS is_mandatory BOOLEAN DEFAULT false;

-- Índice opcional para consultas por obrigatoriedade
CREATE INDEX IF NOT EXISTS idx_event_is_mandatory ON public.event(is_mandatory);

