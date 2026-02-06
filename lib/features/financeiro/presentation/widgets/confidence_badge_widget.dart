import 'package:flutter/material.dart';
import '../../domain/models/financial_attachment.dart';

/// Widget que exibe um badge de confiança baseado no confidence score
class ConfidenceBadgeWidget extends StatelessWidget {
  final ConfidenceLevel level;
  final double? score;

  const ConfidenceBadgeWidget({
    super.key,
    required this.level,
    this.score,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.1),
        border: Border.all(color: config.color, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            size: 14,
            color: config.color,
          ),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: config.color,
            ),
          ),
          if (score != null) ...[
            const SizedBox(width: 4),
            Text(
              '${(score! * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: config.color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  _BadgeConfig _getConfig() {
    switch (level) {
      case ConfidenceLevel.high:
        return _BadgeConfig(
          label: 'Alta Confiança',
          color: const Color(0xFF4CAF50), // Verde
          icon: Icons.check_circle,
        );
      case ConfidenceLevel.medium:
        return _BadgeConfig(
          label: 'Média Confiança',
          color: const Color(0xFFFFA726), // Laranja
          icon: Icons.warning_amber,
        );
      case ConfidenceLevel.low:
        return _BadgeConfig(
          label: 'Baixa Confiança',
          color: const Color(0xFFF44336), // Vermelho
          icon: Icons.error_outline,
        );
      case ConfidenceLevel.unknown:
        return _BadgeConfig(
          label: 'Desconhecido',
          color: const Color(0xFF9E9E9E), // Cinza
          icon: Icons.help_outline,
        );
    }
  }
}

class _BadgeConfig {
  final String label;
  final Color color;
  final IconData icon;

  _BadgeConfig({
    required this.label,
    required this.color,
    required this.icon,
  });
}

/// Widget que indica que um valor foi sugerido pela IA
class AiSuggestedBadge extends StatelessWidget {
  const AiSuggestedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 12,
            color: const Color(0xFF2196F3),
          ),
          const SizedBox(width: 4),
          Text(
            'IA',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2196F3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget que exibe um aviso de possível duplicata
class DuplicateWarningWidget extends StatelessWidget {
  final VoidCallback? onViewDuplicate;

  const DuplicateWarningWidget({
    super.key,
    this.onViewDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        border: Border.all(color: const Color(0xFFFF9800), width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: const Color(0xFFFF9800),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Possível Duplicata',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE65100),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Encontramos um lançamento similar no sistema',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFFE65100).withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          if (onViewDuplicate != null)
            TextButton(
              onPressed: onViewDuplicate,
              child: Text('Ver'),
            ),
        ],
      ),
    );
  }
}
