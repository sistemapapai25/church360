# Plano de Migracao Supabase - Church360 para Nova Conta (sem Auth)

Data: 2026-01-23

## 0) Objetivo
Migrar TODO o projeto para uma nova conta Supabase, com schema + dados (todas as tabelas), preservando RLS, policies, views, functions, triggers, extensoes e storage. Auth nao sera migrado.

Definicao explicita de "TODO o projeto" (sem Auth):
- `public` + demais schemas custom (tabelas, views, funcoes, triggers, policies, extensoes usadas).
- Storage (buckets + policies + arquivos).
- Edge Functions + secrets.
- Nao tocar em `auth.*` (evitar migrations que alterem auth).

Criterios de sucesso:
- Schema identico (ou superior) ao atual, sem regressao funcional.
- Dados completos em todas as tabelas de negocio.
- RLS e policies ativas e testadas por tenant.
- Storage e Edge Functions operando no novo projeto.
- Cutover reversivel e documentado.

## 1) Premissas e decisoes
- Destino: projeto novo (do zero).
- Dados: migrar todas as tabelas.
- Auth: NAO migrar (apenas analisar/diagnosticar se necessario).
- Downtime: indefinido; plano cobre janela curta e opcao de pre-carga.
- Ferramentas: Supabase CLI + SQL + scripts simples.
- Fonte de verdade do schema: `supabase/migrations` da raiz (garantir que scripts fora desta arvore sejam incorporados se forem necessarios).

## 2) Inventario cirurgico (fonte -> destino)
Objetivo: capturar todos os objetos do banco, policies e status de RLS.
Os scripts prontos ficam em `migration/inventory/*.sql`.

### 2.1 Schemas e extensoes
- Arquivo: `migration/inventory/00_schemas_extensoes.sql`

### 2.2 Tabelas, views, materialized views
- Arquivo: `migration/inventory/01_tables_views_matviews.sql`

### 2.3 Funcoes e triggers
- Arquivo: `migration/inventory/02_functions_triggers.sql`

### 2.4 Policies e status de RLS
- Arquivo: `migration/inventory/03_policies_rls.sql`

### 2.5 Grants (tabelas e funcoes)
- Arquivo: `migration/inventory/04_grants.sql`

### 2.6 Indexes, constraints e sequences (opcional, recomendado)
- Arquivo: `migration/inventory/05_indexes_constraints_sequences.sql`

### 2.7 Storage (buckets e objetos)
- Arquivo: `migration/inventory/06_storage.sql`
- Inclui policies de `storage.objects` e status de RLS no schema `storage`.

### 2.8 Mapeamento de colunas que referenciam usuario (Auth)
- Arquivo: `migration/inventory/07_auth_references.sql`
- Objetivo: listar FKs formais para `auth.users` + colunas UUID que provavelmente guardam `auth.uid()`.

### 2.9 Checks de go/no-go (SQL curto)
- Arquivo: `migration/inventory/08_go_no_go_checks.sql`
- Objetivo: gerar contagens, orfaos e sinais de inconsistencias apos import.

### 2.10 Observacoes
- Guardar os resultados em `migration/inventory/output/`.
- Usar o inventario para validar drift e para comparar origem vs destino.

## 3) Checagem de drift vs migrations
Objetivo: garantir que o schema real = migrations do repo.

Passos:
1) Dump de schema do projeto atual.
2) Diff entre `supabase/migrations` e dump real.
3) Corrigir drift criando migration extra (se necessario).

## 4) Ponto critico: Auth nao sera migrado
Sem Auth, os `auth.uid()` nao terao correspondencia com dados antigos.
Defina UMA estrategia antes de importar dados:

### Opcao A (ideal, mas precisa ser validada antes)
- Recriar usuarios com os mesmos UUIDs no novo Auth.
- Objetivo: manter `user_account.auth_user_id` e `created_by` intactos.
- Validar se o endpoint Admin permite definir `id` no create user.

### Opcao B (default realista)
- Criar usuarios novos (UUIDs novos).
- Gerar tabela de mapeamento `old_auth_uid -> new_auth_uid`.
- Atualizar TODAS as colunas FK que referenciam `auth.users`.
- Recalcular `user_account.auth_user_id` e funcoes dependentes.
- Manter um campo legado (se necessario) para rastrear o ID antigo.

