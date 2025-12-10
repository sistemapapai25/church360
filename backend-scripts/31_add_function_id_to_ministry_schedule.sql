-- =====================================================
-- MIGRAÇÃO 31: Adicionar function_id e índices únicos condicionais
-- Tabela: ministry_schedule
-- Objetivo: Permitir múltiplas funções por usuário no mesmo ministério/evento,
--           mantendo unicidade para presença geral (sem função)
-- =====================================================

BEGIN;

-- Garantir extensão para gen_random_uuid
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Criar tabela de funções, caso não exista
CREATE TABLE IF NOT EXISTS public.ministry_function (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE,
  name TEXT NOT NULL,
  description TEXT,
  requires_skill BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Criar tabela de funções por membro, caso não exista
CREATE TABLE IF NOT EXISTS public.member_function (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  function_id UUID NOT NULL REFERENCES public.ministry_function(id) ON DELETE CASCADE,
  ministry_id UUID REFERENCES public.ministry(id) ON DELETE SET NULL,
  skill_level INTEGER CHECK (skill_level >= 1 AND skill_level <= 5),
  certified BOOLEAN DEFAULT false,
  certification_date DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, function_id, ministry_id)
);

-- Adicionar coluna function_id referenciando ministry_function
ALTER TABLE public.ministry_schedule
  ADD COLUMN IF NOT EXISTS function_id UUID REFERENCES public.ministry_function(id) ON DELETE SET NULL;

-- Remover a antiga restrição de unicidade (event_id, ministry_id, member_id)
-- Nome padrão gerado pelo Postgres costuma ser: ministry_schedule_event_id_ministry_id_member_id_key
ALTER TABLE public.ministry_schedule
  DROP CONSTRAINT IF EXISTS ministry_schedule_event_id_ministry_id_member_id_key;

-- Criar índices únicos condicionais
-- 1) Para registros COM função: evitar duplicar mesma função para mesmo usuário no mesmo evento/ministério
CREATE UNIQUE INDEX IF NOT EXISTS uq_ministry_schedule_event_ministry_user_function_notnull
  ON public.ministry_schedule (event_id, ministry_id, user_id, function_id)
  WHERE function_id IS NOT NULL;

-- 2) Para registros SEM função (presença geral): manter unicidade por evento/ministério/membro
CREATE UNIQUE INDEX IF NOT EXISTS uq_ministry_schedule_event_ministry_user_function_null
  ON public.ministry_schedule (event_id, ministry_id, user_id)
  WHERE function_id IS NULL;

COMMIT;

-- =====================================================
-- FIM
-- =====================================================
