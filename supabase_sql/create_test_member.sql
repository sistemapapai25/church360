-- ============================================
-- CRIAR MEMBRO DE TESTE PARA O USUÁRIO LOGADO
-- ============================================
-- 
-- Este script cria um membro de teste vinculado ao email do usuário logado
-- Execute este script no Supabase SQL Editor
--
-- IMPORTANTE: Substitua 'SEU_EMAIL_AQUI' pelo email que você usa para fazer login!
-- ============================================

-- PASSO 1: Verificar se já existe um membro com este email
-- (Execute esta query primeiro para ver se já existe)
SELECT * FROM member WHERE email = 'SEU_EMAIL_AQUI';

-- PASSO 2: Se não existir, criar o membro
-- (Substitua 'SEU_EMAIL_AQUI' pelo seu email de login)
INSERT INTO member (
  first_name,
  last_name,
  email,
  phone,
  birthdate,
  gender,
  marital_status,
  status,
  photo_url,
  address,
  city,
  state,
  zip_code,
  conversion_date,
  baptism_date,
  membership_date,
  notes
) VALUES (
  'Alcides',                          -- Primeiro nome
  'Costa',                            -- Sobrenome
  'SEU_EMAIL_AQUI',                   -- ⚠️ SUBSTITUA PELO SEU EMAIL DE LOGIN!
  '(11) 99999-9999',                  -- Telefone
  '1990-01-01',                       -- Data de nascimento
  'male',                             -- Gênero: 'male', 'female', 'other'
  'married',                          -- Estado civil: 'single', 'married', 'divorced', 'widowed'
  'member_active',                    -- Status: 'visitor', 'new_convert', 'member_active', 'member_inactive', 'transferred', 'deceased'
  NULL,                               -- URL da foto (deixe NULL por enquanto)
  'Rua Exemplo, 123',                 -- Endereço
  'São Paulo',                        -- Cidade
  'SP',                               -- Estado
  '01234-567',                        -- CEP
  '2020-01-01',                       -- Data de conversão
  '2020-02-15',                       -- Data de batismo
  '2020-03-01',                       -- Data de membresia
  'Membro de teste criado para vincular ao usuário logado' -- Observações
)
ON CONFLICT (email) DO UPDATE SET
  first_name = EXCLUDED.first_name,
  last_name = EXCLUDED.last_name,
  updated_at = NOW();

-- PASSO 3: Verificar se foi criado com sucesso
SELECT 
  id,
  first_name,
  last_name,
  email,
  status,
  created_at
FROM member 
WHERE email = 'SEU_EMAIL_AQUI';

-- ============================================
-- ALTERNATIVA: Se você não sabe qual é o email do usuário logado
-- ============================================
-- Execute esta query para ver todos os usuários cadastrados no auth:
-- (Você precisa ter permissão de admin para ver isso)

-- SELECT 
--   id,
--   email,
--   created_at,
--   last_sign_in_at
-- FROM auth.users
-- ORDER BY created_at DESC;

-- ============================================
-- EXEMPLO COMPLETO COM EMAIL REAL
-- ============================================
-- Aqui está um exemplo de como deve ficar após substituir o email:
--
-- INSERT INTO member (
--   first_name, last_name, email, phone, birthdate, gender, marital_status, status
-- ) VALUES (
--   'Alcides', 'Costa', 'alcidescostant@hotmail.com', '(11) 99999-9999', 
--   '1990-01-01', 'male', 'married', 'member_active'
-- );
-- ============================================

