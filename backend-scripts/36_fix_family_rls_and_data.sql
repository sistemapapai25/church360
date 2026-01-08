
-- 1. Fix RLS
ALTER TABLE relacionamentos_familiares ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable read access for authenticated users" ON relacionamentos_familiares;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON relacionamentos_familiares;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON relacionamentos_familiares;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON relacionamentos_familiares;
DROP POLICY IF EXISTS "Read access for authenticated users" ON relacionamentos_familiares;
DROP POLICY IF EXISTS "Manage access for admins and leaders" ON relacionamentos_familiares;
DROP POLICY IF EXISTS "Manage own relationships" ON relacionamentos_familiares;
DROP POLICY IF EXISTS "Manage inverse relationships" ON relacionamentos_familiares;

CREATE POLICY "Read access for authenticated users"
ON relacionamentos_familiares FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Manage access for admins and leaders"
ON relacionamentos_familiares FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_access_level ual
    WHERE ual.user_id = auth.uid()
    AND ual.access_level_number >= 3
  )
);

CREATE POLICY "Manage own relationships"
ON relacionamentos_familiares FOR ALL
TO authenticated
USING (
  membro_id = auth.uid()
)
WITH CHECK (
  membro_id = auth.uid()
);

CREATE POLICY "Manage inverse relationships"
ON relacionamentos_familiares FOR ALL
TO authenticated
USING (
  parente_id = auth.uid()
)
WITH CHECK (
  parente_id = auth.uid()
);

-- 2. Fix Data (Sync Inverses)
DO $$
DECLARE
    r RECORD;
    membro_gender TEXT;
    inv_type TEXT;
    existing_id UUID;
BEGIN
    FOR r IN SELECT * FROM relacionamentos_familiares LOOP
        -- Get member gender (A's gender)
        SELECT gender::text INTO membro_gender FROM user_account WHERE id = r.membro_id;
        
        -- Normalize gender
        IF membro_gender IS NULL OR membro_gender = '' THEN 
             membro_gender := 'M'; -- Default
        END IF;
        IF LOWER(membro_gender) IN ('female', 'f', 'feminino') THEN 
            membro_gender := 'F';
        ELSE 
            membro_gender := 'M';
        END IF;

        -- Determine inverse type (Logic: B calls A what?)
        -- A -> B is r.tipo_relacionamento
        inv_type := NULL;
        
        CASE r.tipo_relacionamento
            WHEN 'pai' THEN inv_type := CASE WHEN membro_gender='M' THEN 'filho' ELSE 'filha' END;
            WHEN 'mae' THEN inv_type := CASE WHEN membro_gender='M' THEN 'filho' ELSE 'filha' END;
            WHEN 'filho' THEN inv_type := CASE WHEN membro_gender='M' THEN 'pai' ELSE 'mae' END;
            WHEN 'filha' THEN inv_type := CASE WHEN membro_gender='M' THEN 'pai' ELSE 'mae' END;
            WHEN 'irmao' THEN inv_type := CASE WHEN membro_gender='M' THEN 'irmao' ELSE 'irma' END;
            WHEN 'irma' THEN inv_type := CASE WHEN membro_gender='M' THEN 'irmao' ELSE 'irma' END;
            WHEN 'conjuge' THEN inv_type := 'conjuge';
            WHEN 'genro' THEN inv_type := CASE WHEN membro_gender='M' THEN 'sogro' ELSE 'sogra' END;
            WHEN 'nora' THEN inv_type := CASE WHEN membro_gender='M' THEN 'sogro' ELSE 'sogra' END;
            WHEN 'sogro' THEN inv_type := CASE WHEN membro_gender='M' THEN 'genro' ELSE 'nora' END;
            WHEN 'sogra' THEN inv_type := CASE WHEN membro_gender='M' THEN 'genro' ELSE 'nora' END;
            WHEN 'neto' THEN inv_type := CASE WHEN membro_gender='M' THEN 'avo' ELSE 'ava' END; 
            WHEN 'neta' THEN inv_type := CASE WHEN membro_gender='M' THEN 'avo' ELSE 'ava' END;
            WHEN 'avo' THEN inv_type := CASE WHEN membro_gender='M' THEN 'neto' ELSE 'neta' END; 
            WHEN 'ava' THEN inv_type := CASE WHEN membro_gender='M' THEN 'neto' ELSE 'neta' END; 
            WHEN 'sobrinho' THEN inv_type := CASE WHEN membro_gender='M' THEN 'tio' ELSE 'tia' END;
            WHEN 'sobrinha' THEN inv_type := CASE WHEN membro_gender='M' THEN 'tio' ELSE 'tia' END;
            WHEN 'tio' THEN inv_type := CASE WHEN membro_gender='M' THEN 'sobrinho' ELSE 'sobrinha' END;
            WHEN 'tia' THEN inv_type := CASE WHEN membro_gender='M' THEN 'sobrinho' ELSE 'sobrinha' END;
            WHEN 'primo' THEN inv_type := CASE WHEN membro_gender='M' THEN 'primo' ELSE 'prima' END;
            WHEN 'prima' THEN inv_type := CASE WHEN membro_gender='M' THEN 'primo' ELSE 'prima' END;
            ELSE inv_type := NULL;
        END CASE;

        -- If inverse type found, ensure inverse record exists
        IF inv_type IS NOT NULL THEN
            -- Check if B -> A exists
            SELECT id INTO existing_id FROM relacionamentos_familiares 
            WHERE membro_id = r.parente_id AND parente_id = r.membro_id;
            
            IF existing_id IS NULL THEN
                -- Insert inverse
                INSERT INTO relacionamentos_familiares (membro_id, parente_id, tipo_relacionamento)
                VALUES (r.parente_id, r.membro_id, inv_type);
            ELSE
                -- Update to fix bad data
                UPDATE relacionamentos_familiares SET tipo_relacionamento = inv_type WHERE id = existing_id AND tipo_relacionamento != inv_type;
            END IF;
        END IF;

    END LOOP;
END $$;
