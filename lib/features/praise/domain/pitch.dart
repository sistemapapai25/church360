import 'dart:math' as math;
import 'dart:typed_data';

import 'chord.dart';

/// Frequência fundamental de [samples] (mono, -1..1) em Hz, ou `null` quando
/// não há nota clara (silêncio, ruído). Autocorrelação normalizada (McLeod):
/// o primeiro pico perto do maior, refinado por parábola. Faixa 60–1100 Hz,
/// do Mi grave do violão ao agudo do cavaco.
double? detectPitch(Float32List samples, int sampleRate) {
  final n = samples.length;
  var energy = 0.0;
  for (final s in samples) {
    energy += s * s;
  }
  if (energy / n < 1e-5) return null;

  final minLag = sampleRate ~/ 1100;
  final maxLag = math.min(sampleRate ~/ 60, n ~/ 2);
  final nsdf = Float64List(maxLag + 2);
  for (var tau = minLag; tau <= maxLag + 1; tau++) {
    var r = 0.0, m = 0.0;
    for (var i = 0; i + tau < n; i++) {
      final a = samples[i], b = samples[i + tau];
      r += a * b;
      m += a * a + b * b;
    }
    nsdf[tau] = m == 0 ? 0 : 2 * r / m;
  }

  var best = 0.0;
  for (var t = minLag; t <= maxLag; t++) {
    if (nsdf[t] > best) best = nsdf[t];
  }
  if (best < 0.6) return null;
  for (var t = minLag + 1; t <= maxLag; t++) {
    if (nsdf[t] >= 0.9 * best &&
        nsdf[t] >= nsdf[t - 1] &&
        nsdf[t] >= nsdf[t + 1]) {
      final a = nsdf[t - 1], b = nsdf[t], c = nsdf[t + 1];
      final den = a - 2 * b + c;
      final shift = den == 0 ? 0.0 : 0.5 * (a - c) / den;
      return sampleRate / (t + shift);
    }
  }
  return null;
}

/// Nota mais perto de [hz] (Lá = [a4]) e quanto falta em cents (-50..50).
({String note, int semitone, double cents}) nearestNote(
  double hz, {
  double a4 = 440,
}) {
  final midi = 69 + 12 * math.log(hz / a4) / math.ln2;
  final near = midi.round();
  final semi = near % 12;
  return (
    note: Chord.noteName(semi, flats: false),
    semitone: semi,
    cents: (midi - near) * 100,
  );
}
