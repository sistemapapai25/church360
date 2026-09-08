import 'package:flutter/material.dart';
import 'pearl_button.dart';

/// Substituto perolado (PearlButton) para [FloatingActionButton] e
/// [FloatingActionButton.extended] — usado nos botões de destaque
/// ("Novo X", menu de gestão) espalhados pelas telas de lista do app.
///
/// Sem [label]: círculo 56x56 (equivalente ao FAB normal).
/// Com [label]: pílula com largura calculada a partir do texto
/// (equivalente ao FAB estendido, ícone + texto).
class PearlFab extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String? label;
  final Color? color;
  final String? tooltip;

  /// Enquanto true, mostra um spinner branco no lugar do ícone e o botão
  /// fica desabilitado (equivalente ao ícone giratório que alguns FABs
  /// trocavam durante uma ação assíncrona, ex. gerando recomendações).
  final bool loading;

  const PearlFab({
    super.key,
    required this.onPressed,
    required this.icon,
    this.label,
    this.color,
    this.tooltip,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    final effectiveOnPressed = loading ? null : onPressed;

    Widget leading() {
      if (!loading) return Icon(icon, color: Colors.white, size: label == null ? 24 : 20);
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    }

    final Widget button;
    if (label == null) {
      button = PearlButton(
        color: effectiveColor,
        width: 56,
        height: 56,
        borderRadius: BorderRadius.circular(28),
        onTap: effectiveOnPressed,
        child: leading(),
      );
    } else {
      const textStyle = TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      );
      const horizontalPadding = 22.0;
      const iconSize = 20.0;
      const iconLabelGap = 10.0;

      final textPainter = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final width = horizontalPadding * 2 + iconSize + iconLabelGap + textPainter.width;

      button = PearlButton(
        color: effectiveColor,
        width: width,
        height: 52,
        borderRadius: BorderRadius.circular(26),
        onTap: effectiveOnPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading(),
            const SizedBox(width: iconLabelGap),
            Text(label!, style: textStyle),
          ],
        ),
      );
    }

    return tooltip != null ? Tooltip(message: tooltip!, child: button) : button;
  }
}
