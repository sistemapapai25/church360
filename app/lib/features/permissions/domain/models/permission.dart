/// Model: Permission (Permissão)
/// Representa uma permissão do sistema
class Permission {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String category;
  final String? subcategory;
  final bool isActive;
  final bool requiresContext;
  final DateTime? createdAt;

  const Permission({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.category,
    this.subcategory,
    this.isActive = true,
    this.requiresContext = false,
    this.createdAt,
  });

  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      subcategory: json['subcategory'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      requiresContext: (json['requires_context'] as bool?) ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'category': category,
      'subcategory': subcategory,
      'is_active': isActive,
      'requires_context': requiresContext,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Permission copyWith({
    String? id,
    String? code,
    String? name,
    String? description,
    String? category,
    String? subcategory,
    bool? isActive,
    bool? requiresContext,
    DateTime? createdAt,
  }) {
    return Permission(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      isActive: isActive ?? this.isActive,
      requiresContext: requiresContext ?? this.requiresContext,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

