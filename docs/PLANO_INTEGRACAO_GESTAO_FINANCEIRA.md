# Plano de Integracao - Gestao Financeira (Financas Papai -> Church360)

## 0. Meta e criterios de sucesso
- Paridade funcional: todas as funcoes do Financas Papai disponiveis no Church360.
- Seguranca: RLS com isolamento por tenant e permissoes por papel.
- Estabilidade: nenhuma regressao nas funcionalidades atuais (contribution/expense/financial_goal).
- Operacao: rollout gradual com feature flag e rollback seguro.
- Dados: reconciliacao de totais entre lancamentos e movimentos financeiros.

## 1. Escopo funcional (paridade 100%)
### 1.1 Modulos obrigatorios
- Lancamentos (contas a pagar/receber): criar, editar, pagar, reabrir, anexos (boleto/comprovante).
- Movimentos financeiros (extrato/caixa): conciliacao, edicao, regras de classificacao.
- Agenda financeira (visao por datas/compromissos).
- Cadastros: beneficiarios, categorias (hierarquia), contas financeiras, pessoas, tipos de culto, usuarios.
- Cultos: registro, dizimos, ofertas, importacao para caixa.
- Desafios financeiros e carne (carnet): participantes, parcelas, link publico, pagamentos e lembretes.
- Gestao financeira de desafios (fluxo de recebimentos/baixas).
- Relatorios: dashboard, contas pagas/abertas, resumo anual, relatorio de pagamentos.
- Configuracoes: regras de classificacao, mensagens, dados da igreja.
- Edge Functions: create-user, ensure-admin, carne-por-token, desafio-lembrete-vencimento, whatsapp-send-message, analisar-comprovante.

### 1.2 Itens opcionais (pos-MVP)
- Recibos/reembolsos em PDF se a estrategia for mover para Edge Function.
- Capacitor (mobile) se houver demanda especifica.
- Webhook externo (N8N) para relatorios.

## 2. Premissas e restricoes
- Nao clonar o repositorio terceiro, apenas leitura dos arquivos.
- Acesso ao Supabase apenas leitura (schema e metadados).
- Church360 e multi-tenant (tenant_id) devem ser preservados.
- Manter compatibilidade com tabelas financeiras atuais no curto prazo.
- Pasta local do terceiro pode estar incompleta; paridade validada com o repo original.

## 3. Foto do Church360 (hoje)
- App Flutter com Riverpod e rotas em `app/lib/core/navigation/app_router.dart`.
- Tabelas financeiras existentes: `contribution`, `expense`, `financial_goal`, `contribution_info`, todas com `tenant_id`.
- Funcoes public existentes: `can_manage_financial`, `get_financial_report`, `get_financial_statistics`, `current_tenant_id`.
- Sistema de permissoes proprio (nao usar `user_roles` do terceiro).

## 4. O que reaproveitar para mexer o minimo possivel no banco
### 4.1 Reaproveitar sem mudar
- `contribution`, `expense`, `financial_goal`, `contribution_info`: base financeira ja com `tenant_id`.
- Enums existentes: `payment_method` e `contribution_type`.
- `worship_service` e `worship_attendance`: podem substituir `cultos` do terceiro.
- `church_info` e `church_settings`: dados da igreja.
- Permissoes: `permissions`, `roles`, `role_permissions`, `user_roles` (modelo Church360).
- `message_template`: pode substituir `configuracao_mensagens`.

### 4.2 Reaproveitar com ajustes pequenos
- `contribution`: adicionar `worship_service_id` para ligar dizimos/ofertas a um culto.
- `expense`: considerar migrar `category` (texto) para FK em `categories`, ou manter e criar view de compatibilidade.
- `message_template`: criar templates de lembrete com `name/content/variables`.
- `church_info` ou `contribution_info`: adicionar campos de recibo/reembolso se necessario.

### 4.3 Tabelas novas inevitaveis
- `categories`, `beneficiaries`, `lancamentos`, `contas_financeiras`, `movimentos_financeiros`.
- `classification_rules`.
- `desafios`, `desafio_participantes`, `desafio_parcelas` (se participantes nao forem usuarios logados).
- `pessoas` (se nao mapear para `member`/`user_account`).
- `configuracao_mensagens` (se nao mapear para `message_template`).
- `transferencias`, `recibos_sequencia`, `saldos_mensais` (se esses fluxos forem ativados).
- `cultos`, `dizimos`, `ofertas`, `tipos_culto` (apenas se nao mapear para `worship_service` e `contribution`).

