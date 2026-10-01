import 'chord.dart';
import 'chord_shapes.dart';

/// Pedaço de uma linha de cifra: acorde (opcional) sobre um trecho de letra.
/// `[G]Grande é o [D/F#]Senhor` → (G, "Grande é o "), (D/F#, "Senhor").
class ChordSegment {
  const ChordSegment(this.chord, this.lyric);
  final String? chord;
  final String lyric;
}

sealed class ChordProLine {
  const ChordProLine();
}

class LyricLine extends ChordProLine {
  const LyricLine(this.segments);
  final List<ChordSegment> segments;
}

/// `{name: value}`. Os apelidos do ChordPro já chegam normalizados:
/// soc → start_of_chorus, c → comment, t → title...
class DirectiveLine extends ChordProLine {
  const DirectiveLine(this.name, this.value);
  final String name;
  final String? value;
}

class EmptyLine extends ChordProLine {
  const EmptyLine();
}

class ChordProDocument {
  const ChordProDocument(this.lines);
  final List<ChordProLine> lines;

  /// Primeiro valor da diretiva (title, artist, key, capo, tempo...).
  String? meta(String name) {
    for (final l in lines) {
      if (l is DirectiveLine && l.name == name) return l.value;
    }
    return null;
  }
}

/// `{batida: D . D U . U D U}` → `['D', '.', 'D', 'U', '.', 'U', 'D', 'U']`.
/// D = ↓, U = ↑, `.` = colcheia sem ataque. Sem B/C de propósito: são nomes
/// de nota. O que não for D/U/. é ignorado.
List<String> parseStrum(String? value) => [
  for (final c in (value ?? '').toUpperCase().split(''))
    if (c == 'D' || c == 'U' || c == '.') c,
];

const _aliases = {
  't': 'title',
  'st': 'subtitle',
  'c': 'comment',
  'ci': 'comment_italic',
  'soc': 'start_of_chorus',
  'eoc': 'end_of_chorus',
  'sov': 'start_of_verse',
  'eov': 'end_of_verse',
  'sob': 'start_of_bridge',
  'eob': 'end_of_bridge',
  'sot': 'start_of_tab',
  'eot': 'end_of_tab',
};

final _directive = RegExp(r'^\{\s*([A-Za-z_]+)\s*(?::\s*(.*?))?\s*\}$');
final _chordTag = RegExp(r'\[([^\]]*)\]');

ChordProDocument parseChordPro(String source) {
  final lines = <ChordProLine>[];
  for (final raw in source.replaceAll('\r\n', '\n').split('\n')) {
    final line = raw.trimRight();
    if (line.trim().isEmpty) {
      lines.add(const EmptyLine());
      continue;
    }
    final d = _directive.firstMatch(line.trim());
    if (d != null) {
      final name = d[1]!.toLowerCase();
      final value = d[2];
      lines.add(
        DirectiveLine(
          _aliases[name] ?? name,
          (value == null || value.isEmpty) ? null : value,
        ),
      );
      continue;
    }
    lines.add(LyricLine(_segments(line)));
  }
  return ChordProDocument(lines);
}

List<ChordSegment> _segments(String line) {
  final out = <ChordSegment>[];
  var pos = 0;
  String? pending;
  for (final m in _chordTag.allMatches(line)) {
    if (m.start > pos || pending != null) {
      out.add(ChordSegment(pending, line.substring(pos, m.start)));
    }
    pending = m[1];
    pos = m.end;
  }
  if (pos < line.length || pending != null) {
    out.add(ChordSegment(pending, line.substring(pos)));
  }
  return out;
}

/// Transpõe todos os `[acordes]` do texto e a diretiva `{key:}`.
/// O resto (letra, diretivas, acordes que não parseiam) sai byte a byte igual.
/// A grafia segue o tom de destino quando a música declara `{key:}`.
String transposeChordPro(String source, int semitones) {
  if (semitones % 12 == 0) return source;
  final key = parseChordPro(source).meta('key');
  final keyChord = key == null ? null : Chord.tryParse(key);
  final newKey = keyChord?.transpose(semitones);
  final flats = newKey == null
      ? null
      : Chord.keyPrefersFlats(newKey.toString());
  final target = newKey?.transpose(0, preferFlats: flats).toString();

  return source
      .replaceAllMapped(_chordTag, (m) {
        final c = Chord.tryParse(m[1]!);
        return c == null
            ? m[0]!
            : '[${c.transpose(semitones, preferFlats: flats)}]';
      })
      .replaceAllMapped(
        RegExp(r'(\{\s*key\s*:\s*)([^}]*?)(\s*\})', caseSensitive: false),
        (m) => target == null ? m[0]! : '${m[1]}$target${m[3]}',
      );
}

