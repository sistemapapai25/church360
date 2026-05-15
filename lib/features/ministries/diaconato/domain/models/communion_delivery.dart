// Modelos do lote de ceia do Diaconato (MD.4 do roadmap
// "Ministérios — telas próprias"). Reflete as tabelas
// `communion_delivery_batch` e `communion_delivery_item` introduzidas em
// `supabase/migrations/20260515000001_communion_delivery_batch_and_item.sql`.

/// Estados do lote em si.
enum CommunionBatchStatus {
  open('open', 'Aberto'),
  closed('closed', 'Fechado');

  final String value;
  final String label;
  const CommunionBatchStatus(this.value, this.label);

  static CommunionBatchStatus fromValue(String value) {
    return CommunionBatchStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CommunionBatchStatus.open,
    );
  }
}

/// Ciclo de vida do item: pending → assigned → delivered (ou not_found / cancelled).
enum CommunionDeliveryStatus {
  pending('pending', 'Pendente'),
  assigned('assigned', 'Atribuído'),
  delivered('delivered', 'Entregue'),
  notFound('not_found', 'Não encontrado'),
  cancelled('cancelled', 'Cancelado');

  final String value;
  final String label;
  const CommunionDeliveryStatus(this.value, this.label);

  static CommunionDeliveryStatus fromValue(String value) {
    return CommunionDeliveryStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CommunionDeliveryStatus.pending,
    );
  }
}

/// Motivo da entrega — snapshot do `absent_action` que originou o item.
enum CommunionDeliveryReason {
  communion('communion', 'Levar ceia'),
  callAndCommunion('call_and_communion', 'Ligar + ceia');

  final String value;
  final String label;
  const CommunionDeliveryReason(this.value, this.label);

  static CommunionDeliveryReason fromValue(String value) {
    return CommunionDeliveryReason.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CommunionDeliveryReason.communion,
    );
  }
}

/// Lote de entrega de ceia — agrupa items por (ministry, attendance_count).
class CommunionDeliveryBatch {
  final String id;
  final String tenantId;
  final String ministryId;
  final String attendanceCountId;
  final DateTime serviceDate;
  final CommunionBatchStatus status;
  final String? notes;
  final String? createdBy;
  final DateTime? closedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CommunionDeliveryBatch({
    required this.id,
    required this.tenantId,
    required this.ministryId,
    required this.attendanceCountId,
    required this.serviceDate,
    required this.status,
    this.notes,
    this.createdBy,
    this.closedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommunionDeliveryBatch.fromJson(Map<String, dynamic> json) {
    return CommunionDeliveryBatch(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      ministryId: json['ministry_id'] as String,
      attendanceCountId: json['attendance_count_id'] as String,
      serviceDate: DateTime.parse(json['service_date'] as String),
      status: CommunionBatchStatus.fromValue(json['status'] as String),
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Item do lote — 1 pessoa a receber ceia.
class CommunionDeliveryItem {
  final String id;
  final String tenantId;
  final String batchId;
  final String userId;
  final CommunionDeliveryReason reason;
  final String? assignedTo;
  final CommunionDeliveryStatus status;
  final DateTime? deliveredAt;
  final String? notes;
  final DateTime? reminderAppSentAt;
  final DateTime? reminderWhatsappSentAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CommunionDeliveryItem({
    required this.id,
    required this.tenantId,
    required this.batchId,
    required this.userId,
    required this.reason,
    this.assignedTo,
    required this.status,
    this.deliveredAt,
    this.notes,
    this.reminderAppSentAt,
    this.reminderWhatsappSentAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommunionDeliveryItem.fromJson(Map<String, dynamic> json) {
    return CommunionDeliveryItem(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      batchId: json['batch_id'] as String,
      userId: json['user_id'] as String,
      reason: CommunionDeliveryReason.fromValue(json['reason'] as String),
      assignedTo: json['assigned_to'] as String?,
      status: CommunionDeliveryStatus.fromValue(json['status'] as String),
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'] as String)
          : null,
      notes: json['notes'] as String?,
      reminderAppSentAt: json['reminder_app_sent_at'] != null
          ? DateTime.parse(json['reminder_app_sent_at'] as String)
          : null,
      reminderWhatsappSentAt: json['reminder_whatsapp_sent_at'] != null
          ? DateTime.parse(json['reminder_whatsapp_sent_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
