import '../../presentation/utils/series_pattern_label.dart';

/// Fase 6 — REC-01. Definição do padrão de repetição de uma série de eventos
/// fixos (`public.event_series`, migration `20260902000100`).
///
/// A série é chaveada pelo `batch_id` que as ocorrências já carregavam antes
/// desta fase — [id] **é** o `batch_id`, não um id novo. Não existe FK reversa
/// de `event.batch_id` para cá: séries criadas antes desta fase continuam
/// válidas e simplesmente não têm linha aqui (série legada, IC-7 — hoje 100%
/// da produção, VEREDITO A4 do `06-DB-BASELINE.md`).
///
/// Os `assert` abaixo espelham, um a um, os CHECKs do servidor. Eles não são
/// a autoridade — a constraint é — mas fazem o erro aparecer no cliente, com
/// o nome da constraint, em vez de virar um 400 opaco do PostgREST.
class EventSeries {
  /// O `batch_id` do lote de ocorrências. Chave primária de `event_series`.
  final String? id;

  /// Carimbado pelo servidor (`current_tenant_id()` dentro da RPC), nunca
  /// pelo formulário.
  final String? tenantId;

  /// A FASE do intervalo, não a data nominal de início (Achado #9).
  ///
  /// `_matchesWeekInterval` conta as semanas a partir desta data: uma série
  /// quinzenal ancorada num domingo cai em domingos alternados A PARTIR
  /// DELE. Recalcular a âncora depois de gravada desloca todas as ocorrências
  /// novas para as semanas erradas, intercaladas com as existentes — por isso
  /// a RPC preserva `anchor_date` no ramo `ON CONFLICT DO UPDATE`.
  final DateTime anchorDate;

  /// `'semanal'` | `'variavel'` (`event_series_pattern_chk`).
  final String patternGroup;

  /// `null` | `'quinzenal'` | `'dias'` | `'unico'`
  /// (`event_series_vartype_chk`). Só faz sentido com
  /// [patternGroup] == `'variavel'`.
  final String? variableType;

  /// Numeração de `DateTime.weekday` (1=segunda .. 7=domingo), a mesma do
  /// estado `_fixedWeekdays` do formulário e da coluna no servidor.
  final List<int> weekdays;

  /// 1..8 (`event_series_interval_chk`).
  final int intervalWeeks;

  /// `null` | 1..5, onde 5 significa "último" (`event_series_ordinal_chk`).
  final int? monthlyOrdinal;

  /// Data de encerramento escolhida pelo líder (REC-01).
  ///
  /// `null` significa **horizonte padrão**: 12 meses a partir da criação, o
  /// comportamento que existia antes desta fase. O teto duro de 24 meses é a
  /// constraint `event_series_horizon_chk` do servidor.
  final DateTime? recurrenceEndDate;

  /// Hora do dia da série, em minutos desde 00:00, 0..1439
  /// (`event_series_start_time_chk`).
  ///
  /// De propósito é `int` e não `TimeOfDay`: este é um modelo de domínio e
  /// não importa Flutter. A conversão para `TimeOfDay` fica na tela.
  final int startTimeMinutes;

  /// Só de exibição — carimbados pelo servidor, ausentes de [toJson].
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EventSeries({
    this.id,
    this.tenantId,
    required this.anchorDate,
    required this.patternGroup,
    this.variableType,
    required this.weekdays,
    required this.intervalWeeks,
    this.monthlyOrdinal,
    this.recurrenceEndDate,
    required this.startTimeMinutes,
    this.createdAt,
    this.updatedAt,
  }) : assert(
         intervalWeeks >= 1 && intervalWeeks <= 8,
         'EventSeries.intervalWeeks precisa estar entre 1 e 8 '
         '(event_series_interval_chk)',
       ),
       assert(
         monthlyOrdinal == null ||
             (monthlyOrdinal >= 1 && monthlyOrdinal <= 5),
         'EventSeries.monthlyOrdinal precisa ser nulo ou estar entre 1 e 5 '
         '(event_series_ordinal_chk)',
       ),
       assert(
         startTimeMinutes >= 0 && startTimeMinutes <= 1439,
         'EventSeries.startTimeMinutes precisa estar entre 0 e 1439 '
         '(event_series_start_time_chk)',
       );

  /// Descrição do padrão em PT-BR, para a UI.
  ///
  /// Delega para `describeSeriesPattern` (A-13): `pattern_group` e
  /// `variable_type` são valores de banco e **nunca** aparecem crus na tela.
  String get patternLabel => describeSeriesPattern(
    patternGroup: patternGroup,
    variableType: variableType,
    weekdays: weekdays,
    intervalWeeks: intervalWeeks,
    monthlyOrdinal: monthlyOrdinal,
  );

  factory EventSeries.fromJson(Map<String, dynamic> json) {
    return EventSeries(
      id: json['id'] as String?,
      tenantId: json['tenant_id'] as String?,
      anchorDate: DateTime.parse(json['anchor_date'] as String),
      patternGroup: json['pattern_group'] as String,
      variableType: json['variable_type'] as String?,
      weekdays: ((json['weekdays'] as List?) ?? const [])
          .map((d) => (d as num).toInt())
          .toList(),
      intervalWeeks: (json['interval_weeks'] as num).toInt(),
      monthlyOrdinal: (json['monthly_ordinal'] as num?)?.toInt(),
      recurrenceEndDate: json['recurrence_end_date'] != null
          ? DateTime.parse(json['recurrence_end_date'] as String)
          : null,
      startTimeMinutes: (json['start_time_minutes'] as num).toInt(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Sem `id`, `tenant_id`, `created_at` nem `updated_at`: os quatro são
  /// carimbados pelo servidor dentro da RPC de escrita.
  ///
  /// As duas datas saem como `yyyy-MM-dd` porque as colunas são `date`. Mandar
  /// ISO completo faria o Postgres truncar em silêncio, e o dia gravado
  /// passaria a depender do fuso do aparelho de quem salvou.
  Map<String, dynamic> toJson() {
    return {
      'anchor_date': formatSeriesDate(anchorDate),
      'pattern_group': patternGroup,
      'variable_type': variableType,
      'weekdays': weekdays,
      'interval_weeks': intervalWeeks,
      'monthly_ordinal': monthlyOrdinal,
      'recurrence_end_date': recurrenceEndDate == null
          ? null
          : formatSeriesDate(recurrenceEndDate!),
      'start_time_minutes': startTimeMinutes,
    };
  }
}

/// Serializa uma data para o formato `date` do Postgres (`yyyy-MM-dd`).
///
/// Não usa `toIso8601String()` de propósito: a coluna é `date`, e mandar o
/// timestamp completo deixaria o dia gravado dependente do fuso do aparelho.
String formatSeriesDate(DateTime date) {
  final mes = date.month.toString().padLeft(2, '0');
  final dia = date.day.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-$mes-$dia';
}
