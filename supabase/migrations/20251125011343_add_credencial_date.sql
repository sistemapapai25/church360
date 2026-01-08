ALTER TABLE user_account 
ADD COLUMN IF NOT EXISTS credencial_date DATE;

COMMENT ON COLUMN user_account.credencial_date IS 'Data de credenciamento do membro';;
