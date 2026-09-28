import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/courses/presentation/providers/courses_provider.dart';
import 'package:church360_app/features/events/presentation/providers/events_provider.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_student.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_turma.dart';
import 'package:church360_app/features/ministries/batismo/presentation/providers/baptism_providers.dart';
import 'package:church360_app/features/ministries/batismo/presentation/widgets/baptism_turmas_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// O sheet de Turmas é a porta de gestão da tela da turma: é por aqui que o
// Batismo abre a turma para editar. Em Cursos a mesma tela é vitrine.

const _ministryId = 'm1';
const _comEspelho = 'bt-1';
const _semEspelho = 'bt-2';
const _studyGroupId = 'sg-1';

BaptismTurma _turma(String id, String name) => BaptismTurma(
  id: id,
  tenantId: 't1',
  ministryId: _ministryId,
  name: name,
  status: BaptismTurmaStatus.ativa,
  createdAt: DateTime(2026, 9, 1),
);

Widget _host({Map<String, String> groupIds = const {}}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => showBaptismTurmasSheet(
                  context: context,
                  ministryId: _ministryId,
                  canCreate: true,
                  canEdit: true,
                  canDelete: true,
                ),
                child: const Text('abrir turmas'),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/turmas/:studyGroupId/gestao',
        builder: (context, state) =>
            Text('gestao ${state.pathParameters['studyGroupId']}'),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      baptismTurmasProvider(_ministryId).overrideWith(
        (ref) async => [
          _turma(_comEspelho, 'Batizandos 2026'),
          _turma(_semEspelho, 'Turma sem grupo'),
        ],
      ),
      baptismStudentsProvider(
        _ministryId,
      ).overrideWith((ref) async => <BaptismStudent>[]),
      baptismEventTypeCatalogProvider.overrideWith((ref) async => []),
      allEventsProvider.overrideWith((ref) async => []),
      ministryTurmaGroupIdsProvider(
        _ministryId,
      ).overrideWith((ref) async => groupIds),
    ],
    child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
  );
}

Future<void> _abrirFolha(WidgetTester tester) async {
  await tester.tap(find.text('abrir turmas'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('tocar no card abre a turma em modo gestão', (tester) async {
    await tester.pumpWidget(_host(groupIds: {_comEspelho: _studyGroupId}));
    await _abrirFolha(tester);

    expect(find.text('Batizandos 2026'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('baptism-turma-open-bt-1')));
    await tester.pumpAndSettle();

    // A folha fecha antes de navegar: quem voltar cai no workspace.
    expect(find.text('gestao $_studyGroupId'), findsOneWidget);
    expect(find.text('Batizandos 2026'), findsNothing);
  });

  testWidgets('turma sem grupo espelho não abre nada', (tester) async {
    await tester.pumpWidget(_host(groupIds: {_comEspelho: _studyGroupId}));
    await _abrirFolha(tester);

    await tester.tap(find.byKey(const ValueKey('baptism-turma-open-bt-2')));
    await tester.pumpAndSettle();

    expect(find.text('Turma sem grupo'), findsOneWidget);
    expect(find.textContaining('gestao'), findsNothing);
  });
}
