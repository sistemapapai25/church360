/// Alvo de audiência de um evento (responsável, visibilidade ou inscrição).
///
/// Espelha o CHECK do servidor (`event_audience_single_target_chk`):
/// exatamente um entre [userId]/[groupId]/[ministryId]/[rbacRoleId] é
/// preenchido — `num_nonnulls(user_id, group_id, ministry_id, rbac_role_id) = 1`.
enum EventAudienceTargetKind {
  person,
  group,
  ministry,

  /// Cargo RBAC tenant-scoped de `public.roles` (tela Permissões > Cargos).
  /// Não tem relação com o campo [EventAudience.role], que é o papel da linha
  /// de audiência (`responsible`/`visibility`/`registration`) — é a mesma
  /// armadilha de nome que fez a coluna do servidor se chamar `rbac_role_id`.
  role,
}

class EventAudience {
  final String? id;
  final String eventId;
  final String role;
  final String? userId;
  final String? groupId;
  final String? ministryId;
  final String? rbacRoleId;

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
    this.rbacRoleId,
    this.displayName,
  }) : assert(
         (userId != null ? 1 : 0) +
                 (groupId != null ? 1 : 0) +
                 (ministryId != null ? 1 : 0) +
                 (rbacRoleId != null ? 1 : 0) ==
             1,
         'EventAudience precisa de exatamente um alvo: userId, groupId, ministryId ou rbacRoleId',
       );

  EventAudienceTargetKind get targetKind {
    if (userId != null) return EventAudienceTargetKind.person;
    if (groupId != null) return EventAudienceTargetKind.group;
    if (ministryId != null) return EventAudienceTargetKind.ministry;
    return EventAudienceTargetKind.role;
  }

  String get targetId {
    switch (targetKind) {
      case EventAudienceTargetKind.person:
        return userId!;
      case EventAudienceTargetKind.group:
        return groupId!;
      case EventAudienceTargetKind.ministry:
        return ministryId!;
      case EventAudienceTargetKind.role:
        return rbacRoleId!;
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
      rbacRoleId: json['rbac_role_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'role': role,
      'user_id': userId,
      'group_id': groupId,
      'ministry_id': ministryId,
      'rbac_role_id': rbacRoleId,
    };
  }
}
