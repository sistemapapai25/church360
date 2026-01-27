# Plano de Execucao Segura - Integracao Gestao Financeira

## Objetivo
Executar a integracao com risco minimo, garantindo backup, rollback, validacoes e controle de acesso em todas as etapas.

## Definicoes rapidas
- staging: ambiente espelho da producao para testes reais.
- producao: ambiente real com dados de usuarios.
- feature flag: chave que ativa/desativa o modulo por tenant.
- rollback: plano de retorno imediato para estado anterior.

## Artefatos obrigatorios antes de iniciar
- Lista completa de telas/rotas do terceiro (inventario de paridade).
- Mapa de dados (tabelas e campos: origem -> destino).
- Matriz de permissoes (financial.*) ligada ao sistema Church360.
- Runbook de rollback com responsaveis e tempos.
- Lista de integracoes externas (WhatsApp, IA, webhook).

## Sequencia detalhada (passo a passo)
### 0) Preflight administrativo
0.1) Definir responsaveis
- Owner tecnico, owner de dados, owner de release.
- Responsavel por backups e por rollback.

0.2) Definir janela de manutencao
- Planejar janela curta para migracoes criticas.
- Definir comunicacao interna e plano de contingencia.

0.3) Acessos e segredos
- Confirmar acesso de leitura ao Supabase.
- Listar secrets atuais e destino por ambiente (staging/producao).

### 1) Backup e snapshot (antes de qualquer codigo)
1.1) Banco de dados
- Dump completo de schema e dados com ferramenta oficial.
- Dump de roles, policies e functions.
- Guardar em storage seguro com versionamento.
- Validar restauracao do dump em ambiente isolado.
- Observacao: `supabase db dump` exige Docker; se indisponivel, usar `pg_dump` com connection string.

1.2) Storage
- Inventariar buckets e pastas.
- Copiar objetos e metadados para backup externo.
- Validar contagem total de objetos e tamanho.

1.3) Codigo e configuracao
- Criar branch/tag de release do estado atual.
- Exportar variaveis de ambiente e secrets (app e Edge).
- Guardar o estado do `firebase.json` e configs relacionadas.

### 2) Staging espelho
2.1) Criar ambiente
- Criar projeto Supabase de staging.
- Replicar schema, roles, policies, functions e storage.
- Subir Edge Functions atuais para staging.

2.2) Dados para testes
- Restaurar um subconjunto anonimo dos dados reais (se permitido).
- Garantir que `tenant_id` esteja consistente.

2.3) Verificacoes basicas
- Acesso autenticado funcionando.
- RLS validada para tenant de teste.
- Buckets e policies funcionando em staging.

### 3) Inventario e paridade do terceiro
3.1) Verificar completude da pasta `financas-papai`
- Comparar `src/App.tsx` (rotas) com `src/pages` reais.
- Listar paginas/components ausentes e recuperar do repo original.

3.2) Verificar schema usado pelo codigo
- Buscar `from('tabela')` e `rpc('funcao')` no codigo.
- Comparar com migrations existentes do terceiro.
- Registrar tabelas/funcoes faltantes para criar manualmente.

3.3) Verificar integracoes externas
- Identificar webhooks hardcoded e APIs externas.
- Registrar como configuracoes por ambiente/tenant.

Saida desta etapa: "gap list" com itens obrigatorios antes de implementar.

### 4) Banco de dados (staging primeiro)
4.1) Modelagem e compatibilidade
- Definir se sera Opcao A (views compatibilidade) ou Opcao B (backfill).
- Definir tabelas novas e campos obrigatorios com `tenant_id` e `created_by`.

4.2) Migracoes seguras
- Escrever migrations pequenas e reversiveis.
- Incluir indices e constraints necessarios.
- Criar triggers e auditoria desde o inicio.

4.3) RLS e permissoes
- Politicas padrao: `tenant_id = current_tenant_id()`.
- Regras especificas para funções publicas (service role).
- Testar permissao por papel (admin vs usuario).

4.4) Seeds e dados base
- Inserir categorias padrao.
- Criar templates em `message_template`.
- Validar consistencia com dados existentes (contribution/expense).

