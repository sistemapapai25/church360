/// Model: Role (Cargo/Função)
/// Representa um cargo customizável no sistema
class Role {
  final String id;
  final String name;
  final String? description;
  final String? parentRoleId;
  final int hierarchyLevel;
  final bool allowsContext;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  const Role({
    required this.id,
    required this.name,
    this.description,
    this.parentRoleId,
    this.hierarchyLevel = 0,
    this.allowsContext = false,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      parentRoleId: json['parent_role_id'] as String?,
      hierarchyLevel: (json['hierarchy_level'] as int?) ?? 0,
      allowsContext: (json['allows_context'] as bool?) ?? false,
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
      'name': name,
      'description': description,
      'parent_role_id': parentRoleId,
      'hierarchy_level': hierarchyLevel,
      'allows_context': allowsContext,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
    };
  }

  Role copyWith({
    String? id,
    String? name,
    String? description,
    String? parentRoleId,
    int? hierarchyLevel,
    bool? allowsContext,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return Role(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      parentRoleId: parentRoleId ?? this.parentRoleId,
      hierarchyLevel: hierarchyLevel ?? this.hierarchyLevel,
      allowsContext: allowsContext ?? this.allowsContext,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

