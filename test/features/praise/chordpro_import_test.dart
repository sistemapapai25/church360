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

    test(
      'linha só de acordes vira passagem; rótulo vira comentário; tom vira key',
      () {
        const src = 'Tom: G\n[Intro]\nG  C  D\n\n[Refrão]\nEm   C\nSanto santo';
        expect(
          chordsOverLyricsToChordPro(src),
          '{key: G}\n{comment: Intro}\n[G] [C] [D]\n\n{comment: Refrão}\n[Em]Santo[C] santo',
        );
      },
    );

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

  test('batida: só D, U e ponto', () {
    expect(parseStrum('D . d U . U D U'), [
      'D',
      '.',
      'D',
      'U',
      '.',
      'U',
      'D',
      'U',
    ]);
    expect(parseStrum('B C D'), ['D']);
    expect(parseStrum(null), isEmpty);
  });

  test('batida inserida não impede a conversão da cifra colada', () {
    const pasted = '{batida: D . U}\nG     D\nSanto santo';
    final out = chordsOverLyricsToChordPro(pasted);
    expect(out, '{batida: D . U}\n[G]Santo [D]santo');
  });

  group('correção por instrumento', () {
    const src =
        '[G]Grande é o [D/F#]Senhor\n{baixo: - F#}\n{teclado: G7}\n'
        '[C]Santo [D]santo';

    test('troca só para o instrumento, na ordem; - mantém', () {
      expect(
        forInstrument(src, 'baixo'),
        '[G]Grande é o [F#]Senhor\n[C]Santo [D]santo',
      );
      expect(
        forInstrument(src, 'teclado'),
        '[G7]Grande é o [D/F#]Senhor\n[C]Santo [D]santo',
      );
      expect(
        forInstrument(src, 'violao'),
        '[G]Grande é o [D/F#]Senhor\n[C]Santo [D]santo',
      );
    });

    test('correção solta (sem linha de acordes acima) é ignorada', () {
      expect(
        forInstrument('{comment: Intro}\n{baixo: E}', 'baixo'),
        '{comment: Intro}',
      );
    });

    test('editor: insere no fim da linha, depois das correções', () {
      final at = instrumentFixAt(src, 3);
      expect(at.chords, 'G D/F#');
      expect(at.offset, src.indexOf('\n[C]'));
    });

    test('cifra colada: linha de acordes vale pela letra de baixo', () {
      const pasted = 'G          D/F#\nGrande é o Senhor\nC';
      final at = instrumentFixAt(pasted, 0);
      expect(at.chords, 'G D/F#');
      expect(at.offset, pasted.indexOf('\nC'));
      final withFix = pasted.replaceRange(at.offset, at.offset, '\n{baixo: E}');
      expect(
        chordsOverLyricsToChordPro(withFix),
        '[G]Grande é o [D/F#]Senhor\n{baixo: E}\n[C]',
      );
    });

    test('acordes sem letra antes de diretiva não engolem a diretiva', () {
      expect(
        chordsOverLyricsToChordPro('G  C\n{batida: D U}'),
        '[G] [C]\n{batida: D U}',
      );
    });
  });

  test('Simplificada: só a tríade, sem baixo', () {
    expect(
      simplifyChordPro('[C7M]a [Am7]b [G/B]c [Bm7(b5)]d [Dsus4]e'),
      '[C]a [Am]b [G]c [Bm]d [D]e',
    );
  });
}
