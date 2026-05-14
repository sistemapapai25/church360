import 'package:flutter/foundation.dart';

/// Status do ciclo de vida de uma visita do Raízes.
/// Em sincronia com o CHECK constraint em `raizes_visit_schedule`.
enum RaizesVisitStatus {
  pending('pending', 'Pendente'),
  confirmed('confirmed', 'Confirmada'),
  completed('completed', 'Realizada'),
  reschedule('reschedule', 'Reagendar'),
  cancelled('cancelled', 'Cancelada');

  final String value;
  final String label;
  const RaizesVisitStatus(this.value, this.label);

  static RaizesVisitStatus fromValue(String? value) {
    if (value == null) return RaizesVisitStatus.pending;
    return RaizesVisitStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => RaizesVisitStatus.pending,
    );
  }

  /// Visitas em estado "ativo" (entram nos KPIs do dashboard e em lembretes).
  bool get isOpen =>
      this == RaizesVisitStatus.pending || this == RaizesVisitStatus.confirmed;
}

/// Período do dia quando não há horário exato. Sincronia com CHECK em SQL.
enum RaizesVisitPeriod {
  morning('morning', 'Manhã'),
  afternoon('afternoon', 'Tarde'),
  evening('evening', 'Final da tarde'),
  night('night', 'Noite');

  final String value;
  final String label;
  const RaizesVisitPeriod(this.value, this.label);

  static RaizesVisitPeriod? fromValue(String? value) {
    if (value == null) return null;
    for (final p in RaizesVisitPeriod.values) {
      if (p.value == value) return p;
    }
    return null;
  }
}

/// Modelo de uma visita planejada do Raízes.
@immutable
class RaizesVisit {
  final String id;
  final String tenantId;
  final String ministryId;
  final String visitorId;
  final String? assignedTo;
  final DateTime scheduledDate;
  final String? scheduledTime; // HH:mm:ss (formato Postgres `time`).
  final RaizesVisitPeriod? period;
  final RaizesVisitStatus status;
  final DateTime? reminderAppSentAt;
  final DateTime? reminderWhatsappSentAt;
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Campos derivados (preenchidos pelo repository via embed):
  final String? visitorName;
  final String? assignedToName;

  const RaizesVisit({
    required this.id,
    required this.tenantId,
    required this.ministryId,
    required this.visitorId,
    required this.assignedTo,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.period,
    required this.status,
    required this.reminderAppSentAt,
    required this.reminderWhatsappSentAt,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.visitorName,
    this.assignedToName,
  });

  factory RaizesVisit.fromJson(Map<String, dynamic> json) {
    String? extractName(dynamic embed) {
      if (embed is Map<String, dynamic>) {
        final first = (embed['first_name'] as String?)?.trim() ?? '';
        final last = (embed['last_name'] as String?)?.trim() ?? '';
        final full = '$first $last'.trim();
        return full.isEmpty ? null : full;
      }
      return null;
    }

    return RaizesVisit(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      ministryId: json['ministry_id'] as String,
      visitorId: json['visitor_id'] as String,
      assignedTo: json['assigned_to'] as String?,
      scheduledDate: DateTime.parse(json['scheduled_date'] as String),
      scheduledTime: json['scheduled_time'] as String?,
      period: RaizesVisitPeriod.fromValue(json['period'] as String?),
      status: RaizesVisitStatus.fromValue(json['status'] as String?),
      reminderAppSentAt: json['reminder_app_sent_at'] != null
          ? DateTime.parse(json['reminder_app_sent_at'] as String)
          : null,
      reminderWhatsappSentAt: json['reminder_whatsapp_sent_at'] != null
          ? DateTime.parse(json['reminder_whatsapp_sent_at'] as String)
          : null,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      visitorName: extractName(json['visitor']),
      assignedToName: extractName(json['assignee']),
    );
  }

  /// Está em atraso se a data já passou e o status ainda está aberto.
  bool get isOverdue {
    if (!status.isOpen) return false;
    final today = DateTime.now();
    final dateOnly = DateTime(today.year, today.month, today.day);
    return scheduledDate.isBefore(dateOnly);
  }

  /// Visita marcada para hoje (em qualquer status).
  bool get isToday {
    final today = DateTime.now();
    return scheduledDate.year == today.year &&
        scheduledDate.month == today.month &&
        scheduledDate.day == today.day;
  }
}
