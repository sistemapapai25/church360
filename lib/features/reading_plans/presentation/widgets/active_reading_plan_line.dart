import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_icons.dart';
import '../../domain/models/reading_plan.dart';

/// Linha do plano de leitura em andamento da pessoa, no card "Para sua
/// edificação" da Home (C2): "Dia N de T · Ler hoje". Tocar abre o módulo do
/// dia (`/reading-plans/:id/modules/:day`).
class ActiveReadingPlanLine extends StatelessWidget {
  final ActiveReadingPlan data;

  /// Injetável para teste; o padrão navega com `context.push`.
  final void Function(String route)? onNavigate;

  const ActiveReadingPlanLine({super.key, required this.data, this.onNavigate});

  /// Dia a abrir: o atual do progresso, preso entre 1 e o total do plano.
  static int dayToOpen(ActiveReadingPlan data) {
    final total = data.plan.totalModules < 1 ? 1 : data.plan.totalModules;
    final day = data.progress.currentDay;
    return day < 1 ? 1 : (day > total ? total : day);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final day = dayToOpen(data);
    final total = data.plan.totalModules < 1 ? 1 : data.plan.totalModules;
    final route = '/reading-plans/${data.plan.id}/modules/$day';

    return Material(
      color: cs.primaryContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const ValueKey('active-reading-plan-line'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => (onNavigate ?? context.push)(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(AppIcons.book, color: cs.onPrimaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.plan.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      'Dia $day de $total · Ler hoje',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onPrimaryContainer.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(AppIcons.forward, size: 16, color: cs.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}
