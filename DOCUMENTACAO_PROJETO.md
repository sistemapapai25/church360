# Financas Papai - Documentacao Completa do Projeto

## Sumario
1. Visao geral
2. Stack e dependencias
3. Arquitetura e fluxo
4. Estrutura de pastas
5. Rotas e telas
6. Modelo de dados (schema Supabase)
7. Supabase: Auth, RLS, Storage e RPCs
8. Edge Functions e jobs
9. Fluxos principais (passo a passo)
10. Configuracoes e variaveis de ambiente
11. Pontos de atencao
12. Como rodar localmente

## 1) Visao geral
Financas Papai e um sistema web de gestao financeira para igrejas, com foco em:
- Contas a pagar/receber (lancamentos) e conciliacao bancaria (movimentos financeiros).
- Registro de cultos, dizimos e ofertas.
- Desafios financeiros com carne (carnet) de parcelas, lembretes e cobranca por WhatsApp.
- Cadastros (beneficiarios, categorias, contas financeiras, pessoas/participantes, usuarios).
- Emissao de recibos e reembolsos em PDF.

O backend e Supabase (Postgres + Auth + Storage + Edge Functions), e o frontend e React + Vite + TypeScript.

## 2) Stack e dependencias
### Frontend
- React 18 + TypeScript
- Vite (build e dev server)
- React Router (roteamento)
- Tailwind CSS + shadcn/ui (componentes baseados em Radix)
- TanStack Query (usado em telas de relatorios e configuracoes)
- date-fns (datas)
- xlsx (importacao de extratos)
- pdf-lib (geracao de PDFs de recibo/reembolso)

### Backend
- Supabase (Auth, Database, Storage, Edge Functions)
- Postgres com RLS (Row Level Security)
- pg_cron + pg_net (agendamento de jobs e chamadas HTTP)

### Mobile (opcional)
- Capacitor (android/ios)

## 3) Arquitetura e fluxo
### Camadas principais
- UI (React) -> Supabase client -> Database/Storage/Edge Functions
- Autenticacao centralizada em useAuth
- Controle de acesso por roles em user_roles + funcao is_admin()
- Layout privado com barra de navegacao (Navigation) e rotas protegidas

### Composicao do App
- App.tsx:
  - ErrorBoundary (captura erros globais)
  - QueryClientProvider (TanStack Query)
  - TooltipProvider
  - Toaster + Sonner (notificacoes)
  - Router + rotas publicas/privadas
  - ProtectedRoute (exige sessao)

### Duas linhas de dados financeiros
1) Lancamentos (contas a pagar/receber):
   - Registro de obrigacoes futuras ou realizadas.
   - Status (EM_ABERTO, PAGO, CANCELADO).
   - Pagamento gera movimento financeiro real.

2) Movimentos financeiros (extrato/caixa):
   - Fluxo real do caixa/banco.
   - Usado para conciliacao e resumo anual.

### Conectores importantes
- Pagamento de lancamento cria movimento_financeiro (origem = LANCAMENTO, ref_id = lancamento.id).
- Reabrir lancamento remove movimento_financeiro correspondente.
- Importar extrato cria movimentos (origem = EXTRATO ou AJUSTE).
- Importar caixa cria movimentos (origem = CULTO, ref_id = dizimo/oferta).

## 4) Estrutura de pastas
Resumo do que cada area contem:

- src/
  - App.tsx: router, providers, layout privado
  - main.tsx: bootstrap do React
  - pages/: telas do sistema
  - components/: componentes de UI e modais com logica de negocio
  - hooks/: hooks (auth, roles, toast, mobile)
  - services/: funcoes de dominio (ex.: categorias, cultos)
  - lib/: utilidades (supabase client, helpers)
  - integrations/supabase/: client e tipos do Supabase
  - types/: tipos auxiliares (alguns podem estar desatualizados)
  - utils/: helpers de data

