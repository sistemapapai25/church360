import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/courses/presentation/providers/courses_provider.dart';
import 'package:church360_app/features/events/presentation/providers/events_provider.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_student.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_turma.dart';
import 'package:church360_app/features/ministries/batismo/presentation/providers/baptism_providers.dart';
import 'package:church360_app/features/ministries/batismo/presentation/screens/tabs/batismo_alunos_tab.dart';
import 'package:church360_app/features/ministries/batismo/presentation/screens/tabs/batismo_turmas_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// A aba Turmas é a entrada do Batismo e a porta de gestão da tela da turma:
// é por aqui que o Batismo abre a turma para editar. Em Cursos a mesma tela
// é vitrine. "Alunos" é o atalho para todos os alunos de todas as turmas.

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

Widget _host({Map<String, String> groupIds = const {}, bool canEdit = true}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: BatismoTurmasTab(ministryId: _ministryId)),
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
      baptismChecklistTallyProvider(
        _ministryId,
      ).overrideWith((ref) async => {}),
      baptismMeetingRollsProvider(_ministryId).overrideWith((ref) async => []),
      for (final action in BaptismWriteAction.values)
        baptismCanWriteProvider((
          ministryId: _ministryId,
          action: action,
        )).overrideWith((ref) async => canEdit),
    ],
    child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
  );
}

Future<void> _abrirAba(WidgetTester tester, Widget host) async {
  await tester.binding.setSurfaceSize(const Size(900, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(host);
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
    await _abrirAba(tester, _host(groupIds: {_comEspelho: _studyGroupId}));

    expect(find.text('Batizandos 2026'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('baptism-turma-open-bt-1')));
    await tester.pumpAndSettle();

    expect(find.text('gestao $_studyGroupId'), findsOneWidget);
  });

  testWidgets('turma sem grupo espelho não abre nada', (tester) async {
    await _abrirAba(tester, _host(groupIds: {_comEspelho: _studyGroupId}));

    await tester.tap(find.byKey(const ValueKey('baptism-turma-open-bt-2')));
    await tester.pumpAndSettle();

    expect(find.text('Turma sem grupo'), findsOneWidget);
    expect(find.textContaining('gestao'), findsNothing);
  });

  testWidgets('busca filtra as turmas pelo nome', (tester) async {
    await _abrirAba(tester, _host());

    await tester.enterText(find.byType(TextField).first, 'sem grupo');
    await tester.pumpAndSettle();

    expect(find.text('Turma sem grupo'), findsOneWidget);
    expect(find.text('Batizandos 2026'), findsNothing);
  });

  testWidgets('"Alunos" abre todos os alunos de todas as turmas', (
    tester,
  ) async {
    await _abrirAba(tester, _host());

    await tester.tap(find.text('Alunos'));
    await tester.pumpAndSettle();

    final alunos = tester.widget<BatismoAlunosTab>(
      find.byType(BatismoAlunosTab),
    );
    expect(alunos.ministryId, _ministryId);
    expect(alunos.lockedTurmaId, isNull);
  });

  testWidgets('com permissão de edição a barra oferece o link', (tester) async {
    await _abrirAba(tester, _host());
    expect(find.text('Link de inscrição'), findsOneWidget);
    expect(find.text('Nova turma'), findsOneWidget);
  });

  testWidgets('sem permissão não há link nem turma nova', (tester) async {
    await _abrirAba(tester, _host(canEdit: false));
    expect(find.text('Link de inscrição'), findsNothing);
    expect(find.text('Nova turma'), findsNothing);
    // Consultar continua aberto: o atalho de alunos é leitura.
    expect(find.text('Alunos'), findsOneWidget);
  });
}
