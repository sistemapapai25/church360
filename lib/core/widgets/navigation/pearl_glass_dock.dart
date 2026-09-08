import 'dart:ui';

import 'package:flutter/material.dart';

/// A barra inferior como um "dock de vidro" contendo pérolas da MESMA
/// família visual — Home, Bíblia, Igreja, Cursos e Mais sempre parecem
/// parte do mesmo sistema, só a intensidade muda entre repouso, hover e
/// selecionado. Validado no playground (`lib/dev/pearl_button_playground.dart`)
/// antes de vir pra cá.
///
/// Não é `PearlButton`/`PearlFab` (mantidos intactos) — é uma pérola
/// compacta própria, com um 3º eixo de intensidade (`selected`) que o
/// original não tem.

/// Superfície de vidro fosco que sustenta os itens do dock.
class PearlGlassDock extends StatelessWidget {
  final List<Widget> children;
  final bool dark;

  const PearlGlassDock({super.key, required this.children, required this.dark});

  @override
  Widget build(BuildContext context) {
    final baseColor = dark
        ? const Color(0xFF14161B).withValues(alpha: 0.62)
        : Colors.white.withValues(alpha: 0.62);
    final topBorder = dark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.65);
    final shadowColor = dark
        ? Colors.black.withValues(alpha: 0.60)
        : Colors.black.withValues(alpha: 0.12);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: topBorder, width: 1.2)),
            boxShadow: [
              BoxShadow(color: shadowColor, blurRadius: 28, offset: const Offset(0, -8)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: children,
          ),
        ),
      ),
    );
  }
}

typedef PearlDockContentBuilder = Widget Function(
  BuildContext context,
  bool selected,
  Color activeColor,
);

/// Pérola compacta de item de navegação. Mesma linguagem visual do
/// `PearlButton` (base escura tintada, realce/underglow/penumbra, glow,
/// glaze, sink no press), mas com um 3º eixo de intensidade: `selected`.
class PearlDockItem extends StatefulWidget {
  final PearlDockContentBuilder contentBuilder;
  final String label;
  final Color color;
  final bool selected;
  final bool showLabel;
  final bool dark;
  final VoidCallback onTap;

  const PearlDockItem({
    super.key,
    required this.contentBuilder,
    required this.label,
    required this.color,
    required this.selected,
    required this.showLabel,
    required this.dark,
    required this.onTap,
  });

  @override
  State<PearlDockItem> createState() => _PearlDockItemState();
}

class _PearlDockItemState extends State<PearlDockItem> {
  static const _duration = Duration(milliseconds: 220);
  static const _curve = Curves.easeOut;

  bool _hovering = false;
  bool _pressed = false;