- supabase/
  - migrations/: migrations do banco
  - functions/: Edge Functions (Deno)
  - config.toml: configuracoes de funcoes

- public/: assets e manifest PWA
- capacitor.config.ts: config do app mobile

## 5) Rotas e telas
### Publicas
- /auth
  - Login de usuario.
  - Chama ensure_default_categories apos login.

- /carne/:token
  - carne publico do participante (sem login).
  - Busca dados via Edge Function carne-por-token.

- /env
  - Debug simples para checar variaveis do Vite.

- /teste-supabase
  - Teste de conexao com Supabase.

### Privadas (com Navigation e ProtectedRoute)
#### Dashboard
- / (Dashboard)
  - Resumo do mes: em aberto, pagos, receitas.
  - Lista de proximos vencimentos.
  - Tabela base: lancamentos.

#### Movimentacoes
- /contas-a-pagar
  - Lista de lancamentos EM_ABERTO por mes.
  - Busca, modo tabela/card, editar e pagar.

- /contas-pagas
  - Lancamentos PAGO por mes.
  - Opcao de reabrir (volta para EM_ABERTO e remove movimento financeiro).

- /relatorio-pagamentos
  - Lista de lancamentos em aberto por periodo.
  - Envio de relatorio para webhook N8N (WhatsApp).

- /financeiro/agenda
  - Calendario mensal de vencimentos (lancamentos).

- /financeiro/resumo-anual
  - Resumo anual por mes usando movimentos_financeiros.
  - Filtro por conta e opcao de incluir transferencias internas.

#### Conciliacao
- /financeiro/lancamentos
  - Extrato consolidado (movimentos_financeiros).
  - Filtros por conta/mes/tipo (entradas/saidas/transferencias).
  - Edicao (descricao, data, categoria, beneficiario, comprovante).
  - Aplicar regras de classificacao.
  - Leitura de comprovante via IA (edge function analisar-comprovante).
  - Recibo/Reembolso em PDF e opcao de anexar como comprovante.
  - Upload e consulta de Extrato PDF por conta/mes.
  - Calculadora embutida.

- /movimentacoes/importar-extrato
  - Importa CSV/XLSX de extratos bancarios.
  - Mapeia colunas e cria movimentos_financeiros.
  - Deduplicacao opcional.

- /movimentacoes/importar-caixa
  - Converte dizimos/ofertas de cultos em movimentos_financeiros.
  - Marca registros como importados.

#### Cultos
- /movimentacoes/entradas-culto
  - Registro de culto (data, tipo, pregador, publico).
  - Cadastro de dizimos e ofertas do culto.
  - Salva em cultos, dizimos e ofertas.

- /lista-cultos
  - Lista e edita cultos do mes.
  - Edita dizimos e ofertas.

#### Desafios Financeiros
- /meus-desafios
  - CRUD de desafios.
  - Adicao de participantes (pessoas).
  - Envio de mensagens por WhatsApp.
  - Gera token de carne publico (carnet).

- /meus-desafios/gestao-carnes
  - Visualiza carne do participante (carnet).
  - Edita valor das parcelas e dia de vencimento.
  - Registra pagamento de parcela com mensagem de agradecimento.

- /meus-desafios/gestao-financeira
  - Relatorio de parcelas pagas e pendentes por periodo.

#### Cadastros
- /cadastros/beneficiarios
  - CRUD de beneficiarios (pessoa/empresa que recebe pagamentos).
  - Upload de assinatura (bucket Assinaturas).

- /cadastros/categorias
  - CRUD de categorias (hierarquia via parent_id).
  - Visualizacao por tipo (receita/despesa/transferencia).
  - Admin pode trocar o usuario em foco.

- /cadastros/contas-financeiras
  - CRUD de contas (CAIXA ou BANCO).
  - Upload de logo (bucket Logos).
  - Marca conta como Conta de Aplicacao (localStorage).

