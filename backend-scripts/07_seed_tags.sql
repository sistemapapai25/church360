-- =====================================================
-- Script: Inserir Tags de Teste
-- Descrição: Insere tags comuns em igrejas e associa a membros
-- =====================================================

-- Limpar dados existentes (opcional - comentar se não quiser limpar)
DELETE FROM member_tag;
DELETE FROM tag;

-- Inserir tags comuns em igrejas
INSERT INTO tag (name, color, category) VALUES
  ('Batizado', '#2196F3', 'Espiritual'),
  ('Líder', '#FF9800', 'Ministério'),
  ('Músico', '#9C27B0', 'Ministério'),
  ('Professor EBD', '#4CAF50', 'Ministério'),
  ('Obreiro', '#F44336', 'Ministério'),
  ('Diácono', '#795548', 'Cargo'),
  ('Presbítero', '#607D8B', 'Cargo'),
  ('Jovem', '#00BCD4', 'Faixa Etária'),
  ('Criança', '#FFEB3B', 'Faixa Etária'),
  ('Intercessor', '#E91E63', 'Ministério'),
  ('Visitante Frequente', '#8BC34A', 'Status'),
  ('Novo Convertido', '#FFC107', 'Espiritual');

-- Buscar IDs das tags criadas
DO $$
DECLARE
  v_tag_batizado_id UUID;
  v_tag_lider_id UUID;
  v_tag_musico_id UUID;
  v_tag_professor_id UUID;
  v_tag_obreiro_id UUID;
  v_tag_jovem_id UUID;
  v_tag_intercessor_id UUID;
  v_tag_visitante_id UUID;
  v_tag_novo_id UUID;
  
  v_member_ids UUID[];
BEGIN
  -- Buscar IDs das tags
  SELECT id INTO v_tag_batizado_id FROM tag WHERE name = 'Batizado' LIMIT 1;
  SELECT id INTO v_tag_lider_id FROM tag WHERE name = 'Líder' LIMIT 1;
  SELECT id INTO v_tag_musico_id FROM tag WHERE name = 'Músico' LIMIT 1;
  SELECT id INTO v_tag_professor_id FROM tag WHERE name = 'Professor EBD' LIMIT 1;
  SELECT id INTO v_tag_obreiro_id FROM tag WHERE name = 'Obreiro' LIMIT 1;
  SELECT id INTO v_tag_jovem_id FROM tag WHERE name = 'Jovem' LIMIT 1;
  SELECT id INTO v_tag_intercessor_id FROM tag WHERE name = 'Intercessor' LIMIT 1;
  SELECT id INTO v_tag_visitante_id FROM tag WHERE name = 'Visitante Frequente' LIMIT 1;
  SELECT id INTO v_tag_novo_id FROM tag WHERE name = 'Novo Convertido' LIMIT 1;
  
  -- Buscar alguns membros para associar tags
  SELECT ARRAY_AGG(id) INTO v_member_ids 
  FROM (SELECT id FROM member WHERE status = 'member_active' LIMIT 10) AS members;
  
  -- Associar tags aos membros (exemplos)
  IF array_length(v_member_ids, 1) > 0 THEN
    -- Batizados (primeiros 8 membros)
    IF v_tag_batizado_id IS NOT NULL AND array_length(v_member_ids, 1) >= 8 THEN
      INSERT INTO member_tag (member_id, tag_id)
      SELECT unnest(v_member_ids[1:8]), v_tag_batizado_id
      ON CONFLICT DO NOTHING;
    END IF;
    
    -- Líderes (primeiros 3 membros)
    IF v_tag_lider_id IS NOT NULL AND array_length(v_member_ids, 1) >= 3 THEN
      INSERT INTO member_tag (member_id, tag_id)
      SELECT unnest(v_member_ids[1:3]), v_tag_lider_id
      ON CONFLICT DO NOTHING;
    END IF;
    
    -- Músicos (membros 2, 4, 6)
    IF v_tag_musico_id IS NOT NULL AND array_length(v_member_ids, 1) >= 6 THEN
      INSERT INTO member_tag (member_id, tag_id)
      VALUES 
        (v_member_ids[2], v_tag_musico_id),
        (v_member_ids[4], v_tag_musico_id),
        (v_member_ids[6], v_tag_musico_id)
      ON CONFLICT DO NOTHING;
    END IF;
    
    -- Professores EBD (membros 1, 3, 5)
    IF v_tag_professor_id IS NOT NULL AND array_length(v_member_ids, 1) >= 5 THEN
      INSERT INTO member_tag (member_id, tag_id)
      VALUES 
        (v_member_ids[1], v_tag_professor_id),
        (v_member_ids[3], v_tag_professor_id),
        (v_member_ids[5], v_tag_professor_id)
      ON CONFLICT DO NOTHING;
    END IF;
    
    -- Obreiros (primeiros 2 membros)
    IF v_tag_obreiro_id IS NOT NULL AND array_length(v_member_ids, 1) >= 2 THEN
      INSERT INTO member_tag (member_id, tag_id)
      SELECT unnest(v_member_ids[1:2]), v_tag_obreiro_id
      ON CONFLICT DO NOTHING;
    END IF;
    
    -- Jovens (membros 4, 5, 6, 7)
    IF v_tag_jovem_id IS NOT NULL AND array_length(v_member_ids, 1) >= 7 THEN
      INSERT INTO member_tag (member_id, tag_id)
      VALUES 
        (v_member_ids[4], v_tag_jovem_id),
        (v_member_ids[5], v_tag_jovem_id),
        (v_member_ids[6], v_tag_jovem_id),
        (v_member_ids[7], v_tag_jovem_id)
      ON CONFLICT DO NOTHING;
    END IF;
    
    -- Intercessores (membros 1, 2, 8)
    IF v_tag_intercessor_id IS NOT NULL AND array_length(v_member_ids, 1) >= 8 THEN
      INSERT INTO member_tag (member_id, tag_id)
      VALUES 
        (v_member_ids[1], v_tag_intercessor_id),
        (v_member_ids[2], v_tag_intercessor_id),
        (v_member_ids[8], v_tag_intercessor_id)
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;
  
  -- Associar tag "Visitante Frequente" a visitantes
  IF v_tag_visitante_id IS NOT NULL THEN
    INSERT INTO member_tag (member_id, tag_id)
    SELECT id, v_tag_visitante_id
    FROM member
    WHERE status = 'visitor'
    LIMIT 3
    ON CONFLICT DO NOTHING;
  END IF;
  
  -- Associar tag "Novo Convertido" a membros recentes (últimos 30 dias)
  IF v_tag_novo_id IS NOT NULL THEN
    INSERT INTO member_tag (member_id, tag_id)
    SELECT id, v_tag_novo_id
    FROM member
    WHERE conversion_date >= CURRENT_DATE - INTERVAL '30 days'
    LIMIT 2
    ON CONFLICT DO NOTHING;
  END IF;
END $$;

-- Mostrar estatísticas
SELECT 
  'Tags criadas' AS metric,
  COUNT(*) AS value
FROM tag

UNION ALL

SELECT 
  'Associações membro-tag' AS metric,
  COUNT(*) AS value
FROM member_tag

UNION ALL

SELECT 
  'Tags mais usadas' AS metric,
  NULL AS value
FROM tag
LIMIT 1;

-- Mostrar tags mais usadas
SELECT 
  t.name AS tag_name,
  t.color,
  COUNT(mt.member_id) AS member_count
FROM tag t
LEFT JOIN member_tag mt ON t.id = mt.tag_id
GROUP BY t.id, t.name, t.color
ORDER BY member_count DESC, t.name;

