/// Acorde de cifra: raiz + sufixo (verbatim) + baixo opcional.
///
/// O sufixo (m, 7, maj7, sus4, add9, 7M, (9), º...) nunca é interpretado:
/// transpor mexe só na raiz e no baixo, então qualquer grafia que a igreja
/// use sobrevive intacta.
class Chord {
  const Chord(this.root, this.suffix, [this.bass]);

  final String root;
  final String suffix;
  final String? bass;

  static final _pattern = RegExp(r'^([A-G][#b]?)([^/]*)(?:/([A-G][#b]?))?$');

  static const _sharps = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];
  static const _flats = [
    'C',
    'Db',
    'D',
    'Eb',
    'E',
    'F',
    'Gb',
    'G',
    'Ab',
    'A',
    'Bb',
    'B',
  ];

  /// Tons escritos com bemol, por semitom: maiores F Bb Eb Ab Db e menores
  /// Dm Gm Cm Fm Bbm Ebm. F#/Gb fica em sustenido (F# é o usual em louvor).
  static const _flatMajor = {5, 10, 3, 8, 1};
  static const _flatMinor = {2, 7, 0, 5, 10, 3};

  /// `null` quando o texto não é acorde (ex.: "N.C.", "x2").
  static Chord? tryParse(String text) {
    final m = _pattern.firstMatch(text.trim());
    if (m == null) return null;
    return Chord(m[1]!, m[2]!, m[3]);
  }

  static const _naturals = {
    'C': 0,
    'D': 2,
    'E': 4,
    'F': 5,
    'G': 7,
    'A': 9,
    'B': 11,
  };

  /// Natural + acidente, então E#, B#, Cb e Fb também resolvem.
  static int semitoneOf(String note) {
    final acc = note.length > 1 ? (note[1] == '#' ? 1 : -1) : 0;
    return (_naturals[note[0]]! + acc) % 12;
  }

  static String _shift(String note, int semitones, bool flats) =>
      (flats ? _flats : _sharps)[(semitoneOf(note) + semitones) % 12];

  /// Distância em semitons (0..11) de um tom para outro. "G" → "A" = 2.
  static int interval(String fromKey, String toKey) =>
      (semitoneOf(Chord.tryParse(toKey)!.root) -
          semitoneOf(Chord.tryParse(fromKey)!.root)) %
      12;

  /// O tom de destino decide a grafia: Bb pede bemol, D pede sustenido.
  static bool keyPrefersFlats(String key) {
    final k = Chord.tryParse(key);
    if (k == null) return false;
    final s = semitoneOf(k.root);
    return k.suffix == 'm' ? _flatMinor.contains(s) : _flatMajor.contains(s);
  }

  /// Tom deslocado, já na grafia que o tom de destino pede ("G" +3 = "Bb").
  /// `null` quando [key] não é tom.
  static String? shiftKey(String key, int semitones) {
    final shifted = Chord.tryParse(key)?.transpose(semitones);
    if (shifted == null) return null;
    return shifted
        .transpose(0, preferFlats: keyPrefersFlats(shifted.toString()))
        .toString();
  }

  /// Sem [preferFlats], mantém o estilo do próprio acorde (Bb+3 = Db).
  Chord transpose(int semitones, {bool? preferFlats}) {
    final flats = preferFlats ?? root.endsWith('b');
    return Chord(
      _shift(root, semitones, flats),
      suffix,
      bass == null ? null : _shift(bass!, semitones, flats),
    );
  }

  @override
  String toString() => bass == null ? '$root$suffix' : '$root$suffix/$bass';
}
