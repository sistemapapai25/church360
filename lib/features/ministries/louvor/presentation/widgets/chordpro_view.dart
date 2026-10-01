import 'package:flutter/material.dart';

import '../../../../../core/design/app_icons.dart';
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

/// Grade de bateria: uma linha por peça, um quadrado por toque, a contagem
/// embaixo (8 = colcheias `1 & 2 &`, 16 = semicolcheias `1 e & a`).
class DrumGrid extends StatelessWidget {
  final Map<String, List<bool>> grid;
  final double fontSize;

  const DrumGrid({super.key, required this.grid, this.fontSize = 15});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final meta = Theme.of(context).textTheme.bodySmall?.color;
    final steps = grid.values.fold(0, (n, l) => l.length > n ? l.length : n);
    final cell = fontSize * (steps > 8 ? 1.1 : 1.5);
    final perBeat = steps > 8 ? 4 : 2;
    const sub = ['', 'e', '&', 'a'];
    Widget row(String label, List<Widget> cells) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: fontSize * 4.5,
          child: Text(label, style: TextStyle(fontSize: fontSize * 0.8)),
        ),
        ...cells,
      ],
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final MapEntry(key: v, value: label) in drumVoices.entries)
            if (grid[v] != null)
              row(label, [
                for (var i = 0; i < steps; i++)
                  Container(
                    width: cell - 2,
                    height: cell - 2,
                    margin: EdgeInsets.only(
                      right: (i + 1) % perBeat == 0 ? 6 : 2,
                      bottom: 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: i < grid[v]!.length && grid[v]![i]
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                    ),
                  ),
              ]),
          row('', [
            for (var i = 0; i < steps; i++)
              Container(
                width: cell - 2,
                margin: EdgeInsets.only(right: (i + 1) % perBeat == 0 ? 6 : 2),
                alignment: Alignment.center,
                child: Text(
                  i % perBeat == 0
                      ? '${i ~/ perBeat + 1}'
                      : (perBeat == 2 ? '&' : sub[i % perBeat]),
                  style: TextStyle(fontSize: fontSize * 0.7, color: meta),
                ),
              ),
          ]),
        ],
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

  /// Quantas colunas quando divide (2 ou 3).
  final int columnCount;

  /// "Tablaturas: mostrar/ocultar" (§1.5 item 7): falso esconde o bloco
  /// `{start_of_tab}`…`{end_of_tab}` inteiro.
  final bool showTabs;

  /// "Só letra": esconde a linha dos acordes (linha só de acorde some).
  final bool lyricsOnly;

  /// `{batida: ...}`: desenhada no lugar ([StrumDisplay.always]), escondida,
  /// ou só marcada para o leitor saber onde cada uma está
  /// ([StrumDisplay.current], que mostra a da seção na tela fora do corpo).
  final StrumDisplay strums;

  /// Uma chave por `{batida}`, na ordem do texto, presa no bloco dela.
  final List<GlobalKey>? strumKeys;

  /// ▶ ao lado do título de cada seção (índice de [chordProSections]).
  /// Nulo = sem player.
  final ValueChanged<int>? onPlaySection;

  /// Uma chave por seção, presa no título, para o player achar onde rolar.
  final List<GlobalKey>? sectionKeys;

  /// Instrumento Bateria: desenha as grades `{bateria}` (nos outros elas
  /// somem).
  final bool drums;

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
    this.columnCount = 2,
    this.showTabs = true,
    this.lyricsOnly = false,
    this.strums = StrumDisplay.always,
    this.strumKeys,
    this.diagramFor,
    this.onPlaySection,
    this.sectionKeys,
    this.drums = false,
  });

  static const _chordLight = Color(0xFF9A3412);
  static const _chordDark = Color(0xFFFDBA74);

  /// Largura mínima para a cifra caber em duas colunas.
  static const twoColumnWidth = 900.0;

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
    var sectionIndex = 0;
    var inTab = false;
    final doc = parseChordPro(source);
    final sections = chordProSections(doc);
    for (final line in doc.lines) {
      if (line is DirectiveLine && line.name == 'start_of_tab') inTab = true;
      if (line is DirectiveLine && line.name == 'end_of_tab') {
        inTab = false;
        continue;
      }
      if (inTab && !showTabs) {
        // A seção oculta conta igual, senão o ▶ das seguintes desalinha.
        if (line is DirectiveLine && sectionLabel(line) != null) sectionIndex++;
        continue;
      }
      switch (line) {
        case EmptyLine():
          breaks.add(blocks.length);
          blanks.add(blocks.length);
          blocks.add(SizedBox(height: fontSize * 0.8));
        case DirectiveLine(name: 'bateria', :final value):
          if (drums) {
            blocks.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: DrumGrid(grid: parseDrums(value), fontSize: fontSize),
              ),
            );
          }
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
        case DirectiveLine(:final name):
          final label = sectionLabel(line);
          if (label != null) {
            final i = sectionIndex++;
            final keys = sectionKeys;
            final bpm = i < sections.length ? sections[i].bpm : null;
            drawn.clear();
            breaks.add(blocks.length);
            blocks.add(
              Padding(
                key: keys != null && i < keys.length ? keys[i] : null,
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: name.startsWith('comment')
                            ? labelStyle?.copyWith(fontStyle: FontStyle.italic)
                            : labelStyle,
                      ),
                    ),
                    if (onPlaySection != null)
                      IconButton(
                        tooltip: 'Tocar $label',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(AppIcons.playArrow, size: 20),
                        onPressed: () => onPlaySection!(i),
                      ),
                    if (bpm != null)
                      Text(
                        '$bpm bpm',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            );
          }
        case LyricLine():
          final hasChords =
              !lyricsOnly && line.segments.any((s) => s.chord != null);
          final hasLyrics = line.segments.any((s) => s.lyric.trim().isNotEmpty);
          if (!hasChords && !hasLyrics) break;
          blocks.add(
            Wrap(
              spacing: gap,
              children: [
                for (final w in words(line))
                  // Só letra: a "palavra" que era só o acorde sobre um
                  // espaço viraria um recuo no começo da linha.
                  if (hasChords || w.any((p) => p.lyric.isNotEmpty))
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
        // Corta no início de seção/estrofe mais perto de cada divisão.
        final n = columnCount.clamp(2, 3);
        final cuts = <int>[0];
        for (var k = 1; k < n; k++) {
          final target = blocks.length * k / n;
          final cut = breaks.reduce(
            (a, b) => (a - target).abs() <= (b - target).abs() ? a : b,
          );
          if (cut > cuts.last) cuts.add(cut);
        }
        if (cuts.length < 2) return column(blocks);
        cuts.add(blocks.length);
        final parts = <Widget>[];
        for (var k = 0; k + 1 < cuts.length; k++) {
          // A coluna não começa com linha em branco.
          var from = cuts[k];
          while (k > 0 && blanks.contains(from) && from < cuts[k + 1]) {
            from++;
          }
          if (k > 0) parts.add(const SizedBox(width: 32));
          parts.add(Expanded(child: column(blocks.sublist(from, cuts[k + 1]))));
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: parts,
        );
      },
    );
  }
}
