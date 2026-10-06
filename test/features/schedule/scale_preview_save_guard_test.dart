import 'dart:async';

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
  testWidgets('Salvar só libera depois que a prévia carrega', (tester) async {
    final repo = _FakeMinistries();
    await _pump(tester, repo);
    await tester.pump();
    expect(_saveButton(tester), isNull);

    repo.members.complete([]);
    await tester.pumpAndSettle();
    expect(_saveButton(tester), isNotNull);
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
}
