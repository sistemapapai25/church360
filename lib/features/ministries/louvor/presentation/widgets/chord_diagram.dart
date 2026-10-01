import 'package:flutter/material.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../praise/domain/chord.dart';
import '../../../../praise/domain/chord_shapes.dart';

/// Desenho do acorde no instrumento: braço (cordas, casas, x/o, pestana e o
/// número do dedo na bolinha) ou teclado com as notas acesas. Cor ativa =
/// primary, nunca a do CifraClub.
///
/// [chord] é o desenho, não o som: com capo/afinação o leitor passa
/// [shapeChord].
class ChordDiagram extends StatelessWidget {
  final Chord chord;
  final PraiseInstrument instrument;
  final double width;

  const ChordDiagram({
    super.key,
    required this.chord,
    required this.instrument,
    this.width = 64,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (instrument == PraiseInstrument.teclado) {
      return CustomPaint(
        size: Size(width * 1.6, width * 0.7),
        painter: _KeyboardPainter(chordTones(chord), scheme),
      );
    }
    final shape = fretShape(chord, instrument);
    if (shape == null) {
      return SizedBox(
        width: width,
        height: width * 1.25,
        child: Center(
          child: Text(
            'Sem desenho',
            textAlign: TextAlign.center,
            style: CommunityDesign.metaStyle(context).copyWith(fontSize: 11),
          ),
        ),
      );
    }
    return CustomPaint(
      size: Size(width, width * 1.25),
      painter: _FretPainter(shape, scheme, bass: instrument.isBass),
    );
  }
}

class _FretPainter extends CustomPainter {
  final List<int?> shape;
  final ColorScheme scheme;

  /// Baixo: uma nota só, então sem × nas outras cordas nem número de dedo.
  final bool bass;

  _FretPainter(this.shape, this.scheme, {this.bass = false});

  static const _rows = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final fingers = fingersOf(shape);
    final fretted = [
      for (final f in shape)
        if (f != null && f > 0) f,
    ];
    final high = fretted.isEmpty ? 0 : fretted.reduce((a, b) => a > b ? a : b);
    final low = fretted.isEmpty ? 1 : fretted.reduce((a, b) => a < b ? a : b);
    // Até a 5ª casa desenha desde a pestana; acima, numera a casa inicial.
    final base = high <= _rows ? 1 : low;

    final label = size.width * 0.18;
    final top = size.height * 0.16;
    final left = label;
    final w = size.width - label * 1.4;
    final h = size.height - top - 2;
    final n = shape.length;
    final dx = w / (n - 1);
    final dy = h / _rows;

    final line = Paint()
      ..color = scheme.onSurfaceVariant.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    final dot = Paint()..color = scheme.primary;

    for (var i = 0; i < n; i++) {
      canvas.drawLine(
        Offset(left + i * dx, top),
        Offset(left + i * dx, top + h),
        line,
      );
    }
    for (var r = 0; r <= _rows; r++) {
      canvas.drawLine(
        Offset(left, top + r * dy),
        Offset(left + w, top + r * dy),
        r == 0 && base == 1
            ? (Paint()
                ..color = line.color
                ..strokeWidth = 3)
            : line,
      );
    }

    final small = TextStyle(
      fontSize: size.width * 0.15,
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    if (base > 1) {
      _text(canvas, '$base', Offset(left - label * 0.6, top + dy / 2), small);
    }

    final r = dx * 0.36 < dy * 0.36 ? dx * 0.36 : dy * 0.36;
    final finger = TextStyle(
      fontSize: r * 1.3,
      height: 1,
      color: scheme.onPrimary,
      fontWeight: FontWeight.w700,
    );
    final barre = barreOf(shape);
    if (barre != null) {
      final y = top + (barre.fret - base + 0.5) * dy;
      canvas.drawRRect(
        RRect.fromLTRBR(
          left + barre.from * dx - r,
          y - r,
          left + barre.to * dx + r,
          y + r,
          Radius.circular(AppTheme.pillRadius),
        ),
        dot,
      );
      _text(canvas, '1', Offset(left + barre.from * dx, y), finger);
    }
    for (var i = 0; i < n; i++) {
      final f = shape[i];
      final x = left + i * dx;
      if (f == null && bass) continue;
      if (f == null || f == 0) {
        _text(canvas, f == null ? '×' : '○', Offset(x, top * 0.45), small);
      } else {
        if (barre != null && fingers[i] == 1) continue;
        final c = Offset(x, top + (f - base + 0.5) * dy);
        canvas.drawCircle(c, r, dot);
        if (r >= 5 && !bass) _text(canvas, '${fingers[i]}', c, finger);
      }
    }
  }

