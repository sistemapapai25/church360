/// Enum para tipo de vinculação
enum MaterialLinkType {
  communionGroup('communion_group', 'Grupo de Comunhão'),
  course('course', 'Curso'),
  event('event', 'Evento'),
  ministry('ministry', 'Ministério'),
  studyGroup('study_group', 'Grupo de Estudo'),
  general('general', 'Geral');

  final String value;
  final String label;

  const MaterialLinkType(this.value, this.label);

  static MaterialLinkType fromString(String value) {
    return MaterialLinkType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MaterialLinkType.general,
    );
  }
}

/// Modelo de Vinculação de Material
class SupportMaterialLink {
  final String id;
  final String materialId;
  final MaterialLinkType linkType;
  final String linkedEntityId;
  final DateTime createdAt;
  final String? createdBy;

  SupportMaterialLink({
    required this.id,
    required this.materialId,
    required this.linkType,
    required this.linkedEntityId,
    required this.createdAt,
    this.createdBy,
  });

  /// Criar a partir de JSON
  factory SupportMaterialLink.fromJson(Map<String, dynamic> json) {
    return SupportMaterialLink(
      id: json['id'] as String,
      materialId: json['material_id'] as String,
      linkType: MaterialLinkType.fromString(json['link_type'] as String),
      linkedEntityId: json['linked_entity_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'material_id': materialId,
      'link_type': linkType.value,
      'linked_entity_id': linkedEntityId,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }

  /// Copiar com alterações
  SupportMaterialLink copyWith({
    String? id,
    String? materialId,
    MaterialLinkType? linkType,
    String? linkedEntityId,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return SupportMaterialLink(
      id: id ?? this.id,
      materialId: materialId ?? this.materialId,
      linkType: linkType ?? this.linkType,
      linkedEntityId: linkedEntityId ?? this.linkedEntityId,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

