import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Dock flutuante de vidro fosco usada pela navegação principal.
///
/// A forma de cápsula, o espaço ao redor e o desfoque seguem a referência
/// visual do Instagram, mas continuam usando os tokens do Church360. A barra
/// não encosta nas bordas da tela para que o conteúdo permaneça visível por
/// trás do vidro.
class PearlGlassDock extends StatelessWidget {
  final List<Widget> children;
  final bool dark;

  const PearlGlassDock({super.key, required this.children, required this.dark});

  @override
  Widget build(BuildContext context) {
    final borderColor = dark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.78);
    final shadowColor = Colors.black.withValues(alpha: dark ? 0.34 : 0.14);
    final gradient = dark
        ? [
            AppTheme.darkSurface.withValues(alpha: 0.82),
            const Color(0xFF070B12).withValues(alpha: 0.90),
          ]
        : [
            Colors.white.withValues(alpha: 0.86),
            AppTheme.muted.withValues(alpha: 0.78),
          ];

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                height: 76,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 24,
                      spreadRadius: 1,
                      offset: const Offset(0, 8),
                    ),
                    if (dark)
                      BoxShadow(
                        color: AppTheme.darkRing.withValues(alpha: 0.08),
                        blurRadius: 18,
                        spreadRadius: -4,
                        offset: const Offset(0, -2),
                      ),
                  ],
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
    );
  }
}

typedef PearlDockContentBuilder =
    Widget Function(BuildContext context, bool selected, Color activeColor);

/// Item de navegação em vidro suave.
///
/// O nome público é mantido para não quebrar telas e playgrounds existentes;
/// a aparência em produção é agora um estado ativo azul, sem pérolas ou
/// glows coloridos independentes por item.
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
    const width = 46.0;
    const height = 40.0;
    final selectedSurface = widget.dark
        ? Colors.white.withValues(alpha: 0.14)
        : AppTheme.accent.withValues(alpha: 0.90);
    final hoverSurface = widget.dark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFFF1F5F9).withValues(alpha: 0.92);
    final borderColor = widget.selected
        ? Colors.white.withValues(alpha: widget.dark ? 0.20 : 0.62)
        : Colors.transparent;
    final iconColor = widget.selected
        ? widget.color
        : (widget.dark
              ? Colors.white.withValues(alpha: 0.62)
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: _duration,
                curve: _curve,
                transform: Matrix4.translationValues(0, _pressed ? 1.5 : 0, 0),
                width: width,
                height: height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: widget.selected
                      ? [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.14),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
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
          ),
        ),
      ),
    );
  }
}
