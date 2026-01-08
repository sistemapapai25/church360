
DO $$
BEGIN
    -- Verificar colunas da tabela 'group'
    RAISE NOTICE 'Colunas da tabela group:';
    FOR r IN (SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'group') LOOP
        RAISE NOTICE '- % (%)', r.column_name, r.data_type;
    END LOOP;

    -- Verificar se tabela 'member' existe
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'member') THEN
        RAISE NOTICE 'Tabela member EXISTE.';
    ELSE
        RAISE NOTICE 'Tabela member NÃO EXISTE.';
    END IF;

    -- Verificar se tabela 'user_account' existe
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'user_account') THEN
        RAISE NOTICE 'Tabela user_account EXISTE.';
    END IF;
END $$;
