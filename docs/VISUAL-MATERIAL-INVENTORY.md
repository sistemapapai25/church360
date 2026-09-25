# Inventário visual — onda 4

Snapshot estático da árvore `lib/`, atualizado em 20/09/2026 durante a onda
de padronização de Visitors. O inventário serve para ordenar as próximas
ondas; ele não substitui a revisão de contexto de cada símbolo.

## Método

```powershell
rg -o "Icons\.[A-Za-z0-9_]+" lib --glob '*.dart'
rg -l "Icons\." lib --glob '*.dart'
```

O catálogo `lib/core/design/app_icons.dart` é contado separadamente. Na base
atual há 224 arquivos consumidores e 2.495 referências diretas a `Icons.*`.
O handoff anterior registrava 223 consumidores; a diferença é preservada como
um ajuste de inventário, não como uma remoção presumida.

## Ordem de migração

| Área | Referências | Arquivos | Situação nesta onda |
| --- | ---: | ---: | --- |
| Members | 207 | 4 | Slice completo: listagem, perfil e formulário migrados |
| Visitors | 34 | 4 | Slice completo: listagem, registro de visita, follow-up e estatísticas migrados |
| Ministries | 295 | 29 | Listagem, workspace compartilhado, detalhe/formulário, Batismo, Diaconato e Raízes migrados |
| Events | 158 | 9 | Slice completo: listagem, detalhe, formulário, registro e diálogos/widgets migrados |
| Groups | 98 | 6 | Slice completo: listagem, detalhe, formulários e reuniões migrados |
| Study Groups | 62 | 5 | Slice completo: listagem, detalhe, formulário e lição migrados |
| Church Schedule | 23 | 2 | Slice completo nesta onda: listagem e formulário migrados |
| News | 33 | 3 | Slice completo nesta onda: leitura, gestão e formulário migrados |
| Financeiro | 105 | 13 | Migrado nesta onda: telas, formulários, contas, categorias, comprovantes e widgets |
| Financeiro legado | 53 | 5 | Migrado nesta onda: contribuições, despesas, metas e relatórios |
| Community | 85 | 2 | Migrado nesta onda: shell, mural, classificados, membros e moderação; preservar Font Awesome |
| Reports (`core/screens/reports`) | 57 | 8 | Slice completo: oito relatórios migrados |
| Home Content | 28 | 2 | Slice completo nesta onda: banners e formulário migrados |
| Church Info | 41 | 2 | Slice completo nesta onda: leitura e formulário migrados |
| Devotionals | 48 | 3 | Slice completo nesta onda: lista, detalhe e formulário migrados |

Os números por área são referências textuais e podem incluir símbolos que
serão classificados como específicos de uma tela, além dos símbolos que podem
ser promovidos ao catálogo. A prioridade é migrar sem alterar contratos de
dados, rotas ou identificadores persistidos.

## Catálogo ampliado nesta onda

`AppIcons` agora cobre também limpeza e expansão de filtros, filtros de
membros, visitantes, acompanhamento, registro de visita, conversão, batismo,
membresia, endereço, contato, familiares, categorias e alertas. As quatro
telas do recorte de Visitors deixaram de declarar símbolos Material diretamente;
símbolos de marca e os identificadores de ícones persistidos dos ministérios
continuam fora desse catálogo por decisão de arquitetura.

## Onda 4 — Visitors

Os cards de visitante e o painel de busca agora usam `GlassCard`; os estados
de ciclo de vida e acompanhamento usam `StatusBadge`; os dois formulários e os
cards/gráficos de estatísticas usam a mesma superfície e o catálogo semântico.
Não houve alteração em rotas, permissões, repositórios ou contratos de dados.
Foram adicionados quatro testes de widget para proteger essas superfícies.

## Onda visual — Quick News, Testimonies e Prayer Requests

- `quick_news_list_screen.dart` e `quick_news_form_screen.dart` usam
  `GlassCard`, `StatusBadge` e `AppIcons` nos cards, estados, imagem, validade
  e ações, preservando upload, permissões e payloads.
- `testimonies_list_screen.dart` e `testimony_form_screen.dart` usam a mesma
  superfície compartilhada e o catálogo semântico para visibilidade, contato,
  campos e ações.
- `prayer_requests_list_screen.dart`, `prayer_request_detail_screen.dart` e
  `prayer_request_form_screen.dart` usam vidro nas superfícies principais,
  `StatusBadge` para o ciclo do pedido e `AppIcons` nos filtros, privacidade,
  métricas e ações. Os emojis de categoria/status continuam nos menus de
  domínio.
