import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/community_design.dart';
import '../../domain/models/tenant_unit.dart';
import '../providers/branches_provider.dart';
import '../widgets/grant_unit_access_dialog.dart';

/// Painel da matriz: lista a rede (matriz + filiais) e permite criar uma
/// filial nova. CHU-289.
class BranchesListScreen extends ConsumerWidget {
  const BranchesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCreateAsync = ref.watch(isMatrizAdminProvider);
    final unitsAsync = ref.watch(myNetworkUnitsProvider);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
            decoration: BoxDecoration(
              color: CommunityDesign.headerColor(context),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Voltar',
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.account_tree,
                    size: 24,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filiais',
                        style: CommunityDesign.titleStyle(context).copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Rede da sua igreja',
                        style: CommunityDesign.metaStyle(context),
                      ),
                    ],
                  ),
                ),
                canCreateAsync.maybeWhen(
                  data: (canCreate) => canCreate
                      ? ElevatedButton.icon(
                          onPressed: () => context.push('/branches/new'),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Nova Filial'),
                          style: CommunityDesign.pillButtonStyle(
                            context,
                            Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : const SizedBox.shrink(),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: unitsAsync.when(
              data: (units) {
                final matrizList = units.where((u) => u.isMatriz).toList();
                final matriz = matrizList.isEmpty ? null : matrizList.first;
                final filiais = units.where((u) => u.isFilial).toList()
                  ..sort((a, b) => a.name.compareTo(b.name));

                if (matriz == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Não foi possível identificar a matriz da sua rede.',
                        style: CommunityDesign.metaStyle(context),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final canGrantAccess = canCreateAsync.maybeWhen(
                  data: (canCreate) => canCreate,
                  orElse: () => false,
                );

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    _UnitCard(unit: matriz, canGrantAccess: canGrantAccess),
                    const SizedBox(height: 24),
                    Text(
                      'FILIAIS',
                      style: CommunityDesign.metaStyle(context).copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (filiais.isEmpty)
                      Container(
                        decoration: CommunityDesign.overlayDecoration(
                          Theme.of(context).colorScheme,
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.account_tree_outlined,
                              size: 48,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.2),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhuma filial cadastrada ainda',
                              style: CommunityDesign.titleStyle(context),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            canCreateAsync.maybeWhen(
                              data: (canCreate) => canCreate
                                  ? ElevatedButton.icon(
                                      onPressed: () =>
                                          context.push('/branches/new'),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Criar Primeira Filial'),
                                      style: CommunityDesign.pillButtonStyle(
                                        context,
                                        Theme.of(context).colorScheme.primary,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                              orElse: () => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      )
                    else
                      ...filiais.map(
                        (u) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _UnitCard(
                            unit: u,
                            canGrantAccess: canGrantAccess,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Erro ao carregar filiais',
                        style: CommunityDesign.titleStyle(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: CommunityDesign.metaStyle(context),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.invalidate(myNetworkUnitsProvider);
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Tentar Novamente'),
                        style: CommunityDesign.pillButtonStyle(
                          context,
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final TenantUnit unit;
  final bool canGrantAccess;

  const _UnitCard({required this.unit, this.canGrantAccess = false});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: CommunityDesign.overlayDecoration(
        Theme.of(context).colorScheme,
      ),
      child: Padding(
        padding: CommunityDesign.overlayPadding,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                unit.isMatriz ? Icons.church : Icons.store,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                unit.name,
                style: CommunityDesign.titleStyle(
                  context,
                ).copyWith(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            if (canGrantAccess)
              IconButton(
                icon: const Icon(Icons.person_add_alt_1),
                tooltip: 'Conceder acesso em ${unit.name}',
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) => GrantUnitAccessDialog(unit: unit),
                ),
              ),
            CommunityDesign.badge(
              context,
              unit.isMatriz ? 'Matriz' : 'Filial',
              unit.isMatriz ? Colors.blue : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
