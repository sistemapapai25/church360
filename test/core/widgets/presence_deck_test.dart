import 'package:church360_app/core/widgets/presence_deck.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<String>> pumpDeck(WidgetTester tester, {bool justify = false}) async {
    final log = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PresenceDeck(
            people: const [
              PresenceCardData(id: 'a', name: 'Ana'),
              PresenceCardData(id: 'b', name: 'Bruno'),
              PresenceCardData(id: 'c', name: 'Carla'),
            ],
            onDecide: (p, ok) => log.add('${p.id}:${ok ? 'presente' : 'ausente'}'),
            onUndo: (p) => log.add('${p.id}:desfeito'),
            onJustify: justify ? (p) => log.add('${p.id}:justificada') : null,
            done: const Text('fim'),
            doneAction: const Text('Salvar'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return log;
  }

  Future<void> tap(WidgetTester tester, String tooltip) async {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
  }

  testWidgets('Depois manda a carta para o fim e o Desfazer devolve', (tester) async {
    final log = await pumpDeck(tester);
    expect(find.byTooltip('Justificada'), findsNothing);

    await tap(tester, 'Depois');
    expect(find.textContaining('1 de 3'), findsOneWidget);
    expect(log, isEmpty);

    await tap(tester, 'Desfazer');
    await tap(tester, 'Presente'); // Ana voltou para a frente
    await tap(tester, 'Depois'); // Bruno vai para o fim
    await tap(tester, 'Não está aqui'); // Carla
    await tap(tester, 'Presente'); // Bruno
    expect(log, ['a:presente', 'c:ausente', 'b:presente']);
    expect(find.text('fim'), findsOneWidget);

    await tap(tester, 'Desfazer');
    expect(log.last, 'b:desfeito');
  });

  testWidgets('Justificada só existe com onJustify', (tester) async {
    final log = await pumpDeck(tester, justify: true);
    await tap(tester, 'Justificada');
    await tap(tester, 'Desfazer');
    expect(log, ['a:justificada', 'a:desfeito']);
  });

  testWidgets('PresenceDeckScreen devolve as marcas no Salvar', (tester) async {
    Map<String, PresenceMark>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await PresenceDeckScreen.open(
              context,
              title: 'Chamada em cartas',
              allowJustified: true,
              people: const [
                PresenceCardData(id: 'a', name: 'Ana'),
                PresenceCardData(id: 'b', name: 'Bruno'),
                PresenceCardData(id: 'c', name: 'Carla'),
              ],
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tap(tester, 'Presente');
    await tap(tester, 'Não está aqui');
    await tap(tester, 'Justificada');
    expect(find.text('1 presente · 1 ausente · 1 justificada'), findsOneWidget);
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(result, {'a': PresenceMark.present, 'b': PresenceMark.absent, 'c': PresenceMark.justified});
  });
}
