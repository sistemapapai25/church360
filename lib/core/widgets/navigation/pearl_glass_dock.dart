import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Dock flutuante de vidro ("liquid glass") usada pela navegação principal.
///
/// Segue a referência do Instagram: cápsula solta das bordas, fundo quase
/// transparente e desfoque forte do conteúdo que passa por trás. Para o vidro
/// aparecer, o `Scaffold` que a recebe precisa de `extendBody: true` — sem
/// isso o corpo termina acima da dock e o blur só tem o fundo liso do
/// Scaffold para borrar (era a "barra atrás da barra").
class PearlGlassDock extends StatelessWidget {
  final List<Widget> children;
  final bool dark;

  const PearlGlassDock({super.key, required this.children, required this.dark});

  /// Altura da cápsula, sem a margem inferior nem a área segura do sistema.
  static const double dockHeight = 64.0;
  static const double bottomMargin = 10.0;

  @override
  Widget build(BuildContext context) {
    // Base bem translúcida: quem dá corpo ao vidro é o blur, não a cor.
    final gradient = dark
        ? [
            const Color(0xFF2A2F38).withValues(alpha: 0.42),
            const Color(0xFF0B0F16).withValues(alpha: 0.52),
          ]
        : [
            Colors.white.withValues(alpha: 0.52),
            Colors.white.withValues(alpha: 0.34),
          ];
    // Borda com brilho em cima e quase apagada embaixo, como luz batendo
    // na aresta do vidro.
    final rim = dark
        ? [
            Colors.white.withValues(alpha: 0.26),
            Colors.white.withValues(alpha: 0.06),
          ]
        : [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.35),
          ];
    final shadowColor = Colors.black.withValues(alpha: dark ? 0.32 : 0.10);

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final radius = BorderRadius.circular(dockHeight / 2);

    // O BottomNavigationBar do Scaffold pode oferecer altura livre ao filho.
    // O SizedBox externo impede que a cápsula ocupe a tela inteira e a mantém
    // ancorada no rodapé também no Flutter Web.
    return SizedBox(
      height: dockHeight + bottomMargin + bottomInset,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, bottomMargin + bottomInset),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  // Sombra curta e difusa: deslocada demais ela vira uma
                  // faixa escura sob a cápsula e lembra a barra antiga.
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 18,
                    spreadRadius: -4,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: Container(
                    height: dockHeight,
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: rim,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: gradient,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: children,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

typedef PearlDockContentBuilder =
    Widget Function(BuildContext context, bool selected, Color activeColor);

/// Item de navegação em vidro suave.
///
/// O nome público é mantido para não quebrar telas e playgrounds existentes;
/// o item ativo ganha uma pílula larga de vidro, sem pérolas nem glows
/// coloridos por item.
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
  static const _duration = Duration(milliseconds: 180);
  static const _curve = Curves.easeOutCubic;

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

  @override
  Widget build(BuildContext context) {
    const height = 50.0;
    // Pílula larga no item ativo, como no Instagram; nas telas estreitas ela
    // encolhe para caber na fatia do item em vez de estourar a dock.
    final selectedSurface = widget.dark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.06);
    final hoverSurface = widget.dark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.035);
    final borderColor = widget.selected
        ? Colors.white.withValues(alpha: widget.dark ? 0.14 : 0.70)
        : Colors.transparent;
    final iconColor = widget.selected
        ? (widget.dark ? Colors.white : widget.color)
        : (widget.dark
              ? Colors.white.withValues(alpha: 0.66)
              : AppTheme.mutedForeground);
    final surface = widget.selected
        ? selectedSurface
        : (_hovering ? hoverSurface : Colors.transparent);

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite
                ? (constraints.maxWidth - 4).clamp(40.0, 68.0)
                : 68.0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: _duration,
                  curve: _curve,
                  transform: Matrix4.translationValues(
                    0,
                    _pressed ? 1.5 : 0,
                    0,
                  ),
                  width: width,
                  height: height,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(height / 2),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: widget.contentBuilder(
                    context,
                    widget.selected,
                    iconColor,
                  ),
                ),
                if (widget.showLabel) ...[
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: _duration,
                    curve: _curve,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: widget.selected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: iconColor,
                    ),
                    child: Text(widget.label),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