- /cadastros/tipos-culto
  - CRUD de tipos de culto.

- /cadastros/pessoas
  - CRUD de pessoas/participantes (admin).

- /cadastros/usuarios
  - Admin cria usuarios (edge function create-user) e define roles.

#### Configuracoes
- /configuracoes/regras-classificacao
  - Regras para auto-classificar movimentos (descricao -> categoria/beneficiario).

- /configuracoes/igreja
  - Dados da igreja para recibos/reembolsos.
  - Upload de assinatura (bucket Assinaturas).

- /configuracoes/mensagens
  - Templates de mensagens automaticas.

### Outras telas
- /env (EnvCheck) e /teste-supabase (TesteSupabase)
- EnvDebug.tsx (nao roteada)
- Index.tsx (nao usada)
- NotFound.tsx (404)

## 6) Modelo de dados (schema Supabase)
Referencia principal: src/integrations/supabase/types.ts
Observacao: alguns campos aparecem em codigo/migracoes mas nao estao nesse arquivo, o que sugere tipos desatualizados.

### 6.1 Relacoes (visao geral)
- auth.users -> profiles (auth_user_id)
- auth.users -> user_roles (user_id)
- profiles (1) -> church_settings (user_id)
- categories (1) -> lancamentos (categoria_id)
- beneficiaries (1) -> lancamentos (beneficiario_id)
- contas_financeiras (1) -> movimentos_financeiros (conta_id)
- cultos (1) -> dizimos (culto_id)
- cultos (1) -> ofertas (culto_id)
- desafios (1) -> desafio_participantes (desafio_id)
- pessoas (1) -> desafio_participantes (pessoa_id)
- desafio_participantes (1) -> desafio_parcelas (participante_id)

### 6.2 Tabelas (detalhadas)

#### public.auditoria
- id (uuid)
- entidade (text)
- entidade_id (uuid/text)
- acao (enum acao_auditoria)
- antes (jsonb)
- depois (jsonb)
- motivo (text)
- user_id (uuid)
- timestamp (timestamptz)
Uso: trilha de auditoria dos lancamentos.

#### public.beneficiaries
- id (uuid)
- user_id (uuid)
- name (text)
- documento (text)
- phone (text)
- email (text)
- observacoes (text)
- created_at (timestamptz)
- deleted_at (timestamptz)
- assinatura_path (text, opcional)
Uso: quem recebe pagamentos (despesas e reembolsos). Assinatura pode ser buscada no bucket Assinaturas.

#### public.bills
- id (uuid)
- user_id (uuid)
- amount (numeric)
- description (text)
- due_date (date)
- status (text)
- attachment_path (text)
- created_at (timestamptz)
Uso: nao mapeado diretamente no frontend atual.

#### public.categories
- id (uuid)
- user_id (uuid)
- name (text)
- tipo (enum tipo_categoria)
- parent_id (uuid, self-reference)
- ordem (int)
- created_at (timestamptz)
- deleted_at (timestamptz)
Uso: classificacao de lancamentos/movimentos. Hierarquia via parent_id.

#### public.church_settings
- user_id (uuid)
- igreja_nome (text)
- igreja_cnpj (text)
- responsavel_nome (text)
- responsavel_cpf (text)
- assinatura_path (text)
- created_at (timestamptz)
- updated_at (timestamptz)
Uso: dados para recibos e reembolsos.

#### public.classification_rules
- id (uuid)
- user_id (uuid)
- term (text)
- category_id (uuid -> categories.id)
- beneficiary_id (uuid -> beneficiaries.id)
- created_at (timestamptz)
Uso: auto-classificacao por descricao de movimentos.

#### public.contas_financeiras
- id (uuid)
- user_id (uuid)
- tipo (CAIXA ou BANCO)
- nome (text)
- instituicao (text)
- agencia (text)
- numero (text)
- saldo_inicial (numeric)
- saldo_inicial_em (date)
- logo (text)
- created_at (timestamptz)
Uso: contas usadas nos movimentos financeiros.

