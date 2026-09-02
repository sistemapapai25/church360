/// Fase 6 — REC-03/REC-04 (Plano 06-08). Detecção LOCAL de mudança de padrão
/// ou de período de uma série, no formulário de evento.
///
/// **(i) Esta função decide AVISO e DIÁLOGO — nunca o efeito.** Quem decide se
/// a operação vai apagar, criar ou não fazer nada é
/// `public.regenerate_event_series` (migration `20260902000900`), que **não
/// recebe parâmetro de modo**: ela recalcula o modo dentro do servidor,
/// comparando o padrão recebido com a linha persistida em
/// `public.event_series`. Qualquer opinião do cliente é ignorada — e é por
/// isso que o diálogo aberto no Salvar é escolhido pelo `mode` RETORNADO pela
/// prévia, não por esta detecção.
///
/// **(ii) Por isso ela replica LITERALMENTE as três regras do passo (7) do
/// servidor:**
///   1. os dias da semana são comparados ORDENADOS nos dois lados — `{7,3}` e
///      `{3,7}` são o mesmo padrão, e chamar isso de mudança apagaria e
///      recriaria a série inteira por nada, cancelando as inscrições de todo
///      mundo no caminho;
///   2. `recurrenceEndDate` nulo significa o fallback histórico de 12 meses
///      sobre `anchorDate`, dos DOIS lados — comparar `null` com data daria
///      sempre "mudou", e salvar o formulário sem tocar na data viraria
///      `extend` ou `shorten`;
///   3. mudança de padrão ABSORVE mudança de período (A-06), para que nunca
///      exista caminho que abra dois diálogos no mesmo Salvar.
///
/// Divergir dessas regras faz a UI prometer um efeito e o servidor entregar
/// outro (T-08-01). A paridade está travada em
/// `test/features/events/series_change_detection_test.dart`.
///
/// **(iii) Série legada devolve [SeriesChangeKind.none] de propósito.** Sem
/// linha em `event_series` não existe referência para comparar: IC-7 já
/// desabilita os campos de padrão e `Repetir até`, e a RPC responderia
/// `SERIES_NOT_FOUND`. As três camadas concordam por decisão, não por acaso.
library;

import '../../domain/models/event_series.dart';

/// A diferença que o formulário tem em relação à definição persistida.
///
/// Mapeia 1:1 a tabela de IC-4 do `06-UI-SPEC.md`: [none] → DLG-1,
/// [extend] → DLG-2, [shorten] → DLG-3, [pattern] → DLG-4.
enum SeriesChangeKind { none, extend, shorten, pattern }

/// Compara o estado do formulário com a definição persistida em [series].
///
/// [weekdays] usa a numeração de `DateTime.weekday` (1=segunda .. 7=domingo),
/// a mesma do estado `_fixedWeekdays` do formulário e da coluna
/// `event_series.weekdays`.
SeriesChangeKind detectSeriesChange({
  required EventSeries? series,
  required String patternGroup,
  String? variableType,
  required List<int> weekdays,
  required int intervalWeeks,
  int? monthlyOrdinal,
  DateTime? recurrenceEndDate,
}) {
  // (1) Série legada — ver (iii) no cabeçalho.
  if (series == null) return SeriesChangeKind.none;

  // (2) Padrão, com os dias ordenados dos DOIS lados. Absorve qualquer
  // mudança de período (A-06).
  final mudouPadrao =
      patternGroup != series.patternGroup ||
      variableType != series.variableType ||
      intervalWeeks != series.intervalWeeks ||
      monthlyOrdinal != series.monthlyOrdinal ||
      !_mesmosDias(weekdays, series.weekdays);

  if (mudouPadrao) return SeriesChangeKind.pattern;

  // (3) Período, com o fallback de 12 meses sobre a âncora nos dois lados e
  // comparando SÓ a parte de data (a coluna do servidor é `date`).
  final fimAntigo = _horizonte(series.recurrenceEndDate, series.anchorDate);
  final fimNovo = _horizonte(recurrenceEndDate, series.anchorDate);

  if (fimNovo.isAfter(fimAntigo)) return SeriesChangeKind.extend;
  if (fimNovo.isBefore(fimAntigo)) return SeriesChangeKind.shorten;
  return SeriesChangeKind.none;
}

/// `true` quando as duas listas descrevem o mesmo conjunto de dias, sem levar
/// a ordem em conta — a mesma comparação de `array_agg(x ORDER BY x)` que o
/// servidor faz.
bool _mesmosDias(List<int> a, List<int> b) {
  final ordenadoA = [...a]..sort();
  final ordenadoB = [...b]..sort();
  if (ordenadoA.length != ordenadoB.length) return false;
  for (var i = 0; i < ordenadoA.length; i++) {
    if (ordenadoA[i] != ordenadoB[i]) return false;
  }
  return true;
}

/// Data de encerramento efetiva: a escolhida, ou o fallback histórico de 12
/// meses a partir de [anchorDate] quando não há nenhuma.
///
/// A hora é descartada: a coluna do servidor é `date`, e comparar timestamps
/// faria o resultado depender do fuso do aparelho.
DateTime _horizonte(DateTime? escolhida, DateTime anchorDate) {
  final base = escolhida ?? _maisDozeMeses(anchorDate);
  return DateTime(base.year, base.month, base.day);
}

/// `data + INTERVAL '12 months'` com a MESMA aritmética do Postgres.
///
/// `DateTime(2027, 2, 29)` estoura para 01/03 em Dart; o Postgres grampeia no
/// último dia do mês (28/02). Uma âncora em 29/02 faria as duas
/// implementações discordarem por um dia — e um dia de diferença aqui vira um
/// `extend`/`shorten` fantasma no exato dia de borda.
DateTime _maisDozeMeses(DateTime data) {
  final ano = data.year + 1;
  final ultimoDiaDoMes = DateTime(ano, data.month + 1, 0).day;
  return DateTime(ano, data.month, data.day.clamp(1, ultimoDiaDoMes));
}
