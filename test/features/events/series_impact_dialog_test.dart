// Fase 6 — REC-05 (Plano 06-04). As "Regras de contagem nos diálogos" do
// `06-UI-SPEC.md` são o contrato mais fácil de quebrar desta fase: são regras
// de OMISSÃO e de SUBSTITUIÇÃO, invisíveis para `flutter analyze` e para
// qualquer teste de compilação. Um `0 inscrições` na tela não derruba nada —
// só faz o líder confirmar uma exclusão em massa achando que entendeu.
//
// Estes testes travam as quatro regras, uma a uma, mais o rótulo do botão
// destrutivo (que tem que carregar a contagem real) e a proibição de plural
// preguiçoso `(s)`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/events/domain/models/event_series_impact.dart';
import 'package:church360_app/features/events/presentation/widgets/series_impact_dialog.dart';

EventSeriesImpact _impacto({
  int futuras = 14,
  int passadas = 3,
  int inscricoes = 0,
  DateTime? primeira,
  DateTime? ultima,
}) => EventSeriesImpact(
  dryRun: true,
  futureCount: futuras,
  pastCount: passadas,
  firstFuture: primeira ?? DateTime(2026, 9, 3),
  lastFuture: ultima ?? DateTime(2026, 12, 10),
  affectedRegistrations: inscricoes,
  affectedSchedules: 0,
  deletedCount: 0,
  notifiedCount: 0,
);

