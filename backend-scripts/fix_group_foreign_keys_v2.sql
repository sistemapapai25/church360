-- Script para corrigir FKs de groups usando as colunas corretas (leader_user_id)
-- Execute este script para garantir integridade referencial
BEGIN;

-- 1. Atualizar leader_user_id inválidos para NULL
UPDATE "group"
SET leader_user_id = NULL
WHERE leader_user_id IS NOT NULL 
AND NOT EXISTS (SELECT 1 FROM user_account WHERE id = "group".leader_user_id);

-- 2. Atualizar host_user_id inválidos para NULL
UPDATE "group"
SET host_user_id = NULL
WHERE host_user_id IS NOT NULL 
AND NOT EXISTS (SELECT 1 FROM user_account WHERE id = "group".host_user_id);

-- 3. Recriar constraints se necessário
DO $$
BEGIN
    -- Leader FK
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'group_leader_user_id_fkey') THEN
        ALTER TABLE "group" ADD CONSTRAINT group_leader_user_id_fkey 
            FOREIGN KEY (leader_user_id) REFERENCES user_account(id) ON DELETE SET NULL;
    END IF;

    -- Host FK
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'group_host_user_id_fkey') THEN
        ALTER TABLE "group" ADD CONSTRAINT group_host_user_id_fkey 
            FOREIGN KEY (host_user_id) REFERENCES user_account(id) ON DELETE SET NULL;
    END IF;
END $$;

COMMIT;
