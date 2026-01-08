import 'package:flutter/material.dart';

class CommunityDesign {
  static const Color backgroundColor = Color(0xFFF5F9FD);
  static const double radius = 18;
  static const double compactImageHeight = 160;
  static const double gridSpacing = 16;
  static const double gridTargetItemWidth = 270;
  static const double gridMainAxisExtentCompact = 520;

  static Color scaffoldBackgroundColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? theme.scaffoldBackgroundColor
        : backgroundColor;
  }

  static Color headerColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface
        : backgroundColor;
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

  static BoxDecoration overlayDecoration(
    ColorScheme colorScheme, {
    bool hovered = false,
  }) {
    return BoxDecoration(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [hovered ? overlayHoverShadow() : overlayBaseShadow()],
    );
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
      color: colorScheme.surface,
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

  static Widget badge(
    BuildContext context,
    String label,
    Color color, {
    IconData? icon,
    double iconSize = 12,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
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
    final base = Theme.of(context);
    if (base.brightness == Brightness.dark) return base;

    const primary = Color(0xFF0B5FA5);
    const secondary = Color(0xFF1787C9);
    const tertiary = Color(0xFF41D3F2);
    const surface = Color(0xFFFFFFFF);
    const bg = Color(0xFFF3F6FA);

    final scheme = base.colorScheme.copyWith(
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      tertiary: tertiary,
      onTertiary: Colors.black,
      surface: surface,
      surfaceContainerHighest: bg,
      primaryContainer: const Color(0xFFD6E9F7),
      onPrimaryContainer: const Color(0xFF0A3557),
      secondaryContainer: const Color(0xFFCFEAFA),
      onSecondaryContainer: const Color(0xFF08324A),
      tertiaryContainer: const Color(0xFFCEF6FE),
      onTertiaryContainer: const Color(0xFF043A45),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: scheme.primary.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: const Color(0xFFF5F9FD), // Matches Community App Bar
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 1, // Slight elevation as per Community design
        shadowColor: Colors.black.withValues(alpha: 0.08),
        scrolledUnderElevation: 2,
      ),
      tabBarTheme: base.tabBarTheme.copyWith(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
      ),
    );
  }
}
