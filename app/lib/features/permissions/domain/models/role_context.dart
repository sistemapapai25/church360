/// Model: RoleContext (Contexto do Cargo)
/// Representa um contexto específico para um cargo
/// Ex: "Casa de Oração - Dona Joana", "Hospital Santa Casa"
class RoleContext {
  final String id;
  final String roleId;
  final String contextName;
  final String? description;
  final Map<String, dynamic>? metadata;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  const RoleContext({
    required this.id,
    required this.roleId,
    required this.contextName,
    this.description,
    this.metadata,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  factory RoleContext.fromJson(Map<String, dynamic> json) {
    return RoleContext(
      id: json['id'] as String,
      roleId: json['role_id'] as String,
      contextName: json['context_name'] as String,
      description: json['description'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role_id': roleId,
      'context_name': contextName,
      'description': description,
      'metadata': metadata,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
    };
  }

  RoleContext copyWith({
    String? id,
    String? roleId,
    String? contextName,
    String? description,
    Map<String, dynamic>? metadata,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return RoleContext(
      id: id ?? this.id,
      roleId: roleId ?? this.roleId,
      contextName: contextName ?? this.contextName,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

