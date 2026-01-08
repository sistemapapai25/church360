-- Script to synchronize hierarchical family relationships (Grandparents)
-- Finds chains: A -> B (Parent) -> C (Child) => A is Grandparent of C

DO $$
DECLARE
    chain RECORD;
    grandparent_gender TEXT;
    grandchild_gender TEXT;
    gp_type TEXT; -- avo/ava
    gc_type TEXT; -- neto/neta
BEGIN
    -- Loop through all Parent -> Child -> Child chains
    -- rel1: A -> B (A is Parent of B)
    -- rel2: B -> C (B is Parent of C)
    FOR chain IN 
        SELECT 
            r1.membro_id as gp_id,
            r2.parente_id as gc_id,
            r1.tipo_relacionamento as gp_rel_type -- pai/mae
        FROM relacionamentos_familiares r1
        JOIN relacionamentos_familiares r2 ON r1.parente_id = r2.membro_id
        WHERE r1.tipo_relacionamento IN ('pai', 'mae')
          AND r2.tipo_relacionamento IN ('pai', 'mae')
    LOOP
        -- 1. Determine Grandparent Type (Avô/Avó)
        -- Based on r1.tipo (pai=Male, mae=Female)
        IF chain.gp_rel_type = 'pai' THEN
            gp_type := 'avo';
        ELSE
            gp_type := 'ava';
        END IF;

        -- 2. Determine Grandchild Type (Neto/Neta)
        -- Need gender of C (Grandchild)
        SELECT gender INTO grandchild_gender FROM user_account WHERE id = chain.gc_id;
        
        -- Normalize gender
        IF grandchild_gender IS NULL THEN grandchild_gender := 'M'; END IF;
        IF LOWER(grandchild_gender) IN ('female', 'f', 'feminino') THEN
            gc_type := 'neta';
        ELSE
            gc_type := 'neto';
        END IF;

        -- 3. Insert GP -> GC (Avô -> Neto) if not exists
        IF NOT EXISTS (
            SELECT 1 FROM relacionamentos_familiares 
            WHERE membro_id = chain.gp_id AND parente_id = chain.gc_id
        ) THEN
            INSERT INTO relacionamentos_familiares (membro_id, parente_id, tipo_relacionamento)
            VALUES (chain.gp_id, chain.gc_id, gp_type);
            RAISE NOTICE 'Linked Grandparent: % -> % (%)', chain.gp_id, chain.gc_id, gp_type;
        END IF;

        -- 4. Insert GC -> GP (Neto -> Avô) if not exists
        IF NOT EXISTS (
            SELECT 1 FROM relacionamentos_familiares 
            WHERE membro_id = chain.gc_id AND parente_id = chain.gp_id
        ) THEN
            INSERT INTO relacionamentos_familiares (membro_id, parente_id, tipo_relacionamento)
            VALUES (chain.gc_id, chain.gp_id, gc_type);
            RAISE NOTICE 'Linked Grandchild: % -> % (%)', chain.gc_id, chain.gp_id, gc_type;
        END IF;

    END LOOP;
END $$;
