import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../../core/design/app_icons.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../presentation/providers/ministries_provider.dart';
import '../../../shared/presentation/widgets/ministry_finance_tab.dart';
import '../../../shared/presentation/widgets/ministry_whatsapp_tab.dart';
import '../../../shared/presentation/widgets/ministry_reports_tab.dart';
import '../../../shared/presentation/widgets/ministry_scale_tab.dart';
import '../../../shared/presentation/widgets/ministry_submodule_guard.dart';
import '../../../shared/presentation/widgets/ministry_team_tab.dart';
import '../../../shared/presentation/widgets/ministry_workspace_shell.dart';
import '../../domain/models/raizes_dashboard_stats.dart';
import '../providers/raizes_dashboard_provider.dart';

/// Workspace do Raízes — o mesmo esqueleto do Batismo, com uma aba a mais.
///
/// O que era a tela inteira do módulo (KPIs de visitantes e os atalhos para
/// visitas, padrinhos e indicações) virou a aba **Painel**, e passou a
/// conviver com Equipe, Escala, Financeiro, WhatsApp e Relatórios, que são as
/// mesmas de qualquer ministério. Nada de layout mora aqui: o cabeçalho, o
/// voltar e a barra de abas vêm do [MinistryWorkspaceShell].
///
/// O Financeiro entrou de graça nessa mudança — o caixa do departamento é
/// da base, e o Raízes só não o mostrava por não estar no shell.
class RaizesHomeScreen extends ConsumerWidget {
  final String ministryId;

  const RaizesHomeScreen({super.key, required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MinistrySubmoduleGuard(
      ministryId: ministryId,
      requiredPermission: 'raizes.view',
      submoduleLabel: 'Raízes',
      builder: (context) => _RaizesWorkspace(ministryId: ministryId),
    );
  }
}

class _RaizesWorkspace extends ConsumerWidget {
  final String ministryId;

  const _RaizesWorkspace({required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamCount = ref
        .watch(ministryMembersProvider(ministryId))
        .maybeWhen(data: (m) => m.length, orElse: () => null);
    final stats = ref
        .watch(raizesDashboardStatsProvider(ministryId))
        .maybeWhen(data: (s) => s, orElse: () => null);

    return MinistryWorkspaceShell(
      ministryId: ministryId,
      fallbackTitle: 'Raízes',
      stats: [
        if (stats != null)
          MinistryWorkspaceStat(
            label: 'visitas hoje',
            value: '${stats.visitsToday}',
            icon: AppIcons.today,
          ),
        if (stats != null && stats.visitsOverdue > 0)
          MinistryWorkspaceStat(
            label: 'atrasadas',
            value: '${stats.visitsOverdue}',
            icon: AppIcons.eventBusy,
          ),
        if (teamCount != null)
          MinistryWorkspaceStat(
            label: 'na equipe',
            value: '$teamCount',
            icon: Icons.groups_outlined,
          ),
      ],
      tabs: [
        MinistryWorkspaceTab(
          label: 'Painel',
          builder: (_) => RaizesPainelTab(ministryId: ministryId),
        ),
        MinistryWorkspaceTab(
          label: 'Equipe',
          count: teamCount?.toString(),
          builder: (_) => MinistryTeamTab(ministryId: ministryId),
        ),
        MinistryWorkspaceTab(
          label: 'Escala',
          builder: (_) => MinistryScaleTab(ministryId: ministryId),
        ),
        MinistryWorkspaceTab(
          label: 'Financeiro',
          builder: (_) => MinistryFinanceTab(ministryId: ministryId),
        ),
        MinistryWorkspaceTab(
          label: 'WhatsApp',
          builder: (_) => MinistryWhatsAppTab(ministryId: ministryId),
        ),
        MinistryWorkspaceTab(
          label: 'Relatórios',
          builder: (_) => MinistryReportsTab(ministryId: ministryId),
        ),
      ],
    );
  }
}

/// Aba Painel do Raízes: os KPIs de visitantes e os atalhos do módulo.
///
/// Era a tela inteira até 24/09. Perdeu o `Scaffold` e a `AppBar` — as duas
/// agora são do shell — e manteve o resto, inclusive o disparo de lembretes
/// ao entrar no módulo.
class RaizesPainelTab extends ConsumerStatefulWidget {
  final String ministryId;

  const RaizesPainelTab({super.key, required this.ministryId});

