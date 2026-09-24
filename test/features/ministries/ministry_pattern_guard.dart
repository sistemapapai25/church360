/// Régua do padrão de ministério — Fase 7 ("não apodrecer").
///
/// O padrão inteiro do workspace de ministério mora em três peças, e a forma
/// de perdê-lo é sempre a mesma: alguém escreve o ministério novo do zero,
/// com `Scaffold` + `TabBar` próprios e uma busca à mão, e a tela nasce
/// parecida mas fora do sistema. Esta régua é uma varredura de código-fonte
/// que reprova exatamente isso, antes da revisão humana.
///
/// Ela lê texto, não widget: um teste de árvore de widgets não pega o caso
/// que interessa, que é uma tela **nova** que ninguém lembrou de testar. O
/// preço é ser heurística; por isso cada regra tem saída registrada em
/// [patternExemptions], com motivo, em vez de ser afrouxada.
///
/// As seis regras:
///
/// | id | onde vale | o que exige |
/// | :-- | :-- | :-- |
/// | `shell-obrigatorio`    | `*_home_screen.dart` | montar em `MinistryWorkspaceShell` |
/// | `guarda-de-entrada`    | `*_home_screen.dart` | passar pelo `MinistrySubmoduleGuard` |
/// | `abas-do-catalogo`     | `*_home_screen.dart` | abas por `ministryTabsFromCatalog` |
/// | `abas-fora-do-shell`   | ministérios, menos o shell | ninguém mais monta `TabBar`/`AppTabs` |
/// | `busca-escrita-a-mao`  | `*_tab.dart`, `*_list_screen.dart` | busca não é `TextField` com "Buscar" |
/// | `busca-sem-filter-bar` | `*_tab.dart`, `*_list_screen.dart` | estado de busca exige `AppFilterBar` |
///
/// O padrão em prosa está em `docs/PADRAO-MINISTERIO.md`.
library;

import 'dart:io';

/// Raiz do que esta régua fiscaliza. Fora daqui ela não opina.
const String ministriesRoot = 'lib/features/ministries/';

/// A única tela autorizada a montar abas.
const String _workspaceShellFile = 'ministry_workspace_shell.dart';

/// Saídas registradas, por regra: sufixo de caminho -> motivo.
///
/// Está vazio de propósito. Uma exceção nova entra aqui **com o motivo
/// escrito**, e não afrouxando a regra: a régua serve justamente para que o
/// desvio fique visível em diff.
const Map<String, Map<String, String>> patternExemptions = {};

/// Um desvio do padrão, já com endereço.
class MinistryPatternViolation {
  final String file;

  /// Linha (1-based). Zero quando a regra fala do arquivo inteiro.
  final int line;

  final String rule;
  final String message;

  const MinistryPatternViolation({
    required this.file,
    required this.line,
    required this.rule,
    required this.message,
  });

  @override
  String toString() =>
      '${line > 0 ? '$file:$line' : file}\n    [$rule] $message';
}

String _normalize(String path) => path.replaceAll('\\', '/');

bool isMinistryFile(String path) => _normalize(path).contains(ministriesRoot);

bool isMinistryHomeScreen(String path) =>
    isMinistryFile(path) && _normalize(path).endsWith('_home_screen.dart');

/// Superfície de lista: aba de workspace ou a listagem de ministérios. São as
/// telas em que "buscar" quer dizer filtrar o que já está na tela — e é onde
/// a `AppFilterBar` é obrigatória.
///
/// Um seletor de membro dentro de uma folha (`*_sheet.dart`,
/// `ministry_member_actions.dart`) **não** é isso: ali o campo procura gente
/// que não está na tela, e segue livre.
bool isMinistryListSurface(String path) {
  final p = _normalize(path);
  if (!isMinistryFile(p)) return false;
  return p.endsWith('_tab.dart') || p.endsWith('_list_screen.dart');
}

bool isWorkspaceShell(String path) =>
    _normalize(path).endsWith(_workspaceShellFile);

/// Apaga o conteúdo das linhas de comentário, preservando a numeração — um
/// `///` que cita `TabBar` para explicar a regra não pode reprovar o arquivo.
String stripDartComments(String source) {
  final out = <String>[];
  var inBlock = false;
  for (final line in source.split('\n')) {
    final trimmed = line.trimLeft();
    if (inBlock) {
      out.add('');
      if (trimmed.contains('*/')) inBlock = false;
      continue;
    }
    if (trimmed.startsWith('/*')) {
      out.add('');
      if (!trimmed.contains('*/')) inBlock = true;
      continue;
    }
    if (trimmed.startsWith('//')) {
      out.add('');
      continue;
    }
    out.add(line);
  }
  return out.join('\n');
}

final RegExp _tabWidgets = RegExp(
  r'\b(AppTabs|TabBar|TabBarView|DefaultTabController)\s*\(',
);

