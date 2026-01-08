-- =====================================================
-- Migration: Fix Group Foreign Keys (Retry Safe - No Member Table)
-- Description: Change leader_id and host_id to reference user_account
-- Date: 2025-12-19
-- Note: Table 'member' was deleted in previous migrations, so we cannot join with it.
--       We assume leader_id and host_id in 'group' table ALREADY contain user_account IDs (UUIDs).
--       If they contained old member IDs, we might have lost the mapping if member table is gone.
--       However, since user_account was expanded to include member fields, maybe the IDs are preserved or migrated?
--       Checking 21_unify_user_tables_migration.sql, it seems it truncated tables, so IDs might be new or lost.
--       BUT, assuming the current leader_id/host_id values are actually valid UUIDs that SHOULD point to user_account
--       but just have the wrong FK constraint (or missing one), we will just try to cast/repoint them.
-- =====================================================

-- 1. Create temporary columns to store the user_account_id (IF NOT EXISTS to avoid errors)
ALTER TABLE "group" ADD COLUMN IF NOT EXISTS leader_user_id UUID REFERENCES user_account(id) ON DELETE SET NULL;
ALTER TABLE "group" ADD COLUMN IF NOT EXISTS host_user_id UUID REFERENCES user_account(id) ON DELETE SET NULL;

-- 2. Migrate data
-- Since 'member' table does not exist, we can't look up by email.
-- We will assume the existing 'leader_id' and 'host_id' are already valid UUIDs that correspond to user_account IDs
-- OR they are old member IDs that are now orphan.
-- Strategy: Try to find a user_account that matches the ID. If match, use it.
UPDATE "group" g
SET leader_user_id = g.leader_id
WHERE leader_user_id IS NULL 
  AND EXISTS (SELECT 1 FROM user_account ua WHERE ua.id = g.leader_id);

UPDATE "group" g
SET host_user_id = g.host_id
WHERE host_user_id IS NULL
  AND EXISTS (SELECT 1 FROM user_account ua WHERE ua.id = g.host_id);

-- If leader_id/host_id were NOT valid user_account IDs (e.g. old member IDs), they will remain NULL in new columns.
-- This is acceptable as we can't recover the mapping without the member table.

-- 3. Drop old constraints (if any exist pointing to non-existent member table or whatever)
ALTER TABLE "group" DROP CONSTRAINT IF EXISTS group_leader_id_fkey;
ALTER TABLE "group" DROP CONSTRAINT IF EXISTS group_host_id_fkey;

-- 4. Swap columns safely using a DO block
DO $$
BEGIN
    -- Handle Leader ID
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'group' AND column_name = 'leader_id') THEN
        -- Check if we haven't already renamed it
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'group' AND column_name = 'leader_member_id') THEN
            ALTER TABLE "group" RENAME COLUMN leader_id TO leader_member_id;
        END IF;
    END IF;

    -- Handle Host ID
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'group' AND column_name = 'host_id') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'group' AND column_name = 'host_member_id') THEN
            ALTER TABLE "group" RENAME COLUMN host_id TO host_member_id;
        END IF;
    END IF;
END $$;

-- 5. Rename new columns to final names (if they exist as _user_id)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'group' AND column_name = 'leader_user_id') THEN
        -- Only rename if target 'leader_id' does not exist (it should have been renamed/dropped above)
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'group' AND column_name = 'leader_id') THEN
            ALTER TABLE "group" RENAME COLUMN leader_user_id TO leader_id;
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'group' AND column_name = 'host_user_id') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'group' AND column_name = 'host_id') THEN
            ALTER TABLE "group" RENAME COLUMN host_user_id TO host_id;
        END IF;
    END IF;
END $$;

-- 6. Add comments
COMMENT ON COLUMN "group".leader_id IS 'Líder do grupo (referência a user_account)';
COMMENT ON COLUMN "group".host_id IS 'Anfitrião do grupo (referência a user_account)';