#### public.cultos
- id (uuid)
- user_id (uuid)
- data (date)
- tipo_id (uuid -> tipos_culto.id)
- pregador (text)
- adultos (int)
- criancas (int)
- created_at (timestamptz)
Uso: registro de cultos e origem para dizimos/ofertas.

#### public.dizimos
- id (uuid)
- culto_id (uuid -> cultos.id)
- nome (text)
- valor (numeric)
- importado (bool)
- created_at (timestamptz)
- tipo (text, opcional em alguns ambientes)
Uso: dizimos por culto.

#### public.ofertas
- id (uuid)
- culto_id (uuid -> cultos.id)
- valor (numeric)
- valor_dinheiro (numeric)
- valor_moedas (numeric)
- importado (bool)
- created_at (timestamptz)
Uso: ofertas do culto.

#### public.lancamentos
- id (uuid)
- user_id (uuid)
- tipo (enum tipo_lancamento)
- categoria_id (uuid -> categories.id)
- beneficiario_id (uuid -> beneficiaries.id)
- descricao (text)
- valor (numeric)
- vencimento (date)
- status (enum status_lancamento)
- data_pagamento (date)
- valor_pago (numeric)
- forma_pagamento (enum forma_pagamento)
- observacoes (text)
- boleto_url (text)
- comprovante_url (text)
- conta_id (uuid -> contas_financeiras.id)
- recibo_ano (int)
- recibo_numero (int)
- recibo_pdf_path (text)
- recibo_gerado_em (timestamptz)
- created_at, updated_at, deleted_at (timestamptz)
Uso: contas a pagar/receber e agenda financeira.

#### public.movimentos_financeiros
- id (uuid)
- user_id (uuid)
- conta_id (uuid -> contas_financeiras.id)
- data (date)
- tipo (ENTRADA ou SAIDA)
- valor (numeric)
- descricao (text)
- origem (CULTO, LANCAMENTO, AJUSTE, EXTRATO, etc)
- ref_id (uuid/text, referencia da origem)
- categoria_id (uuid -> categories.id)
- beneficiario_id (uuid -> beneficiaries.id)
- comprovante_url (text)
- created_at (timestamptz)
Uso: extrato real de caixa/banco.

#### public.pessoas
- id (uuid)
- nome (text)
- telefone (text)
- email (text)
- ativo (bool)
- auth_user_id (uuid -> auth.users.id)
- created_at (timestamptz)
Uso: participantes de desafios.

#### public.desafios
- id (uuid)
- titulo (text)
- descricao (text)
- valor_mensal (numeric)
- qtd_parcelas (int)
- data_inicio (date)
- dia_vencimento (int)
- lembrete_dias_antes (int[])
- ativo (bool)
- created_at (timestamptz)
Uso: configuracao dos desafios financeiros.

#### public.desafio_participantes
- id (uuid)
- desafio_id (uuid -> desafios.id)
- pessoa_id (uuid -> pessoas.id)
- participant_user_id (uuid -> auth.users.id)
- status (text: ATIVO/INATIVO)
- token_link (uuid)
- token_expires_at (timestamptz)
- valor_personalizado (numeric, opcional)
- created_at (timestamptz)
Uso: vinculo pessoa x desafio, gera carne (carnet).

#### public.desafio_parcelas
- id (uuid)
- participante_id (uuid -> desafio_participantes.id)
- competencia (date)
- vencimento (date)
- valor (numeric)
- status (text: ABERTO/PAGO/CANCELADO)
- pago_em (timestamptz)
- pago_valor (numeric)
- pago_obs (text)
- created_at (timestamptz)
Uso: parcelas do carne (carnet).

#### public.configuracao_mensagens
- id (uuid)
- tipo (text)
- titulo (text)
- template_mensagem (text)
- ativo (bool)
- created_at, updated_at (timestamptz)
Uso: templates de mensagens automaticas.

