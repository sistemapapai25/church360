-- ============================================
-- Script: Adicionar novos campos à tabela member
-- Descrição: Adiciona campos de apelido, CPF, data de casamento, profissão, complemento, bairro e tipo de membro
-- Data: 2025-10-17
-- ============================================

-- 1. Adicionar coluna de apelido (nickname)
ALTER TABLE member
ADD COLUMN IF NOT EXISTS nickname TEXT;

-- 2. Adicionar coluna de CPF
ALTER TABLE member
ADD COLUMN IF NOT EXISTS cpf TEXT;

-- 3. Adicionar coluna de data de casamento
ALTER TABLE member
ADD COLUMN IF NOT EXISTS marriage_date DATE;

-- 4. Adicionar coluna de profissão
ALTER TABLE member
ADD COLUMN IF NOT EXISTS profession TEXT;

-- 5. Adicionar coluna de complemento do endereço
ALTER TABLE member
ADD COLUMN IF NOT EXISTS address_complement TEXT;

-- 6. Adicionar coluna de bairro
ALTER TABLE member
ADD COLUMN IF NOT EXISTS neighborhood TEXT;

-- 7. Criar ENUM para tipo de membro (se não existir)
DO $$ BEGIN
  CREATE TYPE member_type AS ENUM (
    'titular',      -- Membro titular
    'congregado',   -- Congregado
    'cooperador',   -- Cooperador
    'crianca'       -- Criança
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- 8. Adicionar coluna de tipo de membro
ALTER TABLE member
ADD COLUMN IF NOT EXISTS member_type member_type;

-- 9. Adicionar comentários nas colunas para documentação
COMMENT ON COLUMN member.nickname IS 'Apelido do membro';
COMMENT ON COLUMN member.cpf IS 'CPF do membro (formato: 000.000.000-00)';
COMMENT ON COLUMN member.marriage_date IS 'Data de casamento do membro';
COMMENT ON COLUMN member.profession IS 'Profissão do membro';
COMMENT ON COLUMN member.address_complement IS 'Complemento do endereço (apto, bloco, etc)';
COMMENT ON COLUMN member.neighborhood IS 'Bairro do membro';
COMMENT ON COLUMN member.member_type IS 'Tipo de membro (titular, congregado, cooperador, criança)';

-- 10. Verificar se as colunas foram criadas
SELECT 
  column_name, 
  data_type, 
  is_nullable
FROM information_schema.columns
WHERE table_name = 'member'
  AND column_name IN ('nickname', 'cpf', 'marriage_date', 'profession', 'address_complement', 'neighborhood', 'member_type')
ORDER BY column_name;

