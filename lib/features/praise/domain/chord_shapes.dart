import 'chord.dart';

/// Instrumento do painel do acorde. É preferência do aparelho, não vai para
/// música nem repertório (plano §12.4).
///
/// [tuning] = altura MIDI de cada corda solta, da mais grave à mais aguda na
/// ordem do desenho. `null` = teclado (sem braço).
enum PraiseInstrument {
  violao('Violão e guitarra', [40, 45, 50, 55, 59, 64]),
  teclado('Teclado', null),
  // Afinação reentrante (G4 C4 E4 A4): o baixo do acorde não é a 1ª corda.
  ukulele('Ukulele', [67, 60, 64, 69], bassFree: true),
  cavaco('Cavaco', [62, 67, 71, 74], bassFree: true),
  // Cebolão em E (B E G# B E), a mais comum; os pares tocam juntos.
  viola('Viola caipira', [47, 52, 56, 59, 64]);

  const PraiseInstrument(this.label, this.tuning, {this.bassFree = false});

  final String label;
  final List<int>? tuning;

  /// No ukulele e no cavaco ninguém procura o baixo na corda mais grave.
  final bool bassFree;
}

/// Notas do acorde em semitons (0 = C), o baixo primeiro e depois raiz,
/// terça, quinta e extensões. Lê as grafias da cifra brasileira: C9 = add9
/// (sem sétima), D4 = sus4, Bº = diminuto com sétima, 7M/7+ = sétima maior.
/// O que não reconhece no sufixo é ignorado: a tríade sempre sai.
List<int> chordTones(Chord c) {
  var s = c.suffix.replaceAll(RegExp(r'[()\s]'), ',').replaceAll('7+', '7M');
  int? third = 4;
  var fifth = 7;
  final ext = <int>[];

  if (RegExp(r'^(m(?!aj)|min)').hasMatch(s)) third = 3;
  if (RegExp(r'dim|º|°').hasMatch(s)) {
    third = 3;
    fifth = 6;
    ext.add(9);
  } else if (s.contains('ø')) {
    third = 3;
    fifth = 6;
    ext.add(10);
  }
  if (RegExp(r'aug|^\+').hasMatch(s)) fifth = 8;
  if (RegExp(r'maj7|7M|M7').hasMatch(s)) {
    ext.add(11);
    s = s.replaceAll(RegExp(r'maj7|7M|M7'), '');
  }
  if (s.contains('sus') && !RegExp(r'sus\d').hasMatch(s)) third = 5;

  for (final m in RegExp(r'([b#]?)(\d+)([+-]?)').allMatches(s)) {
    final acc = (m[1] == 'b' || m[3] == '-')
        ? -1
        : (m[1] == '#' || m[3] == '+')
        ? 1
        : 0;
    switch (int.parse(m[2]!)) {
      case 2:
        third = 2;
      case 4:
        third = 5;
      case 5:
        // Power chord (C5): sem terça.
        if (acc == 0 && s.replaceAll(',', '') == '5') third = null;
        fifth = 7 + acc;
      case 6:
        ext.add(9);
      case 7:
        if (!RegExp(r'dim|º|°').hasMatch(s)) ext.add(10);
      case 9:
        ext.add(2 + acc);
      case 11:
        ext.add(5 + acc);
      case 13:
        ext.add(9 + acc);
    }
  }

  final root = Chord.semitoneOf(c.root);
  final tones = <int>[
    if (c.bass != null) Chord.semitoneOf(c.bass!),
    root,
    if (third != null) (root + third) % 12,
    (root + fifth) % 12,
    for (final e in ext) (root + e) % 12,
  ];
  return [
    for (var i = 0; i < tones.length; i++)
      if (tones.indexOf(tones[i]) == i) tones[i],
  ];
}

/// Notas para mostrar ("G B D"). Intervalo menor/diminuto sai em bemol (C7 =
/// Bb, não A#), exceto em raiz com sustenido; o resto segue a grafia do tom.
String chordNoteNames(Chord c) {
  final root = Chord.semitoneOf(c.root);
  final minor = RegExp(r'^(m(?!aj)|min)').hasMatch(c.suffix);
  final keyFlats =
      c.root.endsWith('b') ||
      Chord.keyPrefersFlats('${c.root}${minor ? 'm' : ''}');
  final tones = chordTones(c);
  return [
    for (var i = 0; i < tones.length; i++)
      if (i == 0 && c.bass != null)
        c.bass!
      else if (tones[i] == root)
        c.root
      else
        Chord.noteName(
          tones[i],
          flats:
              keyFlats ||
              (!c.root.endsWith('#') &&
                  const {1, 3, 6, 8, 10}.contains((tones[i] - root) % 12)),
        ),
  ].join(' ');
}

