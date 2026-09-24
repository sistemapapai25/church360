import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../presentation/providers/ministries_provider.dart';
import '../../../shared/domain/ministry_type_catalog.dart';
import '../../../shared/presentation/providers/ministry_type_catalog_providers.dart';
import '../../../shared/presentation/widgets/ministry_finance_tab.dart';
import '../../../shared/presentation/widgets/ministry_whatsapp_tab.dart';
import '../../../shared/presentation/widgets/ministry_reports_tab.dart';
import '../../../shared/presentation/widgets/ministry_scale_tab.dart';
import '../../../shared/presentation/widgets/ministry_submodule_guard.dart';
import '../../../shared/presentation/widgets/ministry_team_tab.dart';
import '../../../shared/presentation/widgets/ministry_workspace_shell.dart';
import '../../domain/models/diaconato_dashboard_stats.dart';
import '../../domain/models/worship_attendance.dart';
import '../providers/diaconato_attendance_providers.dart';
import '../widgets/worship_service_picker_sheet.dart';

/// Workspace do Diaconato — o mesmo esqueleto do Batismo, com uma aba a
/// mais.
///
/// O dashboard de KPIs e os atalhos de checklist, ausentes e lotes de ceia
/// viraram a aba **Painel**, ao lado de Equipe, Escala, Financeiro, Avisos e
/// Relatórios, que são as mesmas de qualquer ministério. As telas por culto
/// continuam em rotas próprias: são de um evento, não do departamento.
class DiaconatoHomeScreen extends ConsumerWidget {
  final String ministryId;

  const DiaconatoHomeScreen({super.key, required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MinistrySubmoduleGuard(
      ministryId: ministryId,
      requiredPermission: 'diaconato.view',
      submoduleLabel: 'Diaconato',
      builder: (context) => _DiaconatoWorkspace(ministryId: ministryId),
    );
  }
}

class _DiaconatoWorkspace extends ConsumerWidget {
  final String ministryId;

  const _DiaconatoWorkspace({required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamCount = ref
        .watch(ministryMembersProvider(ministryId))
        .maybeWhen(data: (m) => m.length, orElse: () => null);

    return MinistryWorkspaceShell(
      ministryId: ministryId,
      fallbackTitle: 'Diaconato',
      stats: [
        if (teamCount != null)
          MinistryWorkspaceStat(
            label: 'na equipe',
            value: '$teamCount',
            icon: Icons.groups_outlined,
          ),
      ],
      tabs: ministryTabsFromCatalog(
        catalog: ref.watch(ministryTypeCatalogSyncProvider),
        typeCode: MinistryTypeCodes.diaconato,
        slots: {
          MinistryTabKeys.painel: MinistryTabSlot(
            defaultLabel: 'Painel',
            builder: (_) => DiaconatoPainelTab(ministryId: ministryId),
          ),
          MinistryTabKeys.equipe: MinistryTabSlot(
            defaultLabel: 'Equipe',
            count: teamCount?.toString(),
            builder: (_) => MinistryTeamTab(ministryId: ministryId),
          ),
          MinistryTabKeys.escala: MinistryTabSlot(
            defaultLabel: 'Escala',
            builder: (_) => MinistryScaleTab(ministryId: ministryId),
          ),
          MinistryTabKeys.financeiro: MinistryTabSlot(
            defaultLabel: 'Financeiro',
            builder: (_) => MinistryFinanceTab(ministryId: ministryId),
          ),
          MinistryTabKeys.whatsapp: MinistryTabSlot(
            defaultLabel: 'WhatsApp',
            builder: (_) => MinistryWhatsAppTab(ministryId: ministryId),
          ),
          MinistryTabKeys.relatorios: MinistryTabSlot(
            defaultLabel: 'Relatórios',
            builder: (_) => MinistryReportsTab(ministryId: ministryId),
          ),
        },
      ),
    );
  }
}

/// Aba Painel do Diaconato: os KPIs do módulo e os atalhos por culto.
///
/// Era a tela inteira até 24/09. Perdeu o `Scaffold` e a `AppBar` — as duas
/// agora são do shell — e manteve o resto, inclusive o disparo das
/// notificações de ceia ao entrar.
class DiaconatoPainelTab extends ConsumerStatefulWidget {
  final String ministryId;

