/// Alvo de audiência de um evento (responsável, visibilidade ou inscrição).
///
/// Espelha o CHECK do servidor (`event_audience_single_target_chk`):
/// exatamente um entre [userId]/[groupId]/[ministryId] é preenchido.
enum EventAudienceTargetKind { person, group, ministry }

class EventAudience {
  final String? id;
  final String eventId;
  final String role;
  final String? userId;
  final String? groupId;
  final String? ministryId;

  /// Preenchido só por join/lookup de exibição (ex.: nome no chip do
  /// formulário). Nunca persistido — ausente de [toJson].
  final String? displayName;

  EventAudience({
    this.id,
    required this.eventId,
    required this.role,
    this.userId,
    this.groupId,
    this.ministryId,
    this.displayName,
  }) : assert(
         (userId != null ? 1 : 0) +
                 (groupId != null ? 1 : 0) +
                 (ministryId != null ? 1 : 0) ==
             1,
         'EventAudience precisa de exatamente um alvo: userId, groupId ou ministryId',
       );

  EventAudienceTargetKind get targetKind {
    if (userId != null) return EventAudienceTargetKind.person;
    if (groupId != null) return EventAudienceTargetKind.group;
    return EventAudienceTargetKind.ministry;
  }

  String get targetId {
    switch (targetKind) {
      case EventAudienceTargetKind.person:
        return userId!;
      case EventAudienceTargetKind.group:
        return groupId!;
      case EventAudienceTargetKind.ministry:
        return ministryId!;
    }
  }

  factory EventAudience.fromJson(Map<String, dynamic> json) {
    return EventAudience(
      id: json['id'] as String?,
      eventId: json['event_id'] as String,
      role: json['role'] as String,
      userId: json['user_id'] as String?,
      groupId: json['group_id'] as String?,
      ministryId: json['ministry_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'role': role,
      'user_id': userId,
      'group_id': groupId,
      'ministry_id': ministryId,
    };
  }
}
