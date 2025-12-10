-- =====================================================
-- VALIDAÇÃO: ministry_schedule com function_id e índices únicos condicionais
-- Cenário de teste completo com dados sintéticos (rollback automático)
-- =====================================================

BEGIN;

-- Preparar dados mínimos
-- Usuário/conta
INSERT INTO public.user_account (id, first_name, last_name)
VALUES (gen_random_uuid(), 'Teste', 'Usuario')
RETURNING id INTO STRICT user_id;

-- Membros (2)
INSERT INTO public.member (id, user_account_id, first_name, last_name)
VALUES (gen_random_uuid(), user_id, 'Joao', 'Silva')
RETURNING id INTO STRICT member1_id;

INSERT INTO public.member (id, first_name, last_name)
VALUES (gen_random_uuid(), 'Maria', 'Souza')
RETURNING id INTO STRICT member2_id;

-- Ministério
INSERT INTO public.ministry (id, name, is_active)
VALUES (gen_random_uuid(), 'Validação Ministério', true)
RETURNING id INTO STRICT ministry_id;

-- Evento
INSERT INTO public.event (id, name, start_date, is_mandatory)
VALUES (gen_random_uuid(), 'Evento Validação', CURRENT_DATE, false)
RETURNING id INTO STRICT event_id;

-- Funções
INSERT INTO public.ministry_function (id, code, name, is_active)
VALUES (gen_random_uuid(), 'VOCAL', 'Vocal Principal', true)
RETURNING id INTO STRICT func_vocal_id;

INSERT INTO public.ministry_function (id, code, name, is_active)
VALUES (gen_random_uuid(), 'AUX', 'Auxiliar', true)
RETURNING id INTO STRICT func_aux_id;

-- Vincular membros ao ministério
INSERT INTO public.ministry_member (id, ministry_id, user_id, role, joined_at)
VALUES (gen_random_uuid(), ministry_id, member1_id, 'member', CURRENT_DATE);

INSERT INTO public.ministry_member (id, ministry_id, user_id, role, joined_at)
VALUES (gen_random_uuid(), ministry_id, member2_id, 'member', CURRENT_DATE);

-- 1) Presença geral (sem função): permite 1 por (evento, ministério, membro), bloqueia duplicata
INSERT INTO public.ministry_schedule (event_id, ministry_id, user_id, notes)
VALUES (event_id, ministry_id, member1_id, 'Presença Geral');

-- Deve FALHAR (duplicata de presença geral)
DO $$
BEGIN
  BEGIN
    INSERT INTO public.ministry_schedule (event_id, ministry_id, user_id, notes)
    VALUES (event_id, ministry_id, member1_id, 'Presença Geral');
    RAISE EXCEPTION 'Esperava falha de unicidade (presença geral), mas inseriu.';
  EXCEPTION WHEN unique_violation THEN
    -- OK
    NULL;
  END;
END $$;

-- 2) Por função: permite múltiplas funções distintas, bloqueia duplicata da mesma função
INSERT INTO public.ministry_schedule (event_id, ministry_id, user_id, function_id, notes)
VALUES (event_id, ministry_id, member1_id, func_vocal_id, 'Vocal Principal');

INSERT INTO public.ministry_schedule (event_id, ministry_id, user_id, function_id, notes)
VALUES (event_id, ministry_id, member1_id, func_aux_id, 'Auxiliar');

-- Deve FALHAR (mesma função repetida)
DO $$
BEGIN
  BEGIN
    INSERT INTO public.ministry_schedule (event_id, ministry_id, user_id, function_id, notes)
    VALUES (event_id, ministry_id, member1_id, func_vocal_id, 'Vocal Principal');
    RAISE EXCEPTION 'Esperava falha de unicidade (mesma função), mas inseriu.';
  EXCEPTION WHEN unique_violation THEN
    -- OK
    NULL;
  END;
END $$;

-- 3) Outro membro com mesma função no mesmo evento/ministério: permitido
INSERT INTO public.ministry_schedule (event_id, ministry_id, user_id, function_id, notes)
VALUES (event_id, ministry_id, member2_id, func_vocal_id, 'Vocal Principal');

-- Limpeza automática
ROLLBACK;

-- =====================================================
-- FIM
-- =====================================================