### 4.4 Buckets e storage (nomes reais do terceiro)
- Buckets usados no codigo: `Assinaturas`, `Comprovantes`, `Logos`.
- Decisao: manter nomes originais (menos mudanca) ou padronizar lowercase e ajustar o front.
- Observacao: o terceiro usa `getPublicUrl` em `Logos` e `Comprovantes`; no Church360, trocar por signed URLs.

## 5. Diferencas chave (Church360 vs Financas Papai)
- Financas Papai usa `user_id` como dono do dado; Church360 exige `tenant_id` + RLS por tenant.
- Financas Papai usa `profiles` + `user_roles` simples; Church360 tem `user_account` + sistema de permissoes.
- Financas Papai separa "lancamentos" (obrigacoes) de "movimentos" (fluxo real); Church360 hoje tem "contribution/expense".
- Financas Papai tem cultos/dizimos/ofertas; Church360 ja possui `worship_service` e `worship_attendance`.
- Pacote local sincronizado com repo original (rotas/paginas e supabase).
- Migrations do terceiro nao cobrem todas as tabelas que o codigo usa; nao confiar nelas como fonte unica.
- Buckets no terceiro usam Title Case e URLs publicas; no Church360 preferir signed URLs + policies por tenant.

## 6. Decisoes tecnicas chave (registrar antes de codar)
### 6.1 Estrategia de dados financeiros
- Opcao A (recomendada): manter `contribution/expense` e criar modulo `lancamentos/movimentos` separado, com views de unificacao.
- Opcao B: migrar `contribution/expense` para `lancamentos` e manter tabelas antigas read-only.
- Decisao: Opcao A.

### 6.2 Identidade do usuario
- `created_by` deve referenciar `auth.users(id)` e sempre acompanhar `tenant_id`.
- `user_account` continua como tabela de perfil; nao duplicar `profiles` do terceiro.

### 6.3 Cultos (preferir reaproveitar)
- Opcao A (recomendada): mapear `cultos/dizimos/ofertas` para `worship_service` e registrar valores em `contribution`.
- Opcao B: criar tabelas `cultos/dizimos/ofertas` separadas (apenas se a equipe preferir isolar).
- Decisao: Opcao A.

### 6.4 PDF de recibos/reembolsos
- Opcao A: gerar PDF no Flutter (pacote equivalente ao pdf-lib).
- Opcao B (recomendada): gerar via Edge Function e armazenar no bucket.
- Decisao: Opcao B.

### 6.5 Dependencias externas
- WhatsApp (UAZAPI) e IA de comprovantes (LOVABLE_API_KEY) entram no MVP ou fase 2?
- Decisao: fase 2 (pos-MVP), com feature flag.
### 6.6 Roles e identidade (nao replicar o modelo do terceiro)
- Padrao Church360: permissoes e `user_roles` proprios; descartar `profiles` e `user_roles` simples do terceiro.
- `create-user` e `ensure-admin` devem respeitar `tenant_id` e a matriz de permissoes do Church360.
### 6.7 Configuracao da igreja
- Mapear `ConfiguracaoIgreja` para `church_settings`/`church_info` sem criar campos duplicados.
- Definir onde ficam `responsavel_*` e dados legais (se necessario, usar tabela nova de configuracoes financeiras).
- Decisao: mapear `igreja_nome` -> `church_name` e estender `church_settings` com `igreja_cnpj`, `responsavel_nome`, `responsavel_cpf`, `assinatura_path`.
### 6.8 Webhooks e URLs externas
- `RelatorioPagamentos` usa webhook hardcoded (N8N); definir configuracao via tabela/secret e fallback.
- Decisao: mover webhook para configuracao por tenant (tabela/secret) e remover hardcode.

## 7. Mapa de dados detalhado
### 7.1 Enums (novos)
- `tipo_lancamento`: DESPESA | RECEITA
- `status_lancamento`: EM_ABERTO | PAGO | CANCELADO
- `forma_pagamento`: PIX | DINHEIRO | CARTAO | BOLETO | TRANSFERENCIA | OUTRO
- `tipo_categoria`: DESPESA | RECEITA | TRANSFERENCIA
- `acao_auditoria`: CREATE | UPDATE | DELETE | STATUS_CHANGE

