import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/design/community_design.dart';
import '../../../presentation/providers/ministries_provider.dart';
import '../../../shared/presentation/widgets/ministry_submodule_guard.dart';
import '../../domain/models/raizes_dashboard_stats.dart';
import '../providers/raizes_dashboard_provider.dart';

/// Dashboard do módulo Raízes (Lote 4A).
///
/// KPIs vêm de `user_account` (visitantes/new_convert) sem depender de
/// tabelas novas. Agenda de visitas (4B), sugestões e padrinhos (4C) e
/// integração com Diaconato (5A) permanecem como placeholders no rodapé.
class RaizesHomeScreen extends ConsumerWidget {
  final String ministryId;

  const RaizesHomeScreen({super.key, required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MinistrySubmoduleGuard(
      ministryId: ministryId,
      requiredPermission: 'raizes.view',
      submoduleLabel: 'Raízes',
      builder: (context) => _RaizesContent(ministryId: ministryId),
    );
  }
}

class _RaizesContent extends ConsumerStatefulWidget {
  final String ministryId;

  const _RaizesContent({required this.ministryId});

  @override
  ConsumerState<_RaizesContent> createState() => _RaizesContentState();
}

class _RaizesContentState extends ConsumerState<_RaizesContent> {
  @override
  void initState() {
    super.initState();
    // Dispara o despacho de lembretes server-side ao entrar no módulo.
    // Idempotente via reminder_app_sent_at — falha silenciosa para não bloquear UI.
    // Após o despacho, invalida o KPI provider para refletir as visitas marcadas
    // como notificadas (não afeta contagens, mas é seguro).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final repo = ref.read(raizesRepositoryProvider);
      repo.dispatchVisitReminders().then((created) {
        if (created > 0 && mounted) {
          ref.invalidate(raizesDashboardStatsProvider(widget.ministryId));
        }
      }).catchError((_) {
        // Silencioso: o usuário ainda vê o dashboard; lembrete não bloqueia.
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final ministryId = widget.ministryId;
    final ministryAsync = ref.watch(ministryByIdProvider(ministryId));
    final statsAsync = ref.watch(raizesDashboardStatsProvider(ministryId));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: ministryAsync.maybeWhen(
          data: (m) => Text(m?.name ?? 'Raízes'),
          orElse: () => const Text('Raízes'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
            onPressed: () =>
                ref.invalidate(raizesDashboardStatsProvider(ministryId)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(raizesDashboardStatsProvider(ministryId));
          await ref.read(raizesDashboardStatsProvider(ministryId).future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              'Dashboard',
              style: CommunityDesign.titleStyle(context)
                  .copyWith(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            statsAsync.when(
              data: (stats) => _StatsGrid(stats: stats),
              loading: () => const _StatsGridSkeleton(),
              error: (error, _) => _StatsError(
                message: '$error',
                onRetry: () =>
                    ref.invalidate(raizesDashboardStatsProvider(ministryId)),
              ),
            ),
            const SizedBox(height: 24),
            _PrimaryActionCard(
              icon: Icons.event_available_outlined,
              title: 'Agenda de visitas',
              description:
                  'Criar visitas, atribuir responsáveis e acompanhar status. Lembretes internos disparam ao abrir este módulo.',
              onTap: () => context.push(
                  '/ministries/$ministryId/raizes/visits'),
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 12),
            _PrimaryActionCard(
              icon: Icons.person_search,
              title: 'Ver visitantes',
              description:
                  'Abrir a lista completa de visitantes com os filtros do Raízes (primeira visita, salvação, follow-up, faixa etária).',
              onTap: () => context.push('/visitors'),
              color: colorScheme.primary,
            ),
            const SizedBox(height: 12),
            _PrimaryActionCard(
              icon: Icons.person_add_alt_1,
              title: 'Cadastrar novo visitante',
              description:
                  'Abre o formulário pré-configurado para visitantes.',
              onTap: () => context.push(
                  '/members/new?status=visitor&type=visitante'),
              color: colorScheme.tertiary,
            ),
            const SizedBox(height: 24),
            Text(
              'Em breve',
              style: CommunityDesign.titleStyle(context)
                  .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const _PlaceholderCard(
              icon: Icons.recommend_outlined,
              title: 'Indicações e padrinhos',
              description:
                  'Sugestões sociais por perfil, padrinhos do Raízes e WhatsApp via /dispatch-config. Lote 4C.',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final RaizesDashboardStats stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = <_StatItem>[
      _StatItem(
        title: 'Visitas hoje',
        value: stats.visitsToday,
        icon: Icons.today_outlined,
        color: Colors.deepPurple,
      ),
      _StatItem(
        title: 'Visitas atrasadas',
        value: stats.visitsOverdue,
        icon: Icons.event_busy_outlined,
        color: Colors.red,
      ),
      _StatItem(
        title: 'Visitantes ativos',
        value: stats.totalActiveVisitors,
        icon: Icons.groups_2_outlined,
        color: Colors.indigo,
      ),
      _StatItem(
        title: 'Querem contato',
        value: stats.wantingContactPending,
        icon: Icons.mark_chat_unread_outlined,
        color: Colors.orange,
      ),
      _StatItem(
        title: 'Sem padrinho',
        value: stats.withoutMentor,
        icon: Icons.person_off_outlined,
        color: Colors.redAccent,
      ),
      _StatItem(
        title: 'Decisões (30d)',
        value: stats.newSalvationsLast30Days,
        icon: Icons.favorite_outline,
        color: Colors.pink,
      ),
      _StatItem(
        title: 'Novos visitantes (30d)',
        value: stats.newVisitorsLast30Days,
        icon: Icons.fiber_new_outlined,
        color: Colors.teal,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: items.map((it) => _StatCard(item: it)).toList(),
    );
  }
}

class _StatsGridSkeleton extends StatelessWidget {
  const _StatsGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: List.generate(
        4,
        (_) => Container(
          decoration: CommunityDesign.overlayDecoration(
            Theme.of(context).colorScheme,
          ),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _StatsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CommunityDesign.overlayDecoration(
        Theme.of(context).colorScheme,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Falha ao carregar KPIs',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: CommunityDesign.metaStyle(context),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Tentar de novo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  final String title;
  final int value;
  final IconData icon;
  final Color color;

  _StatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: CommunityDesign.overlayDecoration(
        Theme.of(context).colorScheme,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(item.icon, color: item.color, size: 22),
              const Spacer(),
              Text(
                '${item.value}',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: item.color,
                ),
              ),
            ],
          ),
          Text(
            item.title,
            style: CommunityDesign.metaStyle(context)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Color color;

  const _PrimaryActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: CommunityDesign.overlayDecoration(
          Theme.of(context).colorScheme,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: CommunityDesign.titleStyle(context).copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: CommunityDesign.metaStyle(context),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
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
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: CommunityDesign.titleStyle(context).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
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
