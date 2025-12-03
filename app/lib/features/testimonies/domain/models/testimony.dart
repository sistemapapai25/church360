/// Model para Testemunhos
class Testimony {
  final String id;
  final String title;
  final String description;
  final String authorId;
  final bool isPublic;
  final bool allowWhatsappContact;
  final DateTime createdAt;
  final DateTime updatedAt;

  Testimony({
    required this.id,
    required this.title,
    required this.description,
    required this.authorId,
    required this.isPublic,
    required this.allowWhatsappContact,
    required this.createdAt,
    required this.updatedAt,
  });

  // From JSON
  factory Testimony.fromJson(Map<String, dynamic> json) {
    return Testimony(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      authorId: json['author_id'] as String,
      isPublic: json['is_public'] as bool,
      allowWhatsappContact: json['allow_whatsapp_contact'] as bool,
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
      'author_id': authorId,
      'is_public': isPublic,
      'allow_whatsapp_contact': allowWhatsappContact,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // CopyWith
  Testimony copyWith({
    String? id,
    String? title,
    String? description,
    String? authorId,
    bool? isPublic,
    bool? allowWhatsappContact,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Testimony(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      authorId: authorId ?? this.authorId,
      isPublic: isPublic ?? this.isPublic,
      allowWhatsappContact: allowWhatsappContact ?? this.allowWhatsappContact,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
