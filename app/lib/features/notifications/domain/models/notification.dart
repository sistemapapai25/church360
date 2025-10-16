import 'package:flutter/foundation.dart';

/// Tipo de notificação
enum NotificationType {
  devotionalDaily('devotional_daily', 'Devocional Diário', '📖'),
  prayerRequestPrayed('prayer_request_prayed', 'Oração Recebida', '🙏'),
  prayerRequestAnswered('prayer_request_answered', 'Oração Respondida', '✨'),
  eventReminder('event_reminder', 'Lembrete de Evento', '📅'),
  meetingReminder('meeting_reminder', 'Lembrete de Reunião', '👥'),
  worshipReminder('worship_reminder', 'Lembrete de Culto', '⛪'),
  groupNewMember('group_new_member', 'Novo Membro', '🎉'),
  financialGoalReached('financial_goal_reached', 'Meta Atingida', '💰'),
  birthdayReminder('birthday_reminder', 'Aniversário', '🎂'),
  general('general', 'Geral', '📢');

  const NotificationType(this.value, this.displayName, this.icon);

  final String value;
  final String displayName;
  final String icon;

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => NotificationType.general,
    );
  }
}

/// Status da notificação
enum NotificationStatus {
  pending('pending', 'Pendente'),
  sent('sent', 'Enviada'),
  read('read', 'Lida'),
  failed('failed', 'Falha');

  const NotificationStatus(this.value, this.displayName);

  final String value;
  final String displayName;

  static NotificationStatus fromString(String value) {
    return NotificationStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => NotificationStatus.pending,
    );
  }
}

/// Modelo de notificação
@immutable
class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final NotificationStatus status;
  final String? route;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? sentAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    required this.status,
    this.route,
    required this.createdAt,
    required this.updatedAt,
    this.sentAt,
    this.readAt,
  });

  /// Criar a partir do JSON do Supabase
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: NotificationType.fromString(json['type'] as String),
      title: json['title'] as String,
      body: json['body'] as String,
      data: json['data'] as Map<String, dynamic>?,
      status: NotificationStatus.fromString(json['status'] as String),
      route: json['route'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at'] as String) : null,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at'] as String) : null,
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type.value,
      'title': title,
      'body': body,
      'data': data,
      'status': status.value,
      'route': route,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sent_at': sentAt?.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
    };
  }

  /// Helpers
  bool get isRead => status == NotificationStatus.read;
  bool get isUnread => status != NotificationStatus.read;
  
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()} semana${difference.inDays > 14 ? 's' : ''} atrás';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} dia${difference.inDays > 1 ? 's' : ''} atrás';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hora${difference.inHours > 1 ? 's' : ''} atrás';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''} atrás';
    } else {
      return 'Agora';
    }
  }

  /// CopyWith
  AppNotification copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    NotificationStatus? status,
    String? route,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? sentAt,
    DateTime? readAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      status: status ?? this.status,
      route: route ?? this.route,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sentAt: sentAt ?? this.sentAt,
      readAt: readAt ?? this.readAt,
    );
  }
}

/// Modelo de preferências de notificação
@immutable
class NotificationPreferences {
  final String id;
  final String userId;
  final bool devotionalDaily;
  final bool prayerRequestPrayed;
  final bool prayerRequestAnswered;
  final bool eventReminder;
  final bool meetingReminder;
  final bool worshipReminder;
  final bool groupNewMember;
  final bool financialGoalReached;
  final bool birthdayReminder;
  final bool general;
  final bool quietHoursEnabled;
  final String? quietHoursStart; // HH:mm format
  final String? quietHoursEnd;   // HH:mm format
  final DateTime createdAt;
  final DateTime updatedAt;

  const NotificationPreferences({
    required this.id,
    required this.userId,
    this.devotionalDaily = true,
    this.prayerRequestPrayed = true,
    this.prayerRequestAnswered = true,
    this.eventReminder = true,
    this.meetingReminder = true,
    this.worshipReminder = true,
    this.groupNewMember = true,
    this.financialGoalReached = true,
    this.birthdayReminder = true,
    this.general = true,
    this.quietHoursEnabled = false,
    this.quietHoursStart,
    this.quietHoursEnd,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Criar a partir do JSON do Supabase
  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      devotionalDaily: json['devotional_daily'] as bool? ?? true,
      prayerRequestPrayed: json['prayer_request_prayed'] as bool? ?? true,
      prayerRequestAnswered: json['prayer_request_answered'] as bool? ?? true,
      eventReminder: json['event_reminder'] as bool? ?? true,
      meetingReminder: json['meeting_reminder'] as bool? ?? true,
      worshipReminder: json['worship_reminder'] as bool? ?? true,
      groupNewMember: json['group_new_member'] as bool? ?? true,
      financialGoalReached: json['financial_goal_reached'] as bool? ?? true,
      birthdayReminder: json['birthday_reminder'] as bool? ?? true,
      general: json['general'] as bool? ?? true,
      quietHoursEnabled: json['quiet_hours_enabled'] as bool? ?? false,
      quietHoursStart: json['quiet_hours_start'] as String?,
      quietHoursEnd: json['quiet_hours_end'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'devotional_daily': devotionalDaily,
      'prayer_request_prayed': prayerRequestPrayed,
      'prayer_request_answered': prayerRequestAnswered,
      'event_reminder': eventReminder,
      'meeting_reminder': meetingReminder,
      'worship_reminder': worshipReminder,
      'group_new_member': groupNewMember,
      'financial_goal_reached': financialGoalReached,
      'birthday_reminder': birthdayReminder,
      'general': general,
      'quiet_hours_enabled': quietHoursEnabled,
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// CopyWith
  NotificationPreferences copyWith({
    String? id,
    String? userId,
    bool? devotionalDaily,
    bool? prayerRequestPrayed,
    bool? prayerRequestAnswered,
    bool? eventReminder,
    bool? meetingReminder,
    bool? worshipReminder,
    bool? groupNewMember,
    bool? financialGoalReached,
    bool? birthdayReminder,
    bool? general,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationPreferences(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      devotionalDaily: devotionalDaily ?? this.devotionalDaily,
      prayerRequestPrayed: prayerRequestPrayed ?? this.prayerRequestPrayed,
      prayerRequestAnswered: prayerRequestAnswered ?? this.prayerRequestAnswered,
      eventReminder: eventReminder ?? this.eventReminder,
      meetingReminder: meetingReminder ?? this.meetingReminder,
      worshipReminder: worshipReminder ?? this.worshipReminder,
      groupNewMember: groupNewMember ?? this.groupNewMember,
      financialGoalReached: financialGoalReached ?? this.financialGoalReached,
      birthdayReminder: birthdayReminder ?? this.birthdayReminder,
      general: general ?? this.general,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Modelo de token FCM
@immutable
class FcmToken {
  final String id;
  final String userId;
  final String token;
  final String? deviceId;
  final String? deviceName;
  final String? platform;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastUsedAt;

  const FcmToken({
    required this.id,
    required this.userId,
    required this.token,
    this.deviceId,
    this.deviceName,
    this.platform,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    required this.lastUsedAt,
  });

  /// Criar a partir do JSON do Supabase
  factory FcmToken.fromJson(Map<String, dynamic> json) {
    return FcmToken(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      token: json['token'] as String,
      deviceId: json['device_id'] as String?,
      deviceName: json['device_name'] as String?,
      platform: json['platform'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastUsedAt: DateTime.parse(json['last_used_at'] as String),
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'token': token,
      'device_id': deviceId,
      'device_name': deviceName,
      'platform': platform,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_used_at': lastUsedAt.toIso8601String(),
    };
  }
}

