-- Adicionar coluna foto à tabela user_account
ALTER TABLE user_account 
ADD COLUMN IF NOT EXISTS foto TEXT;;
