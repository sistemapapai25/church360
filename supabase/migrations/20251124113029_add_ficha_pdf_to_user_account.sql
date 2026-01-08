-- Adicionar coluna ficha_pdf à tabela user_account
ALTER TABLE user_account 
ADD COLUMN IF NOT EXISTS ficha_pdf TEXT;;
