/// Modelo de Banner da Home
/// Representa um banner exibido na tela inicial do app
class HomeBanner {
  final String id;
  final String title;
  final String? description;
  final String imageUrl;
  final String? linkUrl; // URL externa (quando linkType = 'external')
  final String linkType; // 'external', 'event', 'reading_plan', 'course', 'message'
  final String? linkedId; // ID do registro vinculado
  final int orderIndex;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  HomeBanner({
    required this.id,
    required this.title,
    this.description,
    required this.imageUrl,
    this.linkUrl,
    this.linkType = 'external',
    this.linkedId,
    required this.orderIndex,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  /// Criar a partir de JSON do Supabase
  factory HomeBanner.fromJson(Map<String, dynamic> json) {
    return HomeBanner(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String,
      linkUrl: json['link_url'] as String?,
      linkType: json['link_type'] as String? ?? 'external',
      linkedId: json['linked_id'] as String?,
      orderIndex: json['order_index'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'link_url': linkUrl,
      'link_type': linkType,
      'linked_id': linkedId,
      'order_index': orderIndex,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Copiar com modificações
  HomeBanner copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    String? linkUrl,
    String? linkType,
    String? linkedId,
    int? orderIndex,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HomeBanner(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      linkUrl: linkUrl ?? this.linkUrl,
      linkType: linkType ?? this.linkType,
      linkedId: linkedId ?? this.linkedId,
      orderIndex: orderIndex ?? this.orderIndex,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Obter texto descritivo do tipo de vínculo
  String get linkTypeText {
    switch (linkType) {
      case 'event':
        return 'Evento';
      case 'reading_plan':
        return 'Plano de Leitura';
      case 'course':
        return 'Curso';
      case 'message':
        return 'Palavra/Mensagem';
      case 'external':
      default:
        return 'Link Externo';
    }
  }

  /// Verificar se tem vínculo interno
  bool get hasInternalLink => linkType != 'external' && linkedId != null;
}

