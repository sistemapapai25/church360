import 'package:flutter/material.dart';

/// Botão de ação em estilo Soft Glass / Premium Blue.
///
/// Os parâmetros legados [dark], [moldingEnabled] e [lightTintBoost] são
/// mantidos para compatibilidade com as telas existentes. A aparência atual
/// usa uma única superfície de ação com profundidade sutil, sem o efeito
/// perolado ou glows multicoloridos do componente anterior.
class PearlButton extends StatefulWidget {
  final Widget child;
  final Color color;
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final bool dark;
  final bool moldingEnabled;
  final double lightTintBoost;

  const PearlButton({
    super.key,
    required this.child,
    required this.color,
    this.width = 160,
    this.height = 56,
    this.borderRadius,
    this.onTap,
    this.dark = true,
    this.moldingEnabled = false,
    this.lightTintBoost = 0.0,
  });

  @override
  State<PearlButton> createState() => _PearlButtonState();
}

class _PearlButtonState extends State<PearlButton> {
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
    final radius =
        widget.borderRadius ?? BorderRadius.circular(widget.height / 2);
    final disabled = widget.onTap == null;
    final startColor = Color.lerp(widget.color, Colors.white, 0.08)!;
    final endColor = Color.lerp(widget.color, Colors.black, 0.14)!;

    return AnimatedOpacity(
      duration: _duration,
      curve: _curve,
      opacity: disabled ? 0.48 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: radius,
          onHover: _setHover,
          onHighlightChanged: _setPressed,
          onFocusChange: _setHover,
          child: AnimatedContainer(
            duration: _duration,
            curve: _curve,
            transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
            width: widget.width,
            height: widget.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [startColor, endColor],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: _hovering ? 0.65 : 0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _pressed ? 0.12 : 0.18),
                  blurRadius: _pressed ? 7 : 14,
                  offset: Offset(0, _pressed ? 3 : 6),
                ),
                BoxShadow(
                  color: widget.color.withValues(
                    alpha: _hovering ? 0.16 : 0.09,
                  ),
                  blurRadius: _hovering ? 18 : 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
