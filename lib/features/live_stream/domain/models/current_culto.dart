/// Resposta da RPC `current_culto` (migration 006500): "tem culto agora?".
///
/// `isLive` = chave do culto ao vivo ligada OU culto da Agenda aberto.
/// `streamUrl` só vem com a chave ligada; `checkinEnabled` diz se a igreja
/// tem a presença pelo celular configurada (pino no mapa).
class CurrentCulto {
  final bool isLive;
  final String? eventId;
  final String? title;
  final String? startHhmm;
  final String? streamUrl;
  final String? message;
  final bool checkinEnabled;

  const CurrentCulto({
    required this.isLive,
    this.eventId,
    this.title,
    this.startHhmm,
    this.streamUrl,
    this.message,
    this.checkinEnabled = false,
  });

  static const none = CurrentCulto(isLive: false);

  factory CurrentCulto.fromJson(Object? json) {
    final m = json is Map ? json : const {};
    return CurrentCulto(
      isLive: m['is_live'] == true,
      eventId: m['event_id'] as String?,
      title: m['title'] as String?,
      startHhmm: m['start_hhmm'] as String?,
      streamUrl: m['stream_url'] as String?,
      message: m['message'] as String?,
      checkinEnabled: m['checkin_enabled'] == true,
    );
  }
}
