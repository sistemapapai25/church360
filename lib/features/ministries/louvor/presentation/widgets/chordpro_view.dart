import 'package:flutter/material.dart';

import '../../../../praise/domain/chord.dart';
import '../../../../praise/domain/chordpro.dart';

/// Como o leitor mostra as batidas (print 12, mais "só a da seção atual").
enum StrumDisplay {
  always('Mostrar sempre'),
  hidden('Ocultar sempre'),
  current('Só a da seção atual');

  const StrumDisplay(this.label);
  final String label;
}

/// Batida em setas com a contagem em colcheias embaixo:
/// ```text
/// ↓     ↓ ↑     ↑ ↓ ↑
/// 1  &  2  &  3  &  4  &
/// ```
class StrumView extends StatelessWidget {
  final List<String> pattern;
  final double fontSize;

  const StrumView({super.key, required this.pattern, this.fontSize = 15});

  @override
  Widget build(BuildContext context) {
    final meta = Theme.of(context).textTheme.bodySmall?.color;
    return Semantics(
      label:
          'Batida: ${pattern.map((p) => switch (p) {
            'D' => 'baixo',
            'U' => 'cima',
            _ => 'pausa',
          }).join(', ')}',
      child: ExcludeSemantics(
        child: Wrap(
          children: [
            for (final (i, p) in pattern.indexed)
              SizedBox(
                width: fontSize * 1.4,
                child: Column(
                  children: [
                    Text(
                      switch (p) {
                        'D' => '↓',
                        'U' => '↑',
                        _ => ' ',
                      },
                      style: TextStyle(
                        fontSize: fontSize * 1.3,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      i.isEven ? '${i ~/ 2 + 1}' : '&',
                      style: TextStyle(fontSize: fontSize * 0.75, color: meta),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Corpo da cifra: acorde em cima da sílaba.
///
/// A linha quebra entre palavras e cada pedaço (acorde + sílaba) é um bloco
/// próprio, então a quebra nunca separa o acorde da sílaba dele (contrato de
/// UI §2.2) e não depende mais de rolar na horizontal.
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

  /// Toque no acorde (já transposto). Nulo = acorde não é clicável.
  final ValueChanged<Chord>? onChordTap;

  /// Escolha do usuário (como "Dividir em colunas" do CifraClub). Só divide
  /// se também houver largura de [twoColumnWidth].
  final bool twoColumns;

  /// `{batida: ...}`: desenhada no lugar ([StrumDisplay.always]), escondida,
  /// ou só marcada para o leitor saber onde cada uma está
  /// ([StrumDisplay.current], que mostra a da seção na tela fora do corpo).
  final StrumDisplay strums;

  /// Uma chave por `{batida}`, na ordem do texto, presa no bloco dela.
  final List<GlobalKey>? strumKeys;

  /// "No corpo da cifra": diagrama em cima do acorde (já transposto) na
  /// primeira vez que ele aparece em cada seção. Nulo = sem diagrama.
  final Widget Function(Chord chord)? diagramFor;

  const ChordProView({
    super.key,
    required this.source,
    this.semitones = 0,
    this.preferFlats,
    this.fontSize = 15,
    this.onChordTap,
    this.twoColumns = false,
    this.strums = StrumDisplay.always,
    this.strumKeys,
    this.diagramFor,
  });

  static const _chordLight = Color(0xFF9A3412);
  static const _chordDark = Color(0xFFFDBA74);

  /// Largura mínima para a cifra caber em duas colunas.
  static const twoColumnWidth = 900.0;

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

  /// Palavras da linha, cada uma com seus pedaços (acorde?, texto). Um acorde
  /// no meio da palavra ("Gran[D]de") fica na mesma palavra.
  static List<List<ChordSegment>> words(LyricLine line) {
    final out = <List<ChordSegment>>[[]];
    for (final s in line.segments) {
      final tokens = RegExp(
        r'\S*\s*',
      ).allMatches(s.lyric).map((m) => m[0]!).where((t) => t.isNotEmpty);
      if (tokens.isEmpty) out.last.add(ChordSegment(s.chord, ''));
      var chord = s.chord;
      for (final t in tokens) {
        out.last.add(ChordSegment(chord, t.trimRight()));
        chord = null;
        if (t != t.trimRight()) out.add([]);
      }
    }
    return out.where((w) => w.isNotEmpty).toList();
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
    // Um caractere da monoespaçada: espaço entre palavras e folga do acorde.
    final gap = fontSize * 0.6;

    // Acordes que já ganharam diagrama na seção atual.
    final drawn = <String>{};

    Widget chordText(String raw) {
      final shown = _chord(raw);
      final parsed = Chord.tryParse(shown);
      final withDiagram =
          diagramFor != null && parsed != null && drawn.add('$parsed');
      final text = Padding(
        padding: EdgeInsets.only(right: gap),
        child: withDiagram
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  diagramFor!(parsed),
                  Text(shown, style: chordStyle),
                ],
              )
            : Text(shown, style: chordStyle),
      );
      if (onChordTap == null || parsed == null) return text;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChordTap!(parsed),
          child: text,
        ),
      );
    }

    final blocks = <Widget>[];
    // Pontos onde dá para cortar em colunas sem partir uma estrofe.
    final breaks = <int>[];
    final blanks = <int>{};
    var strumIndex = 0;
    for (final line in parseChordPro(source).lines) {
      switch (line) {
        case EmptyLine():
          breaks.add(blocks.length);
          blanks.add(blocks.length);
          blocks.add(SizedBox(height: fontSize * 0.8));
        case DirectiveLine(name: 'batida', :final value):
          final keys = strumKeys;
          final key = keys != null && strumIndex < keys.length
              ? keys[strumIndex]
              : null;
          strumIndex++;
          if (strums == StrumDisplay.hidden) break;
          blocks.add(
            strums == StrumDisplay.current
                ? SizedBox(key: key)
                : Padding(
                    key: key,
                    padding: const EdgeInsets.only(bottom: 6),
                    child: StrumView(
                      pattern: parseStrum(value),
                      fontSize: fontSize,
                    ),
                  ),
          );
        case DirectiveLine(:final name, :final value):
          final label = name.startsWith('comment')
              ? value
              : (_sections.containsKey(name)
                    ? (value ?? _sections[name])
                    : null);
          if (label != null) {
            drawn.clear();
            breaks.add(blocks.length);
            blocks.add(
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
          final hasChords = line.segments.any((s) => s.chord != null);
          final hasLyrics = line.segments.any((s) => s.lyric.trim().isNotEmpty);
          blocks.add(
            Wrap(
              spacing: gap,
              children: [
                for (final w in words(line))
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final p in w)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasChords)
                              p.chord == null
                                  ? Text('', style: chordStyle)
                                  : chordText(p.chord!),
                            if (hasLyrics) Text(p.lyric, style: base),
                          ],
                        ),
                    ],
                  ),
              ],
            ),
          );
      }
    }

    return LayoutBuilder(
      builder: (context, c) {
        Widget column(List<Widget> children) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
        if (!twoColumns ||
            c.maxWidth < twoColumnWidth ||
            breaks.isEmpty ||
            blocks.length < 12) {
          return column(blocks);
        }
        // Corta no início de seção/estrofe mais perto do meio.
        final half = blocks.length / 2;
        final cut = breaks.reduce(
          (a, b) => (a - half).abs() <= (b - half).abs() ? a : b,
        );
        // A coluna da direita não começa com linha em branco.
        var right = cut;
        while (blanks.contains(right)) {
          right++;
        }
        if (cut == 0 || right >= blocks.length) return column(blocks);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: column(blocks.sublist(0, cut))),
            const SizedBox(width: 32),
            Expanded(child: column(blocks.sublist(right))),
          ],
        );
      },
    );
  }
}
