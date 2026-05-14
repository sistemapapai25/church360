/// Lote 11.5 — Modelo da `ministry_change_notification_config`.
///
/// Reflete a tabela criada no Lote 11.0 (`70_*.sql`). Controla quem recebe
/// notificação in-app quando há mudança na agenda de um ministério.
library;

enum NotificationConfigMode {
  leaders('leaders', 'Líderes e coordenadores'),
  allMembers('all_members', 'Todos os membros'),
  custom('custom', 'Lista personalizada');

  final String value;
  final String label;
  const NotificationConfigMode(this.value, this.label);

  static NotificationConfigMode fromValue(String? value) {
    return NotificationConfigMode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationConfigMode.leaders,
    );
  }
}

class MinistryNotificationConfig {
  final String ministryId;
  final bool active;
  final NotificationConfigMode mode;
  final List<String> customMinistryIds;
  final List<String> customUserIds;
  final bool notifyOnEventAdded;
  final bool notifyOnEventRemoved;
  final bool notifyOnEventUpdated;
  final bool notifyOnMemberAssigned;
  final bool alwaysIncludeAffectedMember;

  const MinistryNotificationConfig({
    required this.ministryId,
    this.active = true,
    this.mode = NotificationConfigMode.leaders,
    this.customMinistryIds = const [],
    this.customUserIds = const [],
    this.notifyOnEventAdded = true,
    this.notifyOnEventRemoved = true,
    this.notifyOnEventUpdated = true,
    this.notifyOnMemberAssigned = true,
    this.alwaysIncludeAffectedMember = true,
  });

  /// Default usado quando o ministério não tem row na tabela ainda.
  /// Reflete os defaults do schema SQL (Lote 11.0).
  factory MinistryNotificationConfig.defaultFor(String ministryId) =>
      MinistryNotificationConfig(ministryId: ministryId);

  factory MinistryNotificationConfig.fromJson(Map<String, dynamic> json) {
    List<String> asList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    bool asBool(dynamic v, {bool fallback = true}) {
      if (v is bool) return v;
      if (v is String) {
        final s = v.toLowerCase();
        if (s == 'true') return true;
        if (s == 'false') return false;
      }
      return fallback;
    }

    return MinistryNotificationConfig(
      ministryId: (json['ministry_id'] ?? '').toString(),
      active: asBool(json['active']),
      mode: NotificationConfigMode.fromValue(json['mode']?.toString()),
      customMinistryIds: asList(json['custom_ministry_ids']),
      customUserIds: asList(json['custom_user_ids']),
      notifyOnEventAdded: asBool(json['notify_on_event_added']),
      notifyOnEventRemoved: asBool(json['notify_on_event_removed']),
      notifyOnEventUpdated: asBool(json['notify_on_event_updated']),
      notifyOnMemberAssigned: asBool(json['notify_on_member_assigned']),
      alwaysIncludeAffectedMember: asBool(json['always_include_affected_member']),
    );
  }

  Map<String, dynamic> toUpsertJson() {
    return {
      'ministry_id': ministryId,
      'active': active,
      'mode': mode.value,
      'custom_ministry_ids': customMinistryIds,
      'custom_user_ids': customUserIds,
      'notify_on_event_added': notifyOnEventAdded,
      'notify_on_event_removed': notifyOnEventRemoved,
      'notify_on_event_updated': notifyOnEventUpdated,
      'notify_on_member_assigned': notifyOnMemberAssigned,
      'always_include_affected_member': alwaysIncludeAffectedMember,
    };
  }

  MinistryNotificationConfig copyWith({
    bool? active,
    NotificationConfigMode? mode,
    List<String>? customMinistryIds,
    List<String>? customUserIds,
    bool? notifyOnEventAdded,
    bool? notifyOnEventRemoved,
    bool? notifyOnEventUpdated,
    bool? notifyOnMemberAssigned,
    bool? alwaysIncludeAffectedMember,
  }) {
    return MinistryNotificationConfig(
      ministryId: ministryId,
      active: active ?? this.active,
      mode: mode ?? this.mode,
      customMinistryIds: customMinistryIds ?? this.customMinistryIds,
      customUserIds: customUserIds ?? this.customUserIds,
      notifyOnEventAdded: notifyOnEventAdded ?? this.notifyOnEventAdded,
      notifyOnEventRemoved: notifyOnEventRemoved ?? this.notifyOnEventRemoved,
      notifyOnEventUpdated: notifyOnEventUpdated ?? this.notifyOnEventUpdated,
      notifyOnMemberAssigned:
          notifyOnMemberAssigned ?? this.notifyOnMemberAssigned,
      alwaysIncludeAffectedMember:
          alwaysIncludeAffectedMember ?? this.alwaysIncludeAffectedMember,
    );
  }
}
