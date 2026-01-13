class BibleLexeme {
  final int id;
  final String strongCode;
  final String language;
  final String? lemma;
  final String? transliteration;
  final String? ptGloss;
  final String? ptDefinition;

  const BibleLexeme({
    required this.id,
    required this.strongCode,
    required this.language,
    this.lemma,
    this.transliteration,
    this.ptGloss,
    this.ptDefinition,
  });

  factory BibleLexeme.fromJson(Map<String, dynamic> json) {
    return BibleLexeme(
      id: json['id'] as int,
      strongCode: json['strong_code'] as String,
      language: json['language'] as String,
      lemma: json['lemma'] as String?,
      transliteration: json['transliteration'] as String?,
      ptGloss: json['pt_gloss'] as String?,
      ptDefinition: json['pt_definition'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'strong_code': strongCode,
      'language': language,
      if (lemma != null) 'lemma': lemma,
      if (transliteration != null) 'transliteration': transliteration,
      if (ptGloss != null) 'pt_gloss': ptGloss,
      if (ptDefinition != null) 'pt_definition': ptDefinition,
    };
  }

  BibleLexeme copyWith({
    int? id,
    String? strongCode,
    String? language,
    String? lemma,
    String? transliteration,
    String? ptGloss,
    String? ptDefinition,
  }) {
    return BibleLexeme(
      id: id ?? this.id,
      strongCode: strongCode ?? this.strongCode,
      language: language ?? this.language,
      lemma: lemma ?? this.lemma,
      transliteration: transliteration ?? this.transliteration,
      ptGloss: ptGloss ?? this.ptGloss,
      ptDefinition: ptDefinition ?? this.ptDefinition,
    );
  }

  @override
  String toString() => 'BibleLexeme($strongCode)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BibleLexeme && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

