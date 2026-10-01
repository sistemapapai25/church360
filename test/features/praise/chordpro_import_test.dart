import 'package:church360_app/features/praise/domain/chord.dart';
import 'package:church360_app/features/praise/domain/chordpro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chordsOverLyricsToChordPro', () {
    test('acorde vai para a coluna certa da letra', () {
      const src = 'G          D/F#\nGrande é o Senhor';
      expect(chordsOverLyricsToChordPro(src), '[G]Grande é o [D/F#]Senhor');
    });

    test('acorde depois do fim da letra estica a linha', () {
      const src = 'C        G\nAleluia';
      expect(chordsOverLyricsToChordPro(src), '[C]Aleluia  [G]');
    });

    test('linha só de acordes vira passagem; rótulo vira comentário; tom vira key', () {
      const src = 'Tom: G\n[Intro]\nG  C  D\n\n[Refrão]\nEm   C\nSanto santo';
      expect(
        chordsOverLyricsToChordPro(src),
        '{key: G}\n{comment: Intro}\n[G] [C] [D]\n\n{comment: Refrão}\n[Em]Santo[C] santo',
      );
    });

    test('letra sem acorde e ChordPro já pronto passam intactos', () {
      expect(chordsOverLyricsToChordPro('só letra\noutra'), 'só letra\noutra');
      // palavra que começa com A–G não é acorde
      expect(chordsOverLyricsToChordPro('Deus\nAleluia'), 'Deus\nAleluia');
      const pro = '{title: X}\n[G]Teste';
      expect(chordsOverLyricsToChordPro(pro), pro);
    });
  });

  group('alignLyricLine', () {
    LyricLine line(String s) => parseChordPro(s).lines.single as LyricLine;

    test('acorde em cima da sílaba, mesma largura', () {
      final a = alignLyricLine(line('[G]Grande é o [D/F#]Senhor'));
      expect(a.chords, 'G          D/F#');
      expect(a.lyrics, 'Grande é o Senhor');
    });

    test('acorde mais largo que a sílaba empurra a letra', () {
      final a = alignLyricLine(line('[Cmaj7]a[G]b'));
      expect(a.chords, 'Cmaj7 G');
      expect(a.lyrics, 'a     b');
    });

    test('aplica a transformação de tom antes de medir', () {
      final a = alignLyricLine(
        line('[G]Santo [D/F#]santo'),
        (c) => Chord.tryParse(c)?.transpose(2).toString() ?? c,
      );
      expect(a.chords, 'A     E/G#');
    });

    test('ida e volta: importar e alinhar devolve a cifra colada', () {
      const colada = 'G          D/F#\nGrande é o Senhor';
      final a = alignLyricLine(line(chordsOverLyricsToChordPro(colada)));
      expect('${a.chords}\n${a.lyrics}', colada);
    });
  });
}
