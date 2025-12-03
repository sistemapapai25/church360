import 'package:flutter/material.dart';

/// Tema da aplicação Church 360
/// Baseado em Material Design 3
class AppTheme {
  // Cores principais
  static const Color primaryColor = Color(0xFF3B82F6); // Azul
  static const Color secondaryColor = Color(0xFF10B981); // Verde
  static const Color errorColor = Color(0xFFEF4444); // Vermelho
  static const Color warningColor = Color(0xFFF59E0B); // Amarelo
  static const Color successColor = Color(0xFF10B981); // Verde

  static final Color background = HSLColor.fromAHSL(1.0, 250, 0.5, 0.98).toColor();
  static final Color foreground = HSLColor.fromAHSL(1.0, 240, 0.10, 0.15).toColor();
  static final Color card = HSLColor.fromAHSL(1.0, 0, 0.0, 1.0).toColor();
  static final Color cardForeground = HSLColor.fromAHSL(1.0, 240, 0.10, 0.15).toColor();
  static final Color primary = HSLColor.fromAHSL(1.0, 240, 0.60, 0.50).toColor();
  static final Color primaryForeground = HSLColor.fromAHSL(1.0, 0, 0.0, 1.0).toColor();
  static final Color primaryHover = HSLColor.fromAHSL(1.0, 240, 0.60, 0.45).toColor();
  static final Color secondary = HSLColor.fromAHSL(1.0, 250, 0.25, 0.95).toColor();
  static final Color secondaryForeground = HSLColor.fromAHSL(1.0, 240, 0.10, 0.15).toColor();
  static final Color muted = HSLColor.fromAHSL(1.0, 250, 0.25, 0.96).toColor();
  static final Color mutedForeground = HSLColor.fromAHSL(1.0, 240, 0.08, 0.50).toColor();
  static final Color accent = HSLColor.fromAHSL(1.0, 260, 0.50, 0.92).toColor();
  static final Color accentForeground = HSLColor.fromAHSL(1.0, 260, 0.50, 0.25).toColor();
  static final Color success = HSLColor.fromAHSL(1.0, 145, 0.60, 0.45).toColor();
  static final Color border = HSLColor.fromAHSL(1.0, 250, 0.20, 0.88).toColor();
  static final Color input = HSLColor.fromAHSL(1.0, 250, 0.20, 0.90).toColor();
  static final Color ring = HSLColor.fromAHSL(1.0, 240, 0.60, 0.50).toColor();

  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(12));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(10));
  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(8));

  static const LinearGradient gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF3B82F6),
      Color(0xFF7C4DFF),
    ],
    stops: [0.0, 1.0],
  );

  static final LinearGradient gradientSubtle = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      HSLColor.fromAHSL(1.0, 250, 0.50, 0.98).toColor(),
      HSLColor.fromAHSL(1.0, 250, 0.25, 0.95).toColor(),
    ],
  );

  static final LinearGradient gradientCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      HSLColor.fromAHSL(1.0, 0, 0.0, 1.0).toColor(),
      HSLColor.fromAHSL(1.0, 250, 0.25, 0.97).toColor(),
    ],
  );

  static final BoxShadow shadowSm = BoxShadow(
    color: HSLColor.fromAHSL(0.08, 240, 0.20, 0.20).toColor(),
    blurRadius: 8,
    spreadRadius: 0,
    offset: const Offset(0, 2),
  );

  static final BoxShadow shadowMd = BoxShadow(
    color: HSLColor.fromAHSL(0.12, 240, 0.20, 0.20).toColor(),
    blurRadius: 24,
    spreadRadius: 0,
    offset: const Offset(0, 8),
  );

  static final BoxShadow shadowLg = BoxShadow(
    color: HSLColor.fromAHSL(0.16, 240, 0.20, 0.20).toColor(),
    blurRadius: 40,
    spreadRadius: 0,
    offset: const Offset(0, 16),
  );

  static final BoxShadow shadowPrimary = BoxShadow(
    color: primary.withValues(alpha: 0.2),
    blurRadius: 24,
    spreadRadius: 0,
    offset: const Offset(0, 8),
  );

  /// Tema claro
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    
    // Color Scheme
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
      brightness: Brightness.light,
    ),
    
    // AppBar
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 2,
    ),
    
    // Card
    cardTheme: CardThemeData(
      elevation: 2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    
    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: input,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ring, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    ),
    
    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    
    // Floating Action Button
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
  );

  /// Tema escuro
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    
    // Color Scheme
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
      brightness: Brightness.dark,
    ),
    
    // AppBar
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 2,
    ),
    
    // Card
    cardTheme: CardThemeData(
      elevation: 2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    
    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: input,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ring, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    ),
    
    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    
    // Floating Action Button
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
  );
}