### Opcao C (ultimo recurso)
- Importar dados e setar `created_by`/FKs para NULL quando necessario.
- Perde rastreabilidade e pode quebrar regras de negocio.

### 4.4 Decisao de alvo canonico (obrigatoria)
Escolher UM padrao para o destino:
- Padrao recomendado (curto prazo): manter `user_account.id` como legado e usar `auth_user_id` para o novo Auth.
- Longo prazo: alinhar `user_account.id` = `auth.uid()` e remover dependencias antigas.
- O inventario do item 2.8 define o escopo de colunas a serem rewire.
- Validar compatibilidade: revisar policies/funcoes que usam `auth.uid()` e/ou `auth_user_id` para garantir que o alvo canonico escolhido nao quebre acesso.

## 5) Preflight e backups
1) Congelar escrita no app (feature flag ou manutencao). Se nao houver downtime, usar pre-carga e delta.
2) Dump de schema e dados do banco atual.
3) Exportar lista de buckets e objetos.
4) Snapshot de secrets e Edge Functions (valores dos secrets devem ser capturados do cofre/dashboard atual).
5) Inventariar todas as colunas relacionadas a usuario (item 2.8) e definir estrategia de rewire.
6) Revisar scripts fora de `supabase/migrations` (ex.: `backend-scripts`, `financas-papai/supabase/migrations`) e decidir o que precisa ser incorporado.

## 6) Criar projeto novo
- Criar projeto Supabase (dashboard ou CLI).
- Definir regiao, senha do DB, habilitar Storage.
- Linkar o repo local ao novo projeto (`supabase link`).

## 7) Preparar migrations para ambiente novo
- Revisar migrations com alteracoes no schema `auth`.
- Ajustar/ignorar migrations que mexem em `auth.*` (ex.: desativar RLS em auth) se o objetivo e nao tocar no Auth.
- Garantir que extensoes (ex.: unaccent) estejam no schema correto.
- Garantir que funcoes `SECURITY DEFINER` tenham `SET search_path` seguro.
- Gerar uma lista explicita de migrations que tocam `auth.*` para filtrar no destino.
  Exemplo (no repo local):
  ```
  rg -n "auth\\." supabase/migrations
  ```
- Nao ignorar migrations que APENAS referenciam `auth.uid()` em policies ou funcoes; elas fazem parte do modelo de seguranca.

## 8) Exportacao do banco (fonte)
### 8.1 Dump de schema
Usar CLI para dump de schema (observacao: o `db dump` ignora schemas gerenciados como auth e storage por padrao).

Exemplo (schema):
```
supabase db dump --linked -f migration/dumps/schema.sql
```

### 8.2 Dump de dados
Exportar dados somente do schema `public` (recomendado) e excluir `auth`.

Exemplo (dados):
```
supabase db dump --linked --data-only --use-copy -s public -f migration/dumps/data.sql
```

Opcional:
- `--db-url` se nao estiver linkado.
- `--exclude schema.table` para excluir tabelas na exportacao de dados.
- `--role-only` se precisar exportar roles (raro em Supabase hosted).

## 9) Importacao no projeto novo
1) Rodar migrations no destino.
2) Importar dados do dump `data.sql` via `psql` usando uma role com bypass de RLS (service_role/owner).
3) Se houver FKs sensiveis, usar constraints deferred ou desabilitar triggers durante o restore.
4) Recriar/reconciliar sequences com `setval()` (se houver sequences).
5) Executar o rewire de IDs de usuario (se Opcao B), antes de validar RLS.
   - Fase 1: `user_account.auth_user_id` + tabelas centrais de membership/roles.
   - Fase 2: colunas satelites (`created_by`, `updated_by`, `user_id`, etc.) encontradas no inventario 2.8.
6) Rodar `ANALYZE` (por schema ou por tabelas criticas) para evitar regressao de performance.
7) Validar constraints e indices.

## 10) Migracao de Storage (arquivos)
1) Listar buckets e objetos na origem.
2) Recriar buckets no destino.
3) Copiar arquivos (CLI storage ou S3 compatible).

