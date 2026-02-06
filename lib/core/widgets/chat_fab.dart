import 'package:flutter/material.dart';

/// Botão flutuante padronizado para agentes (Suporte, Financeiro, Pastoral, etc.)
class FloatingAgentButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final List<Color> gradientColors;
  final double size;
  final double iconSize;

  const FloatingAgentButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.gradientColors = const [Color(0xff3F8CFF), Color(0xff6A4DFF)],
    this.size = 65,
    this.iconSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            color: Colors.white,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}

/// Botão de Suporte oficial (Wrapper do FloatingAgentButton)
class SupportButton extends StatelessWidget {
  final VoidCallback? onTap;

  const SupportButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return FloatingAgentButton(
      icon: Icons.support_agent,
      onTap: onTap ?? () {},
      gradientColors: const [Color(0xff3F8CFF), Color(0xff6A4DFF)],
    );
  }
}
