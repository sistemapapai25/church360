import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:church360_app/features/events/domain/models/event.dart';
import 'package:church360_app/features/events/domain/models/event_update.dart';
import 'package:church360_app/features/events/presentation/providers/events_provider.dart';
import 'package:church360_app/features/events/presentation/widgets/event_updates.dart';

final _event = Event(
  id: 'e1',
  name: 'Culto',
  startDate: DateTime(2026, 10, 10, 19),
  status: 'published',
  createdAt: DateTime(2026, 10, 1),
);

EventUpdate _notice() => EventUpdate.fromJson({
  'id': 'u1',
  'event_id': 'e1',
  'kind': 'notice',
  'title': 'Mudou a sala',
  'body': 'Vamos para a sala 2.',
  'created_at': DateTime.now().toUtc().toIso8601String(),
});

Future<void> _pump(
  WidgetTester tester, {
  required List<EventUpdate> updates,
  required bool podePublicar,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        eventUpdatesProvider('e1').overrideWith((ref) async => updates),
        canPostEventUpdateProvider(
          'e1',
        ).overrideWith((ref) async => podePublicar),
      ],
      child: MaterialApp(
        home: Scaffold(body: EventUpdatesSummary(event: _event)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('membro sem itens não vê a seção', (tester) async {
    await _pump(tester, updates: const [], podePublicar: false);
    expect(find.text('Atualizações'), findsNothing);
  });

  testWidgets('quem pode publicar vê o estado vazio e "+ Aviso"', (
    tester,
  ) async {
    await _pump(tester, updates: const [], podePublicar: true);
    expect(find.text('Nenhum aviso ainda ·'), findsOneWidget);
    expect(find.text('Publicar aviso'), findsOneWidget);
    expect(find.text('Aviso'), findsOneWidget);

    await tester.tap(find.text('Publicar aviso'));
    await tester.pumpAndSettle();
    expect(find.text('Novo aviso'), findsOneWidget);
    expect(
      find.text('Avisos não podem ser editados, só excluídos.'),
      findsOneWidget,
    );
    // Mensagem é obrigatória.
    await tester.tap(find.widgetWithText(FilledButton, 'Publicar aviso'));
    await tester.pump();
    expect(find.text('Escreva a mensagem do aviso.'), findsOneWidget);
  });

  testWidgets('membro não vê o menu ⋮ do aviso', (tester) async {
    await _pump(tester, updates: [_notice()], podePublicar: false);
    expect(find.text('Mudou a sala'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('quem pode exclui pelo ⋮ com confirmação', (tester) async {
    await _pump(tester, updates: [_notice()], podePublicar: true);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir aviso'));
    await tester.pumpAndSettle();
    expect(
      find.text('Quem já viu este aviso não será avisado da exclusão.'),
      findsOneWidget,
    );
  });
}
