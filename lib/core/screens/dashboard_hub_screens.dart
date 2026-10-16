import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/branches/presentation/providers/branches_provider.dart';
import '../../features/church_info/presentation/providers/church_info_provider.dart';
import '../../features/church_onboarding/presentation/widgets/onboarding_dashboard_card.dart';
import '../../features/members/presentation/providers/members_provider.dart';
import '../../features/ministries/presentation/providers/ministries_provider.dart';
import '../../features/ministries/presentation/screens/ministries_list_screen.dart';
import '../../features/permissions/presentation/widgets/permission_gate.dart';
import '../../features/permissions/providers/permissions_providers.dart';
import '../../features/support_materials/presentation/screens/support_materials_screen.dart';
import '../domain/models/management_menu.dart';
import '../widgets/app_logo.dart';
import '../widgets/management_menu_row.dart';
import 'leader_panel_screen.dart';

// Frente G (roadmap 14/10, pedido de 16/10): as telas que a barra de baixo
// da Dashboard abre por cima dos cards — Pessoas, Ministérios e o perfil da
// igreja (logo), com o ☰ "Gestão da igreja".

/// G2: `/dashboard/pessoas`.
class DashboardPeopleScreen extends StatelessWidget {
  const DashboardPeopleScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pessoas')),
    body: ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: const [
        ManagementMenuSection(category: kPeopleMenu, showTitle: false),
      ],
    ),
  );
}

/// G3: `/dashboard/ministerios`, com as abas Ministérios e Materiais de
/// apoio (cada uma só para quem tem a permissão dela).
class DashboardMinistriesScreen extends ConsumerWidget {
  const DashboardMinistriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool can(String code) =>
        ref.watch(currentUserHasPermissionProvider(code)).valueOrNull == true;
    final tabs = <(String, Widget)>[
      if (can('ministries.view'))
        ('Ministérios', const MinistriesListScreen(embedded: true)),
      if (can('support_materials.view'))
        (
          'Materiais de apoio',
          const SupportMaterialsScreen(fromDashboard: true, embedded: true),
        ),
    ];

    if (tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ministérios')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return DefaultTabController(
      key: ValueKey(tabs.length),
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ministérios'),
          bottom: tabs.length < 2
              ? null
              : TabBar(tabs: [for (final (label, _) in tabs) Tab(text: label)]),
        ),
        body: tabs.length < 2
            ? tabs.first.$2
            : TabBarView(children: [for (final (_, page) in tabs) page]),
      ),
    );
  }
}

/// G4: `/dashboard/igreja`, o perfil da igreja (estilo perfil do Instagram).
class ChurchProfileScreen extends ConsumerWidget {
  const ChurchProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final church = ref.watch(churchInfoProvider).valueOrNull;
    final name = church?.name ?? '';
    String count(AsyncValue<int> v) => v.valueOrNull?.toString() ?? '–';
    final members = count(ref.watch(activeMembersCountProvider));
    final ministries = count(
      ref.watch(activeMinistriesProvider).whenData((l) => l.length),
    );
    // A rede inclui a própria igreja; filiais são as outras unidades.
    final branches = count(
      ref
          .watch(currentNetworkUnitsProvider)
          .whenData((u) => u.isEmpty ? 0 : u.length - 1),
    );

    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(name.isEmpty ? 'Sua igreja' : name),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Gestão da igreja',
            onPressed: () => context.push('/dashboard/igreja/gestao'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(churchInfoProvider);
          ref.invalidate(activeMembersCountProvider);
          ref.invalidate(activeMinistriesProvider);
          ref.invalidate(myNetworkUnitsProvider);
          ref.invalidate(leaderPanelProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Row(
              children: [
                ClipOval(
                  child: SizedBox.square(
                    dimension: 86,
                    child: ChurchLogo(url: church?.logoUrl, name: name),
                  ),
                ),
                const SizedBox(width: 12),
                stat(members, 'membros'),
                stat(ministries, 'ministérios'),
                stat(branches, 'filiais'),
              ],
            ),
            const SizedBox(height: 12),
            if (name.isNotEmpty)
              Text(
                name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            if ((church?.address ?? '').isNotEmpty)
              Text(church!.address!, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PermissionGate(
                    permission: 'church_info.edit',
                    showLoading: false,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilledButton.tonal(
                        onPressed: () => context.push('/church-info/manage'),
                        child: const Text('Editar perfil'),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => context.push('/church-info'),
                    child: const Text('Ver como membro'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // G5: cartão "Seu painel" (some para quem não é pastor/líder).
            const LeaderPanelCard(),
            // F1: "Primeiros passos" no lugar do "Complete seu perfil".
            const OnboardingDashboardCard(),
          ],
        ),
      ),
    );
  }
}

/// G4: `/dashboard/igreja/gestao`, o ☰ do perfil: a gestão em seções.
class ChurchManagementScreen extends StatelessWidget {
  const ChurchManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Gestão da igreja')),
    body: ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        for (final section in kChurchMenu)
          ManagementMenuSection(category: section),
      ],
    ),
  );
}