Observacao: `supabase storage cp` nao e indicado para arquivos acima de 6MB; use outro metodo se houver arquivos grandes.
Observacao 2: se policies usam `storage.objects.owner = auth.uid()`, o upload via service role pode gerar owner NULL/diferente. Prefira policies baseadas em path/tenant quando possivel.
Ordem recomendada: criar buckets -> aplicar policies/grants -> copiar arquivos -> validar contagem/bytes.
Observacao 3: inventario SQL de storage (item 2.7) nao migra arquivos; ele apenas ajuda na validacao.

Exemplo (listar e copiar do projeto origem -> local):
```
supabase storage ls --experimental --linked
supabase storage cp -r ss:///Assinaturas migration/storage/Assinaturas --experimental --linked
supabase storage cp -r ss:///Comprovantes migration/storage/Comprovantes --experimental --linked
supabase storage cp -r ss:///Logos migration/storage/Logos --experimental --linked
```

Depois de linkar o projeto destino, subir do local -> destino:
```
supabase storage cp -r migration/storage/Assinaturas ss:///Assinaturas --experimental --linked
supabase storage cp -r migration/storage/Comprovantes ss:///Comprovantes --experimental --linked
supabase storage cp -r migration/storage/Logos ss:///Logos --experimental --linked
```

## 11) Edge Functions e Secrets
1) Deploy de todas as Edge Functions do repo.
2) Replicar secrets via CLI ou Dashboard.
3) Testar endpoints criticos (carne, whatsapp, analisar-comprovante).
4) Conferir inventario: `supabase/functions` do repo vs `supabase functions list` do projeto.
5) Comparar secrets esperados pelo repo (env vars usadas nas functions) vs o que foi setado no destino.

Exemplo (inventario e deploy):
```
supabase functions list --project-ref <SOURCE_REF>
supabase functions deploy create-user --project-ref <DEST_REF>
supabase functions deploy ensure-admin --project-ref <DEST_REF>
supabase functions deploy carne-por-token --project-ref <DEST_REF>
supabase functions deploy desafio-lembrete-vencimento --project-ref <DEST_REF>
supabase functions deploy whatsapp-send-message --project-ref <DEST_REF>
supabase functions deploy analisar-comprovante --project-ref <DEST_REF>
```

Exemplo (secrets):
```
supabase secrets list --project-ref <SOURCE_REF>
supabase secrets set --project-ref <DEST_REF> --env-file migration/secrets.env
```
Observacao: `supabase secrets list` nao retorna valores; voce precisa obter os valores no cofre atual (dashboard/gerenciador) para montar `migration/secrets.env`.

## 12) Validacoes pos-migracao
- Contagem de linhas por tabela (origem vs destino).
- RLS: usuario de um tenant nao acessa dados de outro tenant.
- Policies: listar e comparar com inventario original.
- Storage: amostragem de downloads e paths assinados.
- Funcoes/Views: chamadas RPC e views criticas.
- Edge Functions: smoke test (200 OK + payload esperado).
- Checks adicionais: soma por tenant, min/max updated_at por tabela financeira, orfaos de FK para auth.users.

## 13) Cutover e rollback
- Atualizar variaveis de ambiente do app (URL/ANON KEY) para o novo projeto.
- Manter projeto antigo em read-only por periodo de seguranca.
- Rollback: reverter app para URL antiga e manter dados congelados.
- Importante: se houver escrita no novo projeto, o rollback cria divergencia. Definir politica de escrita (freeze total ou reconciliacao).

## 14) Artefatos esperados (para o agente Trae)
- `migration/inventory/*.sql` (inventarios acima).
- `migration/inventory/output/` (resultados do inventario).
- `migration/dumps/schema.sql`
- `migration/dumps/data.sql`
- `migration/storage/` (export local de buckets)
- `migration/report_validacao.md`

## 15) Checklist de go/no-go
- [ ] Inventario completo e revisado.
- [ ] Drift resolvido via migrations.
- [ ] Estrategia Auth escolhida e validada.
- [ ] Dump e restore testados em staging.
- [ ] Storage copiado e conferido.
- [ ] Edge Functions e secrets ok.
- [ ] Validacoes de dados e RLS aprovadas.
- [ ] Plano de rollback confirmado.
