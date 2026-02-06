// =====================================================
// CHURCH 360 - FINANCIAL MODELS: BENEFICIARIO
// =====================================================

/// Model: Beneficiário
class Beneficiario {
  final String id;
  final String name;
  final String? documento;
  final String? phone;
  final String? email;
  final String? observacoes;
  final String? assinaturaPath;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final String tenantId;
  final String? createdBy;

  const Beneficiario({
    required this.id,
    required this.name,
    this.documento,
    this.phone,
    this.email,
    this.observacoes,
    this.assinaturaPath,
    this.deletedAt,
    required this.createdAt,
    required this.tenantId,
    this.createdBy,
  });

  factory Beneficiario.fromJson(Map<String, dynamic> json) {
    return Beneficiario(
      id: json['id'] as String,
      name: json['name'] as String,
      documento: json['documento'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      observacoes: json['observacoes'] as String?,
      assinaturaPath: json['assinatura_path'] as String?,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      tenantId: json['tenant_id'] as String,
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'documento': documento,
      'phone': phone,
      'email': email,
      'observacoes': observacoes,
      'assinatura_path': assinaturaPath,
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'tenant_id': tenantId,
      'created_by': createdBy,
    };
  }

  Beneficiario copyWith({
    String? id,
    String? name,
    String? documento,
    String? phone,
    String? email,
    String? observacoes,
    String? assinaturaPath,
    DateTime? deletedAt,
    DateTime? createdAt,
    String? tenantId,
    String? createdBy,
  }) {
    return Beneficiario(
      id: id ?? this.id,
      name: name ?? this.name,
      documento: documento ?? this.documento,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      observacoes: observacoes ?? this.observacoes,
      assinaturaPath: assinaturaPath ?? this.assinaturaPath,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      tenantId: tenantId ?? this.tenantId,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  // Propriedades computadas
  bool get isAtivo => deletedAt == null;
  bool get hasAssinatura => assinaturaPath != null && assinaturaPath!.isNotEmpty;
  bool get hasDocumento => documento != null && documento!.isNotEmpty;
  bool get hasEmail => email != null && email!.isNotEmpty;
  bool get hasPhone => phone != null && phone!.isNotEmpty;
}

