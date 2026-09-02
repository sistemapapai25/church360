// Fase 6 — REC-01 / A-13. Trava das saídas exatas de `describeSeriesPattern`.
//
// `describeSeriesPattern` é a ÚNICA implementação da descrição do padrão de
// repetição em PT-BR (A-13 do `06-UI-SPEC.md`): a mesma frase aparece na
// prévia do formulário, no badge da ocorrência, no DLG-4 e, indiretamente, na
// notificação de mudança de série. Estes testes fazem igualdade LITERAL com a
// tabela "Formatação canônica" do UI-SPEC — não `contains`, não `matches` —
// porque o valor do arquivo único é justamente a frase ser sempre a mesma.
//
// Também travam a numeração dos dias: `weekdays` usa `DateTime.weekday`
// (1=segunda .. 7=domingo), a mesma convenção do estado `_fixedWeekdays` do
// formulário e da coluna `event_series.weekdays` do servidor. Um off-by-one
// aqui não quebra teste nenhum de compilação — só faz a tela mentir sobre o
// dia em que o evento vai acontecer.
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/events/presentation/utils/series_pattern_label.dart';

void main() {
  group('describeSeriesPattern — saídas canônicas do 06-UI-SPEC', () {
    test('semanal com intervalo 1 e um dia', () {
      expect(
        describeSeriesPattern(
          patternGroup: 'semanal',
          weekdays: const [DateTime.sunday],
          intervalWeeks: 1,
        ),
        'Toda semana, domingo',
      );
    });

    test('semanal com intervalo maior que 1 e dois dias', () {
      expect(
        describeSeriesPattern(
          patternGroup: 'semanal',
          weekdays: const [DateTime.sunday, DateTime.wednesday],
          intervalWeeks: 3,
        ),
        'A cada 3 semanas, domingo e quarta',
      );
    });

    test('variavel/quinzenal usa o intervalo em semanas', () {
      expect(
        describeSeriesPattern(
          patternGroup: 'variavel',
          variableType: 'quinzenal',
          weekdays: const [DateTime.monday],
          intervalWeeks: 2,
        ),
        'A cada 2 semanas, segunda',
      );
    });

    test('variavel/dias sem ordinal', () {
      expect(
        describeSeriesPattern(
          patternGroup: 'variavel',
          variableType: 'dias',
          weekdays: const [DateTime.monday, DateTime.wednesday],
          intervalWeeks: 1,
        ),
        'Todo mês, segunda e quarta',
      );
    });

    test('variavel/dias com ordinal 5 renderiza "último"', () {
      expect(
        describeSeriesPattern(
          patternGroup: 'variavel',
          variableType: 'dias',
          weekdays: const [DateTime.friday],
          intervalWeeks: 1,
          monthlyOrdinal: 5,
        ),
        'Todo último sexta do mês',
      );
    });

    test('variavel/unico com ordinal 1', () {
      expect(
        describeSeriesPattern(
          patternGroup: 'variavel',
          variableType: 'unico',
          weekdays: const [DateTime.sunday],
          intervalWeeks: 1,
          monthlyOrdinal: 1,
        ),
        'Uma vez por mês, no 1º domingo',
      );
    });

    test('três ou mais dias são unidos por vírgula com " e " antes do último', () {
      expect(
        describeSeriesPattern(
          patternGroup: 'semanal',
          weekdays: const [
            DateTime.sunday,
            DateTime.wednesday,
            DateTime.friday,
          ],
          intervalWeeks: 1,
        ),
        'Toda semana, domingo, quarta e sexta',
      );
    });

    test('a ordem da lista de entrada não afeta a saída — sempre começa no domingo', () {
      expect(
        describeSeriesPattern(
          patternGroup: 'semanal',
          weekdays: const [
            DateTime.friday,
            DateTime.sunday,
            DateTime.wednesday,
          ],
          intervalWeeks: 1,
        ),
        'Toda semana, domingo, quarta e sexta',
      );
    });
  });

  group('describeSeriesPattern — numeração DateTime.weekday', () {
    // event_series.weekdays é smallint[] com a numeração do Dart
    // (`20260902000100_event_series_schema.sql`, comentário da coluna).
    // Um off-by-one aqui faz a prévia prometer um dia e o loop gerar outro.
    const esperado = <int, String>{
      DateTime.monday: 'segunda',
      DateTime.tuesday: 'terça',
      DateTime.wednesday: 'quarta',
      DateTime.thursday: 'quinta',
      DateTime.friday: 'sexta',
      DateTime.saturday: 'sábado',
      DateTime.sunday: 'domingo',
    };

    esperado.forEach((dia, nome) {
      test('weekday $dia é "$nome"', () {
        expect(
          describeSeriesPattern(
            patternGroup: 'semanal',
            weekdays: [dia],
            intervalWeeks: 1,
          ),
          'Toda semana, $nome',
        );
      });
    });
  });

  group('describeSeriesPattern — ordinais', () {
    const esperado = <int, String>{
      1: '1º',
      2: '2º',
      3: '3º',
      4: '4º',
      5: 'último',
    };

    esperado.forEach((ordinal, rotulo) {
      test('ordinal $ordinal é "$rotulo"', () {
        expect(
          describeSeriesPattern(
            patternGroup: 'variavel',
            variableType: 'dias',
            weekdays: const [DateTime.sunday],
            intervalWeeks: 1,
            monthlyOrdinal: ordinal,
          ),
          'Todo $rotulo domingo do mês',
        );
      });
    });
  });

  group('describeSeriesPattern — bordas', () {
    test('sem nenhum dia escolhido não produz vírgula solta', () {
      final texto = describeSeriesPattern(
        patternGroup: 'semanal',
        weekdays: const [],
        intervalWeeks: 1,
      );
      expect(texto, 'Toda semana');
      expect(texto.endsWith(','), isFalse);
    });

    test('variavel/unico sem ordinal não inventa ordinal', () {
      final texto = describeSeriesPattern(
        patternGroup: 'variavel',
        variableType: 'unico',
        weekdays: const [DateTime.sunday],
        intervalWeeks: 1,
      );
      expect(texto, 'Uma vez por mês, no domingo');
    });
  });
}
