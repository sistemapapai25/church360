// Fase 6 — REC-03/REC-04 (Plano 06-08). Trava da detecção LOCAL de mudança de
// padrão/período do formulário de evento.
//
// O QUE ESTE ARQUIVO TRAVA: a PARIDADE com o passo (7) de
// `supabase/migrations/20260902000900_regenerate_event_series_rpc.sql` — a
// regra que o SERVIDOR usa para decidir o modo (`none`/`extend`/`shorten`/
// `regenerate`). São três regras, e todas as três estão cobertas aqui:
//   1. os dias da semana são comparados ORDENADOS nos dois lados ({7,3} e
//      {3,7} são o MESMO padrão);
//   2. `recurrence_end_date` nulo significa o fallback histórico de 12 meses
//      sobre `anchor_date`, dos DOIS lados;
//   3. mudança de padrão ABSORVE mudança de período (A-06) — nunca dois
//      diálogos no mesmo Salvar.
//
// **Se a regra do servidor mudar, este é o arquivo que muda junto.** A
// detecção local escolhe só o aviso inline e qual diálogo abrir; quem decide
// o efeito real é `regenerate_event_series`. Divergir entre as duas faz a UI
// prometer um efeito e o servidor entregar outro — T-08-01 do plano.
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/events/domain/models/event_series.dart';
import 'package:church360_app/features/events/presentation/utils/series_change_detection.dart';

/// Âncora fixa para todos os casos: o fallback de 12 meses cai em 07/09/2027.
final _anchor = DateTime(2026, 9, 7);

EventSeries _serie({
  String patternGroup = 'semanal',
  String? variableType,
  List<int> weekdays = const [7],
  int intervalWeeks = 1,
  int? monthlyOrdinal,
  DateTime? recurrenceEndDate,
}) => EventSeries(
  id: '22222222-0000-4000-8000-000000000002',
  anchorDate: _anchor,
  patternGroup: patternGroup,
  variableType: variableType,
  weekdays: weekdays,
  intervalWeeks: intervalWeeks,
  monthlyOrdinal: monthlyOrdinal,
  recurrenceEndDate: recurrenceEndDate,
  startTimeMinutes: 19 * 60,
);

