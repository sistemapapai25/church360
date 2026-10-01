import 'package:flutter/material.dart';

import '../../../../praise/domain/chord.dart';
import '../../../../praise/domain/chordpro.dart';

/// Corpo da cifra: acorde em cima da sílaba, em monoespaçada (com fonte
/// proporcional o acorde aponta para a sílaba errada — erro de conteúdo).
///
/// Linha longa rola na horizontal em vez de quebrar: é o fallback que o
/// contrato de UI aceita (seção 2.2), e nunca separa acorde da sílaba.
///
/// O acorde usa cor própria do leitor, não `primary`: o azul do tema é o
/// mesmo da referência de mercado e perde contraste no escuro (seção 2.4).
class ChordProView extends StatelessWidget {
  final String source;

  /// Semitons a transpor só na tela. A versão gravada não muda.
  final int semitones;

  /// Grafia do tom de destino (Bb e não A#). Nulo = estilo de cada acorde.
  final bool? preferFlats;

  final double fontSize;

  const ChordProView({
    super.key,
    required this.source,
    this.semitones = 0,
    this.preferFlats,
    this.fontSize = 15,
  });

  static const _chordLight = Color(0xFF9A3412);
  static const _chordDark = Color(0xFFFDBA74);

  static const _sections = {
    'start_of_chorus': 'Refrão',
    'start_of_verse': 'Verso',
    'start_of_bridge': 'Ponte',
    'start_of_tab': 'Tablatura',
  };

  String _chord(String c) {
    if (semitones % 12 == 0) return c;
    return Chord.tryParse(
          c,
        )?.transpose(semitones, preferFlats: preferFlats).toString() ??
        c;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize,
      height: 1.35,
    );
    final chordStyle = base.copyWith(
      color: dark ? _chordDark : _chordLight,
      fontWeight: FontWeight.w700,
    );
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800);

    final children = <Widget>[];
    for (final line in parseChordPro(source).lines) {
      switch (line) {
        case EmptyLine():
          children.add(SizedBox(height: fontSize * 0.8));
        case DirectiveLine(:final name, :final value):
          final label = name.startsWith('comment')
              ? value
              : (_sections.containsKey(name)
                    ? (value ?? _sections[name])
                    : null);
          if (label != null) {
            children.add(
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Text(
                  label,
                  style: name.startsWith('comment')
                      ? labelStyle?.copyWith(fontStyle: FontStyle.italic)
                      : labelStyle,
                ),
              ),
            );
          }
        case LyricLine():
          final a = alignLyricLine(line, _chord);
          children.add(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (a.chords.isNotEmpty)
                  Text(a.chords, style: chordStyle, softWrap: false),
                if (a.lyrics.trim().isNotEmpty)
                  Text(a.lyrics, style: base, softWrap: false),
              ],
            ),
          );
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
