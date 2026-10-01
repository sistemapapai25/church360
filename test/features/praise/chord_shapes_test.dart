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

  test('outros instrumentos acham desenho', () {
    for (final i in [
      PraiseInstrument.ukulele,
      PraiseInstrument.cavaco,
      PraiseInstrument.viola,
    ]) {
      for (final c in ['G', 'C', 'D', 'Em', 'Am', 'F', 'Bb']) {
        expect(_shape(c, i), isNot('-'), reason: '$c ${i.name}');
      }
    }
    expect(_shape('C', PraiseInstrument.ukulele), '0003');
  });
}
