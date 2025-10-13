-- =====================================================
-- Script: 05_seed_groups.sql
-- Descrição: Inserir grupos/células de teste
-- =====================================================

-- Inserir grupos de teste
INSERT INTO "group" (
  name,
  description,
  leader_id,
  meeting_day_of_week,
  meeting_time,
  meeting_address,
  is_active
) VALUES
-- Grupo 1: Célula Jovens (Sexta-feira = 5)
(
  'Célula Jovens - Centro',
  'Grupo de jovens que se reúne no centro da cidade para estudos bíblicos e comunhão',
  (SELECT id FROM member WHERE first_name = 'Ana' AND last_name = 'Silva' LIMIT 1),
  5,
  '19:30',
  'Rua das Flores, 123 - Centro',
  true
),

-- Grupo 2: Célula Casais (Sábado = 6)
(
  'Célula Casais - Zona Norte',
  'Grupo de casais focado em fortalecer relacionamentos e família',
  (SELECT id FROM member WHERE first_name = 'Carlos' AND last_name = 'Santos' LIMIT 1),
  6,
  '18:00',
  'Av. Principal, 456 - Zona Norte',
  true
),

-- Grupo 3: Célula Mulheres (Quarta-feira = 3)
(
  'Célula Mulheres de Fé',
  'Grupo de mulheres para oração, estudo e apoio mútuo',
  (SELECT id FROM member WHERE first_name = 'Maria' AND last_name = 'Oliveira' LIMIT 1),
  3,
  '14:00',
  'Igreja - Sala 2',
  true
),

-- Grupo 4: Célula Homens (Terça-feira = 2)
(
  'Célula Homens de Valor',
  'Grupo de homens para crescimento espiritual e liderança',
  (SELECT id FROM member WHERE first_name = 'João' AND last_name = 'Costa' LIMIT 1),
  2,
  '20:00',
  'Igreja - Sala 3',
  true
),

-- Grupo 5: Célula Adolescentes (Domingo = 0)
(
  'Célula Teen - Geração Z',
  'Grupo de adolescentes com atividades dinâmicas e relevantes',
  (SELECT id FROM member WHERE first_name = 'Pedro' AND last_name = 'Almeida' LIMIT 1),
  0,
  '16:00',
  'Igreja - Auditório',
  true
),

-- Grupo 6: Célula Inativa (para teste)
(
  'Célula Antiga - Desativada',
  'Grupo que foi desativado',
  NULL,
  NULL,
  NULL,
  NULL,
  false
);

-- Adicionar membros aos grupos
-- Grupo 1: Célula Jovens (5 membros)
INSERT INTO group_member (group_id, member_id, role)
SELECT 
  g.id,
  m.id,
  CASE 
    WHEN m.first_name = 'Ana' THEN 'leader'
    ELSE 'member'
  END
FROM "group" g
CROSS JOIN member m
WHERE g.name = 'Célula Jovens - Centro'
  AND m.first_name IN ('Ana', 'Pedro', 'Lucas')
LIMIT 3;

-- Grupo 2: Célula Casais (4 membros)
INSERT INTO group_member (group_id, member_id, role)
SELECT 
  g.id,
  m.id,
  CASE 
    WHEN m.first_name = 'Carlos' THEN 'leader'
    ELSE 'member'
  END
FROM "group" g
CROSS JOIN member m
WHERE g.name = 'Célula Casais - Zona Norte'
  AND m.first_name IN ('Carlos', 'Maria')
LIMIT 2;

-- Grupo 3: Célula Mulheres (6 membros)
INSERT INTO group_member (group_id, member_id, role)
SELECT 
  g.id,
  m.id,
  CASE 
    WHEN m.first_name = 'Maria' THEN 'leader'
    ELSE 'member'
  END
FROM "group" g
CROSS JOIN member m
WHERE g.name = 'Célula Mulheres de Fé'
  AND m.first_name IN ('Maria', 'Ana', 'Julia')
LIMIT 3;

-- Grupo 4: Célula Homens (5 membros)
INSERT INTO group_member (group_id, member_id, role)
SELECT 
  g.id,
  m.id,
  CASE 
    WHEN m.first_name = 'João' THEN 'leader'
    ELSE 'member'
  END
FROM "group" g
CROSS JOIN member m
WHERE g.name = 'Célula Homens de Valor'
  AND m.first_name IN ('João', 'Carlos', 'Pedro')
LIMIT 3;

-- Grupo 5: Célula Adolescentes (7 membros)
INSERT INTO group_member (group_id, member_id, role)
SELECT 
  g.id,
  m.id,
  CASE 
    WHEN m.first_name = 'Pedro' THEN 'leader'
    ELSE 'member'
  END
FROM "group" g
CROSS JOIN member m
WHERE g.name = 'Célula Teen - Geração Z'
  AND m.first_name IN ('Pedro', 'Lucas', 'Ana')
LIMIT 3;

-- Verificar grupos inseridos
SELECT
  g.id,
  g.name,
  g.meeting_day_of_week,
  g.meeting_time,
  g.is_active,
  m.first_name || ' ' || m.last_name AS leader_name,
  COUNT(gm.member_id) AS member_count
FROM "group" g
LEFT JOIN member m ON g.leader_id = m.id
LEFT JOIN group_member gm ON g.id = gm.group_id
GROUP BY g.id, g.name, g.meeting_day_of_week, g.meeting_time, g.is_active, m.first_name, m.last_name
ORDER BY g.is_active DESC, g.name;

-- Estatísticas
SELECT 
  'Total de grupos' AS metric,
  COUNT(*) AS value
FROM "group"
UNION ALL
SELECT 
  'Grupos ativos' AS metric,
  COUNT(*) AS value
FROM "group"
WHERE is_active = true
UNION ALL
SELECT 
  'Grupos inativos' AS metric,
  COUNT(*) AS value
FROM "group"
WHERE is_active = false
UNION ALL
SELECT 
  'Total de membros em grupos' AS metric,
  COUNT(DISTINCT member_id) AS value
FROM group_member;

