-- Script para inserir membros de teste
-- Execute este script no Supabase SQL Editor

-- Inserir membros de exemplo
INSERT INTO member (
  first_name,
  last_name,
  email,
  phone,
  birthdate,
  gender,
  marital_status,
  status,
  membership_date,
  address,
  city,
  state,
  zip_code
) VALUES
  -- Membros Ativos
  (
    'João',
    'Silva',
    'joao.silva@email.com',
    '(11) 98765-4321',
    '1985-03-15',
    'male',
    'married',
    'member_active',
    '2020-01-10',
    'Rua das Flores, 123',
    'São Paulo',
    'SP',
    '01234-567'
  ),
  (
    'Maria',
    'Santos',
    'maria.santos@email.com',
    '(11) 98765-4322',
    '1990-07-22',
    'female',
    'married',
    'member_active',
    '2020-01-10',
    'Rua das Flores, 123',
    'São Paulo',
    'SP',
    '01234-567'
  ),
  (
    'Pedro',
    'Oliveira',
    'pedro.oliveira@email.com',
    '(11) 98765-4323',
    '1978-11-30',
    'male',
    'single',
    'member_active',
    '2019-05-20',
    'Av. Paulista, 1000',
    'São Paulo',
    'SP',
    '01310-100'
  ),
  (
    'Ana',
    'Costa',
    'ana.costa@email.com',
    '(11) 98765-4324',
    '1995-02-14',
    'female',
    'single',
    'member_active',
    '2021-03-15',
    'Rua Augusta, 500',
    'São Paulo',
    'SP',
    '01305-000'
  ),
  (
    'Carlos',
    'Ferreira',
    'carlos.ferreira@email.com',
    '(11) 98765-4325',
    '1982-09-08',
    'male',
    'married',
    'member_active',
    '2018-07-01',
    'Rua Consolação, 200',
    'São Paulo',
    'SP',
    '01301-000'
  ),
  
  -- Visitantes
  (
    'Juliana',
    'Almeida',
    'juliana.almeida@email.com',
    '(11) 98765-4326',
    '1992-05-20',
    'female',
    'single',
    'visitor',
    NULL,
    NULL,
    'São Paulo',
    'SP',
    NULL
  ),
  (
    'Roberto',
    'Lima',
    'roberto.lima@email.com',
    '(11) 98765-4327',
    '1988-12-03',
    'male',
    'married',
    'visitor',
    NULL,
    NULL,
    'São Paulo',
    'SP',
    NULL
  ),
  (
    'Fernanda',
    'Rodrigues',
    'fernanda.rodrigues@email.com',
    '(11) 98765-4328',
    '1997-08-17',
    'female',
    'single',
    'visitor',
    NULL,
    NULL,
    'São Paulo',
    'SP',
    NULL
  ),
  
  -- Membros Inativos
  (
    'Lucas',
    'Martins',
    'lucas.martins@email.com',
    '(11) 98765-4329',
    '1980-04-25',
    'male',
    'divorced',
    'member_inactive',
    '2015-02-10',
    'Rua Vergueiro, 300',
    'São Paulo',
    'SP',
    '01504-000'
  ),
  (
    'Patrícia',
    'Souza',
    'patricia.souza@email.com',
    '(11) 98765-4330',
    '1987-10-12',
    'female',
    'single',
    'member_inactive',
    '2016-08-20',
    'Av. Rebouças, 1500',
    'São Paulo',
    'SP',
    '05401-100'
  );

-- Verificar membros inseridos
SELECT
  id,
  first_name || ' ' || last_name AS full_name,
  email,
  status,
  membership_date
FROM member
ORDER BY first_name;

-- Contar membros por status
SELECT 
  status,
  COUNT(*) as total
FROM member
GROUP BY status
ORDER BY status;

