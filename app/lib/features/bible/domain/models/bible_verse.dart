/// Modelo de Versículo da Bíblia
class BibleVerse {
  final int id;
  final int bookId;
  final int chapter;
  final int verse;
  final String text;

  // Campos opcionais para exibição
  final String? bookName;
  final String? bookAbbrev;

  const BibleVerse({
    required this.id,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.text,
    this.bookName,
    this.bookAbbrev,
  });

  // Referência completa do versículo (ex: "João 3:16")
  String get reference {
    final book = bookName ?? bookAbbrev ?? 'Livro $bookId';
    return '$book $chapter:$verse';
  }

  // Referência abreviada (ex: "Jo 3:16")
  String get shortReference {
    final book = bookAbbrev ?? bookName ?? 'Livro $bookId';
    return '$book $chapter:$verse';
  }

  // From JSON
  factory BibleVerse.fromJson(Map<String, dynamic> json) {
    return BibleVerse(
      id: json['id'] as int,
      bookId: json['book_id'] as int,
      chapter: json['chapter'] as int,
      verse: json['verse'] as int,
      text: json['text'] as String,
      bookName: json['book_name'] as String?,
      bookAbbrev: json['book_abbrev'] as String?,
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book_id': bookId,
      'chapter': chapter,
      'verse': verse,
      'text': text,
      if (bookName != null) 'book_name': bookName,
      if (bookAbbrev != null) 'book_abbrev': bookAbbrev,
    };
  }

  // Copy with
  BibleVerse copyWith({
    int? id,
    int? bookId,
    int? chapter,
    int? verse,
    String? text,
    String? bookName,
    String? bookAbbrev,
  }) {
    return BibleVerse(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapter: chapter ?? this.chapter,
      verse: verse ?? this.verse,
      text: text ?? this.text,
      bookName: bookName ?? this.bookName,
      bookAbbrev: bookAbbrev ?? this.bookAbbrev,
    );
  }

  @override
  String toString() => 'BibleVerse($reference: $text)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BibleVerse && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

