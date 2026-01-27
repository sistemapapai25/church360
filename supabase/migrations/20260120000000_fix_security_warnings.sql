-- Fix SECURITY DEFINER views to use SECURITY INVOKER
-- This ensures that the views respect the RLS policies of the invoking user
ALTER VIEW IF EXISTS public.vw_conciliacao SET (security_invoker = true);
ALTER VIEW IF EXISTS public.vw_lancamentos_whatsapp SET (security_invoker = true);
ALTER VIEW IF EXISTS public.vw_culto_totais SET (security_invoker = true);

-- Enable RLS on stepbible_lexeme_raw
ALTER TABLE IF EXISTS public.stepbible_lexeme_raw ENABLE ROW LEVEL SECURITY;

-- Add read-only policy for stepbible_lexeme_raw
-- We use a DO block to avoid errors if the policy already exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'stepbible_lexeme_raw'
  ) THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'stepbible_lexeme_raw'
        AND policyname = 'Allow public read access'
    ) THEN
      CREATE POLICY "Allow public read access"
        ON public.stepbible_lexeme_raw
        FOR SELECT
        USING (true);
    END IF;
  END IF;
END $$;