- A cobertura focada em
  `test/features/content/prayer_testimonies_quick_news_visual_test.dart`
  valida quatro cenários em memória.

Não houve alteração em banco, rotas, permissões, providers, repositórios,
upload ou contratos de dados.

## Onda visual — Home Content, Church Info e Devotionals

- `banners_list_screen.dart` e `banner_form_screen.dart` agora usam
  `GlassCard`, `StatusBadge` e `AppIcons` para miniaturas, ações, vínculo e
  publicação, preservando reordenação, upload, permissões e payloads.
- `church_info_screen.dart` usa `GlassCard` nas seções de identidade, missão,
  valores, horários, liderança, contato e redes; `church_info_form_screen.dart`
  agrupa os blocos editáveis na mesma superfície e usa o catálogo semântico.
  Os ícones Font Awesome das marcas sociais permanecem preservados.
- `devotionals_list_screen.dart`, `devotional_detail_screen.dart` e
  `devotional_form_screen.dart` reutilizam vidro nas superfícies principais,
  `StatusBadge` para rascunho/salvo e `AppIcons` nos controles de leitura,
  vídeo, anotações, formulário e comentários. Reações, comentários, vídeo,
  leitura e anotações continuam com os mesmos providers e fluxos.
- A cobertura focada em
  `test/features/content/home_church_devotionals_visual_test.dart` valida
  quatro cenários em memória.

Não houve alteração em banco, rotas, permissões, providers, repositórios,
upload ou contratos de dados.

## Onda visual — Bíblia e planos de leitura

- As onze telas de `bible` e `reading_plans` agora reutilizam `GlassCard` nas
  listas, capítulos, versículos, resultados, favoritos, léxico, detalhes,
  módulos e formulários; estados de plano e progresso usam `StatusBadge`.
- `AppIcons` ganhou somente as semânticas de leitura necessárias (livro,
  tradução, tipografia, navegação de capítulo, execução e reinício). Rotas,
  permissões, providers, repositórios e contratos de dados foram preservados.
- A cobertura focada em
  `test/features/bible_reading_plans_visual_test.dart` valida quatro cenários
  em memória, incluindo o overflow corrigido na grade de capítulos.

Não houve alteração em banco, rotas, permissões, providers, repositórios,
persistência, upload ou contratos de dados.

## Próximo recorte

Quick News, Testimonies, Prayer Requests, Home Content, Church Info,
Devotionals, Bíblia e Planos de Leitura foram concluídos nas ondas recentes.
O próximo recorte deve começar por `courses` e `support_materials`.
Autenticação e dados reais continuam sendo limitações da validação visual local.

### Contagem de encerramento

Considerando cada grupo funcional abaixo como um recorte revisável, restam
**7 recortes** para fechar a auditoria visual dos módulos ainda pendentes:

1. Formação: `courses`, `support_materials`.
2. Crianças, culto e transmissão: `kids`, `worship`, `live_stream`.
3. Escalas e automações: `schedule`, `dispatch`.
4. Pessoas auxiliares: `tags`, `duplicates`, `access_levels`, `branches`.
5. Administração e acesso: `permissions`, `notifications`, `qr_scanner`.
6. Gestão analítica: `analytics`, `custom_reports`.
7. Entrada e apoio: `auth`, `church_selector`, `support_chat`, `contribution`.

São **65 telas `screen.dart` ainda pendentes** pelo inventário atual. O número
de recortes é a unidade de planejamento; cada onda pode fechar vários módulos
relacionados sem alterar rotas, permissões ou contratos de dados.

## Onda visual — Ministries, primeiro recorte

- `ministries_list_screen.dart` agora usa `AppIcons`, `GlassCard`,
  `AppFilterBar` e `StatusBadge` para a busca, cards, ações, estado de erro e
  status inativo. A ordenação alfabética, a busca por nome/descrição, o
  roteamento especializado e a consulta de membros foram preservados.
- `ministry_team_tab.dart` e `ministry_scale_tab.dart` reutilizam `GlassCard`
  nas superfícies repetidas e o catálogo semântico para incluir membro,
  ações, eventos, histórico, busca e estados vazios/erro.
- `AppIcons` ganhou somente semânticas compartilháveis de Ministries:
  remoção de pessoa, ajuste, geração de escala e histórico.
- A cobertura focada da listagem foi adicionada em
  `test/features/ministries/ministries_list_visual_test.dart`; os testes
  existentes do shell, Equipe e Escala continuam cobrindo os fluxos de
  permissões, busca, expansão e responsividade.

