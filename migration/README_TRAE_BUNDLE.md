# Bundle Trae - Inventario e Migracao Supabase

Este bundle contem scripts SQL de inventario para validar schema, RLS, policies, grants, storage e metadados.

## Estrutura
- migration/inventory/*.sql
- migration/inventory/output/ (salvar saidas aqui)

## Como executar (exemplo com psql)
Defina a string de conexao do projeto fonte:
```
set DATABASE_URL=postgres://USER:PASSWORD@HOST:PORT/DB
```

Rodar cada script e salvar saida:
```
psql "%DATABASE_URL%" -f migration/inventory/00_schemas_extensoes.sql -o migration/inventory/output/00_schemas_extensoes.txt
psql "%DATABASE_URL%" -f migration/inventory/01_tables_views_matviews.sql -o migration/inventory/output/01_tables_views_matviews.txt
psql "%DATABASE_URL%" -f migration/inventory/02_functions_triggers.sql -o migration/inventory/output/02_functions_triggers.txt
psql "%DATABASE_URL%" -f migration/inventory/03_policies_rls.sql -o migration/inventory/output/03_policies_rls.txt
psql "%DATABASE_URL%" -f migration/inventory/04_grants.sql -o migration/inventory/output/04_grants.txt
psql "%DATABASE_URL%" -f migration/inventory/05_indexes_constraints_sequences.sql -o migration/inventory/output/05_indexes_constraints_sequences.txt
psql "%DATABASE_URL%" -f migration/inventory/06_storage.sql -o migration/inventory/output/06_storage.txt
psql "%DATABASE_URL%" -f migration/inventory/07_auth_references.sql -o migration/inventory/output/07_auth_references.txt
psql "%DATABASE_URL%" -f migration/inventory/08_go_no_go_checks.sql -o migration/inventory/output/08_go_no_go_checks.txt
```

## Saidas esperadas
- Listas de schemas, extensoes, tabelas, views e matviews.
- Funcoes e triggers com indicadores de security definer e search_path.
- Policies e status de RLS por tabela.
- Grants por tabela e por funcao.
- Indexes, constraints e sequences.
- Buckets e estatisticas de storage.
- Policies e RLS de storage.objects.
- Colunas que referenciam auth (FKs e heuristica).
- Checks de go/no-go (contagens, orfaos, RLS, storage).

## Observacoes
- Se o ambiente nao permitir acesso direto ao banco, rodar via agente Trae usando a string de conexao da origem.
- Use os arquivos em `output/` para comparar com o destino.
