import 'bible_lexeme.dart';

class BibleVerseToken {
  final int id;
  final int verseId;
  final int tokenIndex;
  final int startOffset;
  final int endOffset;
  final String surface;
  final String? normalized;
  final int? lexemeId;
  final double? confidence;
  final String? source;
  final BibleLexeme? lexeme;

  const BibleVerseToken({
    required this.id,
    required this.verseId,
    required this.tokenIndex,
    required this.startOffset,
    required this.endOffset,
    required this.surface,
    this.normalized,
    this.lexemeId,
    this.confidence,
    this.source,
    this.lexeme,
  });

  factory BibleVerseToken.fromJson(Map<String, dynamic> json) {
    final lexemeJson = json['bible_lexeme'];
    return BibleVerseToken(
      id: json['id'] as int,
      verseId: json['verse_id'] as int,
      tokenIndex: json['token_index'] as int,
      startOffset: json['start_offset'] as int,
      endOffset: json['end_offset'] as int,
      surface: json['surface'] as String,
      normalized: json['normalized'] as String?,
      lexemeId: json['lexeme_id'] as int?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      source: json['source'] as String?,
      lexeme: lexemeJson is Map<String, dynamic> ? BibleLexeme.fromJson(lexemeJson) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'verse_id': verseId,
      'token_index': tokenIndex,
      'start_offset': startOffset,
      'end_offset': endOffset,
      'surface': surface,
      if (normalized != null) 'normalized': normalized,
      if (lexemeId != null) 'lexeme_id': lexemeId,
      if (confidence != null) 'confidence': confidence,
      if (source != null) 'source': source,
      if (lexeme != null) 'bible_lexeme': lexeme!.toJson(),
    };
  }

  BibleVerseToken copyWith({
    int? id,
    int? verseId,
    int? tokenIndex,
    int? startOffset,
    int? endOffset,
    String? surface,
    String? normalized,
    int? lexemeId,
    double? confidence,
    String? source,
    BibleLexeme? lexeme,
  }) {
    return BibleVerseToken(
      id: id ?? this.id,
      verseId: verseId ?? this.verseId,
      tokenIndex: tokenIndex ?? this.tokenIndex,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      surface: surface ?? this.surface,
      normalized: normalized ?? this.normalized,
      lexemeId: lexemeId ?? this.lexemeId,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      lexeme: lexeme ?? this.lexeme,
    );
  }

  @override
  String toString() => 'BibleVerseToken(verseId: $verseId, index: $tokenIndex)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BibleVerseToken && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