Future<void> _pump(
  WidgetTester tester,
  EventSeriesImpact impacto, {
  SeriesImpactVariant? variante,
}) async {
  final v =
      variante ??
      (impacto.futureCount > 0
          ? SeriesImpactVariant.deleteFuture
          : SeriesImpactVariant.nothingToDo);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SeriesImpactDialog(
          variant: v,
          impact: impacto,
          eventName: 'Culto de Domingo',
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Todo texto renderizado, incluindo os `Text.rich` (que `find.text` não
/// enxerga porque `data` é nulo neles).
List<String> _textosRenderizados(WidgetTester tester) {
  final saida = <String>[];
  for (final widget in tester.allWidgets) {
    if (widget is Text) {
      final direto = widget.data;
      if (direto != null) {
        saida.add(direto);
      } else {
        final span = widget.textSpan;
        if (span != null) saida.add(span.toPlainText());
      }
    }
  }
  return saida;
}

void main() {
  testWidgets(
    'k == 0 mostra "Nenhuma pessoa inscrita será afetada." e nunca "0 inscrições"',
    (tester) async {
      await _pump(tester, _impacto(inscricoes: 0));

      final textos = _textosRenderizados(tester);
      expect(
        textos,
        contains('Nenhuma pessoa inscrita será afetada.'),
      );
      // A linha é SUBSTITUÍDA, nunca omitida e nunca degradada para "0".
      expect(
        textos.any((linha) => linha.contains('0 inscrições')),
        isFalse,
      );
      expect(find.byIcon(Icons.person_off_outlined), findsNothing);
    },
  );

  testWidgets('k > 0 renderiza a linha destrutiva com Icons.person_off_outlined',
      (tester) async {
    await _pump(tester, _impacto(inscricoes: 5));

    expect(find.byIcon(Icons.person_off_outlined), findsOneWidget);
    expect(
      _textosRenderizados(tester).any(
        (linha) =>
            linha.contains('5 inscrições serão canceladas e as pessoas serão '
                'avisadas.'),
      ),
      isTrue,
    );
    expect(
      _textosRenderizados(tester),
      isNot(contains('Nenhuma pessoa inscrita será afetada.')),
    );
  });

  testWidgets('m == 0 omite completamente a linha de ocorrências passadas',
      (tester) async {
    await _pump(tester, _impacto(passadas: 0));

    expect(
      _textosRenderizados(tester).any((linha) => linha.contains('passada')),
      isFalse,
    );
  });

  testWidgets('m > 0 tranquiliza sobre inscrições, presença e escalas',
      (tester) async {
    await _pump(tester, _impacto(passadas: 3));

    expect(
      _textosRenderizados(tester).any(
        (linha) => linha.contains(
          '3 ocorrências passadas serão preservadas, com inscrições, '
          'presença e escalas.',
        ),
      ),
      isTrue,
    );
  });

  testWidgets(
    'future_count == 0 produz DLG-6: "Nada a excluir" + "Entendi", sem botão destrutivo',
    (tester) async {
      await _pump(tester, _impacto(futuras: 0, passadas: 7));

      expect(find.text('Nada a excluir'), findsOneWidget);
      expect(find.text('Entendi'), findsOneWidget);
      // Nenhum caminho destrutivo: nem o botão, nem o "Cancelar" que só
      // existe ao lado dele.
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('Cancelar'), findsNothing);
      expect(
        _textosRenderizados(tester).any(
          (linha) => linha.contains('Esta ação não pode ser desfeita.'),
        ),
        isFalse,
      );
    },
  );

  testWidgets('o rótulo do botão destrutivo carrega a contagem real',
      (tester) async {
    await _pump(tester, _impacto(futuras: 14));

    expect(find.text('Excluir 14 ocorrências'), findsOneWidget);
    expect(find.text('Excluir as ocorrências futuras?'), findsOneWidget);
  });

  testWidgets('contagem 1 usa singular — nunca "1 ocorrências"', (tester) async {
    await _pump(
      tester,
      _impacto(
        futuras: 1,
        passadas: 1,
        inscricoes: 1,
        primeira: DateTime(2026, 9, 3),
        ultima: DateTime(2026, 9, 3),
      ),
    );

    expect(find.text('Excluir 1 ocorrência'), findsOneWidget);
    final textos = _textosRenderizados(tester);
    expect(textos.any((linha) => linha.contains('1 ocorrências')), isFalse);
    expect(textos.any((linha) => linha.contains('1 inscrições')), isFalse);
  });

  testWidgets('nenhuma string do diálogo usa plural preguiçoso "(s)"',
      (tester) async {
    for (final impacto in [
      _impacto(futuras: 14, passadas: 3, inscricoes: 5),
      _impacto(futuras: 1, passadas: 0, inscricoes: 0),
      _impacto(futuras: 0, passadas: 7),
    ]) {
      await _pump(tester, impacto);
      for (final linha in _textosRenderizados(tester)) {
        expect(
          linha.contains('(s)'),
          isFalse,
          reason: 'plural por parêntese é proibido nesta fase: "$linha"',
        );
      }
    }
  });

  group('DLG-1 — aplicar a toda a série (Plano 06-06)', () {
    testWidgets('título, corpo e botão accent — nada é apresentado como exclusão',
        (tester) async {
      await _pump(
        tester,
        _impacto(futuras: 14, passadas: 3),
        variante: SeriesImpactVariant.applyToSeries,
      );

      final textos = _textosRenderizados(tester);
      expect(textos, contains('Aplicar a toda a série?'));
      expect(textos, contains('Aplicar à série'));
      expect(
        textos.any(
          (l) => l.contains(
            'As alterações vão valer para 14 ocorrências futuras, de '
            '03/09/2026 até 10/12/2026.',
          ),
        ),
        isTrue,
      );
      expect(
        textos.any((l) => l.contains('As 3 ocorrências passadas não serão alteradas.')),
        isTrue,
      );
      // Esta operação não cancela inscrição nenhuma: nenhuma linha de
      // inscrições, nem a de "nenhuma pessoa afetada".
      expect(find.byIcon(Icons.person_off_outlined), findsNothing);
      expect(textos, isNot(contains('Nenhuma pessoa inscrita será afetada.')));
      expect(textos.any((l) => l.contains('não pode ser desfeita')), isFalse);

      expect(seriesImpactIsDestructive(SeriesImpactVariant.applyToSeries), isFalse);
      final botao = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(
        botao.style,
        isNull,
        reason:
            'DLG-1 não remove nada — o botão primário usa o accent do tema, '
            'nunca colorScheme.error.',
      );
    });

    testWidgets('m == 0 omite a linha de passadas também em DLG-1',
        (tester) async {
      await _pump(
        tester,
        _impacto(futuras: 14, passadas: 0),
        variante: SeriesImpactVariant.applyToSeries,
      );

      expect(
        _textosRenderizados(tester).any((l) => l.contains('passada')),
        isFalse,
      );
    });

    testWidgets('contagem 1 usa singular em DLG-1', (tester) async {
      await _pump(
        tester,
        _impacto(
          futuras: 1,
          passadas: 1,
          primeira: DateTime(2026, 9, 6),
          ultima: DateTime(2026, 9, 6),
        ),
        variante: SeriesImpactVariant.applyToSeries,
      );

      final textos = _textosRenderizados(tester);
      expect(
        textos.any(
          (l) => l.contains(
            'As alterações vão valer para 1 ocorrência futura, em 06/09/2026.',
          ),
        ),
        isTrue,
      );
      expect(
        textos.any((l) => l.contains('A ocorrência passada não será alterada.')),
        isTrue,
      );
    });

    testWidgets('DLG-6 no caminho de aplicar diz "Nada a alterar"',
        (tester) async {
      await _pump(
        tester,
        _impacto(futuras: 0, passadas: 7),
        variante: SeriesImpactVariant.nothingToChange,
      );

      final textos = _textosRenderizados(tester);
      expect(textos, contains('Nada a alterar'));
      expect(textos, isNot(contains('Nada a excluir')));
      expect(textos, contains('Entendi'));
      expect(find.byType(FilledButton), findsNothing);
    });
  });
}
