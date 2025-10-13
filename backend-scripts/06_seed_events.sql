-- =====================================================
-- SEED DATA: EVENTOS
-- =====================================================
-- Este script insere eventos de teste no banco de dados
-- =====================================================

-- Limpar dados existentes (opcional - cuidado em produção!)
-- DELETE FROM event_registration;
-- DELETE FROM event;

-- Inserir eventos de teste
INSERT INTO event (
  name,
  description,
  event_type,
  start_date,
  end_date,
  location,
  max_capacity,
  requires_registration,
  status
) VALUES
  -- Cultos regulares (próximos)
  (
    'Culto de Celebração',
    'Culto de domingo com louvor e pregação da Palavra',
    'Culto',
    CURRENT_DATE + INTERVAL '3 days' + TIME '10:00:00',
    CURRENT_DATE + INTERVAL '3 days' + TIME '12:00:00',
    'Templo Principal',
    300,
    false,
    'published'
  ),
  (
    'Culto de Oração',
    'Culto de quarta-feira focado em oração e intercessão',
    'Culto',
    CURRENT_DATE + INTERVAL '5 days' + TIME '19:30:00',
    CURRENT_DATE + INTERVAL '5 days' + TIME '21:00:00',
    'Templo Principal',
    150,
    false,
    'published'
  ),
  
  -- Eventos especiais (futuros)
  (
    'Conferência de Jovens 2025',
    'Conferência anual para jovens com pregadores convidados, louvor e workshops',
    'Conferência',
    CURRENT_DATE + INTERVAL '30 days' + TIME '18:00:00',
    CURRENT_DATE + INTERVAL '32 days' + TIME '22:00:00',
    'Centro de Convenções',
    500,
    true,
    'published'
  ),
  (
    'Retiro de Casais',
    'Fim de semana especial para fortalecimento de casamentos',
    'Retiro',
    CURRENT_DATE + INTERVAL '45 days' + TIME '14:00:00',
    CURRENT_DATE + INTERVAL '47 days' + TIME '16:00:00',
    'Sítio Recanto da Paz',
    50,
    true,
    'published'
  ),
  (
    'Escola Bíblica Dominical',
    'Aulas de estudo bíblico para todas as idades',
    'Ensino',
    CURRENT_DATE + INTERVAL '3 days' + TIME '09:00:00',
    CURRENT_DATE + INTERVAL '3 days' + TIME '10:00:00',
    'Salas de Aula',
    200,
    false,
    'published'
  ),
  
  -- Eventos passados
  (
    'Culto de Ação de Graças',
    'Culto especial de gratidão a Deus',
    'Culto',
    CURRENT_DATE - INTERVAL '7 days' + TIME '19:00:00',
    CURRENT_DATE - INTERVAL '7 days' + TIME '21:00:00',
    'Templo Principal',
    300,
    false,
    'completed'
  ),
  (
    'Batismo nas Águas',
    'Cerimônia de batismo para novos convertidos',
    'Batismo',
    CURRENT_DATE - INTERVAL '14 days' + TIME '15:00:00',
    CURRENT_DATE - INTERVAL '14 days' + TIME '17:00:00',
    'Batistério da Igreja',
    30,
    true,
    'completed'
  ),

  -- Evento cancelado
  (
    'Acampamento de Férias',
    'Acampamento de verão para crianças e adolescentes',
    'Acampamento',
    CURRENT_DATE + INTERVAL '60 days' + TIME '08:00:00',
    CURRENT_DATE + INTERVAL '65 days' + TIME '18:00:00',
    'Camping Águas Claras',
    100,
    true,
    'cancelled'
  );

-- Buscar IDs dos eventos e membros para criar inscrições
DO $$
DECLARE
  v_event_conferencia_id UUID;
  v_event_retiro_id UUID;
  v_event_batismo_id UUID;
  v_member_ids UUID[];
BEGIN
  -- Buscar ID do evento de conferência
  SELECT id INTO v_event_conferencia_id
  FROM event
  WHERE name = 'Conferência de Jovens 2025'
  LIMIT 1;
  
  -- Buscar ID do evento de retiro
  SELECT id INTO v_event_retiro_id
  FROM event
  WHERE name = 'Retiro de Casais'
  LIMIT 1;
  
  -- Buscar ID do evento de batismo (passado)
  SELECT id INTO v_event_batismo_id
  FROM event
  WHERE name = 'Batismo nas Águas'
  LIMIT 1;
  
  -- Buscar alguns IDs de membros
  SELECT ARRAY_AGG(id) INTO v_member_ids
  FROM (
    SELECT id FROM member LIMIT 5
  ) AS members;
  
  -- Inserir inscrições para a conferência (eventos futuros)
  IF v_event_conferencia_id IS NOT NULL AND array_length(v_member_ids, 1) > 0 THEN
    INSERT INTO event_registration (event_id, member_id)
    SELECT v_event_conferencia_id, unnest(v_member_ids[1:3]);
  END IF;

  -- Inserir inscrições para o retiro
  IF v_event_retiro_id IS NOT NULL AND array_length(v_member_ids, 1) > 1 THEN
    INSERT INTO event_registration (event_id, member_id)
    SELECT v_event_retiro_id, unnest(v_member_ids[2:4]);
  END IF;
  
  -- Inserir inscrições para o batismo (evento passado) com check-in marcado
  IF v_event_batismo_id IS NOT NULL AND array_length(v_member_ids, 1) > 2 THEN
    INSERT INTO event_registration (event_id, member_id, checked_in_at)
    SELECT
      v_event_batismo_id,
      unnest(v_member_ids[1:3]),
      CURRENT_DATE - INTERVAL '14 days' + TIME '15:30:00';
  END IF;
END $$;

-- Verificar dados inseridos
SELECT 
  'Eventos criados' AS metric,
  COUNT(*) AS value
FROM event

UNION ALL

SELECT
  'Eventos ativos' AS metric,
  COUNT(*) AS value
FROM event
WHERE status != 'cancelled'

UNION ALL

SELECT
  'Eventos futuros' AS metric,
  COUNT(*) AS value
FROM event
WHERE status != 'cancelled' AND start_date > NOW()

UNION ALL

SELECT 
  'Total de inscrições' AS metric,
  COUNT(*) AS value
FROM event_registration;

