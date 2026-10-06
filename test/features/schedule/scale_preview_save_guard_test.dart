import 'dart:async';

import 'package:church360_app/features/events/domain/models/event.dart';
import 'package:church360_app/features/ministries/data/ministries_repository.dart';
import 'package:church360_app/features/ministries/domain/models/ministry.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:church360_app/features/permissions/data/role_contexts_repository.dart';
import 'package:church360_app/features/permissions/domain/models/role_context.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';
import 'package:church360_app/features/schedule/presentation/screens/scale_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

// "Salvar Escala" apaga a escala do ministério antes de gravar a prévia:
// não pode ficar habilitado com a prévia carregando ou com erro de leitura.

class _FakeMinistries implements MinistriesRepository {
  final members = Completer<List<MinistryMember>>();
  Object? functionsError;

  @override
  Future<List<MinistryMember>> getMinistryMembers(String ministryId) =>
      members.future;
  @override
  Future<Map<String, List<String>>> getMemberFunctionsByMinistry(
    String ministryId,
  ) async {
    if (functionsError != null) throw functionsError!;
    return {};
  }

  @override
  Future<Map<String, String>> getUserPhotoUrlsByIds(List<String> ids) async =>
      {};

  final saved = <String, List<MinistrySchedule>>{};
  final names = <String, String>{};
  final scheduleReads = <String>[];

  @override
  Future<List<MinistrySchedule>> getEventSchedules(String eventId) async {
    scheduleReads.add(eventId);
    return saved[eventId] ?? [];
  }

  @override
  Future<List<MinistrySchedule>> getMinistrySchedules(
    String ministryId,
  ) async => [for (final l in saved.values) ...l];
  @override
  Future<List<Map<String, String>>> getFunctionsCatalog() async => [];
  @override
  Future<Map<String, String>> getUserNamesByIds(List<String> ids) async => {
    for (final id in ids)
      if (names[id] != null) id: names[id]!,
  };
  final removed = <String>[];
  final added = <Map<String, dynamic>>[];
  @override
  Future<void> removeSchedule(String id) async => removed.add(id);
  @override
  Future<MinistrySchedule> addSchedule(Map<String, dynamic> data) async {
    added.add(data);
    throw UnimplementedError();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeContexts implements RoleContextsRepository {
  @override
  Future<List<RoleContext>> getContextsByMinistry(String ministryId) async =>
      [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, _FakeMinistries repo) async {
  tester.view.physicalSize = const Size(1400, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ministriesRepositoryProvider.overrideWithValue(repo),
        roleContextsRepositoryProvider.overrideWithValue(_FakeContexts()),
      ],
      child: const MaterialApp(
        home: ScalePreviewScreen(
          ministryId: 'm-1',
          events: [],
          jointMinistryIds: [],
          byFunction: true,
        ),
      ),
    ),
  );
}

VoidCallback? _saveButton(WidgetTester tester) => tester
    .widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Salvar Escala'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    )
    .onPressed;

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('Salvar só libera depois que a prévia carrega', (tester) async {
    final repo = _FakeMinistries();
    await _pump(tester, repo);
    await tester.pump();
    expect(_saveButton(tester), isNull);

    repo.members.complete([]);
    await tester.pumpAndSettle();
    expect(_saveButton(tester), isNotNull);
  });

  testWidgets('evento passado fica fora e quem já está salvo aparece', (
    tester,
  ) async {
    final repo = _FakeMinistries()..members.complete([]);
    final now = DateTime.now();
    final day = DateTime.utc(now.year, now.month, now.day, 19);
    repo.saved['futuro'] = [
      MinistrySchedule(
        id: 's-1',
        eventId: 'futuro',
        eventName: 'Culto',
        eventStartDate: day.add(const Duration(days: 3)),
        ministryId: 'm-1',
        ministryName: 'Louvor',
        memberId: 'u-ana',
        memberName: 'Ana',
        notes: 'Violão',
        createdAt: now,
      ),
    ];
    repo.names['u-ana'] = 'Ana';
    tester.view.physicalSize = const Size(1400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ministriesRepositoryProvider.overrideWithValue(repo),
          roleContextsRepositoryProvider.overrideWithValue(_FakeContexts()),
        ],
        child: MaterialApp(
          home: ScalePreviewScreen(
            ministryId: 'm-1',
            events: [
              Event(
                id: 'passado',
                name: 'Culto',
                startDate: day.subtract(const Duration(days: 4)),
                createdAt: now,
              ),
              Event(
                id: 'futuro',
                name: 'Culto',
                startDate: day.add(const Duration(days: 3)),
                createdAt: now,
              ),
            ],
            jointMinistryIds: const [],
            byFunction: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('1 evento(s) de dias anteriores'),
      findsOneWidget,
    );
    expect(repo.scheduleReads, isNot(contains('passado')));
    // Ana não tem vínculo com Violão hoje, mas está salva: aparece.
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('erro ao ler funções mostra o erro e não libera Salvar', (
    tester,
  ) async {
    final repo = _FakeMinistries()..functionsError = Exception('rede caiu');
    await _pump(tester, repo);
    repo.members.complete([]);
    await tester.pumpAndSettle();

    expect(find.textContaining('Não foi possível carregar'), findsOneWidget);
    expect(_saveButton(tester), isNull);
  });
  testWidgets('encontro de aula aparece com o professor e Salvar não mexe', (
    tester,
  ) async {
    final repo = _FakeMinistries()..members.complete([]);
    final now = DateTime.now();
    final day = DateTime.utc(now.year, now.month, now.day, 20).add(
      const Duration(days: 2),
    );
    repo.saved['aula'] = [
      MinistrySchedule(
        id: 's-prof',
        eventId: 'aula',
        eventName: 'Aula',
        eventStartDate: day,
        ministryId: 'm-1',
        ministryName: 'Batismo',
        memberId: 'u-gabi',
        memberName: 'Gabriela',
        notes: 'Professor(a)',
        createdAt: now,
      ),
    ];
    tester.view.physicalSize = const Size(1400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ministriesRepositoryProvider.overrideWithValue(repo),
          roleContextsRepositoryProvider.overrideWithValue(_FakeContexts()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScalePreviewScreen(
                      ministryId: 'm-1',
                      events: [
                        Event(
                          id: 'aula',
                          name: 'Aula',
                          eventType: 'aula',
                          startDate: day,
                          createdAt: now,
                        ),
                      ],
                      jointMinistryIds: const [],
                      byFunction: true,
                      lockedEventIds: const {'aula'},
                    ),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Gabriela'), findsOneWidget);
    await tester.tap(find.text('Salvar Escala'));
    await tester.pumpAndSettle();
    expect(repo.removed, isEmpty);
    expect(repo.added, isEmpty);
  });
}
