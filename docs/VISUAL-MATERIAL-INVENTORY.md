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
| Members | 207 | 4 | Listagem migrada; perfil e formulário ainda pendentes |
| Visitors | 34 | 4 | Slice completo: listagem, registro de visita, follow-up e estatísticas migrados |
| Ministries | 295 | 29 | Listagem e workspace compartilhado migrados nesta onda; detalhes e submódulos ainda pendentes |
| Events | 158 | 9 | Pendente |
| Financeiro | 105 | 13 | Pendente |
| Financeiro legado | 53 | 5 | Pendente |
| Community | 85 | 2 | Pendente; preservar Font Awesome |
| Reports (`core/screens/reports`) | 57 | 8 | Ícones compartilhados já parcialmente propagados |

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

## Próximo recorte

O recorte de Ministries agora cobre a listagem principal, a barra de busca, os
cards, o shell do workspace, os tabs compartilhados de Equipe e Escala, o
detalhe e o formulário de ministério. Rotas, permissões, consultas e
submódulos especializados continuam preservados. O próximo recorte deve
revisar os submódulos de alto tráfego antes de avançar para Events.
Autenticação e dados reais continuam sendo limitações da validação visual
local.

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
