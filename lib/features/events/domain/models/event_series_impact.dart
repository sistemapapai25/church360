/// Fase 6 — o `jsonb` de impacto devolvido pelas RPCs de série.
///
/// É o contrato de retorno **comum** às RPCs de série da fase
/// (`delete_event_series_future`, migration `20260902000500`, e as de aplicar/
/// estender/regerar dos Planos 06 e 08): as três respondem o mesmo formato nos
/// dois modos, prévia (`p_dry_run: true`) e execução. Qualquer chave nova
/// acrescentada no servidor tem que aparecer AQUI antes de ser usada na UI —
/// uma chave lida direto do `Map` na tela é como uma contagem passa a mentir
/// silenciosamente quando o servidor muda o nome dela.
///
/// **Este modelo só entra, nunca sai.** Não há `toJson`: nada aqui é enviado
/// ao servidor, e um serializador daria a impressão errada de que a UI pode
/// propor contagens.
///
/// As contagens são a fonte ÚNICA dos números dos diálogos de impacto (A-04 do
/// `06-UI-SPEC.md`): o cutoff de "ocorrência futura" é calculado no servidor
/// (`public.event_series_future_cutoff()`), no fuso invertido de
/// `event.start_date`, e uma contagem local erraria por até 3 horas de janela.
class EventSeriesImpact {
  /// `true` quando a resposta veio de uma prévia — nada foi alterado.
  final bool dryRun;

  /// `n` — ocorrências futuras que a operação atinge.
  final int futureCount;

  /// `m` — ocorrências passadas preservadas.
  final int pastCount;

  /// Primeira e última data do conjunto futuro. **Nulas** quando a série não
  /// tem nenhuma ocorrência futura (DLG-6) — não é erro.
  final DateTime? firstFuture;
  final DateTime? lastFuture;

  /// `k` — inscrições que serão canceladas. Conta inscrições, não pessoas
  /// avisadas: quem não tem conta com login não recebe notificação (A-11).
  final int affectedRegistrations;

  /// Escalas de ministério vinculadas às ocorrências futuras.
  final int affectedSchedules;

  /// Ocorrências de fato excluídas. Sempre `0` em prévia.
  final int deletedCount;

  /// Notificações de fato gravadas. Sempre `<= affectedRegistrations`.
  final int notifiedCount;

  /// Ocorrências criadas — usado pelas fatias de estender/regerar (Planos 06 e
  /// 08). Sempre `0` na exclusão de futuras.
  final int createdCount;

  const EventSeriesImpact({
    required this.dryRun,
    required this.futureCount,
    required this.pastCount,
    this.firstFuture,
    this.lastFuture,
    required this.affectedRegistrations,
    required this.affectedSchedules,
    required this.deletedCount,
    required this.notifiedCount,
    this.createdCount = 0,
  });

  /// Desserializa o `jsonb` do servidor, em snake_case.
  ///
  /// Chave ausente vira `0`/`null` em vez de exceção: a mesma resposta é
  /// consumida por RPCs diferentes desta fase, e nem todas preenchem todas as
  /// chaves. Nenhum valor é INVENTADO — ausente é zero, não uma estimativa.
  factory EventSeriesImpact.fromJson(Map<String, dynamic> json) {
    return EventSeriesImpact(
      dryRun: json['dry_run'] as bool? ?? false,
      futureCount: json['future_count'] as int? ?? 0,
      pastCount: json['past_count'] as int? ?? 0,
      firstFuture: _parseDate(json['first_future']),
      lastFuture: _parseDate(json['last_future']),
      affectedRegistrations: json['affected_registrations'] as int? ?? 0,
      affectedSchedules: json['affected_schedules'] as int? ?? 0,
      deletedCount: json['deleted_count'] as int? ?? 0,
      notifiedCount: json['notified_count'] as int? ?? 0,
      createdCount: json['created_count'] as int? ?? 0,
    );
  }

  /// As colunas de origem são `date`; o servidor serializa como `yyyy-MM-dd`.
  /// Valor irreconhecível vira `null` — nunca uma data inventada.
  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