  void _text(Canvas canvas, String s, Offset center, TextStyle style) {
    final p = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(canvas, center - Offset(p.width / 2, p.height / 2));
  }

  @override
  bool shouldRepaint(_FretPainter old) =>
      old.shape != shape || old.scheme != scheme || old.bass != bass;
}

/// Duas oitavas a partir de Dó, as notas acesas subindo a partir do baixo.
class _KeyboardPainter extends CustomPainter {
  final List<int> tones;
  final ColorScheme scheme;

  _KeyboardPainter(this.tones, this.scheme);

  static const _whites = [0, 2, 4, 5, 7, 9, 11];
  static const _blacks = {1: 0, 3: 1, 6: 3, 8: 4, 10: 5};

  @override
  void paint(Canvas canvas, Size size) {
    final lit = <int>{};
    var prev = -1;
    for (final t in tones) {
      var k = t;
      while (k <= prev) {
        k += 12;
      }
      if (k > 23) k -= 12;
      lit.add(k);
      prev = k;
    }

    final kw = size.width / 14;
    final border = Paint()
      ..color = scheme.onSurfaceVariant.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke;
    final on = Paint()..color = scheme.primary;
    for (var o = 0; o < 2; o++) {
      for (var i = 0; i < 7; i++) {
        final rect = Rect.fromLTWH((o * 7 + i) * kw, 0, kw, size.height);
        canvas.drawRect(
          rect,
          Paint()
            ..color = lit.contains(o * 12 + _whites[i])
                ? scheme.primary
                : Colors.white,
        );
        canvas.drawRect(rect, border);
      }
      _blacks.forEach((semi, after) {
        final rect = Rect.fromLTWH(
          (o * 7 + after + 1) * kw - kw * 0.3,
          0,
          kw * 0.6,
          size.height * 0.6,
        );
        canvas.drawRect(
          rect,
          lit.contains(o * 12 + semi) ? on : (Paint()..color = Colors.black87),
        );
      });
    }
  }

  @override
  bool shouldRepaint(_KeyboardPainter old) =>
      old.tones.join() != tones.join() || old.scheme != scheme;
}

/// Painel ao tocar no acorde: nome, notas e desenho no instrumento. Trocar o
/// instrumento aqui vale para o leitor todo ([onInstrument], que devolve o
/// instrumento de fato: o chip "Baixo" vira o de 4 ou 5 cordas salvo). [shapeOf] dá o
/// desenho com o capo/afinação da tela.
Future<void> showChordSheet(
  BuildContext context, {
  required Chord chord,
  required PraiseInstrument instrument,
  required PraiseInstrument Function(PraiseInstrument) onInstrument,
  Chord Function(Chord chord, PraiseInstrument instrument)? shapeOf,
}) {
  var current = instrument;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) => SafeArea(
        // Rola em celular baixo: desenho grande + instrumentos não cabem.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$chord',
                style: CommunityDesign.titleStyle(
                  context,
                ).copyWith(fontSize: 24),
              ),
              const SizedBox(height: 4),
              Text(
                'Notas: ${chordNoteNames(chord)}',
                style: CommunityDesign.metaStyle(context),
              ),
              const SizedBox(height: 16),
              ChordDiagram(
                chord: shapeOf?.call(chord, current) ?? chord,
                instrument: current,
                width: 140,
              ),
              if (shapeOf != null && '${shapeOf(chord, current)}' != '$chord')
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Desenho de ${shapeOf(chord, current)} (capo/afinação)',
                    style: CommunityDesign.metaStyle(context),
                  ),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final i in PraiseInstrument.pickable)
                    ChoiceChip(
                      shape: const StadiumBorder(),
                      label: Text(i.label),
                      selected: i == current.chip,
                      onSelected: (_) =>
                          setSheet(() => current = onInstrument(i)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
