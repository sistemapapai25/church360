import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/design/community_design.dart';
import '../../../presentation/providers/ministries_provider.dart';
import '../../../shared/presentation/widgets/ministry_submodule_guard.dart';

/// Placeholder do módulo Diaconato. Funcionalidade real (checklist de presença,
/// ausentes, ceia) entra nos sub-lotes 5A/5B.
class DiaconatoHomeScreen extends ConsumerWidget {
  final String ministryId;

  const DiaconatoHomeScreen({super.key, required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MinistrySubmoduleGuard(
      ministryId: ministryId,
      requiredPermission: 'diaconato.view',
      submoduleLabel: 'Diaconato',
      builder: (context) => _DiaconatoContent(ministryId: ministryId),
    );
  }
}

class _DiaconatoContent extends ConsumerWidget {
  final String ministryId;

  const _DiaconatoContent({required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ministryAsync = ref.watch(ministryByIdProvider(ministryId));

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: ministryAsync.maybeWhen(
          data: (m) => Text(m?.name ?? 'Diaconato'),
          orElse: () => const Text('Diaconato'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _PlaceholderCard(
            icon: Icons.dashboard_outlined,
            title: 'Dashboard Diaconato',
            description:
                'Presença por culto, visitantes não cadastrados, pedidos de ceia pendentes e entregas atribuídas. Lote 5A.',
          ),
          const SizedBox(height: 16),
          _PlaceholderCard(
            icon: Icons.checklist_outlined,
            title: 'Checklist de presença',
            description:
                'Membros primeiro, visitantes cadastrados depois, contagem de não cadastrados. Lote 5A.',
          ),
          const SizedBox(height: 16),
          _PlaceholderCard(
            icon: Icons.call_missed_outgoing_outlined,
            title: 'Ausentes',
            description:
                'Triagem dos ausentes: sem ação, ligação, ceia, ou ambos. Lote 5B.',
          ),
          const SizedBox(height: 16),
          _PlaceholderCard(
            icon: Icons.takeout_dining_outlined,
            title: 'Lotes de ceia',
            description:
                'Lote por culto com responsável, status e integração WhatsApp via /dispatch-config. Lote 5B.',
          ),
        ],
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PlaceholderCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: CommunityDesign.overlayDecoration(
        Theme.of(context).colorScheme,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: CommunityDesign.titleStyle(context).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: CommunityDesign.metaStyle(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
