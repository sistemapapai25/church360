import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Uma aba da barra [AppTabs].
class AppTab {
  final String label;

  /// Contador opcional exibido ao lado do rotulo. Texto livre de proposito:
  /// tanto `9` quanto `10/41` aparecem no desenho de referencia.
  final String? count;

  final IconData? icon;

  const AppTab({required this.label, this.count, this.icon});
}

/// Barra de sub-abas em pilula, com contador opcional por aba.
///
/// Agrupa sub-secoes de uma MESMA tela de gestao (Alunos / Checklist /
/// Presenca / WhatsApp / Relatorios de uma turma). Nao substitui a
/// navegacao principal do app nem o `TabBar` do Material em telas que ja
/// usam `TabController`.
///
/// Receita do sistema de design (componente Tabs): trilha em pilula com
/// fundo `muted` e borda `border`; aba ativa com fundo `primary` e texto
/// `primaryForeground`, contador em selo branco translucido; abas inativas
/// em `mutedForeground`, contador com fundo `border`.
///
/// A barra rola na horizontal: com cinco abas ela nao cabe na largura de um
/// celular, e cortar a quinta aba esconderia uma secao inteira.
class AppTabs extends StatelessWidget {
  final List<AppTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Alinhamento quando a barra cabe inteira na largura disponivel.
  final AlignmentGeometry alignment;

  const AppTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final track = dark ? AppTheme.darkInput : AppTheme.muted;
    final borderColor = dark ? AppTheme.darkBorder : AppTheme.border;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.zero,
      child: Align(
        alignment: alignment,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: track,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < tabs.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                _AppTabPill(
                  tab: tabs[i],
                  selected: i == selectedIndex,
                  onTap: () => onChanged(i),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AppTabPill extends StatelessWidget {
  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  const _AppTabPill({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(999);

    final foreground = selected
        ? AppTheme.primaryForeground
        : (dark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground);

    // O contador da aba ativa e um veu branco sobre o azul; o das inativas
    // usa `border` como fundo, com o texto na cor de leitura do tema — no
    // escuro, `foreground` claro, nunca o `#0F172A` do tema claro.
    final counterBackground = selected
        ? Colors.white.withValues(alpha: 0.28)
        : (dark ? AppTheme.darkBorder : AppTheme.border);
    final counterForeground = selected
        ? AppTheme.primaryForeground
        : (dark ? AppTheme.darkForeground : AppTheme.foreground);

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: radius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tab.icon != null) ...[
                Icon(tab.icon, size: 15, color: foreground),
                const SizedBox(width: 6),
              ],
              Text(
                tab.label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  height: 1.2,
                ),
              ),
              if (tab.count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: counterBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tab.count!,
                    style: TextStyle(
                      color: counterForeground,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
