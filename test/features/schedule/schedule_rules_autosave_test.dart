import 'dart:async';

import 'package:church360_app/features/events/data/events_repository.dart';
import 'package:church360_app/features/events/presentation/providers/events_provider.dart';
import 'package:church360_app/features/ministries/data/ministries_repository.dart';
import 'package:church360_app/features/ministries/domain/models/ministry.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:church360_app/features/permissions/data/role_contexts_repository.dart';
import 'package:church360_app/features/permissions/domain/models/role_context.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';
import 'package:church360_app/features/schedule/presentation/screens/schedule_rules_preferences_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Regras & Preferências salva sozinha: 800 ms depois da última mudança, um
// save por vez, e função nova só entra com categoria.

class _FakeMinistries implements MinistriesRepository {
  @override
  Future<List<MinistryMember>> getMinistryMembers(String ministryId) async => [];
  @override
  Future<Map<String, List<String>>> getMemberFunctionsByMinistry(String ministryId) async => {};
  @override
  Future<Map<String, String>> getUserPhotoUrlsByIds(List<String> ids) async => {};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEvents implements EventsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeContexts implements RoleContextsRepository {
  final saves = <Map<String, dynamic>>[];
  Completer<void>? gate;
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<List<RoleContext>> getContextsByMinistry(String ministryId) async => [
        const RoleContext(
          id: 'ctx-1',
          roleId: 'role-1',
          contextName: 'Batismo',
          metadata: {
            'functions': ['Vocal'],
            'available_categories': ['Louvor'],
            'function_category_by_function': {'Vocal': 'Louvor'},
          },
        ),
      ];

  @override
  Future<void> updateContext({
    required String contextId,
    String? contextName,
    String? description,
    Map<String, dynamic>? metadata,
    bool? isActive,
  }) async {
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    await gate?.future;
    saves.add(metadata!);
    inFlight--;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeContexts> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final contexts = _FakeContexts();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      ministriesRepositoryProvider.overrideWithValue(_FakeMinistries()),
      eventsRepositoryProvider.overrideWithValue(_FakeEvents()),
      roleContextsRepositoryProvider.overrideWithValue(contexts),
    ],
    child: const MaterialApp(home: ScheduleRulesPreferencesScreen(ministryId: 'm-1')),
  ));
  await tester.pumpAndSettle();
  return contexts;
}

Future<void> _addFunction(WidgetTester tester, String name) async {
  await tester.enterText(find.byKey(const ValueKey('regras-nova-funcao')), name);
  await tester.tap(find.byKey(const ValueKey('regras-nova-funcao-categoria')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Louvor').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('regras-adicionar-funcao')));
  await tester.pump();
}

void main() {
  testWidgets('Adicionar exige categoria e salva sozinho depois de 800 ms', (tester) async {
    final contexts = await _pump(tester);

    final add = find.byKey(const ValueKey('regras-adicionar-funcao'));
    expect(tester.widget<FilledButton>(add).onPressed, isNull);

    await _addFunction(tester, 'Professor');
    await tester.pump(const Duration(milliseconds: 700));
    expect(contexts.saves, isEmpty);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(contexts.saves, hasLength(1));
    expect(contexts.saves.single['functions'], containsAll(['Vocal', 'Professor']));
    expect(contexts.saves.single['function_category_by_function'], containsPair('Professor', 'Louvor'));
    expect(find.text('Salvo'), findsOneWidget);
  });

  testWidgets('mudança durante um save gera um segundo save no fim, nunca dois juntos', (tester) async {
    final contexts = await _pump(tester);
    contexts.gate = Completer<void>();

    await _addFunction(tester, 'Professor');
    await tester.pump(const Duration(milliseconds: 900));
    expect(contexts.inFlight, 1);

    await _addFunction(tester, 'Diácono');
    await tester.pump(const Duration(milliseconds: 900));
    expect(contexts.maxInFlight, 1);

    contexts.gate!.complete();
    await tester.pumpAndSettle();
    expect(contexts.saves, hasLength(2));
    expect(contexts.maxInFlight, 1);
    expect(contexts.saves.last['functions'], containsAll(['Professor', 'Diácono']));
  });
}
