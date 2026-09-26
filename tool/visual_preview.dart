// flutter run -d chrome -t tool/visual_preview.dart
// Entrada exclusiva de desenvolvimento: os dados vivem apenas em memória.
import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/ministries/batismo/data/baptism_repository.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_member_suggestion.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_student.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_turma.dart';
import 'package:church360_app/features/ministries/batismo/presentation/providers/baptism_providers.dart';
import 'package:church360_app/features/ministries/batismo/presentation/screens/tabs/batismo_alunos_tab.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:church360_app/features/ministries/shared/presentation/widgets/ministry_workspace_shell.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _ministry = 'visual-preview';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Habilita a árvore semântica do Flutter Web para teclado/leitores e
  // automação da prévia (não altera a entrada de produção).
  WidgetsBinding.instance.ensureSemantics();
  final repository = _PreviewRepository();
  runApp(
    ProviderScope(
      overrides: [
        baptismRepositoryProvider.overrideWithValue(repository),
        ministryByIdProvider(_ministry).overrideWith((ref) async => null),
        currentUserHasPermissionProvider(
          'ministries.edit',
        ).overrideWith((ref) async => false),
        baptismChecklistTallyProvider(_ministry).overrideWith(
          (ref) async => {
            'demo-0': (done: 2, total: 5),
            'demo-1': (done: 5, total: 5),
          },
        ),
        baptismEventTypeCatalogProvider.overrideWith((ref) async => []),
        for (final action in BaptismWriteAction.values)
          baptismCanWriteProvider((
            ministryId: _ministry,
            action: action,
          )).overrideWith((ref) async => true),
      ],
      child: const _PreviewApp(),
    ),
  );
}

class _PreviewApp extends StatefulWidget {
  const _PreviewApp();

  @override
  State<_PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<_PreviewApp> {
  bool _dark = false;
  late final _router = GoRouter(
    initialLocation: '/batismo',
    routes: [
      ShellRoute(
        builder: _frame,
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => context.go('/batismo'),
                  child: const Text('Abrir prévia de Alunos'),
                ),
              ),
            ),
            routes: [
              GoRoute(
                path: 'batismo',
                builder: (context, state) => MinistryWorkspaceShell(
                  ministryId: _ministry,
                  fallbackTitle: 'Batismo nas Águas',
                  stats: const [
                    MinistryWorkspaceStat(
                      label: 'alunos de exemplo',
                      value: '4',
                      icon: Icons.school_outlined,
                    ),
                    MinistryWorkspaceStat(
                      label: 'turmas',
                      value: '2',
                      icon: Icons.groups_2_outlined,
                    ),
                  ],
                  tabs: [
                    MinistryWorkspaceTab(
                      label: 'Alunos',
                      builder: (_) =>
                          const BatismoAlunosTab(ministryId: _ministry),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'PAPAI — prévia visual',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: _router,
  );

  Widget _frame(BuildContext context, GoRouterState state, Widget child) =>
      Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Prévia visual · dados de exemplo',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    Semantics(
                      label: _dark ? 'Usar tema claro' : 'Usar tema escuro',
                      child: IconButton(
                        onPressed: () => setState(() => _dark = !_dark),
                        icon: Icon(
                          _dark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      );
}

/// Nenhum cliente de rede é inicializado nesta entrada. Somente as operações
/// de Alunos usadas na conferência visual são implementadas em memória.
class _PreviewRepository implements BaptismRepository {
  final _turmas = [
    BaptismTurma(
      id: 'turma-1',
      tenantId: 'demo',
      ministryId: _ministry,
      name: 'Sexta 19h',
      status: BaptismTurmaStatus.ativa,
      createdAt: DateTime(2026),
    ),
    BaptismTurma(
      id: 'turma-2',
      tenantId: 'demo',
      ministryId: _ministry,
      name: 'Domingo 10h',
      status: BaptismTurmaStatus.ativa,
      createdAt: DateTime(2026),
    ),
  ];
  final _students = [
    for (var index = 0; index < 4; index++)
      BaptismStudent(
        id: 'demo-$index',
        tenantId: 'demo',
        turmaId: index.isEven ? 'turma-1' : 'turma-2',
        fullName: [
          'Ana Carolina de Souza Albuquerque',
          'Bruno Lima',
          'Carla Santos',
          'Daniel Oliveira',
        ][index],
        status: BaptismStudentStatus.values[index % 3],
        source: index.isEven
            ? BaptismStudentSource.publica
            : BaptismStudentSource.manual,
        createdAt: DateTime(2026),
        birthDate: DateTime(1998 + index, 4, 12),
        turmaName: index.isEven ? 'Sexta 19h' : 'Domingo 10h',
      ),
  ];

  @override
  Future<List<BaptismStudent>> getStudents(
    String ministryId, {
    String? turmaId,
  }) async => [
    for (final s in _students)
      if (turmaId == null || s.turmaId == turmaId) s,
  ];
  @override
  Future<List<BaptismTurma>> getTurmas(String ministryId) async =>
      List.of(_turmas);
  @override
  Future<List<BaptismMemberSuggestion>> searchMembers({
    required String ministryId,
    required String query,
  }) async => [];
  @override
  Future<BaptismStudent> createStudent(BaptismStudent student) async {
    _students.add(student);
    return student;
  }

  @override
  Future<BaptismStudent> updateStudent(BaptismStudent student) async {
    final index = _students.indexWhere((item) => item.id == student.id);
    _students[index] = student;
    return student;
  }

  @override
  Future<void> deleteStudent(String id) async =>
      _students.removeWhere((student) => student.id == id);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Ação indisponível nesta prévia visual.');
}