/// Linha de leitor já alinhada: acordes em cima, letra embaixo, as duas com
/// a mesma largura em caracteres (o leitor usa fonte monoespaçada).
/// [chord] transforma cada acorde antes de medir (é onde entra o tom).
({String chords, String lyrics}) alignLyricLine(
  LyricLine line, [
  String Function(String chord)? chord,
]) {
  final top = StringBuffer();
  final bottom = StringBuffer();
  for (final s in line.segments) {
    final c = s.chord == null ? '' : (chord?.call(s.chord!) ?? s.chord!);
    // Acorde mais largo que a sílaba empurra a letra: sem isso o próximo
    // acorde colaria neste.
    final width = c.isEmpty
        ? s.lyric.length
        : (c.length + 1 > s.lyric.length ? c.length + 1 : s.lyric.length);
    top.write(c.padRight(width));
    bottom.write(s.lyric.padRight(width));
  }
  return (
    chords: top.toString().trimRight(),
    lyrics: bottom.toString().trimRight(),
  );
}

final _sectionLine = RegExp(r'^\s*\[([^\]]+)\]\s*$');
final _keyLine = RegExp(
  r'^\s*tom\s*:\s*([A-G][#b]?m?)\s*$',
  caseSensitive: false,
);

// Dentro de [colchetes] o sufixo é livre; para ADIVINHAR se uma linha solta
// é de acordes ele precisa parecer sufixo, senão "Aleluia" e "Deus" viram
// acorde (raiz A/D + sufixo qualquer).
final _strictSuffix = RegExp(
  r'^(?:maj|min|dim|aug|sus|add|m|M|º|°|\+|-|\d|\(|\)|#|b|,)*$',
);

bool _isChordLine(String line) {
  final tokens = line.trim().split(RegExp(r'\s+'));
  return line.trim().isNotEmpty &&
      tokens.every((t) {
        final c = Chord.tryParse(t);
        return c != null && _strictSuffix.hasMatch(c.suffix);
      });
}

/// Converte a cifra no formato "acordes em cima da letra" (o que se copia de
/// site de cifra) para ChordPro. Texto que já é ChordPro passa intacto.
///
/// - linha só de acordes + linha de letra → acordes inseridos na coluna certa;
/// - linha só de acordes sem letra embaixo → `[G] [D]` (intro, passagem);
/// - `[Refrão]`, `[Intro]` (rótulo que não é acorde) → `{comment: ...}`;
/// - `Tom: G` → `{key: G}`.
String chordsOverLyricsToChordPro(String source) {
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  // A batida e a correção por instrumento são inseridas pelo editor também
  // em cifra colada do site: sozinhas elas não fazem o texto ser ChordPro.
  bool isStrum(String l) {
    final name = _directive.firstMatch(l.trim())?[1]?.toLowerCase();
    return name == 'batida' || name == 'bateria' || _fixNames.contains(name);
  }

  if (lines.any((l) => _directive.hasMatch(l.trim()) && !isStrum(l))) {
    return source;
  }

  final out = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trimRight();
    if (isStrum(line)) {
      out.add(line.trim());
      continue;
    }

    final key = _keyLine.firstMatch(line);
    if (key != null) {
      out.add('{key: ${key[1]}}');
      continue;
    }
    final section = _sectionLine.firstMatch(line);
    if (section != null && Chord.tryParse(section[1]!) == null) {
      out.add('{comment: ${section[1]!.trim()}}');
      continue;
    }
    if (!_isChordLine(line)) {
      out.add(line);
      continue;
    }

    final chords = [
      for (final m in RegExp(r'\S+').allMatches(line)) (m.start, m[0]!),
    ];
    final next = i + 1 < lines.length ? lines[i + 1].trimRight() : '';
    if (next.trim().isEmpty ||
        _isChordLine(next) ||
        _directive.hasMatch(next.trim()) ||
        _sectionLine.hasMatch(next)) {
      out.add(chords.map((c) => '[${c.$2}]').join(' '));
      continue;
    }

    var lyric = next.padRight(chords.last.$1);
    for (final (col, c) in chords.reversed) {
      lyric = '${lyric.substring(0, col)}[$c]${lyric.substring(col)}';
    }
    out.add(lyric.trimRight());
    i++;
  }
  return out.join('\n');
}

/// Correção por instrumento (§9.5): `{baixo: G - F#}` logo abaixo de uma linha
/// troca os acordes dela, na ordem, só para quem lê com esse instrumento. `-`
/// (ou acorde a menos) mantém o gerado. É a "diferença" por cima do gerado; a
/// correção é salva como versão nova pelo editor, como qualquer edição.
final _fixNames = {for (final i in PraiseInstrument.pickable) i.name};

bool _isFix(String line) =>
    _fixNames.contains(_directive.firstMatch(line.trim())?[1]?.toLowerCase());

/// O texto como o [instrument] (`PraiseInstrument.chip.name`) lê: correções
/// dele aplicadas, as de todos os instrumentos removidas.
String forInstrument(String source, String instrument) {
  final out = <String>[];
  int? last; // linha com acordes logo acima
  for (final raw in source.replaceAll('\r\n', '\n').split('\n')) {
    if (_isFix(raw)) {
      final d = _directive.firstMatch(raw.trim())!;
      if (d[1]!.toLowerCase() == instrument && last != null) {
        final fix = (d[2] ?? '').trim().split(RegExp(r'\s+'));
        var i = 0;
        out[last] = out[last].replaceAllMapped(_chordTag, (m) {
          final t = i < fix.length ? fix[i] : '-';
          i++;
          return t == '-' || t.isEmpty ? m[0]! : '[$t]';
        });
      }
      continue;
    }
    last = !_directive.hasMatch(raw.trim()) && _chordTag.hasMatch(raw)
        ? out.length
        : null;
    out.add(raw);
  }
  return out.join('\n');
}

