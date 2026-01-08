ALTER TABLE user_account 
ADD COLUMN IF NOT EXISTS entrevista BOOLEAN DEFAULT false;

COMMENT ON COLUMN user_account.entrevista IS 'Indica se o membro passou por entrevista';;
