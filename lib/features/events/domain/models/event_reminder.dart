/// Lembrete configurável de um evento (D-02/D-03).
///
/// Espelha o CHECK do servidor (`event_reminder_offset_chk`):
/// `offset_minutes > 0 AND offset_minutes <= 525600` — de 1 minuto até 1
/// ano (365 dias) antes do início do evento. Também espelha a UNIQUE
/// `(event_id, offset_minutes)`: o mesmo offset não pode se repetir no
/// mesmo evento.
class EventReminder {
  final String? id;
  final String eventId;
  final int offsetMinutes;

  /// Carimbado pelo servidor/repositório, não pelo formulário.
  final String? tenantId;

  /// Só de exibição — nunca persistido, ausente de [toJson].
  final DateTime? createdAt;

  EventReminder({
    this.id,
    required this.eventId,
    required this.offsetMinutes,
    this.tenantId,
    this.createdAt,
  }) : assert(
         offsetMinutes > 0 && offsetMinutes <= 525600,
         'EventReminder.offsetMinutes precisa estar entre 1 e 525600 '
         '(event_reminder_offset_chk)',
       );

  /// Rótulo em português para o usuário — nunca exibe o número bruto de
  /// minutos, sempre a unidade mais legível (minutos, horas ou dias).
  String get label {
    if (offsetMinutes < 60) {
      return '$offsetMinutes minuto${offsetMinutes == 1 ? '' : 's'} antes';
    }
    if (offsetMinutes % 1440 == 0) {
      final dias = offsetMinutes ~/ 1440;
      return '$dias dia${dias == 1 ? '' : 's'} antes';
    }
    if (offsetMinutes % 60 == 0) {
      final horas = offsetMinutes ~/ 60;
      return '$horas hora${horas == 1 ? '' : 's'} antes';
    }
    // Offset livre que não cai em hora/dia exato (ex.: 90 minutos): mostra
    // em minutos mesmo acima de 60, para não arredondar e mentir pro usuário.
    return '$offsetMinutes minutos antes';
  }

  factory EventReminder.fromJson(Map<String, dynamic> json) {
    return EventReminder(
      id: json['id'] as String?,
      eventId: json['event_id'] as String,
      offsetMinutes: json['offset_minutes'] as int,
      tenantId: json['tenant_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'event_id': eventId, 'offset_minutes': offsetMinutes};
  }
}
