-- =====================================================
-- MIGRAÇÃO 32: Migrar notes -> function_id usando ministry_function (name/code)
-- Objetivo: Eliminar dependência de fallback por nome no app
-- =====================================================

BEGIN;

-- Normalizar notes e name/code para comparação case-insensitive
-- Atualizar function_id quando notes corresponder ao nome ou código da função
UPDATE public.ministry_schedule ms
SET function_id = mf.id
FROM public.ministry_function mf
WHERE ms.function_id IS NULL
  AND ms.notes IS NOT NULL
  AND (
    LOWER(TRIM(ms.notes)) = LOWER(TRIM(mf.name)) OR
    LOWER(TRIM(ms.notes)) = LOWER(TRIM(mf.code))
  );

-- Opcional: remover espaços em branco em notes
UPDATE public.ministry_schedule
SET notes = NULLIF(TRIM(notes), '')
WHERE TRUE;

COMMIT;

-- =====================================================
-- FIM
-- =====================================================