void main() {
  group('detectSeriesChange — paridade com o passo (7) da RPC', () {
    test('padrão e período iguais aos persistidos → none', () {
      expect(
        detectSeriesChange(
          series: _serie(recurrenceEndDate: DateTime(2026, 12, 31)),
          patternGroup: 'semanal',
          weekdays: const [7],
          intervalWeeks: 1,
          recurrenceEndDate: DateTime(2026, 12, 31),
        ),
        SeriesChangeKind.none,
      );
    });

    test('dias da semana em ordem diferente ([7,3] x [3,7]) → none', () {
      // Comparação crua de array chamaria isto de mudança e a série inteira
      // seria apagada e recriada por nada, cancelando inscrições no caminho.
      expect(
        detectSeriesChange(
          series: _serie(weekdays: const [7, 3]),
          patternGroup: 'semanal',
          weekdays: const [3, 7],
          intervalWeeks: 1,
        ),
        SeriesChangeKind.none,
      );
    });

    test('só a data de encerramento maior → extend', () {
      expect(
        detectSeriesChange(
          series: _serie(recurrenceEndDate: DateTime(2026, 12, 31)),
          patternGroup: 'semanal',
          weekdays: const [7],
          intervalWeeks: 1,
          recurrenceEndDate: DateTime(2027, 3, 31),
        ),
        SeriesChangeKind.extend,
      );
    });

    test('só a data de encerramento menor → shorten', () {
      expect(
        detectSeriesChange(
          series: _serie(recurrenceEndDate: DateTime(2026, 12, 31)),
          patternGroup: 'semanal',
          weekdays: const [7],
          intervalWeeks: 1,
          recurrenceEndDate: DateTime(2026, 10, 31),
        ),
        SeriesChangeKind.shorten,
      );
    });

    test('muda dia, grupo, tipo variável, intervalo ou ordinal → pattern', () {
      final base = _serie(recurrenceEndDate: DateTime(2026, 12, 31));
      final fim = DateTime(2026, 12, 31);

      // dia da semana
      expect(
        detectSeriesChange(
          series: base,
          patternGroup: 'semanal',
          weekdays: const [3],
          intervalWeeks: 1,
          recurrenceEndDate: fim,
        ),
        SeriesChangeKind.pattern,
      );

      // grupo
      expect(
        detectSeriesChange(
          series: base,
          patternGroup: 'variavel',
          variableType: 'quinzenal',
          weekdays: const [7],
          intervalWeeks: 1,
          recurrenceEndDate: fim,
        ),
        SeriesChangeKind.pattern,
      );

      // tipo variável
      expect(
        detectSeriesChange(
          series: _serie(
            patternGroup: 'variavel',
            variableType: 'quinzenal',
            intervalWeeks: 2,
            recurrenceEndDate: fim,
          ),
          patternGroup: 'variavel',
          variableType: 'dias',
          weekdays: const [7],
          intervalWeeks: 2,
          recurrenceEndDate: fim,
        ),
        SeriesChangeKind.pattern,
      );

      // intervalo
      expect(
        detectSeriesChange(
          series: base,
          patternGroup: 'semanal',
          weekdays: const [7],
          intervalWeeks: 2,
          recurrenceEndDate: fim,
        ),
        SeriesChangeKind.pattern,
      );

      // ordinal
      expect(
        detectSeriesChange(
          series: base,
          patternGroup: 'semanal',
          weekdays: const [7],
          intervalWeeks: 1,
          monthlyOrdinal: 2,
          recurrenceEndDate: fim,
        ),
        SeriesChangeKind.pattern,
      );
    });

    test('padrão E período mudam ao mesmo tempo → pattern (absorção, A-06)', () {
      // Se devolvesse `extend`/`shorten` aqui, o Salvar abriria DLG-2/DLG-3 e
      // o servidor executaria uma regeneração — a UI prometeria um efeito e o
      // servidor entregaria outro.
      expect(
        detectSeriesChange(
          series: _serie(recurrenceEndDate: DateTime(2026, 12, 31)),
          patternGroup: 'semanal',
          weekdays: const [3],
          intervalWeeks: 1,
          recurrenceEndDate: DateTime(2027, 3, 31),
        ),
        SeriesChangeKind.pattern,
      );
      expect(
        detectSeriesChange(
          series: _serie(recurrenceEndDate: DateTime(2026, 12, 31)),
          patternGroup: 'semanal',
          weekdays: const [3],
          intervalWeeks: 1,
          recurrenceEndDate: DateTime(2026, 10, 31),
        ),
        SeriesChangeKind.pattern,
      );
    });

    test('data de encerramento nula dos dois lados → none (fallback 12 meses)',
        () {
      expect(
        detectSeriesChange(
          series: _serie(),
          patternGroup: 'semanal',
          weekdays: const [7],
          intervalWeeks: 1,
        ),
        SeriesChangeKind.none,
      );

      // Nulo persistido x data igual ao fallback (anchor + 12 meses) também é
      // `none`: é o MESMO horizonte, escrito de duas formas.
      expect(
        detectSeriesChange(
          series: _serie(),
          patternGroup: 'semanal',
          weekdays: const [7],
          intervalWeeks: 1,
          recurrenceEndDate: DateTime(2027, 9, 7),
        ),
        SeriesChangeKind.none,
      );

      // E o inverso: persistido igual ao fallback, formulário nulo.
      expect(
        detectSeriesChange(
          series: _serie(recurrenceEndDate: DateTime(2027, 9, 7)),
          patternGroup: 'semanal',
          weekdays: const [7],
          intervalWeeks: 1,
        ),
        SeriesChangeKind.none,
      );
    });

    test('série legada (null) → none, sem referência não há diferença', () {
      // IC-7: os campos de padrão já estão desabilitados, e a RPC responderia
      // `SERIES_NOT_FOUND`. As três camadas concordam de propósito.
      expect(
        detectSeriesChange(
          series: null,
          patternGroup: 'variavel',
          variableType: 'dias',
          weekdays: const [1, 2, 3],
          intervalWeeks: 4,
          monthlyOrdinal: 5,
          recurrenceEndDate: DateTime(2027, 1, 1),
        ),
        SeriesChangeKind.none,
      );
    });
  });
}
