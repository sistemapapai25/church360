# Inventário visual — onda 3

Snapshot estático da árvore `lib/`, atualizado em 20/09/2026 durante a onda
de padronização de Members. O inventário serve para ordenar as próximas ondas;
ele não substitui a revisão de contexto de cada símbolo.

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
| Visitors | 34 | 4 | Próxima fatia sugerida |
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
membros, conversão, batismo, membresia, endereço, contato e familiares. A
listagem de Members deixou de referenciar diretamente `Icons.*`; símbolos de
marca e os identificadores de ícones persistidos dos ministérios continuam
fora desse catálogo por decisão de arquitetura.

## Próximo recorte

Migrar `visitors_list_screen.dart` e `visitor_visit_form_screen.dart`, usando a
mesma receita: `AppIcons` para ações semânticas, `GlassCard` para superfícies
de lista e `StatusBadge` apenas para estados de registro. Depois, revisar o
shell e as listas de Ministries antes de avançar para Events.
