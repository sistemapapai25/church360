import 'package:flutter/material.dart';

import 'pearl_glass_dock.dart';

typedef NavIconBuilder = Widget Function(
  BuildContext context,
  bool isActive,
  Color activeColor,
);

/// Dock de vidro com os 5 itens sempre na mesma família Pearl — só a
/// intensidade muda entre repouso, hover e selecionado. Validado antes no
/// playground isolado (`lib/dev/pearl_button_playground.dart`).
class PremiumBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<PremiumNavItem> items;

  const PremiumBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return PearlGlassDock(
      dark: dark,
      children: List.generate(items.length, (index) {
        final selected = currentIndex == index;
        final item = items[index];

        return Expanded(
          child: Center(
            child: PearlDockItem(
              contentBuilder: (context, isSelected, activeColor) =>
                  item.iconBuilder?.call(context, isSelected, activeColor) ??
                  Icon(item.icon, size: 18, color: Colors.white),
              label: item.label,
              color: item.activeColor,
              selected: selected,
              // Nomes desligados por enquanto — mesma decisão validada no
              // playground antes de trazer pra cá.
              showLabel: false,
              dark: dark,
              onTap: () => onTap(index),
            ),
          ),
        );
      }),
    );
  }
}

class PremiumNavItem {
  final String label;
  final IconData? icon;
  final NavIconBuilder? iconBuilder;
  final Color activeColor;

  const PremiumNavItem({
    required this.label,
    required this.activeColor,
    this.icon,
    this.iconBuilder,
  });
}
