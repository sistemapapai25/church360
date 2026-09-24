import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'ministry_pattern_guard.dart';

/// Fase 7 — a régua para o padrão de ministério não apodrecer.
///
/// Dois grupos, e os dois importam:
///
/// 1. **A árvore de hoje está no padrão** — é o que trava a regressão.
/// 2. **A régua morde** — cada regra reprovando um caso construído, e uma
///    delas reprovando a tela real depois de estragada de propósito. Sem
///    isso, uma régua quebrada passaria verde para sempre, e a suíte estaria
///    dizendo "tudo certo" sobre nada.
void main() {
  final packageRoot = findPackageRoot();

  group('a árvore de ministérios está no padrão', () {
    test('a varredura leu a árvore de verdade', () {
      final files = ministryDartFiles(packageRoot);
      final relative = files.map(ministryRelativePath).toList();

      // Passar vazio não é passar: se a resolução de caminho quebrar, a
      // régua inteira vira um teste vácuo. Estes números são piso, não meta.
      expect(
        files.length,
        greaterThan(30),
        reason: 'a varredura achou ${files.length} arquivos — pouco demais '
            'para ser a árvore de ministérios',
      );

      final homeScreens = relative.where(isMinistryHomeScreen).toList();
      expect(
        homeScreens.length,
        4,
        reason: 'esperava as quatro telas de workspace (genérico, batismo, '
            'raízes, diaconato) e vi: $homeScreens',
      );
      expect(relative.any(isWorkspaceShell), isTrue);
      expect(
        relative.where(isMinistryListSurface).length,
        greaterThanOrEqualTo(8),
      );
    });

    test('nenhum arquivo viola o padrão', () {
      final violations = checkMinistryTree(packageRoot);
      expect(
        violations,
        isEmpty,
        reason:
            'a régua do padrão de ministério reprovou:\n\n'
            '${violations.join('\n\n')}\n\n'
            'O padrão está em docs/PADRAO-MINISTERIO.md. Se o desvio for '
            'proposital, registre-o em patternExemptions com o motivo.',
      );
    });
  });

  group('a régua morde — tela de ministério fora do shell', () {
    test('home screen com Scaffold próprio reprova nas três regras', () {
      final violations = checkMinistrySource(
        path: '${ministriesRoot}louvor/presentation/screens/'
            'louvor_home_screen.dart',
        source: '''
class LouvorHomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Louvor'),
          bottom: const TabBar(tabs: [Tab(text: 'Equipe'), Tab(text: 'Escala')]),
        ),
        body: const TabBarView(children: [Text('a'), Text('b')]),
      ),
    );
  }
}
''',
      );

      final rules = violations.map((v) => v.rule).toSet();
      expect(rules, contains('shell-obrigatorio'));
      expect(rules, contains('guarda-de-entrada'));
      expect(rules, contains('abas-do-catalogo'));
      expect(rules, contains('abas-fora-do-shell'));
    });

    test('home screen no padrão passa', () {
      final violations = checkMinistrySource(
        path: '${ministriesRoot}louvor/presentation/screens/'
            'louvor_home_screen.dart',
        source: '''
class LouvorHomeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MinistrySubmoduleGuard(
      ministryId: ministryId,
      submoduleLabel: 'louvor',
      builder: (context) => MinistryWorkspaceShell(
        ministryId: ministryId,
        fallbackTitle: 'Louvor',
        tabs: ministryTabsFromCatalog(
          catalog: ref.watch(ministryTypeCatalogSyncProvider),
          typeCode: 'louvor',
          slots: const {},
        ),
      ),
    );
  }
}
''',
      );
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('a tela genérica real reprova quando o shell é arrancado', () {
      final real = File(
        '${packageRoot.path}/${ministriesRoot}presentation/screens/'
        'generic_ministry_home_screen.dart',
      );
      expect(real.existsSync(), isTrue, reason: 'cobaia sumiu: ${real.path}');

      final source = real.readAsStringSync();
      final path =
          '${ministriesRoot}presentation/screens/'
          'generic_ministry_home_screen.dart';

      // Intacta: passa.
      expect(
        checkMinistrySource(path: path, source: source),
        isEmpty,
        reason: 'a tela de referência já está fora do padrão',
      );

      // Estragada como a Fase 7 teme: passa a montar o corpo por fora.
      final broken = source.replaceAll(
        'MinistryWorkspaceShell(',
        'Scaffold(body: _MeuLayoutProprio(',
      );
      expect(broken, isNot(source), reason: 'a mutação não pegou');

      final rules = checkMinistrySource(
        path: path,
        source: broken,
      ).map((v) => v.rule).toSet();
      expect(rules, contains('shell-obrigatorio'));
    });
  });

  group('a régua morde — busca escrita à mão', () {
    const tab = '${ministriesRoot}shared/presentation/widgets/louvor_tab.dart';

    test('TextField de busca numa aba reprova, com a linha', () {
      final violations = checkMinistrySource(
        path: tab,
        source: '''
class LouvorTab extends StatelessWidget {
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: const InputDecoration(hintText: 'Buscar por nome...'),
    );
  }
}
''',
      );

      final busca = violations.where((v) => v.rule == 'busca-escrita-a-mao');
      expect(busca, hasLength(1));
      expect(busca.first.line, 5, reason: 'a linha do decoration');
    });

    test('estado de busca sem AppFilterBar reprova', () {
      final rules = checkMinistrySource(
        path: tab,
        source: '''
class _LouvorTabState extends State<LouvorTab> {
  final _searchController = TextEditingController();
  Widget build(BuildContext context) => const SizedBox();
}
''',
      ).map((v) => v.rule).toSet();
      expect(rules, contains('busca-sem-filter-bar'));
    });

    test('aba com AppFilterBar passa', () {
      final violations = checkMinistrySource(
        path: tab,
        source: '''
class _LouvorTabState extends State<LouvorTab> {
  final _searchController = TextEditingController();
  Widget build(BuildContext context) => AppFilterBar(
    searchController: _searchController,
    searchHint: 'Buscar por nome ou função...',
    onSearchChanged: (v) => setState(() => _query = v),
  );
}
''',
      );
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('seletor de membro numa folha segue livre', () {
      final violations = checkMinistrySource(
        path: '${ministriesRoot}shared/presentation/widgets/'
            'louvor_member_sheet.dart',
        source: '''
TextField(
  controller: _searchController,
  decoration: const InputDecoration(labelText: 'Buscar membro...'),
)
''',
      );
      expect(
        violations,
        isEmpty,
        reason: 'uma folha que procura gente fora da tela não é superfície '
            'de lista: ${violations.join('\n')}',
      );
    });
  });

  group('a régua sabe onde não opinar', () {
    test('arquivo fora de ministérios é ignorado', () {
      final violations = checkMinistrySource(
        path: 'lib/features/members/presentation/screens/members_list_screen.dart',
        source: '''
TextField(decoration: InputDecoration(hintText: 'Buscar membro'))
DefaultTabController(length: 2)
''',
      );
      expect(violations, isEmpty);
    });

    test('comentário que cita TabBar não reprova', () {
      final violations = checkMinistrySource(
        path: '${ministriesRoot}shared/presentation/widgets/louvor_tab.dart',
        source: '''
/// Esta tela não monta TabBar( nenhuma — quem monta é o shell.
// DefaultTabController( aqui seria erro.
class LouvorTab extends StatelessWidget {}
''',
      );
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });
}