final RegExp _handRolledSearch = RegExp(
  r'\b(hintText|labelText)\s*:\s*[^,\n]*(buscar|pesquis|procur|filtrar)',
  caseSensitive: false,
);

final RegExp _searchState = RegExp(
  r'\b_?(searchController|searchQuery|searchTerm|searchText|buscaController|textoBusca)\b',
  caseSensitive: false,
);

bool _exempt(String rule, String file) {
  final byRule = patternExemptions[rule];
  if (byRule == null) return false;
  return byRule.keys.any(file.endsWith);
}

/// Passa a régua em um arquivo. Lista vazia = está no padrão — ou não é
/// arquivo de ministério, caso em que a régua não opina.
List<MinistryPatternViolation> checkMinistrySource({
  required String path,
  required String source,
}) {
  final file = _normalize(path);
  if (!isMinistryFile(file)) return const [];

  final violations = <MinistryPatternViolation>[];
  void add(String rule, int line, String message) {
    if (_exempt(rule, file)) return;
    violations.add(
      MinistryPatternViolation(
        file: file,
        line: line,
        rule: rule,
        message: message,
      ),
    );
  }

  final code = stripDartComments(source);
  final lines = code.split('\n');

  if (isMinistryHomeScreen(file)) {
    if (!code.contains('MinistryWorkspaceShell(')) {
      add(
        'shell-obrigatorio',
        0,
        'tela de ministério montada fora do shell. O corpo tem que ser um '
            'MinistryWorkspaceShell — cabeçalho, indicadores e abas vêm dele.',
      );
    }
    if (!code.contains('MinistrySubmoduleGuard(')) {
      add(
        'guarda-de-entrada',
        0,
        'workspace sem MinistrySubmoduleGuard: quem entra é vínculo ou visão '
            'global, e essa decisão não se reescreve por tela.',
      );
    }
    if (!code.contains('ministryTabsFromCatalog(')) {
      add(
        'abas-do-catalogo',
        0,
        'abas fixas no código. Declare slots e deixe ministryTabsFromCatalog '
            'cruzar com public.ministry_type — senão o catálogo deixa de mandar.',
      );
    }
  }

  if (!isWorkspaceShell(file)) {
    for (var i = 0; i < lines.length; i++) {
      if (_tabWidgets.hasMatch(lines[i])) {
        add(
          'abas-fora-do-shell',
          i + 1,
          'abas montadas à mão. Só o ministry_workspace_shell.dart monta '
              'abas; o resto entrega tabs a ele.',
        );
      }
    }
  }

  if (isMinistryListSurface(file)) {
    for (var i = 0; i < lines.length; i++) {
      if (_handRolledSearch.hasMatch(lines[i])) {
        add(
          'busca-escrita-a-mao',
          i + 1,
          'busca escrita à mão. Numa superfície de lista o campo de busca é o '
              'searchHint da AppFilterBar, não um TextField próprio.',
        );
      }
    }
    if (!code.contains('AppFilterBar(') && _searchState.hasMatch(code)) {
      add(
        'busca-sem-filter-bar',
        0,
        'a tela guarda estado de busca mas não usa AppFilterBar. Busca, '
            'filtros e ações moram na mesma faixa.',
      );
    }
  }

  return violations;
}

/// Todo `.dart` sob [ministriesRoot], em ordem estável.
///
/// Separado de [checkMinistryTree] para que o teste possa conferir **o que
/// foi lido** antes de comemorar o resultado: uma varredura que não achou
/// arquivo nenhum passa vazia, e passar vazio não é passar.
List<File> ministryDartFiles(Directory packageRoot) {
  final root = Directory('${packageRoot.path}/$ministriesRoot');
  if (!root.existsSync()) {
    throw StateError('não achei $ministriesRoot em ${packageRoot.path}');
  }
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

/// Caminho relativo ao pacote, com barras normais, como as regras esperam.
String ministryRelativePath(File file) =>
    '$ministriesRoot${_normalize(file.path).split(ministriesRoot).last}';

/// Passa a régua em toda a árvore de ministérios.
List<MinistryPatternViolation> checkMinistryTree(Directory packageRoot) {
  final violations = <MinistryPatternViolation>[];
  for (final f in ministryDartFiles(packageRoot)) {
    violations.addAll(
      checkMinistrySource(
        path: ministryRelativePath(f),
        source: f.readAsStringSync(),
      ),
    );
  }
  return violations;
}

/// Sobe até a pasta que tem `pubspec.yaml`. O diretório de trabalho do
/// `flutter test` costuma ser a raiz do pacote, mas contar com isso deixaria
/// a régua refém de quem a chama.
Directory findPackageRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('não achei o pubspec.yaml a partir de ${Directory.current}');
}
