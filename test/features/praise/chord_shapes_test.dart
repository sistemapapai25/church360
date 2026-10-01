import 'package:church360_app/features/praise/domain/chord.dart';
import 'package:church360_app/features/praise/domain/chord_shapes.dart';
import 'package:flutter_test/flutter_test.dart';

String _notes(String c) => chordNoteNames(Chord.tryParse(c)!);

String _shape(String c, [PraiseInstrument i = PraiseInstrument.violao]) =>
    fretShape(Chord.tryParse(c)!, i)?.map((f) => f ?? 'x').join() ?? '-';

void main() {
  test('notas do acorde pela grafia brasileira', () {
    expect(_notes('G'), 'G B D');
    expect(_notes('Am'), 'A C E');
    expect(_notes('D/F#'), 'F# D A');
    expect(_notes('C9'), 'C E G D'); // add9, sem sétima
    expect(_notes('E7'), 'E G# B D');
    expect(_notes('C7'), 'C E G Bb');
    expect(_notes('Cm'), 'C Eb G');
    expect(_notes('C#m7'), 'C# E G# B');
    expect(_notes('C7M'), 'C E G B');
    expect(_notes('D4'), 'D G A'); // sus4
    expect(_notes('Bm7(b5)'), 'B D F A');
    expect(_notes('Bb'), 'Bb D F');
    expect(_notes('Fm'), 'F Ab C');
    expect(_notes('A7(9-)'), 'A C# E G Bb');
  });

  test('desenhos de violão dos acordes abertos', () {
    expect(_shape('C'), 'x32010');
    expect(_shape('Am'), 'x02210');
    expect(_shape('E'), '022100');
    expect(_shape('Em'), '022000');
    expect(_shape('F'), '133211');
    expect(_shape('D/F#'), '200232'); // A solta também é nota do acorde
    expect(_shape('Bm'), 'x24432');
    for (final c in ['G', 'D', 'A', 'B7', 'C#m', 'Ab', 'Bb', 'F#m7', 'G/B']) {
      expect(_shape(c), isNot('-'), reason: c);
    }
  });

  test('pestana só quando falta dedo', () {
    List<int?> shape(String c) =>
        fretShape(Chord.tryParse(c)!, PraiseInstrument.violao)!;
    expect(barreOf(shape('F')), (fret: 1, from: 0, to: 5));
    expect(barreOf(shape('Bm')), isNotNull);
    expect(barreOf(shape('D')), isNull);
    expect(barreOf(shape('C')), isNull);
  });

  test('baixo: só a nota do baixo, na primeira posição', () {
    const b4 = PraiseInstrument.baixo, b5 = PraiseInstrument.baixo5;
    expect(_shape('E', b4), '0xxx');
    expect(_shape('G', b4), '3xxx');
    expect(_shape('Am7', b4), 'x0xx');
    expect(_shape('C', b4), 'x3xx');
    expect(_shape('D/F#', b4), '2xxx'); // a nota depois da barra
    expect(_shape('D', b4), 'xx0x');
    expect(_shape('Bb', b4), 'x1xx');
    // A corda Si deixa o D e o C mais graves.
    expect(_shape('D', b5), '3xxxx');
    expect(_shape('C', b5), '1xxxx');
    expect(_shape('G', b5), 'x3xxx');
    for (final c in ['C#m', 'Eb', 'F#', 'Ab', 'B7', 'G/B', 'C9']) {
      expect(_shape(c, b4), isNot('-'), reason: c);
      expect(_shape(c, b5), isNot('-'), reason: c);
    }
  });

  test('dedos: pestana é o indicador, o resto pela casa', () {
    String fingers(String c) => fingersOf(
      fretShape(Chord.tryParse(c)!, PraiseInstrument.violao)!,
    ).map((f) => f ?? '-').join();
    expect(fingers('C'), '-32-1-');
    expect(fingers('D'), '---132');
    expect(fingers('Am'), '--231-');
    expect(fingers('E'), '-231--');
    expect(fingers('F'), '134211');
  });

  test('capo e afinação mudam o desenho, não o acorde', () {
    String shape(String c, {int drop = 0, int capo = 0}) =>
        '${shapeChord(Chord.tryParse(c)!, drop: drop, capo: capo)}';
    expect(shape('A', capo: 2), 'G');
    expect(shape('E', drop: 1), 'F');
    expect(shape('D/F#', drop: 2, capo: 2), 'D/F#');
    expect(shape('Bm', capo: 2), 'Am');
  });
}
