/// Modelo de Favorito/Marcador da Bíblia
class BibleBookmark {
  final String id;
  final String memberId;
  final int verseId;
  final String? note;
  final DateTime createdAt;

  // Campos opcionais para exibição
  final String? verseText;
  final String? verseReference;

  const BibleBookmark({
    required this.id,
    required this.memberId,
    required this.verseId,
    this.note,
    required this.createdAt,
    this.verseText,
    this.verseReference,
  });

  // From JSON
  factory BibleBookmark.fromJson(Map<String, dynamic> json) {
    return BibleBookmark(
      id: json['id'] as String,
      memberId: json['user_id'] as String,
      verseId: json['verse_id'] as int,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      verseText: json['verse_text'] as String?,
      verseReference: json['verse_reference'] as String?,
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': memberId,
      'verse_id': verseId,
      if (note != null) 'note': note,
      'created_at': createdAt.toIso8601String(),
      if (verseText != null) 'verse_text': verseText,
      if (verseReference != null) 'verse_reference': verseReference,
    };
  }

  // Copy with
  BibleBookmark copyWith({
    String? id,
    String? memberId,
    int? verseId,
    String? note,
    DateTime? createdAt,
    String? verseText,
    String? verseReference,
  }) {
    return BibleBookmark(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      verseId: verseId ?? this.verseId,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      verseText: verseText ?? this.verseText,
      verseReference: verseReference ?? this.verseReference,
    );
  }

  @override
  String toString() => 'BibleBookmark(id: $id, verseId: $verseId, reference: $verseReference)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BibleBookmark && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
