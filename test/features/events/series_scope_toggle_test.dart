// Fase 6 — REC-02 / IC-3 (Plano 06-06, Task 2).
//
// O toggle de escopo é o controle que decide se um Salvar atinge UMA linha ou
// DEZENAS. Três das suas regras são invisíveis para `flutter analyze` e para
// qualquer teste de compilação, e é exatamente por isso que estão travadas
// aqui, uma a uma:
//
//   • o subtítulo tem que dizer a verdade sobre o alcance, com a contagem do
//     SERVIDOR e plural pela contagem real;
//   • os campos de padrão ficam VISÍVEIS e inoperantes (A-07), inclusive com
//     o toggle ligado quando a série é legada (IC-7);
//   • `error` dos providers de autorização resolve para NÃO renderizar o
//     toggle (fail-closed, IC-8) — divergência deliberada em relação ao ramo
//     `error` do Plano 03-08.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/events/domain/models/event_series.dart';
import 'package:church360_app/features/events/presentation/providers/events_provider.dart';
import 'package:church360_app/features/events/presentation/widgets/series_scope_toggle.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';

const _eventId = '11111111-0000-4000-8000-000000000001';
const _batchId = '22222222-0000-4000-8000-000000000002';

EventSeries _serie() => EventSeries(
  id: _batchId,
  anchorDate: DateTime(2026, 9, 6),
  patternGroup: 'semanal',
  weekdays: const [DateTime.sunday],
  intervalWeeks: 1,
  startTimeMinutes: 1170,
);

enum _Autorizacao { responsavel, semAcesso, erroDeRede }

Future<void> _pump(
  WidgetTester tester, {
  required bool enabled,
  EventSeries? series,
  int? futureCount,
  _Autorizacao autorizacao = _Autorizacao.responsavel,
}) async {
  final overrides = <Override>[
    switch (autorizacao) {
      _Autorizacao.responsavel => isEventResponsibleProvider.overrideWith(
        (ref, id) async => true,
      ),
      _Autorizacao.semAcesso => isEventResponsibleProvider.overrideWith(
        (ref, id) async => false,
      ),
      _Autorizacao.erroDeRede => isEventResponsibleProvider.overrideWith(
        (ref, id) async => throw Exception('falha de rede'),
      ),
    },
    switch (autorizacao) {
      _Autorizacao.responsavel ||
      _Autorizacao.semAcesso => currentUserHasPermissionProvider.overrideWith(
        (ref, code) async => false,
      ),
      _Autorizacao.erroDeRede => currentUserHasPermissionProvider.overrideWith(
        (ref, code) async => throw Exception('falha de rede'),
      ),
    },
  ];

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SeriesScopeToggle(
              eventId: _eventId,
              batchId: _batchId,
              occurrenceDate: DateTime(2026, 9, 6),
              series: series,
              enabled: enabled,
              futureCount: futureCount,
              onChanged: (_) {},
              child: const Text('CAMPOS DE PADRÃO'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// Todo texto renderizado, incluindo `Text.rich`.
List<String> _textos(WidgetTester tester) {
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

bool _camposAbsorvidos(WidgetTester tester) {
  final absorbers = tester
      .widgetList<AbsorbPointer>(find.byType(AbsorbPointer))
      .where((a) => a.absorbing);
  return absorbers.isNotEmpty;
}

void main() {
  group('IC-3 — subtítulo do toggle', () {
    testWidgets('desligado fala de UMA ocorrência e mantém os campos inertes', (
      tester,
    ) async {
      await _pump(tester, enabled: false, series: _serie(), futureCount: 14);

      final textos = _textos(tester);
      expect(textos, contains('Aplicar a toda a série (futuras)'));
      expect(
        textos.any((t) => t.startsWith('Só esta ocorrência, de ')),
        isTrue,
      );
      expect(
        textos,
        contains(
          'Ligue "Aplicar a toda a série" para mudar o padrão ou o período.',
        ),
      );
      // A-07: visíveis, não escondidos.
      expect(textos, contains('CAMPOS DE PADRÃO'));
      expect(_camposAbsorvidos(tester), isTrue);
    });

    testWidgets('ligado com 14 futuras usa a contagem do servidor', (
      tester,
    ) async {
      await _pump(tester, enabled: true, series: _serie(), futureCount: 14);

      expect(
        _textos(tester),
        contains(
          'As 14 ocorrências futuras desta série serão alteradas. '
          'As passadas não são tocadas.',
        ),
      );
      expect(_camposAbsorvidos(tester), isFalse);
    });

    testWidgets('ligado com 0 futuras diz que nada será alterado', (
      tester,
    ) async {
      await _pump(tester, enabled: true, series: _serie(), futureCount: 0);

      expect(
        _textos(tester),
        contains('Esta série não tem ocorrências futuras. Nada será alterado.'),
      );
    });

    testWidgets('contagem ainda desconhecida não imprime "null"', (
      tester,
    ) async {
      await _pump(tester, enabled: true, series: _serie(), futureCount: null);

      for (final t in _textos(tester)) {
        expect(t, isNot(contains('null')));
      }
    });
  });

  group('IC-7 — série legada', () {
    testWidgets(
      'mostra o bloco degradado e mantém o padrão inerte mesmo ligado',
      (tester) async {
        await _pump(tester, enabled: true, series: null, futureCount: 14);

        final textos = _textos(tester);
        expect(textos, contains('Padrão de repetição não registrado'));
        // O toggle continua disponível: campos comuns não dependem do padrão
        // (A-14).
        expect(textos, contains('Aplicar a toda a série (futuras)'));
        expect(
          _camposAbsorvidos(tester),
          isTrue,
          reason:
              'Sem padrão salvo não há o que editar no padrão, mesmo com o '
              'toggle ligado.',
        );
      },
    );
  });

  group('IC-8 — gate fail-closed', () {
    testWidgets('quem não é responsável nem tem events.edit não vê o toggle', (
      tester,
    ) async {
      await _pump(
        tester,
        enabled: false,
        series: _serie(),
        autorizacao: _Autorizacao.semAcesso,
      );

      expect(_textos(tester), isEmpty);
    });

    testWidgets('erro nos providers de autorização NÃO renderiza o toggle', (
      tester,
    ) async {
      await _pump(
        tester,
        enabled: false,
        series: _serie(),
        autorizacao: _Autorizacao.erroDeRede,
      );

      expect(
        _textos(tester),
        isEmpty,
        reason:
            'Falha de rede não pode liberar uma operação em massa — diverge '
            'de propósito do ramo error do Plano 03-08.',
      );
    });
  });

  group('Acessibilidade — alvo de toque do controle de escopo', () {
    testWidgets('o SwitchListTile não encolhe o alvo de toque', (tester) async {
      await _pump(tester, enabled: false, series: _serie(), futureCount: 14);

      final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(tile.visualDensity, isNull);
      expect(tile.contentPadding, EdgeInsets.zero);
    });
  });
}