### 5) Storage e arquivos
5.1) Buckets e policies
- Criar buckets privados: `boletos`, `comprovantes`, `assinaturas`, `logos`.
- Policies por tenant e por `created_by`.
- Proibir `getPublicUrl` no app; usar signed URLs.

5.2) Estrutura de pastas
- Padrao: `tenant_id/entidade/id/arquivo`.
- Garantir que deletes e updates respeitam tenant.

### 6) Edge Functions
6.1) Funcoes base
- `create-user`, `ensure-admin`, `carne-por-token`.
- Validar logs com tenant e user.

6.2) Funcoes opcionais
- `whatsapp-send-message`, `analisar-comprovante`.
- Guardar secrets por ambiente.

6.3) Testes de erro
- Timeout e retry.
- Resposta quando API externa falhar.

### 7) Flutter (UI + Data Layer)
7.1) Arquitetura
- Criar modulos por feature (data/domain/presentation).
- Integrar com o sistema de permissoes do Church360.

7.2) Feature flags
- Flag global + flag por tenant.
- Tela escondida por padrao.

7.3) Telas criticas
- Lancamentos, contas financeiras, movimentos e conciliacao.
- Importacoes (extrato e caixa).
- Cadastros e configuracoes.

7.4) Integracoes especificas
- Substituir `profiles` por `user_account`.
- Substituir `user_roles` do terceiro pelo modelo Church360.
- Ajustar `ConfiguracaoIgreja` para `church_settings`/`church_info`.

### 8) Migracao de dados (se aplicavel)
8.1) Opcao A (views)
- Criar views de compatibilidade para relatórios.
- Ajustar RPCs para consultar dados combinados.

8.2) Opcao B (backfill)
- Criar script de migracao com logs por lote.
- Validar totais por mes e por conta.
- Reprocessar se houver divergencia.

### 9) Testes completos em staging
9.1) RLS e seguranca
- Usuario comum vs admin.
- Tenant A nao acessa Tenant B.

9.2) Fluxos essenciais
- Lancamento -> pagamento -> movimento.
- Reabertura remove movimento.
- Importacao de extrato com deduplicacao.

9.3) Relatorios e reconciliacao
- Totais batem com `contribution/expense`.
- Resumo anual e dashboard batendo com dados reais.

9.4) Arquivos e storage
- Upload e download com signed URLs.
- Politicas de delete e update por tenant.

### 10) Go/No-Go
- Checklist de aceite completo.
- Rollback validado em staging.
- Owners aprovam fluxos criticos.

### 11) Homologacao (UAT)
- Ativar para 1 ou 2 tenants piloto.
- Monitorar logs, tempo de resposta e erros.
- Reconciliar com dados antigos por 2-4 semanas.

### 12) Producao - rollout controlado
12.1) Pre-rollout
- Backup final do banco e storage.
- Tag do release pronta.

12.2) Deploy
- Rodar migrations em janela curta.
- Publicar Edge Functions.
- Ativar flag para 1 tenant.

12.3) Expansao gradual
- Ativar por lotes pequenos.
- Conferir RLS, erros e performance.

### 13) Encerramento
- Ativar para todos os tenants.
- Manter tabelas antigas em read-only por periodo definido.
- Planejar limpeza de legado apos estabilidade.

## Plano de rollback (detalhado)
1) Desativar feature flag por tenant.
2) Reverter Edge Functions para a versao anterior.
3) Executar migrations down (se reversiveis).
4) Restaurar backup do banco se houver corrupcao.
5) Reverter deploy do app.
6) Validar que o sistema antigo voltou a operar.

## Checklists por fase (gates)
### Gate 1: Preflight
- [ ] Backup validado com restauracao.
- [ ] Inventario de telas/rotas completo.
- [ ] Mapa de dados aprovado.

### Gate 2: Staging pronto
- [ ] RLS funcionando por tenant.
- [ ] Buckets privados com signed URL.
- [ ] Edge Functions rodando em staging.

### Gate 3: Go/No-Go
- [ ] Fluxos criticos testados.
- [ ] Relatorios batem com dados existentes.
- [ ] Rollback testado.

### Gate 4: Producao
- [ ] Backup final concluido.
- [ ] Flag ativada para 1 tenant.
- [ ] Monitoramento sem erros criticos.
