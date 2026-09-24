import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/presentation/providers/ministry_finance_providers.dart';
import '../../shared/presentation/widgets/ministry_finance_tab.dart';
import '../../shared/presentation/widgets/ministry_notices_tab.dart';
import '../../shared/presentation/widgets/ministry_reports_tab.dart';
import '../../shared/presentation/widgets/ministry_scale_tab.dart';
import '../../shared/presentation/widgets/ministry_submodule_guard.dart';
import '../../shared/presentation/widgets/ministry_team_tab.dart';
import '../../shared/presentation/widgets/ministry_workspace_shell.dart';
import '../../domain/models/ministry.dart';
import '../providers/ministries_provider.dart';

/// Workspace de qualquer ministério — o esqueleto que o Batismo estreou,
/// agora sem dono.
///
/// São cinco abas base: Equipe, Escala, Financeiro, Avisos e Relatórios.
/// Um ministério de tipo próprio (Batismo, Raízes, Diaconato) é esta mesma
/// tela com abas a mais; nenhum deles tem tela de layout próprio.
///
/// **Quem entra:** vínculo ativo no ministério **ou** visão global de
/// ministérios — é o [MinistrySubmoduleGuard] sem permissão de submódulo.
/// Entrar não autoriza o que existe dentro: o Financeiro exige
/// `ministry_finance.view` por conta própria, e o Relatórios só soma o caixa
/// para quem já pode vê-lo.
class GenericMinistryHomeScreen extends ConsumerWidget {
  final String ministryId;

  const GenericMinistryHomeScreen({super.key, required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MinistrySubmoduleGuard(
      ministryId: ministryId,
      submoduleLabel: 'ministério',
      builder: (context) => _GenericWorkspace(ministryId: ministryId),
    );
  }
}

class _GenericWorkspace extends ConsumerWidget {
  final String ministryId;

  const _GenericWorkspace({required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamCount = ref
        .watch(ministryMembersProvider(ministryId))
        .maybeWhen(data: (m) => m.length, orElse: () => null);

    final nextScale = ref
        .watch(ministrySchedulesProvider(ministryId))
        .maybeWhen(data: _nextScaleLabel, orElse: () => null);

    // O saldo só sobe para a linha de indicadores de quem pode ver o caixa.
    // A aba Financeiro já fecha sozinha para os outros; um número no topo
    // contaria a mesma coisa por fora dela.
    final canSeeCash = ref
        .watch(ministryFinanceAccessProvider(ministryId))
        .maybeWhen(data: (a) => a.canView, orElse: () => false);
    final balance = canSeeCash
        ? ref
              .watch(ministryFinanceSummaryProvider(ministryId))
              .maybeWhen(data: (s) => s.saldo, orElse: () => null)
        : null;

    return MinistryWorkspaceShell(
      ministryId: ministryId,
      fallbackTitle: 'Ministério',
      stats: [
        if (teamCount != null)
          MinistryWorkspaceStat(
            label: 'na equipe',
            value: '$teamCount',
            icon: Icons.groups_outlined,
          ),
        if (nextScale != null)
          MinistryWorkspaceStat(
            label: 'próxima escala',
            value: nextScale,
            icon: Icons.event_outlined,
          ),
        if (balance != null)
          MinistryWorkspaceStat(
            label: 'saldo',
            value: NumberFormat.currency(
              locale: 'pt_BR',
              symbol: 'R\$',
            ).format(balance),
            icon: Icons.account_balance_wallet_outlined,
          ),
      ],
      tabs: [
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
          label: 'Avisos',
          builder: (_) => MinistryNoticesTab(ministryId: ministryId),
        ),
        MinistryWorkspaceTab(
          label: 'Relatórios',
          builder: (_) => MinistryReportsTab(ministryId: ministryId),
        ),
      ],
    );
  }
}

String? _nextScaleLabel(List<MinistrySchedule> schedules) {
  final now = DateTime.now();
  final dated =
      schedules
          .where(
            (s) => s.eventStartDate != null && !s.eventStartDate!.isBefore(now),
          )
          .toList()
        ..sort((a, b) => a.eventStartDate!.compareTo(b.eventStartDate!));
  if (dated.isEmpty) return null;
  return DateFormat('dd/MM').format(dated.first.eventStartDate!);
}