Não houve alteração em rotas, permissões, providers, repositórios,
persistência ou contratos de dados.

## Onda visual — submódulos especializados do Ministries

- As telas operacionais do Diaconato (`Checklist`, `Ausentes` e `Lote de
  ceia`) agora reutilizam `GlassCard` nas superfícies de contexto, pessoas,
  triagem, itens, estados vazios e erro. A entrega de ceia também usa
  `StatusBadge` para o ciclo de status.
- As quatro telas de Raízes (`Dashboard`, `Agenda de visitas`, `Indicações de
  padrinhos` e `Padrinhos`) agora reutilizam `GlassCard` nas grades, ações,
  cards de visita, recomendações e perfis; status de visita usa o badge
  compartilhado.
- O catálogo `AppIcons` ganhou apenas semânticas compartilháveis para Raízes,
  ceia, agenda, padrinhos, recomendações e estados auxiliares. Nenhum ícone
  persistido de ministério, rota, permissão, provider, repositório ou contrato
  de dados foi alterado.
- A cobertura focada em
  `test/features/ministries/diaconato_raizes_visual_test.dart` protege o
  dashboard de Raízes e o checklist do Diaconato com repositórios em memória.

## Onda visual — Ministries, detalhe e formulário

- `ministry_detail_screen.dart` agora reutiliza `GlassCard` no cabeçalho,
  notificações, membros, escalas, estados vazios e CTA especializado; o
  status do ministério usa `StatusBadge`.
- `ministry_form_screen.dart` reutiliza `GlassCard` nas seções de dados, cor,
  funções, status e preview.
- `AppIcons` ganhou as semânticas compartilháveis de descrição, bloqueio,
  cancelamento, supervisão e segurança; não houve alteração em identificadores
  de ícones persistidos.
- A cobertura focada foi adicionada em
  `test/features/ministries/ministry_detail_form_visual_test.dart`.

Não houve alteração em rotas, permissões, providers, repositórios,
persistência ou contratos de dados.

## Onda visual — Batismo, submódulos de maior tráfego

- `batismo_checklist_tab.dart` agora usa `GlassCard` no catálogo de etapas e
  nos cards de progresso por aluno. Filtros, estados vazios, ações de etapa e
  checkboxes passaram a consumir `AppIcons`.
- `batismo_relatorios_tab.dart` e `batismo_whatsapp_tab.dart` preservam seus
  `GlassCard` existentes e passaram a usar o catálogo semântico para relatórios,
  PDF, compartilhamento, filtros, mensagens, busca e estados de erro.
- `AppIcons` ganhou somente semânticas compartilháveis para checklist, espera,
  PDF, compartilhamento, troca de turma, marcação e fixação. Ícones de marca e
  identificadores persistidos de ministério continuam fora do catálogo.
- A cobertura visual foi reforçada nos testes existentes de Checklist,
  Relatórios e WhatsApp, incluindo a presença das superfícies `GlassCard`.

Não houve alteração em rotas, permissões, providers, repositórios,
persistência, fila de mensagens, geração de PDF ou contratos de dados.

## Onda visual — Diaconato e notificações de ministério

- `diaconato_home_screen.dart` agora usa `GlassCard` no último culto, estado
  vazio, alerta de visitantes, erro e atalhos. Os indicadores e atalhos usam
  semânticas de `AppIcons`, preservando os links e o dispatch existentes.
- `ministry_notification_config_screen.dart` agora organiza contexto, público
  e gatilhos em `GlassCard`; ações de salvar, busca e adição usam `AppIcons`.
- O catálogo ganhou somente semânticas reutilizáveis de presença, ceia,
  ausência, captação, sincronização e bloqueio.
- A cobertura focada foi adicionada em
  `test/features/ministries/diaconato_notification_visual_test.dart`, com
  fakes sem rede e validação após rolagem das listas lazy.

Não houve alteração em rotas, permissões, providers, repositórios,
persistência ou contratos de dados.

## Onda visual — Events, listagem

- `events_list_screen.dart` agora reutiliza `GlassCard` nos estados vazio e
  nos cards de evento, `StatusBadge` para o ciclo do evento e `AppIcons` para
  navegação, filtro, seleção, ações, metadados e estados de erro.
- Filtros Próximos/Ativos/Todos, seleção em lote, permissões, links de
  inscrição, exclusão de ocorrências futuras e roteamento foram preservados.
