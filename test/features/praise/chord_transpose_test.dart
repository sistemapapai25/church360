import 'package:church360_app/features/praise/domain/chord.dart';
import 'package:church360_app/features/praise/domain/chordpro.dart';
import 'package:flutter_test/flutter_test.dart';

String t(String chord, int semitones, {bool? flats}) =>
    Chord.tryParse(chord)!.transpose(semitones, preferFlats: flats).toString();

void main() {
  group('Chord.transpose (suíte de aceite da Fase A)', () {
    test('C→C#, B→C, F#→G, Bb→B', () {
      expect(t('C', 1), 'C#');
      expect(t('B', 1), 'C');
      expect(t('F#', 1), 'G');
      expect(t('Bb', 1), 'B');
    });

    test('sufixo sai intacto: menor, sétima, maj7, sus, add', () {
      expect(t('Am', 2), 'Bm');
      expect(t('E7', 2), 'F#7');
      expect(t('Cmaj7', 5), 'Fmaj7');
      expect(t('Dsus4', 2), 'Esus4');
      expect(t('Gadd9', -2), 'Fadd9');
      expect(t('C7M', 2), 'D7M');
      expect(t('A(9)', 2), 'B(9)');
    });

    test('baixo invertido transpõe junto', () {
      expect(t('G/B', 2), 'A/C#');
      expect(t('D/F#', 2), 'E/G#');
      expect(t('Bb/D', 2, flats: true), 'C/E');
    });

    test('ida e volta G→A→G', () {
      for (final c in ['G', 'Em', 'C', 'D/F#', 'Bm7', 'Cadd9']) {
        expect(t(t(c, 2), -2), c, reason: c);
      }
    });

    test('grafia: estilo do acorde sem dica, tom de destino com dica', () {
      expect(t('Bb', 3), 'Db');
      expect(t('A', 1), 'A#');
      expect(t('A', 1, flats: true), 'Bb');
    });

    test('não-acorde não parseia', () {
      expect(Chord.tryParse('N.C.'), isNull);
      expect(Chord.tryParse('x2'), isNull);
      expect(Chord.tryParse(''), isNull);
    });

    test('tom de destino decide bemol pelo semitom', () {
      expect(Chord.keyPrefersFlats('Bb'), isTrue);
      expect(Chord.keyPrefersFlats('A#'), isTrue);
      expect(Chord.keyPrefersFlats('Dm'), isTrue);
      expect(Chord.keyPrefersFlats('D'), isFalse);
      expect(Chord.keyPrefersFlats('F#'), isFalse);
      expect(Chord.interval('G', 'A'), 2);
      expect(Chord.interval('A', 'G'), 10);
    });
  });

  group('parseChordPro', () {
    const song = '''
{title: Grande é o Senhor}
{key: G}
{soc}
[G]Grande é o [D/F#]Senhor
sem acorde
[Em]
{eoc}
''';

    test('diretivas, apelidos e meta', () {
      final doc = parseChordPro(song);
      expect(doc.meta('title'), 'Grande é o Senhor');
      expect(doc.meta('key'), 'G');
      final names = doc.lines.whereType<DirectiveLine>().map((d) => d.name);
      expect(names, containsAll(['start_of_chorus', 'end_of_chorus']));
    });

    test('segmentos: acorde sobre trecho de letra', () {
      final lyric = parseChordPro(song).lines.whereType<LyricLine>().toList();
      final first = lyric[0].segments;
      expect(first.map((s) => s.chord), ['G', 'D/F#']);
      expect(first.map((s) => s.lyric), ['Grande é o ', 'Senhor']);
      expect(lyric[1].segments.single.chord, isNull);
      expect(lyric[2].segments.single.chord, 'Em');
      expect(lyric[2].segments.single.lyric, '');
    });

    test('letra antes do primeiro acorde vira segmento sem acorde', () {
      final seg = (parseChordPro('Oh [C]vem').lines.single as LyricLine).segments;
      expect(seg.map((s) => s.chord), [null, 'C']);
      expect(seg.map((s) => s.lyric), ['Oh ', 'vem']);
    });
  });

  group('transposeChordPro', () {
    test('G→A transpõe acordes e a diretiva key, letra intacta', () {
      const src = '{key: G}\n[G]Santo [D/F#]santo [N.C.]';
      expect(transposeChordPro(src, 2), '{key: A}\n[A]Santo [E/G#]santo [N.C.]');
    });

    test('destino em tom de bemol escreve bemol (G+3 = Bb)', () {
      const src = '{key: G}\n[G] [D/F#] [C]';
      expect(transposeChordPro(src, 3), '{key: Bb}\n[Bb] [F/A] [Eb]');
    });

    test('ida e volta no documento', () {
      const src = '{key: D}\n[D]Eu [A/C#]te [Bm7]louvo [G]';
      expect(transposeChordPro(transposeChordPro(src, 2), -2), src);
    });
  });
}
