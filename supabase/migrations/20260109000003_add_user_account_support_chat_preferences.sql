DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_account'
  ) THEN
    ALTER TABLE public.user_account
      ADD COLUMN IF NOT EXISTS support_chat_preferences jsonb NOT NULL DEFAULT '{}'::jsonb;
  END IF;
END $$;