### 7.2 Tabelas novas (com tenant_id + created_by)
- `categories`: name, tipo, parent_id, ordem, deleted_at, tenant_id, created_by.
- `beneficiaries`: name, documento, phone, email, observacoes, assinatura_path, deleted_at, tenant_id, created_by.
- `lancamentos`: tipo, categoria_id, beneficiario_id, valor, vencimento, status, data_pagamento, valor_pago, forma_pagamento, boleto_url, comprovante_url, conta_id, tenant_id, created_by.
- `auditoria`: entidade, entidade_id, acao, antes, depois, motivo, user_id, tenant_id.
- `contas_financeiras`: tipo, nome, instituicao, agencia, numero, saldo_inicial, saldo_inicial_em, logo, tenant_id, created_by.
- `movimentos_financeiros`: conta_id, data, tipo (ENTRADA/SAIDA), valor, descricao, origem, ref_id, categoria_id, beneficiario_id, comprovante_url, tenant_id, created_by.
- `classification_rules`: term, category_id, beneficiary_id, tenant_id, created_by.
- `pessoas`, `desafios`, `desafio_participantes`, `desafio_parcelas`.
- `configuracao_mensagens` (se nao mapear para `message_template`).
- `transferencias`, `recibos_sequencia`, `saldos_mensais` (se usados).
- `cultos`, `dizimos`, `ofertas`, `tipos_culto` (apenas se nao mapear para `worship_service`/`contribution`).

### 7.3 Tabelas existentes a reaproveitar
- `contribution`, `expense`, `financial_goal`, `contribution_info`.
- `member`, `user_account`, `tenant`, `user_tenant_membership`.
- `message_template` (no lugar de `configuracao_mensagens`).
- `worship_service` e `worship_attendance` (no lugar de `cultos`).

### 7.4 Views e RPCs a portar
- Views: `vw_culto_totais`, `vw_conciliacao`, `vw_lancamentos_whatsapp`.
- RPCs: `ensure_default_categories`, `atualizar_saldo_conta`, `gerar_carne_para_participante`,
  `atualizar_valor_participante`, `atualizar_valor_parcela`, `next_recibo_num`, `registrar_transferencia`.
- Triggers: auditoria em `lancamentos`, gerar parcelas ao criar participante, update_updated_at_column.

### 7.5 Buckets (storage)
- `Assinaturas` (assinaturas de beneficiarios/igreja).
- `Comprovantes` (comprovantes e extratos).
- `Logos` (logos de contas financeiras).

## 8. Plano por fases (execucao segura)
### Fase 0 - Alinhamento e desenho
- Revisar decisoes do item 6 e fechar arquitetura final.
- Definir nomes finais de tabelas (se vao conflitar com futuras tabelas do Church360).
- Definir estrategia de migracao (opcao A ou B).
- Definir se WhatsApp/IA entram no MVP.
- Inventariar rotas/paginas/components ausentes na pasta local e recuperar do repo original.
- Conferir cada tabela usada no codigo vs. migrations do terceiro para evitar lacunas.

### Fase 1 - Banco (staging)
- Criar enums e tabelas novas com `tenant_id` e `created_by` (apenas as inevitaveis).
- Criar indices e constraints de unicidade.
- Portar views, RPCs e triggers do Financas Papai.
- RLS:
  - Padrao: `tenant_id = current_tenant_id()` e controle por permissao.
  - Excecoes: `carne-por-token` via service role.
- Seeds: categorias padrao, templates de mensagens (em `message_template`).

### Fase 2 - Storage e Edge Functions
- Buckets: `boletos`, `comprovantes`, `assinaturas`, `logos`.
- Policies por tenant e created_by.
- Edge Functions:
  - `create-user`, `ensure-admin`.
  - `carne-por-token` (publica, service role).
  - `desafio-lembrete-vencimento` (cron diaria).
  - `whatsapp-send-message` (UAZAPI).
  - `analisar-comprovante` (IA, opcional).

### Fase 3 - Back-end logico
- Ajustar `get_financial_report` e `get_financial_statistics` para incluir `lancamentos` e `movimentos_financeiros`.
- Validar regras de classificacao (termos -> categoria/beneficiario).
- Implementar conciliacao (lancamento pago <-> movimento financeiro).