- A cobertura focada foi adicionada em
  `test/features/events/events_list_visual_test.dart`, com providers em
  memória e sem acesso à rede.

Não houve alteração em rotas, permissões, providers, repositórios,
persistência ou contratos de dados.

## Onda visual — Events, detalhe, formulário e registro

- `event_detail_screen.dart` agora usa `AppIcons` nos estados de acesso,
  informações, inscritos e escalas; os cards de informação, inscrições,
  escalas e estados vazios reutilizam `GlassCard`, e o ciclo do evento usa
  `StatusBadge`.
- `event_form_screen.dart` usa o catálogo semântico nos campos, audiência,
  lembretes, séries e ações; o formulário inteiro reutiliza a superfície
  `GlassCard` sem alterar o fluxo de criação/edição ou de séries.
- `event_registration_screen.dart` usa `AppIcons` nos caminhos de membro e
  convidado; os formulários e o ingresso confirmado reutilizam `GlassCard`.
- Foi adicionada cobertura focada em
  `test/features/events/events_visual_surfaces_test.dart`, com eventos e
  providers em memória, sem acesso à rede.

Não houve alteração em banco, rotas, permissões, providers, repositórios,
persistência, regras de audiência, capacidade, inscrição ou contratos de
dados.

## Onda visual — Events, diálogos e widgets especializados

- `AddRegistrationDialog` agora usa o catálogo `AppIcons` nos estados de
  elegibilidade, busca, seleção e inscrição, preservando a fonte de membros,
  as mensagens de capacidade e o fluxo de gravação.
- `AudiencePicker` e `ReminderPicker` reutilizam `GlassCard` nos bottom sheets
  e passaram a consumir as semânticas compartilhadas para busca, grupos,
  ministérios, cargos, notificações e estados vazios.
- `SeriesImpactDialog`, `SeriesProgressBarrier` e `SeriesScopeToggle` agora
  usam as superfícies de vidro nos overlays e o catálogo semântico para
  impacto destrutivo, ajuda e operação longa; gates, copy, contagens vindas
  do servidor e escopo da série foram preservados.
- Não houve alteração em banco, rotas, permissões, providers, RPCs,
  persistência ou contratos de dados.

## Onda visual — Financeiro e Financeiro legado

- As telas e widgets de `features/financeiro` agora usam `AppIcons` para
  navegação, filtros, lançamentos, contas, categorias, comprovantes,
  confiança de IA e ações de formulário.
- Dashboard, listagem, extrato, contas e categorias reutilizam `GlassCard` nas
  superfícies principais; o resumo dos relatórios legados também usa o mesmo
  componente.
- `features/financial` recebeu a mesma migração semântica para contribuições,
  despesas, metas e relatórios, preservando o fluxo legado e seus contratos.
- A cobertura focada em
  `test/features/financeiro/financeiro_visual_surfaces_test.dart` valida os
  cards do dashboard com providers em memória e o badge de confiança.

Não houve alteração em banco, rotas, permissões, providers, repositórios,
persistência ou contratos de dados. Font Awesome, quando existente fora deste
recorte, e identificadores persistidos de ministério permanecem intactos.

## Onda visual — Community

- `community_screen.dart` agora consome `AppIcons` em navegação, estados vazios,
  ações do mural, classificados, membros, anexos, comentários e formulários.
- O card local compartilhado do feed passou a reutilizar `GlassCard`, mantendo
  o movimento sutil de hover; o WhatsApp continua usando Font Awesome para
  preservar o símbolo de marca.
- `community_admin_screen.dart` agora usa `GlassCard` nos itens de moderação e
  o mesmo catálogo semântico nos tabs, estados vazios e ações de aprovação.
- A cobertura focada em
  `test/features/community/community_visual_surfaces_test.dart` valida o
  mural vazio, a navegação semântica e o card de moderação com dados em memória.

Não houve alteração em banco, rotas, permissões, providers, repositórios,
persistência ou contratos de dados.

## Onda visual — Reports, primeiro recorte

- `attendance_report_screen.dart` reutiliza `GlassCard` no resumo e nas linhas
  de grupos, preservando o gráfico, a média e o indicador de presença.
- `events_report_screen.dart` e `groups_report_screen.dart` reutilizam
  `GlassCard` nas listagens e mantêm filtros, datas, contagens e estados
  existentes.
- A cobertura focada em
  `test/core/screens/reports/reports_visual_surfaces_test.dart` valida as três
  telas com providers em memória.

