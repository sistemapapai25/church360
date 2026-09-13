import 'package:flutter/material.dart';

/// Tema da aplicação Church 360
/// Baseado em Material Design 3
class AppTheme {
  // Cores principais
  static const Color primaryColor = Color(0xFF2563EB); // Azul principal
  static const Color secondaryColor = Color(0xFF1F5E7A); // Azul petróleo
  static const Color aquaColor = Color(
    0xFF7DD3FC,
  ); // Detalhe, usado com parcimônia
  static const Color errorColor = Color(0xFFEF4444); // Vermelho
  static const Color warningColor = Color(0xFFF59E0B); // Amarelo
  static const Color successColor = Color(0xFF10B981); // Verde

  static const Color background = Color(0xFFF8FAFC);
  static const Color foreground = Color(0xFF0F172A);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardForeground = Color(0xFF0F172A);
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryForeground = Color(0xFFFFFFFF);
  static const Color primaryHover = Color(0xFF1D4ED8);
  static const Color secondary = Color(0xFF1F5E7A);
  static const Color secondaryForeground = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFFF1F5F9);
  static const Color mutedForeground = Color(0xFF64748B);
  static const Color accent = Color(0xFFDBEAFE);
  static const Color accentForeground = Color(0xFF1E3A8A);
  static const Color success = Color(0xFF16A34A);
  static const Color border = Color(0xFFCBD5E1);
  static const Color input = Color(0xFFF8FAFC);
  static const Color ring = Color(0xFF2563EB);

  static final ColorScheme _lightColorScheme = ColorScheme.fromSeed(
    seedColor: primaryColor,
    secondary: secondaryColor,
    error: errorColor,
    brightness: Brightness.light,
  ).copyWith(surface: card);

  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(12));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(10));
  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(8));

  static const LinearGradient gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
    stops: [0.0, 1.0],
  );

  static const LinearGradient gradientSubtle = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
  );

  static const LinearGradient gradientCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
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
    colorScheme: _lightColorScheme,
    cardColor: card,

    // AppBar
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 2,
      surfaceTintColor: Colors.transparent,
    ),

    // Card
    cardTheme: CardThemeData(
      color: card,
      elevation: 2,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),

    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      surfaceTintColor: Colors.transparent,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),

    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
