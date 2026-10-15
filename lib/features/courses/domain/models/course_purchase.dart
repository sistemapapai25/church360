/// Compra de curso pago por PIX manual (E6, `course_purchase`).
///
/// `buyerName`/`buyerPhone` só vêm pela fila do revisor
/// (`course_purchases`); a linha lida pelo próprio aluno não os traz.
class CoursePurchase {
  final String id;
  final String courseId;
  final String userId;
  final String status; // pending | approved | rejected
  final double? amount;
  final String receiptPath;
  final String? receiptName;
  final String? notes;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? buyerName;
  final String? buyerPhone;

  const CoursePurchase({
    required this.id,
    required this.courseId,
    required this.userId,
    required this.status,
    this.amount,
    required this.receiptPath,
    this.receiptName,
    this.notes,
    required this.createdAt,
    this.reviewedAt,
    this.buyerName,
    this.buyerPhone,
  });

  factory CoursePurchase.fromJson(Map<String, dynamic> json) => CoursePurchase(
    id: json['id'] as String,
    courseId: (json['course_id'] as String?) ?? '',
    userId: json['user_id'] as String,
    status: json['status'] as String,
    amount: (json['amount'] as num?)?.toDouble(),
    receiptPath: json['receipt_path'] as String,
    receiptName: json['receipt_name'] as String?,
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    reviewedAt: json['reviewed_at'] == null
        ? null
        : DateTime.tryParse(json['reviewed_at'] as String),
    buyerName: json['buyer_name'] as String?,
    buyerPhone: json['buyer_phone'] as String?,
  );

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}
