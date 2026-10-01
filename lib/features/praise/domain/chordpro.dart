import 'chord.dart';

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
      lines.add(DirectiveLine(_aliases[name] ?? name, (value == null || value.isEmpty) ? null : value));
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
  final flats = newKey == null ? null : Chord.keyPrefersFlats(newKey.toString());
  final target = newKey?.transpose(0, preferFlats: flats).toString();

  return source
      .replaceAllMapped(_chordTag, (m) {
        final c = Chord.tryParse(m[1]!);
        return c == null ? m[0]! : '[${c.transpose(semitones, preferFlats: flats)}]';
      })
      .replaceAllMapped(
        RegExp(r'(\{\s*key\s*:\s*)([^}]*?)(\s*\})', caseSensitive: false),
        (m) => target == null ? m[0]! : '${m[1]}$target${m[3]}',
      );
}
