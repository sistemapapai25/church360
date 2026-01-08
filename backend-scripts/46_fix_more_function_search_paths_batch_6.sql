-- =====================================================
-- CORREÇÃO: Function Search Path Mutable (Security) - Parte 6
-- =====================================================
-- Descrição: Recria mais funções apontadas pelo Security Advisor (Batch 6)
-- definindo explicitamente o search_path para evitar injeção de schema.
-- =====================================================

-- 1. update_study_groups_updated_at
CREATE OR REPLACE FUNCTION public.update_study_groups_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

-- 2. update_study_lessons_updated_at
CREATE OR REPLACE FUNCTION public.update_study_lessons_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

-- 3. update_study_participants_updated_at
CREATE OR REPLACE FUNCTION public.update_study_participants_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

-- 4. update_study_attendance_updated_at
CREATE OR REPLACE FUNCTION public.update_study_attendance_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

-- 5. update_study_comments_updated_at
CREATE OR REPLACE FUNCTION public.update_study_comments_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

-- 6. update_study_resources_updated_at
CREATE OR REPLACE FUNCTION public.update_study_resources_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

-- 7. add_creator_as_leader
CREATE OR REPLACE FUNCTION public.add_creator_as_leader()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  INSERT INTO public.study_participants (study_group_id, user_id, role)
  VALUES (NEW.id, NEW.created_by, 'leader')
  ON CONFLICT (study_group_id, user_id) DO NOTHING;

  RETURN NEW;
END;
$function$;

-- 8. notify_new_lesson
CREATE OR REPLACE FUNCTION public.notify_new_lesson()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
  group_name TEXT;
  participant_record RECORD;
BEGIN
  -- Apenas notificar quando lição é publicada
  IF NEW.status != 'published' OR (OLD.status IS NOT NULL AND OLD.status = 'published') THEN
    RETURN NEW;
  END IF;

  -- Buscar nome do grupo
  SELECT name INTO group_name
  FROM public.study_groups
  WHERE id = NEW.study_group_id;

  -- Notificar todos os participantes ativos
  FOR participant_record IN
    SELECT user_id
    FROM public.study_participants
    WHERE study_group_id = NEW.study_group_id
    AND is_active = true
  LOOP
    INSERT INTO public.notifications (
      user_id,
      type,
      title,
      body,
      data,
      route,
      status
    ) VALUES (
      participant_record.user_id,
      'general',
      'Nova Lição Publicada! 📖',
      'Nova lição disponível no grupo "' || group_name || '": ' || NEW.title,
      jsonb_build_object('study_group_id', NEW.study_group_id, 'study_lesson_id', NEW.id),
      '/study-groups/' || NEW.study_group_id || '/lessons/' || NEW.id,
      'pending'
    );
  END LOOP;

  RETURN NEW;
END;
$function$;

-- 9. update_support_material_updated_at
CREATE OR REPLACE FUNCTION public.update_support_material_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;