#### public.profiles
- auth_user_id (uuid)
- email (text)
- name (text)
- phone (text)
- active (bool)
- created_at (timestamptz)
Uso: perfil do usuario.

#### public.user_roles
- id (uuid)
- user_id (uuid)
- role (enum app_role)
- created_at (timestamptz)
Uso: controle de acesso (ADMIN/USER).

#### public.recibos_sequencia
- user_id (uuid)
- ano (int)
- ultimo_numero (int)
Uso: sequencia de recibos/reembolsos.

#### public.saldos_mensais
- id (uuid)
- user_id (uuid)
- conta_id (uuid -> contas_financeiras.id)
- mes (date ou string)
- saldo_inicial (numeric)
Uso: apoio a saldos por mes (nao usado diretamente na UI atual).

#### public.tipos_culto
- id (uuid)
- nome (text)
- ativo (bool)
- ordem (int)
- created_at (timestamptz)
Uso: lista de tipos para cultos.

#### public.transferencias
- id (uuid)
- user_id (uuid)
- conta_origem_id (uuid -> contas_financeiras.id)
- conta_destino_id (uuid -> contas_financeiras.id)
- data (date)
- descricao (text)
- valor (numeric)
- created_at (timestamptz)
Uso: estrutura para transferencias (nao usada diretamente na UI atual).

### 6.3 Views
- public.vw_culto_totais: soma de dizimos e ofertas por culto.
- public.vw_conciliacao: cruzamento entre lancamentos e movimentos financeiros para conciliacao.
- public.vw_lancamentos_whatsapp: view auxiliar para mensagens.

### 6.4 Enums
- app_role: ADMIN | USER
- tipo_lancamento: DESPESA | RECEITA
- status_lancamento: EM_ABERTO | PAGO | CANCELADO
- forma_pagamento: PIX | DINHEIRO | CARTAO | BOLETO | TRANSFERENCIA | OUTRO
- tipo_categoria: DESPESA | RECEITA | TRANSFERENCIA
- acao_auditoria: CREATE | UPDATE | DELETE | STATUS_CHANGE

## 7) Supabase: Auth, RLS, Storage e RPCs
### Auth
- Supabase Auth com email/senha.
- useAuth cria profile e garante admin para email especifico.

### Roles
- user_roles guarda ADMIN/USER.
- useUserRole consulta roles e define isAdmin.
- Funcao is_admin() no banco habilita bypass nas politicas.

### RLS
- RLS habilitado para tabelas criticas.
- Politicas geralmente permitem acesso ao proprio user_id, com excecoes para admin.
- Ha migrations de bypass admin para categorias, contas_financeiras, storage etc.

### Storage (buckets)
- Comprovantes (publico): comprovantes, recibos e extratos PDF.
- Assinaturas (privado): assinaturas de beneficiarios e da igreja.
- boletos (privado): boletos de lancamentos.
- Logos (nao esta nas migrations): logos de bancos.

### Funcoes RPC (Postgres)
- ensure_default_categories: cria categorias padrao para o usuario.
- has_role / is_admin: controle de acesso.
- atualizar_saldo_conta: registra movimento financeiro de entrada (culto).
- gerar_carne_para_participante: gera parcelas ao adicionar participante.
- atualizar_valor_participante: atualiza valor e parcelas em aberto.
- atualizar_valor_parcela: ajusta valor de uma parcela em aberto.
- next_recibo_num: gera sequencia de recibos (usado no PDF).
- registrar_transferencia: previsto para transferencias entre contas.

## 8) Edge Functions e jobs
### Edge Functions (supabase/functions)
- create-user
  - Cria usuario com service role.
  - Cria profile e role.
  - Exige admin.

- ensure-admin
  - Garante role ADMIN para email especifico.

- whatsapp-send-message
  - Envia mensagens via UAZAPI.
  - Entrada: { numero, mensagem }.

