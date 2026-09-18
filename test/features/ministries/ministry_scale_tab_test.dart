import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/ministries/domain/models/ministry.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:church360_app/features/ministries/shared/presentation/widgets/ministry_scale_tab.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _ministryId = 'm1';

MinistrySchedule _schedule({
  required String eventId,
  required String eventName,
  required String memberName,
  DateTime? startDate,
  String? functionName,
}) {
  return MinistrySchedule(
    id: '$eventId-$memberName',
    eventId: eventId,
    eventName: eventName,
    eventStartDate: startDate,
    ministryId: _ministryId,
    ministryName: 'Batismo nas Águas',
    memberId: 'u-$memberName',
    memberName: memberName,
    functionName: functionName,
    createdAt: DateTime(2026, 9, 18),
  );
}

Widget _host(List<MinistrySchedule> schedules, {bool canManage = false}) {
  return ProviderScope(
    overrides: [
      ministrySchedulesProvider(
        _ministryId,
      ).overrideWith((ref) async => schedules),
      currentUserHasPermissionProvider(
        'ministries.manage_schedule',
      ).overrideWith((ref) async => canManage),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Scaffold(body: MinistryScaleTab(ministryId: _ministryId)),
    ),
  );
}

void main() {
  setUpAll(() async {
    // O card formata a data do evento em pt_BR; sem carregar os simbolos o
    // DateFormat estoura no teste.
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('agrupa as escalas por evento', (tester) async {
    await tester.pumpWidget(
      _host([
        _schedule(
          eventId: 'e1',
          eventName: 'Culto de Domingo',
          memberName: 'Ana',
        ),
        _schedule(
          eventId: 'e1',
          eventName: 'Culto de Domingo',
          memberName: 'Bruno',
        ),
        _schedule(eventId: 'e2', eventName: 'Batismo', memberName: 'Carla'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 eventos com escala'), findsOneWidget);
    expect(find.text('Culto de Domingo'), findsOneWidget);
    expect(find.textContaining('2 escalados'), findsOneWidget);
    expect(find.textContaining('1 escalado'), findsOneWidget);
  });

  testWidgets('abrir o evento mostra quem esta escalado e a funcao', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host([
        _schedule(
          eventId: 'e1',
          eventName: 'Culto de Domingo',
          memberName: 'Ana',
          functionName: 'Recepção',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsNothing);

    await tester.tap(find.text('Culto de Domingo'));
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Recepção'), findsOneWidget);
  });

  testWidgets('busca encontra o evento pelo nome de quem esta escalado', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host([
        _schedule(
          eventId: 'e1',
          eventName: 'Culto de Domingo',
          memberName: 'Ana',
        ),
        _schedule(eventId: 'e2', eventName: 'Batismo', memberName: 'Bruno'),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'bruno');
    await tester.pumpAndSettle();

    expect(find.text('Batismo'), findsOneWidget);
    expect(find.text('Culto de Domingo'), findsNothing);
  });

  testWidgets('sem escala nenhuma explica o estado vazio', (tester) async {
    await tester.pumpWidget(_host(const []));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma escala registrada'), findsOneWidget);
  });

  testWidgets('sem permissao nao oferece gerar, regras nem historico', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host([
        _schedule(
          eventId: 'e1',
          eventName: 'Culto de Domingo',
          memberName: 'Ana',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gerar escala'), findsNothing);
    expect(find.text('Regras'), findsNothing);
    expect(find.text('Abrir histórico completo'), findsNothing);
  });

  testWidgets('com permissao oferece as tres portas de saida', (tester) async {
    await tester.pumpWidget(
      _host([
        _schedule(
          eventId: 'e1',
          eventName: 'Culto de Domingo',
          memberName: 'Ana',
        ),
      ], canManage: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gerar escala'), findsOneWidget);
    expect(find.text('Regras'), findsOneWidget);
    expect(find.text('Abrir histórico completo'), findsOneWidget);
  });
}
