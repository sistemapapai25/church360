/// Fase 6 — o `jsonb` de impacto devolvido pelas RPCs de série.
///
/// É o contrato de retorno **comum** às três RPCs de série da fase
/// (`delete_event_series_future` do Plano 03, `apply_event_series_update` do
/// Plano 05 e `regenerate_event_series` do Plano 07): as três respondem o
/// mesmo formato nos dois modos, prévia (`p_dry_run: true`) e execução.
/// Qualquer chave nova acrescentada no servidor tem que aparecer AQUI antes de
/// ser usada na UI — uma chave lida direto do `Map` na tela é como uma
/// contagem passa a mentir silenciosamente quando o servidor muda o nome dela.
///
/// **As chaves de regeneração ([mode], [keptCount], [firstNew], [lastNew],
/// [futureAfterCount], [paidOccurrences], [migratedSchedules]) só vêm
/// preenchidas por `regenerate_event_series`.** As RPCs dos Planos 03 e 05
/// continuam válidas sem alterar nada: toda leitura nova tem default, e chave
/// ausente vira `0`/`''`/`null`, nunca exceção.
///
/// **Este modelo só entra, nunca sai.** Não existe serializador de saída aqui:
/// nada deste modelo é enviado ao servidor, e um serializador daria a impressão
/// errada de que a UI pode propor contagens.
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

  /// Ocorrências futuras de fato ATUALIZADAS por
  /// `apply_event_series_update` (migration `20260902000600`). Sempre `0` em
  /// prévia, e ausente na resposta da RPC de exclusão — por isso cai em `0`.
  ///
  /// É este número, e não o `future_count` da prévia, que o SnackBar de
  /// sucesso informa: entre a prévia e a confirmação o conjunto pode mudar.
  final int updatedCount;

  /// O modo que o SERVIDOR decidiu: `'none'` | `'extend'` | `'shorten'` |
  /// `'regenerate'`. Vazio quando a RPC que respondeu não tem modo.
  ///
  /// **É este campo — e nunca a detecção local — que escolhe qual diálogo
  /// abrir e qual copy de sucesso usar.** O cliente propõe o padrão desejado;
  /// quem compara com `event_series` e decide entre criar, excluir ou regerar
  /// é `regenerate_event_series`.
  final String mode;

  /// Ocorrências futuras que a regeneração PRESERVA (já caem numa data-alvo
  /// do padrão novo e não precisam ser recriadas).
  final int keptCount;

  /// Primeira e última data do conjunto CRIADO. Nulas quando nada é criado.
  final DateTime? firstNew;
  final DateTime? lastNew;

  /// Quantas ocorrências futuras a série tem **depois** da operação. É o
  /// número do SnackBar de sucesso do DLG-4.
  final int futureAfterCount;

  /// Ocorrências futuras com inscrição PAGA. D-16/A-02: o ramo pago é stub
  /// nesta fase — o número existe para diagnóstico, e nenhuma copy de
  /// reembolso é escrita em lugar nenhum.
  final int paidOccurrences;

  /// Escalas de ministério de fato migradas para a data equivalente (D-18).
  /// Sempre `0` em prévia — é medição, não estimativa.
  final int migratedSchedules;

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
    this.updatedCount = 0,
    this.mode = '',
    this.keptCount = 0,
    this.firstNew,
    this.lastNew,
    this.futureAfterCount = 0,
    this.paidOccurrences = 0,
    this.migratedSchedules = 0,
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
      updatedCount: json['updated_count'] as int? ?? 0,
      mode: json['mode'] as String? ?? '',
      keptCount: json['kept_count'] as int? ?? 0,
      firstNew: _parseDate(json['first_new']),
      lastNew: _parseDate(json['last_new']),
      futureAfterCount: json['future_after_count'] as int? ?? 0,
      paidOccurrences: json['paid_occurrences'] as int? ?? 0,
      migratedSchedules: json['migrated_schedules'] as int? ?? 0,
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
