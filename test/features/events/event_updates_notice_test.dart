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
  WidgetTester tester,
  Widget child, {
  required List<EventUpdate> updates,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        eventUpdatesProvider('e1').overrideWith((ref) async => updates),
      ],
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('exibição (tela do evento)', () {
    testWidgets('sem itens, a seção não aparece', (tester) async {
      await _pump(tester, EventUpdatesSummary(event: _event), updates: []);
      expect(find.text('Atualizações'), findsNothing);
    });

    testWidgets('mostra o aviso sem ações de gestão', (tester) async {
      await _pump(
        tester,
        EventUpdatesSummary(event: _event),
        updates: [_notice()],
      );
      expect(find.text('Mudou a sala'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(find.text('Novo aviso'), findsNothing);
    });
  });

  group('gestão (edição do evento)', () {
    testWidgets('vazio: "Nenhum aviso ainda" e sheet exige mensagem', (
      tester,
    ) async {
      await _pump(
        tester,
        const EventNoticesManager(eventId: 'e1'),
        updates: [],
      );
      expect(find.text('Nenhum aviso ainda.'), findsOneWidget);

      await tester.tap(find.text('Novo aviso'));
      await tester.pumpAndSettle();
      expect(
        find.text('Avisos não podem ser editados, só excluídos.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Publicar aviso'));
      await tester.pump();
      expect(find.text('Escreva a mensagem do aviso.'), findsOneWidget);
    });

    testWidgets('exclui pelo ⋮ com confirmação', (tester) async {
      await _pump(
        tester,
        const EventNoticesManager(eventId: 'e1'),
        updates: [_notice()],
      );
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir aviso'));
      await tester.pumpAndSettle();
      expect(
        find.text('Quem já viu este aviso não será avisado da exclusão.'),
        findsOneWidget,
      );
    });
  });
}
