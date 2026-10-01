import 'dart:math' as math;
import 'dart:typed_data';

import 'package:church360_app/features/praise/domain/pitch.dart';
import 'package:flutter_test/flutter_test.dart';

Float32List _tone(double hz, {int rate = 44100, int n = 4096}) {
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    final t = i / rate;
    // Corda tem harmônicos: o detector não pode cair na oitava.
    out[i] =
        0.5 * math.sin(2 * math.pi * hz * t) +
        0.3 * math.sin(4 * math.pi * hz * t) +
        0.1 * math.sin(6 * math.pi * hz * t);
  }
  return out;
}

void main() {
  test('acha a nota das cordas soltas do violão', () {
    for (final hz in [82.41, 110.0, 146.83, 196.0, 246.94, 329.63, 440.0]) {
      expect(detectPitch(_tone(hz), 44100), closeTo(hz, hz * 0.005));
    }
  });

  test('silêncio não vira nota', () {
    expect(detectPitch(Float32List(4096), 44100), isNull);
  });

  test('nota mais perto e cents', () {
    final a = nearestNote(440);
    expect(a.note, 'A');
    expect(a.cents.abs(), lessThan(0.01));
    final flat = nearestNote(435);
    expect(flat.note, 'A');
    expect(flat.cents, closeTo(-19.8, 0.5));
    expect(nearestNote(82.41).note, 'E');
  });

  test('oitava científica: Lá 440 = A4, Mi grave do violão = E2', () {
    expect(nearestNote(440).octave, 4);
    expect(nearestNote(82.41).note, 'E');
    expect(nearestNote(82.41).octave, 2);
    expect(nearestNote(261.63).octave, 4); // Dó central
  });
}