  @override
  ConsumerState<RaizesPainelTab> createState() => _RaizesPainelTabState();
}

class _RaizesPainelTabState extends ConsumerState<RaizesPainelTab> {
  @override
  void initState() {
    super.initState();
    // Dispara o despacho de lembretes server-side ao entrar no módulo.
    // Idempotente via reminder_app_sent_at — falha silenciosa para não bloquear UI.
    // Após o despacho, invalida o KPI provider para refletir as visitas marcadas
    // como notificadas (não afeta contagens, mas é seguro).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final repo = ref.read(raizesRepositoryProvider);
      repo
          .dispatchVisitReminders()
          .then((created) {
            if (created > 0 && mounted) {
              ref.invalidate(raizesDashboardStatsProvider(widget.ministryId));
            }
          })
          .catchError((_) {
            // Silencioso: o usuário ainda vê o dashboard; lembrete não bloqueia.
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    final ministryId = widget.ministryId;
    final statsAsync = ref.watch(raizesDashboardStatsProvider(ministryId));
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(raizesDashboardStatsProvider(ministryId));
        await ref.read(raizesDashboardStatsProvider(ministryId).future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
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
            icon: AppIcons.eventAvailable,
            title: 'Agenda de visitas',
            description:
                'Criar visitas, atribuir responsáveis e acompanhar status. Lembretes internos disparam ao abrir este módulo.',
            onTap: () => context.push('/ministries/$ministryId/raizes/visits'),
            color: Colors.deepPurple,
          ),
          const SizedBox(height: 12),
          _PrimaryActionCard(
            icon: AppIcons.personSearch,
            title: 'Ver visitantes',
            description:
                'Abrir a lista completa de visitantes com os filtros do Raízes (primeira visita, salvação, follow-up, faixa etária).',
            onTap: () => context.push('/visitors'),
            color: colorScheme.primary,
          ),
          const SizedBox(height: 12),
          _PrimaryActionCard(
            icon: AppIcons.personAdd,
            title: 'Cadastrar novo visitante',
            description: 'Abre o formulário pré-configurado para visitantes.',
            onTap: () =>
                context.push('/members/new?status=visitor&type=visitante'),
            color: colorScheme.tertiary,
          ),
          const SizedBox(height: 12),
          _PrimaryActionCard(
            icon: AppIcons.sponsors,
            title: 'Cadastro de padrinhos',
            description:
                'Cadastre membros do ministério como padrinho/madrinha com critérios para alimentar o algoritmo de indicações.',
            onTap: () =>
                context.push('/ministries/$ministryId/raizes/sponsors'),
            color: Colors.teal,
          ),
          const SizedBox(height: 12),
          _PrimaryActionCard(
            icon: AppIcons.recommendations,
            title: 'Indicações de padrinhos',
            description:
                'Sugestões automáticas de padrinho/madrinha por perfil. Aceitar marca o mentor do visitante.',
            onTap: () =>
                context.push('/ministries/$ministryId/raizes/recommendations'),
            color: Colors.amber.shade800,
          ),
        ],
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
        icon: AppIcons.today,
        color: Colors.deepPurple,
      ),
      _StatItem(
        title: 'Visitas atrasadas',
        value: stats.visitsOverdue,
        icon: AppIcons.eventBusy,
        color: Colors.red,
      ),
      _StatItem(
        title: 'Visitantes ativos',
        value: stats.totalActiveVisitors,
        icon: AppIcons.groupsFilled,
        color: Colors.indigo,
      ),
      _StatItem(
        title: 'Querem contato',
        value: stats.wantingContactPending,
        icon: AppIcons.unread,
        color: Colors.orange,
      ),
      _StatItem(
        title: 'Sem padrinho',
        value: stats.withoutMentor,
        icon: AppIcons.personOff,
        color: Colors.redAccent,
      ),
      _StatItem(
        title: 'Decisões (30d)',
        value: stats.newSalvationsLast30Days,
        icon: AppIcons.favorite,
        color: Colors.pink,
      ),
      _StatItem(
        title: 'Novos visitantes (30d)',
        value: stats.newVisitorsLast30Days,
        icon: AppIcons.newPerson,
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
        (_) => GlassCard(
          padding: EdgeInsets.zero,
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
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(AppIcons.error, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Falha ao carregar KPIs',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
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
              icon: const Icon(AppIcons.refresh, size: 18),
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
    return GlassCard(
      padding: const EdgeInsets.all(14),
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
            style: CommunityDesign.metaStyle(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
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
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
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
                  style: CommunityDesign.titleStyle(
                    context,
                  ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(description, style: CommunityDesign.metaStyle(context)),
              ],
            ),
          ),
          const Icon(AppIcons.forward, color: Colors.grey),
        ],
      ),
    );
  }
}