  const DiaconatoPainelTab({super.key, required this.ministryId});

  @override
  ConsumerState<DiaconatoPainelTab> createState() => _DiaconatoPainelTabState();
}

class _DiaconatoPainelTabState extends ConsumerState<DiaconatoPainelTab> {
  @override
  void initState() {
    super.initState();
    // Dispara a RPC server-side de notificações de atribuição de ceia ao
    // entrar na home do Diaconato. Idempotente via reminder_app_sent_at —
    // chamadas repetidas no mesmo dia são no-op. Falha silenciosa para não
    // bloquear a UI: dashboard funciona mesmo sem notif.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final repo = ref.read(diaconatoAttendanceRepositoryProvider);
      repo.dispatchCommunionAssignments().catchError((_) => 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(diaconatoDashboardStatsProvider(widget.ministryId));
        await ref.read(
          diaconatoDashboardStatsProvider(widget.ministryId).future,
        );
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _DashboardSection(ministryId: widget.ministryId),
          const SizedBox(height: 24),
          _SectionLabel(text: 'ATALHOS'),
          const SizedBox(height: 8),
          _PlaceholderCard(
            icon: AppIcons.checklist,
            title: 'Checklist de presença',
            description:
                'Membros primeiro, visitantes cadastrados depois, contagem de não cadastrados.',
            onTap: () => _openWorshipServicePicker(
              context,
              destinationPath: '/checklist',
            ),
          ),
          const SizedBox(height: 16),
          _PlaceholderCard(
            icon: AppIcons.callMissed,
            title: 'Ausentes',
            description:
                'Triagem dos ausentes: sem ação, ligação, ceia, ou ambos.',
            onTap: () => _openWorshipServicePicker(
              context,
              destinationPath: '/absentees',
            ),
          ),
          const SizedBox(height: 16),
          _PlaceholderCard(
            icon: AppIcons.communion,
            title: 'Lotes de ceia',
            description:
                'Lote por culto com responsável, status e (em breve) WhatsApp via dispatch.',
            onTap: () => _openWorshipServicePicker(
              context,
              destinationPath: '/communion-batches',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _DashboardSection extends ConsumerWidget {
  final String ministryId;
  const _DashboardSection({required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(diaconatoDashboardStatsProvider(ministryId));

    return statsAsync.when(
      data: (stats) => _DashboardBody(ministryId: ministryId, stats: stats),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _DashboardError(
        message: e.toString(),
        onRetry: () =>
            ref.invalidate(diaconatoDashboardStatsProvider(ministryId)),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final String ministryId;
  final DiaconatoDashboardStats stats;

  const _DashboardBody({required this.ministryId, required this.stats});

  @override
  Widget build(BuildContext context) {
    final lastCount = stats.lastCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lastCount == null)
          _NoCountHero()
        else
          _LastCountHero(ministryId: ministryId, lastCount: lastCount),
        const SizedBox(height: 16),
        _KpiRow(stats: stats),
        if (stats.unregisteredVisitorsLast30Days > 0) ...[
          const SizedBox(height: 16),
          _UnregisteredBanner(
            count: stats.unregisteredVisitorsLast30Days,
            onCapture: () => context.push('/ministries'),
          ),
        ],
      ],
    );
  }
}

class _LastCountHero extends StatelessWidget {
  final String ministryId;
  final WorshipAttendanceCount lastCount;

  const _LastCountHero({required this.ministryId, required this.lastCount});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateLabel = _capitalize(
      DateFormat(
        "EEE, d 'de' MMM 'de' y",
        'pt_BR',
      ).format(lastCount.serviceDate),
    );

    return GlassCard(
      onTap: () => context.push(
        '/ministries/$ministryId/diaconato/absentees/${lastCount.worshipServiceId}',
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(AppIcons.eventAvailable, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Último culto contado',
                        style: CommunityDesign.metaStyle(context),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateLabel,
                        style: CommunityDesign.titleStyle(
                          context,
                        ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                Icon(
                  AppIcons.forward,
                  size: 14,
                  color: cs.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _MiniStat(
                  label: 'Membros',
                  value: lastCount.totalMembersPresent,
                  color: cs.primary,
                ),
                const SizedBox(width: 8),
                _MiniStat(
                  label: 'Vis. cad.',
                  value: lastCount.totalRegisteredVisitorsPresent,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                _MiniStat(
                  label: 'Não cad.',
                  value: lastCount.totalUnregisteredVisitors,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          lastCount.totalPeople.toString(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Total',
                          style: CommunityDesign.metaStyle(
                            context,
                          ).copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: CommunityDesign.metaStyle(context).copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoCountHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(AppIcons.factCheck, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nenhum culto contado ainda',
                  style: CommunityDesign.titleStyle(
                    context,
                  ).copyWith(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  'Comece pelo checklist do próximo culto.',
                  style: CommunityDesign.metaStyle(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  final DiaconatoDashboardStats stats;
  const _KpiRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KpiChip(
            label: 'Triagem pend.',
            value: stats.pendingTriageInLastCount,
            color: Colors.redAccent,
            icon: AppIcons.help,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiChip(
            label: 'Ceias abertas',
            value: stats.openCommunionItems,
            color: Colors.deepPurple,
            icon: AppIcons.communion,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiChip(
            label: 'Minhas ceias',
            value: stats.myAssignedItems,
            color: Colors.green,
            icon: AppIcons.personFilled,
          ),
        ),
      ],
    );
  }
}

class _KpiChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _KpiChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: CommunityDesign.metaStyle(context).copyWith(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _UnregisteredBanner extends StatelessWidget {
  final int count;
  final VoidCallback onCapture;

  const _UnregisteredBanner({required this.count, required this.onCapture});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accentColor: Colors.orange,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(AppIcons.addCircle, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count visitante${count == 1 ? '' : 's'} não cadastrado'
                  '${count == 1 ? '' : 's'} (30 dias)',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cadastre no Raízes para incluir nas próximas triagens.',
                  style: CommunityDesign.metaStyle(context),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onCapture,
                  icon: const Icon(AppIcons.eco, size: 16),
                  label: const Text('Ir para Raízes'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DashboardError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          const Icon(AppIcons.error, color: Colors.red),
          const SizedBox(height: 8),
          Text(
            'Erro ao carregar dashboard',
            style: CommunityDesign.titleStyle(context).copyWith(fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: CommunityDesign.metaStyle(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(AppIcons.refresh, size: 16),
            label: const Text('Tentar novamente'),
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
  final VoidCallback? onTap;

  const _PlaceholderCard({
    required this.icon,
    required this.title,
    required this.description,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 32, color: cs.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: CommunityDesign.titleStyle(
                    context,
                  ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(description, style: CommunityDesign.metaStyle(context)),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: cs.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ],
      ),
    );

    return GlassCard(onTap: onTap, child: content);
  }
}

/// Abre o picker de culto e empurra
/// `/ministries/<id>/diaconato<destinationPath>/<serviceId>` na seleção.
///
/// Usado pelos cards "Checklist de presença" (`/checklist`) e "Ausentes"
/// (`/absentees`) da home do Diaconato.
void _openWorshipServicePicker(
  BuildContext context, {
  required String destinationPath,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => WorshipServicePickerSheet(
      onSelected: (service) {
        // ministryId vem da rota atual: /ministries/<id>/diaconato.
        final state = GoRouterState.of(context);
        final ministryId = state.pathParameters['id'];
        if (ministryId == null) return;
        context.push(
          '/ministries/$ministryId/diaconato$destinationPath/${service.id}',
        );
      },
    ),
  );
}
