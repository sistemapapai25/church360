# O padrão de ministério

> Escrito em 24/09/2026, Fase 7 do plano
> `.planning/PLANO-2026-09-23-MINISTERIO-PADRAO-HERDADO.md`.
> A régua que faz valer o que está aqui é
> `test/features/ministries/ministry_pattern_guard_test.dart`.

Um ministério é um **app dentro do app**: entra-se nele por uma porta, ele tem
cabeçalho, indicadores e abas próprias, e cada aba manda em si mesma. O
Batismo foi o primeiro a ser escrito assim, e o esqueleto dele ficou sem dono
— hoje os quatro workspaces (genérico, Batismo, Raízes, Diaconato) são a
**mesma tela** com abas diferentes.

Este documento existe para o próximo ministério **não ser escrito do zero**.

---

## 1. As três peças

| Peça | Arquivo | Responde |
| :--- | :--- | :--- |
| **Guarda** | `shared/presentation/widgets/ministry_submodule_guard.dart` | quem entra |
| **Shell** | `shared/presentation/widgets/ministry_workspace_shell.dart` | como a tela se parece |
| **Catálogo** | `shared/domain/ministry_type_catalog.dart` + `public.ministry_type` | quais abas, em que ordem, sob que rótulo |

Nenhuma tela de ministério desenha cabeçalho, barra de abas ou controle de
entrada por conta própria. Quem faz isso são essas três, e é só o que a régua
cobra.

### 1.1 Quem entra ≠ o que pode fazer

É a regra que mais se perde quando alguém reescreve uma tela:

| Eixo | Quem decide |
| :--- | :--- |
| **Entrar** no workspace | vínculo em `ministry_member` **ou** visão global (`ministries.view_all` / `.manage` / …) |
| **Fazer** algo lá dentro | permissão da aba, via cargo RBAC (ex.: `ministry_finance.view`) |
| Ver **todos** os ministérios | `ministries.view_all` e companhia |

`ministries.view` dá acesso ao **hub** (`/ministries`), não a todos os
ministérios. Por isso a rota `/ministries/:id` **não** tem `PermissionOnlyRoute`
— gatear por ela tiraria do membro vinculado o departamento dele. Quem gateia
é o `MinistrySubmoduleGuard`, dentro da tela.

---

## 2. O caminho normal: ministério novo sem código nenhum

Um ministério de tipo `generic` já nasce com as cinco abas base — Equipe,
Escala, Financeiro, WhatsApp e Relatórios — pela rota `/ministries/:id`, que
monta a `GenericMinistryHomeScreen`. **Vinte e quatro dos vinte e sete
ministérios em produção são assim.**

Se o pedido é "quero um ministério novo", a resposta quase sempre é: cadastre
o ministério. Não há código a escrever.

---

## 3. Quando o tipo precisa de abas próprias

Aí sim há trabalho — e ele é, em ordem:

### 3.1 Uma migration no catálogo

`public.ministry_type` é a fonte única de qual aba existe, em que ordem, com
que rótulo, e se o tipo tem atalho de rota:

```sql
INSERT INTO public.ministry_type
  (code, label, description, tabs, route_suffix, offered_on_create, sort_order)
VALUES (
  'louvor',
  'Louvor',
  'Escalas, repertório e equipe do louvor.',
  '[{"key":"equipe","label":"Equipe"},
    {"key":"escala","label":"Escala"},
    {"key":"repertorio","label":"Repertório"}]'::jsonb,
  NULL,          -- abre em /ministries/:id mesmo
  true,          -- aparece no formulário de criação
  40
);
```

A tabela **não tem `tenant_id`**: ela descreve o que o app sabe montar, não
dado de igreja. Só migration escreve nela (sem policy de escrita, grants
revogados).

### 3.2 Um slot no Dart, para cada chave nova

A tela declara o que sabe montar; o catálogo decide o que entra:

```dart
tabs: ministryTabsFromCatalog(
  catalog: ref.watch(ministryTypeCatalogSyncProvider),
  typeCode: typeCode,
  slots: {
    MinistryTabKeys.equipe: MinistryTabSlot(
      defaultLabel: 'Equipe',
      count: teamCount?.toString(),
      builder: (_) => MinistryTeamTab(ministryId: ministryId),
    ),
    // ... e a chave nova, com o widget novo
  },
),
```

Chaves já registradas: `equipe`, `escala`, `financeiro`, `whatsapp`,
`relatorios`, `alunos`, `checklist`, `presenca`, `painel`
(`MinistryTabKeys`).

O cruzamento tem saída pelo lado seguro nas duas falhas possíveis:

- **tipo fora do catálogo** (ou catálogo que não chegou): a tela usa todos os
  slots que declarou, na ordem em que os declarou;
- **chave que o app não conhece**: ignorada, porque uma aba sem widget
  nasceria vazia.

O caso que **não** tem rede é o inverso: chave que a tela tem e o catálogo não
lista **sai da tela**. É o preço de o catálogo mandar de verdade.

### 3.3 Tela própria — último recurso

Só vale a pena quando o tipo tem indicadores próprios no cabeçalho ou telas
internas (Batismo, Raízes, Diaconato). O esqueleto é sempre este:

```dart
class LouvorHomeScreen extends ConsumerWidget {
  final String ministryId;
  const LouvorHomeScreen({super.key, required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MinistrySubmoduleGuard(
      ministryId: ministryId,
      submoduleLabel: 'louvor',
      builder: (context) => MinistryWorkspaceShell(
        ministryId: ministryId,
        fallbackTitle: 'Louvor',
        stats: const [ /* MinistryWorkspaceStat(...) */ ],
        tabs: ministryTabsFromCatalog(
          catalog: ref.watch(ministryTypeCatalogSyncProvider),
          // Tipo com tela própria ganha uma constante em MinistryTypeCodes —
          // que nomeia só os quatro que o Dart precisa citar, não o catálogo.
          typeCode: MinistryTypeCodes.louvor,
          slots: { /* ... */ },
        ),
      ),
    );
  }
}
```

E, junto: `route_suffix` no catálogo (ex.: `/louvor`) mais a `GoRoute`
correspondente em `core/navigation/app_router.dart`. O hub já manda para o
lugar certo sozinho — ele pergunta ao catálogo (`catalog.routeFor(...)`), não
a um `switch`.

**Se a aba exige permissão** (como o Financeiro), quem cobra é a própria aba,
ou um `MinistrySubmoduleGuard` com `requiredPermission`. Não é o shell.

---

## 4. Busca, filtros e ações: `AppFilterBar`

Toda superfície de lista — aba de workspace, listagem de ministérios — põe
busca, filtros e ações na **mesma faixa**, e essa faixa é a `AppFilterBar` de
`core/widgets/`:

```dart
AppFilterBar(
  searchController: _search,
  searchHint: 'Buscar por nome ou função...',
  onSearchChanged: (v) => setState(() => _query = v),
  primaryAction: canManage
      ? AppFilterAction(
          label: 'Incluir membro',
          icon: AppIcons.personAdd,
          onPressed: _addMember,
        )
      : null,
)
```

Ela já resolve altura única dos controles, quebra em duas linhas no celular e
a família visual do campo. Um `TextField` de busca escrito à mão perde as
três, e é o que a régua reprova.

**A exceção legítima:** um seletor que procura gente **fora** da tela — o
"Buscar membro" de `ministry_member_actions.dart`, de `student_form_sheet.dart`
ou da configuração de notificação. Ali o campo não filtra uma lista, ele
consulta o cadastro. Por isso a régua só olha `*_tab.dart` e
`*_list_screen.dart`.

---

## 5. A régua

`test/features/ministries/ministry_pattern_guard_test.dart` varre
`lib/features/ministries/**` como texto e reprova seis desvios:

| id | onde vale | o que exige |
| :--- | :--- | :--- |
| `shell-obrigatorio` | `*_home_screen.dart` | montar em `MinistryWorkspaceShell` |
| `guarda-de-entrada` | `*_home_screen.dart` | passar pelo `MinistrySubmoduleGuard` |
| `abas-do-catalogo` | `*_home_screen.dart` | abas por `ministryTabsFromCatalog` |
| `abas-fora-do-shell` | ministérios, menos o shell | ninguém mais monta `TabBar`/`AppTabs` |
| `busca-escrita-a-mao` | `*_tab.dart`, `*_list_screen.dart` | busca é o `searchHint` da `AppFilterBar` |
| `busca-sem-filter-bar` | `*_tab.dart`, `*_list_screen.dart` | estado de busca exige `AppFilterBar` |

```
flutter test test/features/ministries/ministry_pattern_guard_test.dart
```

Ela lê **texto**, não árvore de widgets, de propósito: o caso que interessa é
a tela nova que ninguém lembrou de testar, e um teste de widget só pega o que
alguém já se lembrou de montar. O preço é ser heurística.

O próprio teste também **prova que a régua morde**: cada regra reprova um caso
construído, e uma delas reprova a `GenericMinistryHomeScreen` real depois de
estragada de propósito. Sem isso, uma régua quebrada passaria verde para
sempre.

**Exceção proposital** entra em `patternExemptions`, no topo de
`ministry_pattern_guard.dart`, com o motivo escrito — nunca afrouxando a
regra. Hoje o mapa está vazio.

---

## 6. O que já mordeu (e a régua não pega)

- **`public.unaccent` não existe neste banco.** Uma migration que a use morre
  na primeira linha e não atualiza nada. Foi assim que `ministry_type` e
  `slug` ficaram vazios de maio a setembro.
- **`plpgsql` não valida corpo no `CREATE`.** Função que chama helper
  inexistente é aceita e só quebra em runtime.
- **Realtime não é ligado por migration.** Depois de gravar, invalide o
  provider; não conte com `onPostgresChanges`.
- **Policy de `INSERT` não é permissão de gravar.** `NOT NULL`, `CHECK` e a
  RLS das tabelas de apoio travam depois.
- **`role_context_id` é decorativo.** `check_user_permission` ignora a coluna:
  um cargo "no contexto do ministério X" vale no tenant inteiro.

---

## 7. O que este padrão **não** resolve

- **RBAC por ministério.** Hoje a permissão é por **módulo**
  (`ministries.*`, `ministry_finance.*`, `baptism.*`, …) e quem individualiza
  é o vínculo. Permissão por ministério é a **Fase 8**, e ela depende de gerar
  `slug` para os 27 registros — todos `NULL` hoje.
- **RLS de `ministry`.** A lista filtra por `visibleMinistriesProvider`, que é
  cliente. Ninguém confirmou que o banco sustenta o mesmo recorte.
