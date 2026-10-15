import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_icons.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../providers/onboarding_provider.dart';

/// Card "Primeiros passos" no topo da Dashboard (F1): só para quem tem
/// `church_info.edit`, some quando tudo estiver feito ou quando a pessoa
/// dispensar. Erro de carga = não mostra (a Dashboard não depende dele).
class OnboardingDashboardCard extends ConsumerWidget {
  const OnboardingDashboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = ref
        .watch(currentUserHasPermissionProvider('church_info.edit'))
        .value;
    if (canEdit != true) return const SizedBox.shrink();

    final status = ref.watch(onboardingStatusProvider).value;
    if (status == null || status.done || status.dismissed) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        key: const ValueKey('onboarding-card'),
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(AppIcons.checklist, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Primeiros passos: ${status.doneCount} de ${status.total}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: status.doneCount / status.total,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Nome e logo, local, cultos, ministérios, prioridades e liderança.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const ValueKey('onboarding-dismiss'),
                    onPressed: () async {
                      try {
                        await ref
                            .read(onboardingRepositoryProvider)
                            .setStep('dismissed', true);
                      } catch (_) {}
                      ref.invalidate(onboardingStatusProvider);
                    },
                    child: const Text('Dispensar'),
                  ),
                  FilledButton(
                    key: const ValueKey('onboarding-continue'),
                    onPressed: () async {
                      await context.push('/primeiros-passos');
                      ref.invalidate(onboardingStatusProvider);
                    },
                    child: const Text('Continuar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
