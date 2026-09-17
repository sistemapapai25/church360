import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_mode_provider.dart';

/// Seletor de tema (Claro / Escuro / Sistema).
///
/// Usado na aba "Mais" (celular) e no drawer da dashboard (desktop), para que a
/// preferencia esteja no mesmo lugar nos dois caminhos de uso.
class ThemeModeSelector extends ConsumerWidget {
  const ThemeModeSelector({
    super.key,
    this.padding,
    this.compact = false,
  });

  final EdgeInsetsGeometry? padding;

  /// No drawer o espaco e estreito: mostra so os icones (com tooltip) para o
  /// botao nao estourar a largura.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    final selector = SegmentedButton<ThemeMode>(
      segments: [
        ButtonSegment(
          value: ThemeMode.light,
          icon: const Icon(Icons.light_mode_outlined),
          label: compact ? null : const Text('Claro'),
          tooltip: 'Claro',
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: const Icon(Icons.dark_mode_outlined),
          label: compact ? null : const Text('Escuro'),
          tooltip: 'Escuro',
        ),
        ButtonSegment(
          value: ThemeMode.system,
          icon: const Icon(Icons.brightness_auto_outlined),
          label: compact ? null : const Text('Sistema'),
          tooltip: 'Seguir o sistema',
        ),
      ],
      selected: {mode},
      showSelectedIcon: false,
      style: compact
          ? SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            )
          : null,
      onSelectionChanged: (selection) {
        ref.read(themeModeProvider.notifier).setThemeMode(selection.first);
      },
    );

    if (padding == null) return selector;
    return Padding(padding: padding!, child: selector);
  }
}
