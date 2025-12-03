-- ============================================
-- Church 360 - Migration: add entrevistador column
-- ============================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'user_account'
      AND column_name = 'entrevistador'
  ) THEN
    ALTER TABLE user_account
      ADD COLUMN entrevistador BOOLEAN DEFAULT FALSE;

    COMMENT ON COLUMN user_account.entrevistador IS 'Indica se o usuário é entrevistador';
  END IF;
END $$;

RAISE NOTICE '✅ Column entrevistador created or already exists';

