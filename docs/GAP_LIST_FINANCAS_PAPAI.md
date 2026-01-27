# Gap List - Financas Papai (inventario inicial)

## Status
- Analise local concluida (sem alterar banco ou codigo).
- Pacote sincronizado com o repo original para `src/`, `supabase/` e `public/` (excluindo `supabase/.temp`).

## 1) Rotas/paginas ausentes (App.tsx) - resolvido
- `./pages/ImportarCaixa`
- `./pages/ResumoAnual`
- `./pages/Pessoas`
- `./pages/Desafios`
- `./pages/Carne`
- `./pages/GestaoFinanceiraDesafios`
- `./pages/CarnePublico`
- `./pages/ConfiguracaoMensagens`

## 2) Componentes ausentes (App.tsx) - resolvido
- `./components/ErrorBoundary`

## 3) Tabelas referenciadas no codigo
- `beneficiaries`
- `categories`
- `lancamentos`
- `contas_financeiras`
- `movimentos_financeiros`
- `classification_rules`
- `church_settings`
- `cultos`
- `dizimos`
- `ofertas`
- `tipos_culto`
- `vw_culto_totais`
- `profiles` (modelo do terceiro)
- `user_roles` (modelo do terceiro)

## 4) Tabelas criadas nas migrations do terceiro
- `lancamentos`
- `classification_rules`
- `auditoria`

## 5) Lacunas de schema (precisam ser definidas no Church360)
- `beneficiaries`, `categories`, `contas_financeiras`, `movimentos_financeiros`
- `cultos`, `dizimos`, `ofertas`, `tipos_culto` (ou mapear para `worship_service`)
- `vw_culto_totais` (view)
- `profiles`, `user_roles` (nao usar; substituir por modelo Church360)

## 6) RPCs usadas no codigo
- `ensure_default_categories`
- `next_recibo_num`

## 7) Edge Functions usadas no codigo
- `ensure-admin`
- `create-user`
- `analisar-comprovante`

## 8) Buckets usados no codigo
- `Assinaturas`
- `Comprovantes`

## 9) Endpoints hardcoded no codigo
- Supabase URL fixa em `financas-papai/src/integrations/supabase/client.ts`.
- Webhook N8N fixo em `financas-papai/src/pages/RelatorioPagamentos.tsx`.

## 10) Proximas decisoes
- Definir estrategia para substituir `profiles`/`user_roles` pelo modelo Church360.
- Definir buckets finais (padrao lowercase) e politica de signed URLs.
