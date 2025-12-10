-- =====================================================
-- VALIDAÇÃO com usuários existentes (sem inserir user_account/member)
-- Gera ministério, evento e funções, vincula 2 usuários existentes
-- Valida unicidade de presença geral e por função; limpa ao final
-- =====================================================

DO $$
DECLARE
  v_user1_id uuid;
  v_user2_id uuid;
  v_ministry_id uuid;
  v_event_id uuid;
  v_func_vocal_id uuid;
  v_func_aux_id uuid;
BEGIN
  -- Selecionar 2 usuários existentes
  SELECT id INTO v_user1_id FROM public.user_account LIMIT 1;
  SELECT id INTO v_user2_id FROM public.user_account WHERE id <> v_user1_id LIMIT 1;

  IF v_user1_id IS NULL OR v_user2_id IS NULL THEN
    RAISE EXCEPTION 'É necessário ter pelo menos 2 usuários em public.user_account para validar.';
  END IF;

  -- Criar ministério
  INSERT INTO public.ministry (id, name, is_active)
  VALUES (gen_random_uuid(), 'Validação (existentes)', true)
  RETURNING id INTO v_ministry_id;

  -- Criar evento
  INSERT INTO public.event (id, name, start_date, is_mandatory)
  VALUES (gen_random_uuid(), 'Evento Validação (existentes)', CURRENT_DATE, false)
  RETURNING id INTO v_event_id;

  -- Criar funções
  INSERT INTO public.ministry_function (id, code, name, is_active)
  VALUES (gen_random_uuid(), 'VOCAL_TEST', 'Vocal Principal (Teste)', true)
  RETURNING id INTO v_func_vocal_id;

  INSERT INTO public.ministry_function (id, code, name, is_active)
  VALUES (gen_random_uuid(), 'AUX_TEST', 'Auxiliar (Teste)', true)
  RETURNING id INTO v_func_aux_id;

  -- Vincular usuários ao ministério (usa user_id)
  INSERT INTO public.ministry_member (id, ministry_id, user_id, role, joined_at)
  VALUES (gen_random_uuid(), v_ministry_id, v_user1_id, 'member', CURRENT_DATE);

  INSERT INTO public.ministry_member (id, ministry_id, user_id, role, joined_at)
  VALUES (gen_random_uuid(), v_ministry_id, v_user2_id, 'member', CURRENT_DATE);

  -- 1) Presença geral (sem função): duplicata deve falhar
  INSERT INTO public.ministry_schedule (event_id, ministry_id, user_id, notes)
  VALUES (v_event_id, v_ministry_id, v_user1_id, 'Presença Geral');

  BEGIN
    INSERT INTO public.ministry_schedule (event_id, ministry_id, user_id, notes)
    VALUES (v_event_id, v_ministry_id, v_user1_id, 'Presença Geral');
    RAISE EXCEPTION 'Esperava falha de unicidade (presença geral), mas inseriu.';
  EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'OK: unicidade de presença geral validada.';
  END;

  -- 2) Por função: funções distintas ok, mesma função deve falhar
  INSERT INTO public.ministry_schedule (event_id, ministry_id, user_id, function_id, notes)
  VALUES (v_event_id, v_ministry_id, v_user1_id, v_func_vocal_id, 'Vocal Principal (Teste)');

  INSERT INTO public.ministry_schedule (event_id, ministry_id, user_id, function_id, notes)
  VALUES (v_event_id, v_ministry_id, v_user1_id, v_func_aux_id, 'Auxiliar (Teste)');

  BEGIN
    INSERT INTO public.ministry_schedule (event_id, ministry_id, user_id, function_id, notes)
    VALUES (v_event_id, v_ministry_id, v_user1_id, v_func_vocal_id, 'Vocal Principal (Teste)');
    RAISE EXCEPTION 'Esperava falha de unicidade (mesma função), mas inseriu.';
  EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'OK: unicidade por função validada.';
  END;

  -- 3) Outro usuário com a mesma função no mesmo evento/ministério: permitido
  INSERT INTO public.ministry_schedule (event_id, ministry_id, user_id, function_id, notes)
  VALUES (v_event_id, v_ministry_id, v_user2_id, v_func_vocal_id, 'Vocal Principal (Teste)');

  -- Limpeza final
  DELETE FROM public.ministry_schedule WHERE event_id = v_event_id AND ministry_id = v_ministry_id;
  DELETE FROM public.ministry_member WHERE ministry_id = v_ministry_id AND user_id IN (v_user1_id, v_user2_id);
  DELETE FROM public.ministry_function WHERE id IN (v_func_vocal_id, v_func_aux_id);
  DELETE FROM public.event WHERE id = v_event_id;
  DELETE FROM public.ministry WHERE id = v_ministry_id;
END $$;

-- =====================================================
-- FIM
-- =====================================================
