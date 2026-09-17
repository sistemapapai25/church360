import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia de tema do app (claro / escuro / sistema), persistida em
/// SharedPreferences.
///
/// O default e [ThemeMode.system] para nao mudar o que o usuario ja ve hoje:
/// antes desta tela o app seguia o sistema de forma fixa.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  static const String prefsKey = 'app_theme_mode';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(prefsKey);
      if (stored == null) return;
      state = _decode(stored);
    } catch (error, stack) {
      // Preferencia de tema nunca pode derrubar o boot do app.
      debugPrint('Falha ao ler preferencia de tema: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, _encode(mode));
    } catch (error, stack) {
      debugPrint('Falha ao salvar preferencia de tema: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeMode _decode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);