/// Onde o editor põe a correção da linha do cursor (fim da linha, depois das
/// correções que já existem) e os acordes dela, para começar preenchido.
/// Em cifra colada do site, linha de acordes vale pela letra de baixo.
({int offset, String chords}) instrumentFixAt(String text, int cursor) {
  final lines = text.split('\n');
  var start = 0;
  var i = 0;
  while (i < lines.length - 1 && start + lines[i].length < cursor) {
    start += lines[i].length + 1;
    i++;
  }
  var chords = [for (final m in _chordTag.allMatches(lines[i])) m[1]!];
  if (chords.isEmpty && _isChordLine(lines[i])) {
    chords = lines[i].trim().split(RegExp(r'\s+'));
    final next = i + 1 < lines.length ? lines[i + 1] : '';
    if (next.trim().isNotEmpty &&
        !_isChordLine(next) &&
        !_directive.hasMatch(next.trim()) &&
        !_sectionLine.hasMatch(next)) {
      start += lines[i].length + 1;
      i++;
    }
  }
  var end = start + lines[i].length;
  while (i + 1 < lines.length && _isFix(lines[i + 1])) {
    i++;
    end += lines[i].length + 1;
  }
  return (offset: end, chords: chords.join(' '));
}

/// Modo Simplificada: troca cada `[acorde]` pela tríade ([Chord.simplified]).
String simplifyChordPro(String source) =>
    source.replaceAllMapped(_chordTag, (m) {
      final c = Chord.tryParse(m[1]!);
      return c == null ? m[0]! : '[${c.simplified}]';
    });

const _sectionNames = {
  'start_of_chorus': 'Refrão',
  'start_of_verse': 'Verso',
  'start_of_bridge': 'Ponte',
  'start_of_tab': 'Tablatura',
};

/// Título de seção que o leitor desenha (`{comment: Intro}`, `{soc}`...).
/// Nulo = a diretiva não abre seção.
String? sectionLabel(DirectiveLine l) => l.name.startsWith('comment')
    ? l.value
    : (_sectionNames.containsKey(l.name)
          ? (l.value ?? _sectionNames[l.name])
          : null);

/// Seções na ordem do texto, para o player por seção: título, BPM próprio
/// (`{tempo: 64}` dentro dela) e quantas linhas de cifra/letra tem.
List<({String label, int? bpm, int lines})> chordProSections(
  ChordProDocument doc,
) {
  final out = <({String label, int? bpm, int lines})>[];
  for (final l in doc.lines) {
    if (l is DirectiveLine && sectionLabel(l) != null) {
      out.add((label: sectionLabel(l)!, bpm: null, lines: 0));
    } else if (out.isEmpty) {
      continue;
    } else if (l is DirectiveLine &&
        l.name == 'tempo' &&
        out.last.bpm == null) {
      out.last = (
        label: out.last.label,
        bpm: int.tryParse(l.value ?? ''),
        lines: out.last.lines,
      );
    } else if (l is LyricLine) {
      out.last = (
        label: out.last.label,
        bpm: out.last.bpm,
        lines: out.last.lines + 1,
      );
    }
  }
  return out;
}

/// Peças da grade de bateria, de cima para baixo como na partitura.
const drumVoices = {
  'prato': 'Prato',
  'chimbal': 'Chimbal',
  'caixa': 'Caixa',
  'bumbo': 'Bumbo',
};

/// `{bateria: chimbal x.x.x.x. | caixa ..x...x. | bumbo x...x...}` →
/// peça → toques (x = toca, `.` = não). Peça desconhecida é ignorada.
Map<String, List<bool>> parseDrums(String? value) {
  final out = <String, List<bool>>{};
  for (final part in (value ?? '').split('|')) {
    final m = RegExp(r'^\s*(\S+)\s+([xX.]+)\s*$').firstMatch(part);
    final voice = m?[1]?.toLowerCase();
    if (voice == null || !drumVoices.containsKey(voice)) continue;
    out[voice] = [for (final c in m![2]!.split('')) c != '.'];
  }
  return out;
}

/// O inverso de [parseDrums], na ordem de [drumVoices]; peça vazia sai.
String drumsToValue(Map<String, List<bool>> grid) => [
  for (final v in drumVoices.keys)
    if (grid[v]?.contains(true) ?? false)
      '$v ${grid[v]!.map((on) => on ? 'x' : '.').join()}',
].join(' | ');

const _accents = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
  'ñ': 'n',
};

/// Título para comparar (aviso de música repetida): sem acento, caixa,
/// pontuação nem espaço a mais. "Grande é o Senhor!" = "grande e o senhor".
String foldTitle(String s) => s
    .toLowerCase()
    .split('')
    .map((c) => _accents[c] ?? c)
    .join()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();
