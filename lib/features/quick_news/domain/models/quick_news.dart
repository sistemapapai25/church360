/// Model para Avisos Rápidos (Fique por Dentro)
class QuickNews {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String? linkUrl;
  final int priority;
  final bool isActive;
  final DateTime? expiresAt;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  QuickNews({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    this.linkUrl,
    required this.priority,
    required this.isActive,
    this.expiresAt,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  // Helper: Está expirado?
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  // Helper: Está ativo e não expirado?
  bool get isVisible {
    return isActive && !isExpired;
  }

  // From JSON
  factory QuickNews.fromJson(Map<String, dynamic> json) {
    return QuickNews(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['image_url'] as String?,
      linkUrl: json['link_url'] as String?,
      priority: json['priority'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'link_url': linkUrl,
      'priority': priority,
      'is_active': isActive,
      'expires_at': expiresAt?.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // CopyWith
  QuickNews copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    String? linkUrl,
    int? priority,
    bool? isActive,
    DateTime? expiresAt,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuickNews(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      linkUrl: linkUrl ?? this.linkUrl,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      expiresAt: expiresAt ?? this.expiresAt,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