- analisar-comprovante
  - Usa IA (LOVABLE_API_KEY) para extrair recebedor, valor e data.
  - Sugere beneficiario/categoria via regras.

- carne-por-token (publica)
  - Retorna participante + parcelas pelo token.

- desafio-lembrete-vencimento
  - Envia lembretes de vencimento das parcelas.
  - Usa configuracao_mensagens e UAZAPI.

### Jobs
- pg_cron agenda chamada diaria para desafio-lembrete-vencimento (08:00).

## 9) Fluxos principais (passo a passo)
### 1. Lancamento -> Pagamento -> Movimento
1) Criar lancamento (status EM_ABERTO).
2) Pagar lancamento (dialogo): define conta, forma, data e valor.
3) Sistema atualiza lancamento para PAGO e cria movimento_financeiro (origem = LANCAMENTO, ref_id = lancamento.id).
4) Reabrir lancamento remove o movimento correspondente.

### 2. Importar extrato bancario
1) Usuario escolhe conta e arquivo CSV/XLSX.
2) Sistema faz parse e mostra preview.
3) Importa linhas selecionadas para movimentos_financeiros.

### 3. Registro de culto e importacao para caixa
1) Tela Entradas Culto cria culto + dizimos + ofertas.
2) Tela Importar Caixa lista dizimos/ofertas do mes.
3) Importa para movimentos_financeiros (origem = CULTO).

### 4. Desafio financeiro e carne (carnet)
1) Admin cria desafio.
2) Admin adiciona participante.
3) Trigger gera parcelas automaticamente.
4) Link publico permite participante ver parcelas.
5) Pagamentos podem ser registrados e geram mensagens de agradecimento.

### 5. Recibos e reembolsos (PDF)
1) Na tela de movimentos, escolher Recibo/Reembolso para saidas.
2) PDF gerado via pdf-lib com dados da igreja/beneficiario.
3) Pode anexar PDF como comprovante.

### 6. Classificacao automatica
1) Regras de classificacao definidas.
2) Botao Aplicar Regras atualiza movimentos do mes.
3) Opcao Ler e aplicar usa IA para sugerir beneficiario/categoria.

## 10) Configuracoes e variaveis de ambiente
### App
- VITE_PUBLIC_APP_URL / VITE_PUBLIC_URL / VITE_APP_URL / VITE_SITE_URL
  - Usado para gerar links publicos (makePublicUrl).

### Supabase (frontend)
- URL e ANON KEY estao hardcoded em src/integrations/supabase/client.ts.
- EnvCheck/EnvDebug exibem VITE_SUPABASE_URL e VITE_SUPABASE_ANON_KEY.

### Edge Functions
- SUPABASE_URL
- SUPABASE_ANON_KEY
- SUPABASE_SERVICE_ROLE_KEY (ou SERVICE_ROLE_KEY)
- UAZAPI_BASE_URL / UAZAPI_TOKEN (WhatsApp)
- LOVABLE_API_KEY (IA de comprovantes)

### Integracoes externas
- Webhook N8N (RelatorioPagamentos): URL fixa no codigo.

## 11) Pontos de atencao
- Tipos do Supabase podem estar desatualizados vs banco real (ex.: valor_personalizado em desafio_participantes).
- Algumas tabelas parecem existir apenas no banco (contas_financeiras, movimentos_financeiros) e nao aparecem em migrations.
- Ha migrations duplicadas para configuracao_mensagens e ajustes de RLS.
- Bucket Logos nao esta nas migrations; precisa existir no Supabase.
- Tela Index.tsx e EnvDebug.tsx nao estao roteadas.

## 12) Como rodar localmente
1) npm install
2) npm run dev

Scripts principais (package.json):
- dev: Vite dev server
- build: Vite build
- build:dev: build em modo development
- lint: ESLint
- preview: Vite preview

---
Fim.
