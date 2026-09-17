import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_mode_provider.dart';

/// Liga/desliga do modo escuro.
///
/// Segue o padrao Claude Design para botoes de estado: pilula de trilho
/// (radius total), thumb circular com o icone do estado atual, transicao curta
/// e acento sobrio — sem borda pesada, sem sombra dura, alvo de toque cheio.
///
/// O estado exibido e o **efetivo** (`Theme.of(context).brightness`), nao o
/// valor bruto do provider: enquanto ninguem tocou, a preferencia e
/// `ThemeMode.system` e o toggle mostra o que o sistema decidiu. O primeiro
/// toque grava `light` ou `dark` explicito.
class ThemeModeSelector extends ConsumerWidget {
  const ThemeModeSelector({super.key, this.padding, this.compact = false});

  final EdgeInsetsGeometry? padding;

  /// No drawer o espaco e estreito: mostra so o botao, sem o rotulo.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    void toggle() {
      ref
          .read(themeModeProvider.notifier)
          .setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
    }

    final toggleButton = _ThemeToggleButton(isDark: isDark, onTap: toggle);

    final content = compact
        ? toggleButton
        : Row(
            children: [
              Expanded(
                child: Text(
                  'Modo escuro',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 12),
              toggleButton,
            ],
          );

    if (padding == null) return content;
    return Padding(padding: padding!, child: content);
  }
}

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton({required this.isDark, required this.onTap});

  final bool isDark;
  final VoidCallback onTap;

  static const double _trackWidth = 56;
  static const double _trackHeight = 32;
  static const double _thumbSize = 26;
  static const Duration _duration = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final trackColor = isDark
        ? cs.primary
        : cs.onSurface.withValues(alpha: 0.12);

    return Semantics(
      toggled: isDark,
      label: 'Modo escuro',
      child: Tooltip(
        message: isDark ? 'Desativar modo escuro' : 'Ativar modo escuro',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: _duration,
            curve: Curves.easeOut,
            width: _trackWidth,
            height: _trackHeight,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(999),
            ),
            child: AnimatedAlign(
              duration: _duration,
              curve: Curves.easeOut,
              alignment: isDark
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                width: _thumbSize,
                height: _thumbSize,
                decoration: BoxDecoration(
                  color: cs.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: _duration,
                  child: Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                    key: ValueKey<bool>(isDark),
                    size: 16,
                    color: isDark ? cs.primary : cs.onSurfaceVariant,
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
