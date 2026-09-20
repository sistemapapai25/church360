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

Revisar o shell e as listas de Ministries antes de avançar para Events. O
recorte de Visitors está completo; autenticação e dados reais continuam sendo
limitações da validação visual local.