Não houve alteração em banco, rotas, permissões, providers, consultas ou
contratos dos três relatórios deste primeiro recorte.

## Onda visual — Reports, segundo recorte

- `active_groups_report.dart`, `upcoming_events_report.dart`,
  `upcoming_expenses_report.dart` e `member_growth_report.dart` reutilizam
  `GlassCard` nos filtros, resumos, gráficos, tabelas e itens clicáveis,
  preservando os acentos de status existentes.
- Os limites padrão de Active Groups e Upcoming Events/Expenses passaram a ser
  normalizados ao início do dia. Isso mantém estável a chave dos providers
  `family` durante rebuilds e evita reentrar em loading a cada atualização,
  sem mudar o período exibido.
- A cobertura focada em
  `test/core/screens/reports/reports_visual_surfaces_test.dart` agora valida
  sete cenários, incluindo os quatro relatórios deste recorte com providers em
  memória.

Não houve alteração em banco, rotas, permissões, consultas ou modelos de
dados. Reports fica concluído nesta auditoria visual.

## Onda visual — Members, perfil e formulário

- `member_profile_screen.dart` agora usa `GlassCard` nas seções recolhíveis do
  perfil, preservando a expansão sob demanda, os fluxos de LGPD, família,
  tags, liderança e QR Code.
- `member_form_screen.dart` agora usa `GlassCard` nas seções recolhíveis do
  cadastro e no vínculo obrigatório de responsável para menores, preservando
  validação, permissões, busca de CEP, família e salvamento.
- Os controles principais e símbolos de foto, navegação, alerta, jornada e
  cadastro passaram a consumir semânticas já existentes em `AppIcons`.
- O dock inferior recebeu o refinamento visual Liquid Glass em dois commits
  locais: cápsula flutuante, ancoragem ao viewport e teste de altura. Essa
  alteração acompanha esta onda para ser entregue junto com Members.

Não houve alteração em banco, rotas, permissões, providers, repositórios ou
contratos de dados.

## Onda visual — Groups, listagem e detalhe

- `groups_list_screen.dart` agora reutiliza `GlassCard` nos cards de grupo,
  `StatusBadge` para o ciclo ativo/inativo e `AppIcons` para filtro, estados,
  metadados e criação.
- `group_detail_screen.dart` agora reutiliza `GlassCard` no cabeçalho, descrição,
  membros, reuniões e materiais; o status do grupo e os controles dessas abas
  usam os componentes e semânticas compartilhados.
- O catálogo `AppIcons` ganhou semânticas para materiais e abas de grupo.
- Foi adicionada cobertura focada em
  `test/features/groups/groups_visual_surfaces_test.dart`, com providers em
  memória e sem acesso à rede.

## Onda visual — Groups, formulários

- `group_form_screen.dart` agora organiza informações básicas, liderança e
  reuniões em `GlassCard`, usa `StatusBadge` para o estado e `AppIcons` nas
  ações e campos.
- `meeting_form_screen.dart` reutiliza `GlassCard` para o grupo, a data e o
  conteúdo da reunião, com ações e campos no catálogo semântico.
- `visitor_form_dialog.dart` ganhou a superfície de vidro e `AppIcons` sem
  alterar o fluxo de cadastro, permissões ou payload.
- Foi adicionada cobertura focada em
  `test/features/groups/groups_forms_visual_test.dart`.

Não houve alteração em rotas, permissões, providers, repositórios,
persistência ou contratos de dados.

## Onda visual — Study Groups

- `study_groups_list_screen.dart` agora reutiliza `GlassCard` nos cards e no
  estado vazio, `StatusBadge` para o ciclo do grupo e `AppIcons` para ações,
  metadados, visibilidade e participação.
- `study_group_detail_screen.dart` organiza informações, lições,
  participantes e estados em `GlassCard`, com abas, status, ações e papéis no
  catálogo semântico.
- `study_group_form_screen.dart` separa informações, encontros e acesso/status
  em superfícies de vidro; o salvamento e as permissões permanecem iguais.
- `lesson_detail_screen.dart` usa uma superfície de conteúdo, badge do ciclo da
  lição e cards de recursos para vídeo, áudio e PDF.
- Foi adicionada cobertura focada em
  `test/features/study_groups/study_groups_visual_test.dart`, com repositório em
  memória e quatro cenários sem acesso à rede.

Não houve alteração em rotas, permissões, providers, repositórios,
persistência ou contratos de dados. Os ícones declarados no modelo de domínio
continuam preservados; as telas passaram a consumir o catálogo compartilhado.
