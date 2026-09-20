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
| Visitors | 34 | 4 | Listagem e registro de visita migrados; follow-up e estatísticas pendentes |
| Ministries | 295 | 29 | Próxima fatia sugerida após Visitors |
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
membresia, endereço, contato e familiares. `visitors_list_screen.dart` e
`visitor_visit_form_screen.dart` deixaram de declarar símbolos Material
diretamente; símbolos de marca e os identificadores de ícones persistidos dos
ministérios continuam fora desse catálogo por decisão de arquitetura.

## Onda 4 — Visitors

Os cards de visitante e o painel de busca agora usam `GlassCard`; os estados
de ciclo de vida e acompanhamento usam `StatusBadge`; o formulário de registro
de visita usa a mesma superfície e o catálogo semântico. Não houve alteração
em rotas, permissões, repositórios ou contratos de dados. Foram adicionados
dois testes de widget para proteger essas superfícies.

## Próximo recorte

Revisar `visitor_followup_form_screen.dart` e
`visitors_statistics_screen.dart` para concluir o recorte de Visitors; depois,
revisar o shell e as listas de Ministries antes de avançar para Events.
