/// Modelo de Livro da Bíblia
class BibleBook {
  final int id;
  final String name;
  final String abbrev;
  final String testament; // 'OT' (Old Testament) ou 'NT' (New Testament)
  final int orderNumber;
  final int chapters;

  const BibleBook({
    required this.id,
    required this.name,
    required this.abbrev,
    required this.testament,
    required this.orderNumber,
    required this.chapters,
  });

  // Computed properties
  bool get isOldTestament => testament == 'OT';
  bool get isNewTestament => testament == 'NT';

  String get testamentName => isOldTestament ? 'Antigo Testamento' : 'Novo Testamento';

  // From JSON
  factory BibleBook.fromJson(Map<String, dynamic> json) {
    return BibleBook(
      id: json['id'] as int,
      name: json['name'] as String,
      abbrev: json['abbrev'] as String,
      testament: json['testament'] as String,
      orderNumber: json['order_number'] as int,
      chapters: json['chapters'] as int,
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'abbrev': abbrev,
      'testament': testament,
      'order_number': orderNumber,
      'chapters': chapters,
    };
  }

  @override
  String toString() => 'BibleBook(id: $id, name: $name, abbrev: $abbrev, testament: $testament)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BibleBook && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

