import 'package:flutter/material.dart';

typedef NavIconBuilder = Widget Function(
  BuildContext context,
  bool isActive,
  Color activeColor,
);

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
          final item = items[index];
          final activeColor = item.activeColor;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(index),
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 44,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: isActive
                            ? LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color.lerp(Colors.white, activeColor, 0.26)!,
                                  Color.lerp(Colors.white, activeColor, 0.10)!,
                                  Color.lerp(Colors.white, activeColor, 0.20)!,
                                ],
                              )
                            : null,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: activeColor.withValues(alpha: 0.30),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (isActive)
                              Positioned(
                                top: 1,
                                left: 5,
                                right: 5,
                                height: 13,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.85),
                                        Colors.white.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            item.iconBuilder?.call(context, isActive, activeColor) ??
                                Icon(
                                  item.icon,
                                  size: 26,
                                  color: isActive
                                      ? activeColor
                                      : Colors.grey.shade500,
                                ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10, // Slight reduction for better fit
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? activeColor
                              : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
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
