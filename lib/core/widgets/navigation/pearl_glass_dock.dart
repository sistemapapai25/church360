import 'dart:ui';

import 'package:flutter/material.dart';

/// Superfície inferior de vidro fosco usada pela navegação principal.
///
/// A barra mantém a sensação de profundidade do app, mas deixa a cor para
/// a hierarquia de navegação: itens inativos são neutros e somente o item
/// selecionado recebe o azul institucional.
class PearlGlassDock extends StatelessWidget {
  final List<Widget> children;
  final bool dark;

  const PearlGlassDock({super.key, required this.children, required this.dark});

  @override
  Widget build(BuildContext context) {
    final baseColor = dark
        ? const Color(0xFF0F1B30).withValues(alpha: 0.84)
        : Colors.white.withValues(alpha: 0.88);
    final topBorder = dark
        ? const Color(0xFF93C5FD).withValues(alpha: 0.22)
        : const Color(0xFFBFDBFE).withValues(alpha: 0.92);
    final shadowColor = Colors.black.withValues(alpha: dark ? 0.30 : 0.10);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: topBorder, width: 1)),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 22,
                offset: const Offset(0, -6),
              ),
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
        ? const Color(0xFF1E3A5F).withValues(alpha: 0.88)
        : const Color(0xFFDBEAFE).withValues(alpha: 0.94);
    final hoverSurface = widget.dark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFFF1F5F9).withValues(alpha: 0.92);
    final borderColor = widget.selected
        ? const Color(0xFF93C5FD).withValues(alpha: 0.72)
        : Colors.transparent;
    final iconColor = widget.selected
        ? widget.color
        : (widget.dark
              ? Colors.white.withValues(alpha: 0.62)
              : const Color(0xFF64748B));
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
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
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
