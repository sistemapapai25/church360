/// Fase 6 — REC-01 / A-13 do `06-UI-SPEC.md`.
///
/// **Esta é a ÚNICA implementação da descrição do padrão de repetição em
/// PT-BR do projeto.** A mesma frase aparece na prévia do formulário de
/// evento, no badge da ocorrência em edição, no corpo do DLG-4 ("Mudar o
/// padrão de repetição?") e, indiretamente, na notificação de mudança de
/// série. Três implementações divergentes é o modo padrão de uma delas
/// envelhecer errado e a UI passar a prometer um dia diferente do que o loop
/// de geração usa.
///
/// Se precisar de uma variação (frase mais curta, com/sem o horário), estenda
/// ESTA função com um parâmetro — não escreva uma segunda.
///
/// As saídas são literais da tabela "Formatação canônica" do `06-UI-SPEC.md`
/// e estão travadas por igualdade exata em
/// `test/features/events/series_pattern_label_test.dart`.
library;

/// Descreve o padrão de repetição de uma série em PT-BR.
///
/// [weekdays] usa a numeração de `DateTime.weekday` (1=segunda .. 7=domingo),
/// a mesma do estado `_fixedWeekdays` do formulário e da coluna
/// `event_series.weekdays` no servidor. A ordem da lista de entrada não
/// importa: a saída sempre começa no domingo.
///
/// [monthlyOrdinal] é 1..5, onde 5 significa "último".
String describeSeriesPattern({
  required String patternGroup,
  String? variableType,
  required List<int> weekdays,
  required int intervalWeeks,
  int? monthlyOrdinal,
}) {
  final dias = _joinWeekdays(weekdays);
  final sufixoDias = dias.isEmpty ? '' : ', $dias';

  if (patternGroup == 'variavel') {
    switch (variableType) {
      case 'quinzenal':
        return 'A cada $intervalWeeks semanas$sufixoDias';
      case 'unico':
        if (dias.isEmpty) return 'Uma vez por mês';
        if (monthlyOrdinal == null) return 'Uma vez por mês, no $dias';
        return 'Uma vez por mês, no ${_ordinalLabel(monthlyOrdinal)} $dias';
      case 'dias':
      default:
        if (monthlyOrdinal == null) {
          return dias.isEmpty ? 'Todo mês' : 'Todo mês, $dias';
        }
        if (dias.isEmpty) return 'Todo ${_ordinalLabel(monthlyOrdinal)} do mês';
        return 'Todo ${_ordinalLabel(monthlyOrdinal)} $dias do mês';
    }
  }

  // 'semanal' e qualquer valor inesperado caem aqui: é o padrão default do
  // formulário e a descrição mais conservadora possível.
  if (intervalWeeks == 1) {
    return 'Toda semana$sufixoDias';
  }
  return 'A cada $intervalWeeks semanas$sufixoDias';
}

/// Nome do dia da semana em PT-BR, acentuado, na numeração de
/// `DateTime.weekday`.
String _weekdayName(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'segunda';
    case DateTime.tuesday:
      return 'terça';
    case DateTime.wednesday:
      return 'quarta';
    case DateTime.thursday:
      return 'quinta';
    case DateTime.friday:
      return 'sexta';
    case DateTime.saturday:
      return 'sábado';
    case DateTime.sunday:
      return 'domingo';
    default:
      return '';
  }
}

/// Une os dias por `, ` com ` e ` antes do último, sempre ordenados a partir
/// do domingo (a ordem em que os chips aparecem no formulário).
String _joinWeekdays(List<int> weekdays) {
  final ordenados = weekdays.where((d) => d >= 1 && d <= 7).toSet().toList()
    ..sort((a, b) => _ordemNaSemana(a).compareTo(_ordemNaSemana(b)));

  final nomes = ordenados.map(_weekdayName).where((n) => n.isNotEmpty).toList();
  if (nomes.isEmpty) return '';
  if (nomes.length == 1) return nomes.first;
  return '${nomes.take(nomes.length - 1).join(', ')} e ${nomes.last}';
}

/// Domingo primeiro: `DateTime.sunday` é 7, mas a semana da UI começa nele.
int _ordemNaSemana(int weekday) => weekday == DateTime.sunday ? 0 : weekday;

/// `1º`, `2º`, `3º`, `4º`, `último` — a tabela `{ordinal}` do `06-UI-SPEC.md`.
String _ordinalLabel(int ordinal) {
  switch (ordinal) {
    case 1:
      return '1º';
    case 2:
      return '2º';
    case 3:
      return '3º';
    case 4:
      return '4º';
    case 5:
    default:
      return 'último';
  }
}
