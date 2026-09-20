import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CommunityDesign {
  static const Color backgroundColor = AppTheme.background;
  static const double radius = AppTheme.cardRadius;
  static const double compactImageHeight = 160;
  static const double gridSpacing = 16;
  static const double gridTargetItemWidth = 270;
  static const double gridMainAxisExtentCompact = 520;

  static Color scaffoldBackgroundColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.scaffoldBackgroundColor;
  }

  static Color headerColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor;
  }

  static BoxShadow overlayBaseShadow() {
    return BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    );
  }

  static BoxShadow overlayHoverShadow() {
    return BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 14,
      offset: const Offset(0, 6),
    );
  }

  static bool isLightScheme(ColorScheme colorScheme) {
    return colorScheme.brightness == Brightness.light;
  }

  static Color cardSurfaceColor(ColorScheme colorScheme) {
    return isLightScheme(colorScheme) ? Colors.white : colorScheme.surface;
  }

  static Border? cardBorder(ColorScheme colorScheme, {double alpha = 0.08}) {
    if (!isLightScheme(colorScheme)) return null;
    return Border.all(color: colorScheme.outline.withValues(alpha: alpha));
  }

  static BoxDecoration overlayDecoration(
    ColorScheme colorScheme, {
    bool hovered = false,
  }) {
    return BoxDecoration(
      color: cardSurfaceColor(colorScheme),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [hovered ? overlayHoverShadow() : overlayBaseShadow()],
      border: cardBorder(colorScheme),
    );
  }

  static BoxDecoration feedCardDecoration(
    ColorScheme colorScheme, {
    bool hovered = false,
    double? radiusValue,
  }) {
    return overlayDecoration(
      colorScheme,
      hovered: hovered,
    ).copyWith(borderRadius: BorderRadius.circular(radiusValue ?? radius));
  }

  static EdgeInsets overlayPadding = const EdgeInsets.all(16);

  static TextStyle authorStyle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 14,
      height: 1.2,
      color: cs.onSurface,
    );
  }

  static TextStyle metaStyle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.2,
      color: cs.onSurfaceVariant.withValues(alpha: 0.85),
    );
  }

  static TextStyle titleStyle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 16,
      height: 1.55,
      fontWeight: FontWeight.w600,
      color: cs.onSurface,
    );
  }

  static TextStyle contentStyle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextStyle(fontSize: 14, height: 1.5, color: cs.onSurface);
  }

  static ButtonStyle pillButtonStyle(
    BuildContext context,
    Color actionColor, {
    bool compact = false,
  }) {
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 10);
    return ButtonStyle(
      padding: WidgetStateProperty.all(padding),
      minimumSize: WidgetStateProperty.all(Size.zero),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: WidgetStateProperty.all(const StadiumBorder()),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed)) {
          return actionColor.withValues(alpha: 0.08);
        }
        return null;
      }),
      visualDensity: VisualDensity.compact,
    );
  }

  static Widget typeBadge(BuildContext context, String type) {
    late Color bgColor;
    late Color borderColor;
    late Color textColor;
    late String label;
    switch (type) {
      case 'prayer_request':
        label = 'Oração';
        bgColor = const Color(0xFFDFF5EA);
        borderColor = const Color(0xFFBFEAD4);
        textColor = const Color(0xFF1D6E45);
        break;
      case 'classified':
        label = 'Classificado';
        bgColor = const Color(0xFFFFF4D6);
        borderColor = const Color(0xFFF2D797);
        textColor = const Color(0xFF8A5B00);
        break;
      case 'testimony':
        label = 'Testemunho';
        bgColor = const Color(0xFFF0E9FF);
        borderColor = const Color(0xFFD7C6FF);
        textColor = const Color(0xFF5A3BA6);
        break;
      default:
        label = 'Geral';
        bgColor = const Color(0xFFEAF4FB);
        borderColor = const Color(0xFFCFE6F6);
        textColor = const Color(0xFF0B5FA5);
    }
    // No escuro os pasteis claros viram manchas brilhantes: o chip passa a ser
    // o proprio texto clareado sobre um veu da mesma cor, igual ao badge().
    if (Theme.of(context).brightness == Brightness.dark) {
      final fg = accentForeground(context, textColor);
      bgColor = fg.withValues(alpha: 0.16);
      borderColor = fg.withValues(alpha: 0.42);
      textColor = fg;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static BoxDecoration reactionOverlayDecoration(ColorScheme colorScheme) {
    return BoxDecoration(
      color: cardSurfaceColor(colorScheme),
      borderRadius: BorderRadius.circular(999),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.14),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
      border: Border.all(color: colorScheme.outline.withValues(alpha: 0.10)),
    );
  }

  static Widget classifiedBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF2D797)),
      ),
      child: const Text(
        'Classificado',
        style: TextStyle(
          color: Color(0xFF8A5B00),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static Widget amberBadge(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFF2D797)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF9A6A18),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static Color devotionalAccent(BuildContext context, String? category) {
    switch (category?.toLowerCase()) {
      case 'domingo':
        return const Color(0xFF0B5FA5);
      case 'quarta':
      case 'quarta-feira':
        return const Color(0xFF1D6E45);
      case 'especial':
        return const Color(0xFF5A3BA6);
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  /// Ajusta uma cor de destaque para uso como *texto* no tema escuro.
  ///
  /// Os accents dos badges sao escuros de proposito (0xFF4E6B85, 0xFF5A3BA6…)
  /// porque no claro eles vao sobre um fundo `accent.withOpacity(0.12)` quase
  /// branco. No escuro esse mesmo fundo fica praticamente preto e o texto
  /// escuro sumia — entao aqui a cor e clareada ate um piso de luminosidade.
  static Color accentForeground(BuildContext context, Color color) {
    if (Theme.of(context).brightness != Brightness.dark) return color;
    final hsl = HSLColor.fromColor(color);
    if (hsl.lightness >= 0.7) return color;
    return hsl
        .withLightness(0.74)
        .withSaturation(hsl.saturation.clamp(0.0, 0.7))
        .toColor();
  }

  static Widget badge(
    BuildContext context,
    String label,
    Color color, {
    IconData? icon,
    double iconSize = 12,
  }) {
    final fg = accentForeground(context, color);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: isDark ? 0.42 : 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  static ThemeData getTheme(BuildContext context) {
    // Compatibilidade com as telas que ainda envolvem seu corpo em Theme.
    // A paleta e os controles agora pertencem ao tema global, inclusive no
    // Financeiro e na Comunidade: este helper não deve criar outro tema.
    return Theme.of(context);
  }
}
