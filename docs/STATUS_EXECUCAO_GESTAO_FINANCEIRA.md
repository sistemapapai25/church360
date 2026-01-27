# Status de Execucao - Integracao Gestao Financeira

## Contexto
Este status acompanha o plano de integracao e o plano de execucao segura.

## Status por fase (agora)
- Fase 0 (alinhamento): concluida.
- Fase 1 (banco em staging): concluida (schema base + migrations aplicadas).
- Fase 2 (storage/edge): em andamento (buckets/policies ok; Edge Functions base deployadas; secrets pendentes).
- Fase 3 (backend logico): pendente (ajustes de RPCs, IA/WhatsApp e jobs).
- Fase 4 (Flutter): pendente (telas, fluxos e validacoes).
- Fase 5 (migracao): pendente (estrategia A/B e backfill).

## O que ja foi feito
- Inventario inicial do pacote `financas-papai`.
- Gap list criado com telas ausentes, tabelas usadas no codigo, RPCs e buckets.
- Plano de execucao segura detalhado.
- Paginas/componentes ausentes baixados do repo original.
- Paridade validada para `src/`, `supabase/` e `public/` (excluindo `supabase/.temp`).
- Tentativa de backup via `supabase db dump` falhou (Docker nao disponivel).
- Decisoes tecnicas principais registradas no plano de integracao.
- Staging criado no Supabase: `khsupilgpzpjuociippe` (sa-east-1) e linkado.
- Schema base aplicado via `backend-scripts/00_schema_base.sql`.
- Migrations aplicadas ate `20260116000005` (sem pendencias).
- Criadas tabelas/enums ausentes no staging: `message_template`, `dispatch_rule`, `dispatch_job`, `dispatch_log`, `dispatch_status`.
- Sistema de acesso criado: `access_level_type`, `user_access_level`, `access_level_history` (tenant_id aplicado).
- `church_info` criado com tenant_id e indice.
- `devotionals` e `devotional_readings` criados com tenant_id + RLS (migracao `20260108000002` aplicada manualmente).
- `profissao` criado e seeds aplicadas via migrations.
- Buckets financeiros criados no staging: `boletos`, `comprovantes`, `assinaturas`, `logos` (privados).
- Policies de storage criadas para buckets financeiros (tenant + can_manage_financial).
- `can_manage_financial` criado em staging para suportar policies.
- Edge Functions existentes deployadas em staging: `auto-scheduler`, `dispatch-processor`, `status-poller`, `support-chat`, `uazapi-callback`.
- Migrations criadas no repo para `can_manage_financial`, buckets/policies financeiros e colunas financeiras em `church_settings`.
- Migrations `20260117000000-20260117000002` aplicadas no staging.
- Edge Functions financeiras portadas no repo (nao deployadas): `create-user`, `ensure-admin`, `carne-por-token`, `desafio-lembrete-vencimento`, `whatsapp-send-message`, `analisar-comprovante`.
- Migrations financeiras aplicadas no staging: `20260118000001` (funcoes/views + tabelas base ausentes) e `20260118000002` (RLS).
- `worship_service` e `worship_attendance` criadas no staging com tenant_id, total_attendance e compatibilidade com `attendance_count`/`date`.

## O que eu faria agora (acao imediata, ordem segura)
1) Fechar Edge/Storage do financeiro
- Definir secrets faltantes (UAZAPI/IA/SMTP) para staging.
- Fazer deploy das Edge Functions financeiras ja portadas.
- Saida: funcoes financeiras operantes no staging.

2) Smoke test tecnico no staging
- Criar template, regra e job de disparo (dispatch).
- Criar devocional e leitura (RLS/tenant).
- Validar busca de `profissao` e view `v_profissao`.
- Saida: validacao funcional minima.

3) Ajustes finais antes da integracao financeira
- Confirmar mapeamento de auth/tenant com `user_access_level` e `user_tenant_membership`.
- Documentar env vars e endpoints para Flutter.
- Saida: checklist para comecar a integracao no app.

## Bloqueios atuais
- Backup via `supabase db dump` bloqueado (Docker nao disponivel).
- Precisa de connection string para usar `pg_dump` local.
- Secrets pendentes para Edge Functions (UAZAPI/IA/SMTP).
- Edge Functions financeiras aguardam deploy no staging.

## Lembretes
- Usuario vai enviar secrets de staging (UAZAPI/IA/SMTP).

## Pedidos de aprovacao
- Posso executar o backup usando `pg_dump` com connection string?
- Posso configurar secrets de Edge Functions no staging?
