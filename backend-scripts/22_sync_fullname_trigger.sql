-- =====================================================
-- Script 22: Trigger para Sincronizar full_name
-- =====================================================
-- Descrição: Sincroniza automaticamente full_name ↔ first_name + last_name
-- Data: 2025-10-27
-- Autor: Church 360 Gabriel
-- =====================================================

BEGIN;

-- =====================================================
-- FUNÇÃO: Sincronizar full_name com first_name + last_name
-- =====================================================

CREATE OR REPLACE FUNCTION sync_user_names()
RETURNS TRIGGER AS $$
BEGIN
  -- Se first_name ou last_name foram alterados, atualiza full_name
  IF (TG_OP = 'INSERT' OR 
      NEW.first_name IS DISTINCT FROM OLD.first_name OR 
      NEW.last_name IS DISTINCT FROM OLD.last_name) THEN
    
    -- Construir full_name a partir de first_name e last_name
    IF NEW.first_name IS NOT NULL AND NEW.last_name IS NOT NULL THEN
      NEW.full_name := TRIM(NEW.first_name || ' ' || NEW.last_name);
    ELSIF NEW.first_name IS NOT NULL THEN
      NEW.full_name := NEW.first_name;
    ELSIF NEW.last_name IS NOT NULL THEN
      NEW.full_name := NEW.last_name;
    END IF;
  END IF;

  -- Se full_name foi alterado e first_name/last_name estão vazios, divide full_name
  IF (TG_OP = 'INSERT' OR NEW.full_name IS DISTINCT FROM OLD.full_name) THEN
    IF NEW.full_name IS NOT NULL AND 
       (NEW.first_name IS NULL OR NEW.last_name IS NULL) THEN
      
      -- Dividir full_name em first_name e last_name
      DECLARE
        name_parts TEXT[];
      BEGIN
        name_parts := string_to_array(TRIM(NEW.full_name), ' ');
        
        IF array_length(name_parts, 1) >= 2 THEN
          -- Primeiro nome é o primeiro elemento
          NEW.first_name := name_parts[1];
          -- Sobrenome é o resto
          NEW.last_name := array_to_string(name_parts[2:array_length(name_parts, 1)], ' ');
        ELSIF array_length(name_parts, 1) = 1 THEN
          -- Se só tem um nome, coloca em first_name
          NEW.first_name := name_parts[1];
          NEW.last_name := '';
        END IF;
      END;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- TRIGGER: Executar antes de INSERT ou UPDATE
-- =====================================================

DROP TRIGGER IF EXISTS trigger_sync_user_names ON user_account;

CREATE TRIGGER trigger_sync_user_names
  BEFORE INSERT OR UPDATE ON user_account
  FOR EACH ROW
  EXECUTE FUNCTION sync_user_names();

-- =====================================================
-- ATUALIZAR DADOS EXISTENTES
-- =====================================================

RAISE NOTICE '==============================================';
RAISE NOTICE 'Atualizando dados existentes...';
RAISE NOTICE '==============================================';

-- Atualizar registros que têm full_name mas não têm first_name/last_name
UPDATE user_account
SET full_name = full_name  -- Força o trigger a executar
WHERE full_name IS NOT NULL 
  AND (first_name IS NULL OR last_name IS NULL);

-- Atualizar registros que têm first_name/last_name mas não têm full_name
UPDATE user_account
SET first_name = first_name  -- Força o trigger a executar
WHERE (first_name IS NOT NULL OR last_name IS NOT NULL)
  AND full_name IS NULL;

RAISE NOTICE '✅ Dados atualizados com sucesso!';

-- =====================================================
-- VERIFICAÇÃO
-- =====================================================

RAISE NOTICE '==============================================';
RAISE NOTICE 'Verificando sincronização...';
RAISE NOTICE '==============================================';

DO $$
DECLARE
  total_users INTEGER;
  synced_users INTEGER;
BEGIN
  SELECT COUNT(*) INTO total_users FROM user_account;
  
  SELECT COUNT(*) INTO synced_users 
  FROM user_account 
  WHERE full_name IS NOT NULL 
    AND (first_name IS NOT NULL OR last_name IS NOT NULL);
  
  RAISE NOTICE 'Total de usuários: %', total_users;
  RAISE NOTICE 'Usuários sincronizados: %', synced_users;
  
  IF total_users = synced_users THEN
    RAISE NOTICE '✅ Todos os usuários estão sincronizados!';
  ELSE
    RAISE NOTICE '⚠️  % usuários precisam de atenção', (total_users - synced_users);
  END IF;
END $$;

RAISE NOTICE '==============================================';
RAISE NOTICE '🎉 TRIGGER CRIADO COM SUCESSO!';
RAISE NOTICE '==============================================';
RAISE NOTICE '';
RAISE NOTICE 'Comportamento:';
RAISE NOTICE '1. ✅ Ao inserir/atualizar first_name + last_name → atualiza full_name';
RAISE NOTICE '2. ✅ Ao inserir/atualizar full_name → divide em first_name + last_name';
RAISE NOTICE '3. ✅ Sincronização automática em tempo real';
RAISE NOTICE '';
RAISE NOTICE '==============================================';

COMMIT;

