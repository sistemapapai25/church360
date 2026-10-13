// Aba Assistência (F6 de ROADMAP-2026-10-12-MINISTERIO-PROCESSOS): famílias
// assistidas pela ação social e os atendimentos. Dado sensível: só quem tem
// ministry_assist.view/.manage. Migration 20261008004300_ministerio_assistencia.

enum FamilyStatus {
  ativa('ativa', 'Ativa'),
  pausada('pausada', 'Pausada'),
  encerrada('encerrada', 'Encerrada');

  final String value;
  final String label;

  const FamilyStatus(this.value, this.label);

  static FamilyStatus fromValue(String? v) =>
      values.firstWhere((s) => s.value == v, orElse: () => ativa);
}

enum AssistanceKind {
  cesta('cesta', 'Cesta'),
  visita('visita', 'Visita'),
  outro('outro', 'Outro');

  final String value;
  final String label;

  const AssistanceKind(this.value, this.label);

  static AssistanceKind fromValue(String? v) =>
      values.firstWhere((k) => k.value == v, orElse: () => outro);
}

class AssistedFamily {
  final String id;

  /// `user_account.id` quando a família é de membro.
  final String? memberId;
  final String name;
  final String? phone;
  final String? address;
  final int? householdSize;
  final String? need;
  final FamilyStatus status;
  final String? notes;
  final DateTime updatedAt;

  const AssistedFamily({
    required this.id,
    this.memberId,
    required this.name,
    this.phone,
    this.address,
    this.householdSize,
    this.need,
    required this.status,
    this.notes,
    required this.updatedAt,
  });

  factory AssistedFamily.fromJson(Map<String, dynamic> j) => AssistedFamily(
    id: j['id'] as String,
    memberId: j['member_id'] as String?,
    name: j['name'] as String? ?? '',
    phone: j['phone'] as String?,
    address: j['address'] as String?,
    householdSize: (j['household_size'] as num?)?.toInt(),
    need: j['need'] as String?,
    status: FamilyStatus.fromValue(j['status'] as String?),
    notes: j['notes'] as String?,
    updatedAt: DateTime.parse(j['updated_at'] as String).toLocal(),
  );
}

class Assistance {
  final String id;
  final AssistanceKind kind;
  final DateTime happenedOn;
  final String? notes;
  final String? stockItemName;
  final double? quantity;

  const Assistance({
    required this.id,
    required this.kind,
    required this.happenedOn,
    this.notes,
    this.stockItemName,
    this.quantity,
  });

  factory Assistance.fromJson(Map<String, dynamic> j) {
    final item = j['ministry_stock_item'];
    return Assistance(
      id: j['id'] as String,
      kind: AssistanceKind.fromValue(j['kind'] as String?),
      happenedOn: DateTime.parse(j['happened_on'] as String),
      notes: j['notes'] as String?,
      stockItemName: item is Map ? item['name'] as String? : null,
      quantity: (j['quantity'] as num?)?.toDouble(),
    );
  }
}