/// Casa de cada corda (`null` = não tocar, 0 = solta), na ordem de
/// [PraiseInstrument.tuning]. `null` quando não acha desenho tocável.
///
/// Calculado em vez de tabelado: serve para qualquer afinação (é o que a B2.2
/// precisa) e para qualquer sufixo que [chordTones] leia. Procura janelas de 4
/// casas e fica com o desenho de menor custo: corda abafada pesa mais que
/// abrir a mão em 4 casas pesa mais que subir no braço, que pesa mais que
/// corda abafada ou dedo a mais.
List<int?>? fretShape(Chord c, PraiseInstrument instrument) =>
    _cache.putIfAbsent(
      '${instrument.name}|$c',
      () => _search(chordTones(c), Chord.semitoneOf(c.root), instrument),
    );

final _cache = <String, List<int?>?>{};

List<int?>? _search(List<int> tones, int root, PraiseInstrument instrument) {
  final tuning = instrument.tuning;
  if (tuning == null) return null;
  final bass = tones.first;
  // Com 4+ notas a quinta justa pode ficar de fora (é o que o músico faz).
  final optional = tones.length >= 4 ? {(root + 7) % 12} : <int>{};
  final required = tones.where((t) => !optional.contains(t)).toSet();
  final maxMuted = tuning.length >= 6 ? 2 : (tuning.length == 5 ? 1 : 0);

  List<int?>? best;
  var bestCost = double.infinity;

  for (var start = 1; start <= 10; start++) {
    final options = [
      for (final open in tuning)
        <int?>[
          null,
          for (var f = start == 1 ? 0 : start; f <= start + 3; f++)
            if (f == 0 || f >= start)
              if (tones.contains((open + f) % 12)) f,
        ],
    ];
    void walk(int i, List<int?> acc) {
      if (i < tuning.length) {
        for (final o in options[i]) {
          // Abafar só as cordas graves, em sequência a partir da primeira.
          if (o == null && (i >= maxMuted || (i > 0 && acc[i - 1] != null))) {
            continue;
          }
          walk(i + 1, [...acc, o]);
        }
        return;
      }
      final cost = _cost(acc, tuning, tones, required, bass, instrument);
      if (cost < bestCost) {
        bestCost = cost;
        best = acc;
      }
    }

    walk(0, []);
  }
  return best;
}

double _cost(
  List<int?> shape,
  List<int> tuning,
  List<int> tones,
  Set<int> required,
  int bass,
  PraiseInstrument instrument,
) {
  final sounding = [
    for (var i = 0; i < shape.length; i++)
      if (shape[i] != null) tuning[i] + shape[i]!,
  ];
  if (sounding.length < 3) return double.infinity;
  if (!required.every((t) => sounding.any((p) => p % 12 == t))) {
    return double.infinity;
  }
  final lowest = sounding.reduce((a, b) => a < b ? a : b);
  if (!instrument.bassFree && lowest % 12 != bass) return double.infinity;

  final fretted = [
    for (final f in shape)
      if (f != null && f > 0) f,
  ];
  final low = fretted.isEmpty ? 0 : fretted.reduce((a, b) => a < b ? a : b);
  final high = fretted.isEmpty ? 0 : fretted.reduce((a, b) => a > b ? a : b);
  // Pestana: a casa mais baixa em 2+ cordas sem corda solta no meio vira 1 dedo.
  final first = shape.indexWhere((f) => f == low);
  final last = shape.lastIndexWhere((f) => f == low);
  final barre =
      low > 0 &&
      last > first &&
      shape.sublist(first, last + 1).every((f) => f != null && f >= low);
  final fingers = barre
      ? 1 + fretted.where((f) => f > low).length
      : fretted.length;
  if (fingers > 4) return double.infinity;

  final muted = shape.where((f) => f == null).length;
  // Corda solta com a mão na 4ª casa ou acima é esticada estranha.
  final open = shape.where((f) => f == 0).length;
  // Abrir a mão em 4 casas é o que mais cansa; depois vem subir no braço.
  return muted * 1.5 +
      (high >= 4 ? open : 0) +
      low +
      (high - low) +
      (high - low >= 3 ? 3 : 0) +
      fingers * 0.5 +
      (lowest % 12 == bass ? 0 : 1);
}

/// Pestana do desenho (casa e cordas), para o diagrama desenhar a barra. Só
/// quando falta dedo (5+ notas presas): o D (xx0232) não leva pestana.
({int fret, int from, int to})? barreOf(List<int?> shape) {
  final fretted = [
    for (final f in shape)
      if (f != null && f > 0) f,
  ];
  if (fretted.length <= 4) return null;
  final low = fretted.reduce((a, b) => a < b ? a : b);
  final first = shape.indexWhere((f) => f == low);
  final last = shape.lastIndexWhere((f) => f == low);
  if (last == first) return null;
  final ok = shape.sublist(first, last + 1).every((f) => f != null && f >= low);
  return ok ? (fret: low, from: first, to: last) : null;
}
