import 'package:flutter/material.dart';

class PremiumBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const PremiumBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final items = const [
    _NavItemData("Devocionais", Icons.menu_book),
    _NavItemData("Agenda", Icons.event),
    _NavItemData("Home", Icons.home_rounded),
    _NavItemData("Contribua", Icons.volunteer_activism),
    _NavItemData("Mais", Icons.menu),
  ];

  final activeColors = const [
    Color(0xFF2F80ED), // Devocionais
    Color(0xFFF2994A), // Agenda
    Color(0xFF1F3C88), // Home
    Color(0xFF27AE60), // Contribua
    Color(0xFF9B51E0), // Mais (Roxo)
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80, // Aumentado para evitar overflow e melhorar toque
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, -2),
            blurRadius: 15,
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (index) {
          final isActive = currentIndex == index;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(index),
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? activeColors[index].withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[index].icon,
                        size: 26,
                        color: isActive
                            ? activeColors[index]
                            : Colors.grey.shade500,
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          items[index].label,
                          style: TextStyle(
                            fontSize: 10, // Slight reduction for better fit
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? activeColors[index]
                                : Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItemData {
  final String label;
  final IconData icon;

  const _NavItemData(this.label, this.icon);
}