### Fase 4 - Flutter (UI e Data Layer)
- Criar features com estrutura Clean Architecture (data/domain/presentation).
- Portar telas equivalentes do Financas Papai:
  - Dashboard, Contas a Pagar, Contas Pagas.
  - Movimentos (conciliacao), Importar Extrato, Importar Caixa.
  - Cultos, Dizimos, Ofertas.
  - Cadastros (categorias, beneficiarios, contas, pessoas, tipos de culto, usuarios).
  - Desafios, Carne, Gestao Financeira de Desafios.
  - Configuracoes (mensagens, regras, igreja).
- Integrar com `PermissionGate` e novas chaves `financial.*`.
- Remover dependencias do front que assumem `getPublicUrl` publico; preferir signed URLs.

### Fase 5 - Migracao e compatibilidade
- Criar views de compatibilidade (se opcao A).
- Script de backfill para transformar `contribution/expense` em `lancamentos`.
- Reconciliar totais por mes e por conta.
- Manter telas antigas ativas ate validacao final.

### Fase 6 - QA e validacao
- RLS: usuario comum vs admin vs tenant diferente.
- Pagamento de lancamento cria movimento (origem LANCAMENTO) e reabrir remove movimento.
- Importacao de extrato com deduplicacao.
- Importacao de caixa (dizimos/ofertas) -> movimentos.
- Desafios/carne: gerar parcelas, link publico, pagamentos.
- Upload de boletos/comprovantes/assinaturas.

### Fase 7 - Rollout
- Feature flag por tenant.
- Deploy em staging -> homologacao -> producao.
- Observabilidade (logs Edge Functions + auditoria).
- Plano de rollback: desabilitar feature flag, manter tabelas antigas ativas.

## 9. Permissoes sugeridas (categoria financial.*)
- `financial.view`, `financial.view_reports` (existentes).
- `financial.manage_lancamentos`.
- `financial.manage_categories`.
- `financial.manage_beneficiaries`.
- `financial.manage_accounts`.
- `financial.import_extrato`.
- `financial.manage_cultos`.
- `financial.manage_desafios`.
- `financial.manage_mensagens`.

## 10. Testes e validacoes detalhadas
- Teste de RLS por tenant e por permissao.
- Teste de integridade de FK (categoria/beneficiario/conta).
- Teste de reconciliacao (lancamento pago = movimento criado).
- Teste de importacao (CSV/XLSX, duplicados, formatos).
- Teste de Edge Functions (carne, WhatsApp, IA).
- Teste de performance (listas com muitos lancamentos e movimentos).
- Teste de telas recuperadas (rotas ausentes no pacote local).
- Teste de configuracao de webhook externo com fallback.

## 11. Observabilidade e operacao
- Logs de Edge Functions com IDs de tenant e usuario.
- Auditoria obrigatoria em lancamentos e pagamentos.
- Alerts para falhas de WhatsApp e cron jobs.

## 12. Riscos e mitigacoes
- Conflito com `user_roles` do Church360: nao criar tabela duplicada.
- Diferenca de modelo de usuario (auth.users vs user_account): manter `created_by` em auth.users e usar `user_account` apenas para leitura.
- Dados antigos inconsistentes: backfill com validacao de totais.
- Dependencias externas (UAZAPI/IA): feature flag e fallback manual.
- Pasta do terceiro incompleta (paginas/componentes ausentes): validar com repo original e bloquear merge ate completar.
- Migrations incompletas do terceiro: derivar schema a partir do codigo e validar com testes.
- Webhook hardcoded: mover para configuracao segura e variavel por tenant.
- Buckets publicos e `getPublicUrl`: trocar por signed URLs e policies restritas.

## 13. Checklist de aceite (go/no-go)
- [ ] Todas as tabelas novas com `tenant_id` e RLS testadas.
- [ ] Fluxos principais operando em staging.
- [ ] Importacoes e conciliacao validadas.
- [ ] Desafios/carne com link publico funcionando.
- [ ] Logs e auditoria ativos.
- [ ] Rollback documentado.

## 14. Perguntas abertas (precisam decisao)
- Confirmar colunas extras em `church_settings` no schema real e ajustar migrations.

## 15. Proximos passos imediatos
1) Validar schema de `church_settings` e preparar migration com colunas financeiras faltantes.
2) Criar staging Supabase e rodar migracoes iniciais.
3) Implementar Edge Functions base (carne-por-token, create-user, whatsapp).
4) Portar telas criticas (lancamentos + contas financeiras) para Flutter.
