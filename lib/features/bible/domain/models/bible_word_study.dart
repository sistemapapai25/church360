/// Estudo palavra por palavra de uma palavra num versículo: junta a camada
/// "a palavra" (bible_word_study) com a camada "neste versículo"
/// (bible_word_study_occurrence). Formato das seções em
/// backend-scripts/lexico/MODELO-ESTUDO.md.
class BibleWordStudy {
  final int verseId;
  final String? palavraPt;
  final String titulo;
  final String language;
  final List<String> strongCodes;
  final String? palavraOriginal;
  final String? transliteracao;
  final String? raiz;
  final String? raizTransliteracao;

  /// Seções da palavra seguidas das seções do versículo, na ordem do padrão.
  final List<Map<String, dynamic>> secoes;

  const BibleWordStudy({
    required this.verseId,
    required this.titulo,
    required this.language,
    required this.strongCodes,
    required this.secoes,
    this.palavraPt,
    this.palavraOriginal,
    this.transliteracao,
    this.raiz,
    this.raizTransliteracao,
  });

  /// Linha de bible_word_study_occurrence com bible_word_study(*) embutido.
  factory BibleWordStudy.fromOccurrenceJson(Map<String, dynamic> json) {
    final study = json['bible_word_study'] as Map<String, dynamic>;
    List<Map<String, dynamic>> sections(dynamic raw) =>
        (raw as List? ?? const []).whereType<Map<String, dynamic>>().toList();
    return BibleWordStudy(
      verseId: json['verse_id'] as int,
      palavraPt: json['palavra_pt'] as String?,
      titulo: study['titulo'] as String,
      language: study['language'] as String,
      strongCodes: (study['strong_codes'] as List? ?? const []).cast<String>(),
      palavraOriginal: study['palavra_original'] as String?,
      transliteracao: study['transliteracao'] as String?,
      raiz: study['raiz'] as String?,
      raizTransliteracao: study['raiz_transliteracao'] as String?,
      secoes: [...sections(study['secoes']), ...sections(json['secoes'])],
    );
  }

  static String _strongRoot(String code) {
    final m = RegExp(r'^([HG])0*(\d+)', caseSensitive: false).firstMatch(code.trim());
    return m == null ? code.trim().toUpperCase() : '${m.group(1)!.toUpperCase()}${m.group(2)}';
  }

  /// O estudo vale para a palavra tocada se o Strong bate pela raiz
  /// (H5945G casa com H5945) ou se a palavra da ARC está em palavra_pt
  /// (só palavras de 4+ letras, para "e", "ao", "teu" não abrirem expressões).
  bool matches({required String strongCode, required String surface}) {
    final root = _strongRoot(strongCode);
    if (strongCodes.any((c) => _strongRoot(c) == root)) return true;
    final word = surface.toLowerCase().trim();
    if (word.length < 4 || palavraPt == null) return false;
    return palavraPt!.toLowerCase().split(RegExp(r'[^\p{L}\-]+', unicode: true)).contains(word);
  }
}