  void _setHover(bool value) {
    if (_hovering == value) return;
    setState(() {
      _hovering = value;
      if (!value) _pressed = false;
    });
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  /// Nível 0..~1.15 que dirige toda a intensidade visual da pérola.
  /// Repouso (não selecionado) fica baixo; hover sobe perto do topo;
  /// selecionado já nasce perto do topo e pode subir um pouco mais.
  double get _level {
    if (widget.selected) {
      if (_pressed) return 1.12;
      if (_hovering) return 1.00;
      return 0.86;
    }
    if (_pressed) return 0.95;
    if (_hovering) return 0.78;
    return 0.32;
  }

  @override
  Widget build(BuildContext context) {
    const w = 46.0;
    const h = 34.0;
    final radius = BorderRadius.circular(h / 2);
    final level = _level;

    // A pérola precisa da SUA PRÓPRIA leitura em cada tema, não só o dock
    // ao redor mudando — senão ela fica "presa" no visual de um tema só.
    // Escuro: base quase preta, cor entra como tint (smoked/deep pearl).
    // Claro: base leitosa/marfim — pérola clara colorida de verdade, não
    // um grafite escuro flutuando sobre o vidro branco.
    final faceSeed = widget.dark ? const Color(0xFF0F1015) : const Color(0xFFFCFAF5);
    final glowBoost = widget.dark ? 1.18 : 1.10;

    // Halo colorido ao redor da pérola: no vidro claro o brilho branco
    // interno se perde contra o fundo pálido, então quem realmente marca
    // hover/seleção ali é esse halo — funciona nos dois temas.
    final haloAlpha = (0.06 + level * 0.34).clamp(0.0, 0.42);
    final haloBlur = h * (0.45 + level * 0.55);
    final haloSpread = level * 1.6;

    // No claro o tint precisa ser bem mais forte desde o repouso — senão a
    // pérola nasce quase branca e só "aparece" no hover.
    final tintRatio = widget.dark
        ? (0.05 + level * 0.13 + 0.04).clamp(0.0, 0.28)
        : (0.36 + level * 0.32).clamp(0.0, 0.70);
    final faceColor = Color.lerp(faceSeed, widget.color, tintRatio)!;
    final topHighlightAlpha = ((0.10 + level * 0.28) * glowBoost).clamp(0.0, 0.60);
    final underglowAlpha = widget.dark
        ? ((0.12 + level * 0.42) * glowBoost).clamp(0.0, 0.85)
        : ((0.08 + level * 0.20) * glowBoost).clamp(0.0, 0.45);
    final bottomRimAlpha = widget.dark
        ? (0.40 + level * 0.32).clamp(0.0, 0.85)
        : (0.14 + level * 0.16).clamp(0.0, 0.36);
    final shineOpacity = ((0.30 + level * 0.55) * glowBoost).clamp(0.0, 1.0);
    final glowAlpha = ((0.04 + level * 0.10) * glowBoost).clamp(0.0, 0.20);

    final sinkY = _pressed ? 3.0 : 0.0;
    final contentShiftY = (_hovering || widget.selected) ? -h * 0.05 * level : 0.0;

    // --- moldagem: carcaça externa + face recuada (mesmo "degrau óptico"
    // do PearlButton refinado), em escala reduzida pro tamanho do dock.
    final shellColor = widget.dark
        ? Color.lerp(faceColor, Colors.black, 0.30)!
        : Color.lerp(faceColor, const Color(0xFFE7E0D2), 0.55)!;
    final bevel = (h * 0.09).clamp(1.4, 3.0);
    final faceRadius = BorderRadius.circular((h / 2 - bevel).clamp(0.0, h / 2));
    final grooveColor = widget.dark
        ? Colors.black.withValues(alpha: (0.30 + level * 0.12).clamp(0.0, 0.45))
        : Colors.black.withValues(alpha: (0.06 + level * 0.05).clamp(0.0, 0.13));
    final rimCatchAlpha = widget.dark ? 0.12 : 0.80;

    final labelColor = widget.selected
        ? widget.color
        : (widget.dark
            ? Colors.white.withValues(alpha: 0.55)
            : Colors.black.withValues(alpha: 0.45));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        behavior: HitTestBehavior.opaque,
        // Preenchimento invisível só pra alcançar uma área de toque decente
        // (a pérola em si tem 34 de altura) — não afeta o visual.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: _duration,
              curve: _curve,
              transform: Matrix4.translationValues(0, sinkY, 0),
              width: w,
              height: h,
              decoration: BoxDecoration(
                borderRadius: radius,
                color: shellColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: (0.10 + level * 0.18).clamp(0.0, 0.30)),
                    blurRadius: h * 0.5,
                    offset: Offset(0, h * 0.35),
                  ),
                  BoxShadow(
                    color: widget.color.withValues(alpha: haloAlpha),
                    blurRadius: haloBlur,
                    spreadRadius: haloSpread,
                  ),
                ],
              ),
              padding: EdgeInsets.all(bevel),
              // Degrau carcaça→face: contorno fino + fio de luz no topo,
              // mesma lógica do PearlButton refinado, em escala de dock.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: faceRadius,
                  border: Border.all(color: grooveColor, width: 1),
                ),
                child: ClipRRect(
                borderRadius: faceRadius,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    DecoratedBox(decoration: BoxDecoration(color: faceColor)),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: 1.2,
                      child: Container(
                        color: Colors.white.withValues(alpha: rimCatchAlpha),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: h * 0.55,
                      child: AnimatedOpacity(
                        duration: _duration,
                        curve: _curve,
                        opacity: topHighlightAlpha,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.white, Color(0x00FFFFFF)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: h * 0.75,
                      child: AnimatedOpacity(
                        duration: _duration,
                        curve: _curve,
                        opacity: underglowAlpha,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.white, Color(0x00FFFFFF)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: h * 0.22,
                      child: AnimatedOpacity(
                        duration: _duration,
                        curve: _curve,
                        opacity: bottomRimAlpha,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black, Color(0x00000000)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: AnimatedContainer(
                        duration: _duration,
                        curve: _curve,
                        transform: Matrix4.translationValues(0, -h * 0.5, 0),
                        width: w * 1.3,
                        height: w * 1.3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: glowAlpha),
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: _duration,
                      curve: _curve,
                      transform: Matrix4.translationValues(0, contentShiftY, 0),
                      child: widget.contentBuilder(context, widget.selected, widget.color),
                    ),
                    Positioned(
                      left: w * 0.08,
                      right: w * 0.08,
                      top: h * 0.10,
                      height: h * 0.46,
                      child: AnimatedOpacity(
                        duration: _duration,
                        curve: _curve,
                        opacity: shineOpacity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(h * 0.3)),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.28),
                                Colors.white.withValues(alpha: 0),
                              ],
                              stops: const [0.0, 0.5],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                ),
              ),
            ),
            if (widget.showLabel) ...[
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: _duration,
                curve: _curve,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w600,
                  color: labelColor,
                ),
                child: Text(widget.label),
              ),
            ],
          ],
          ),
        ),
      ),
    );
  }
}
