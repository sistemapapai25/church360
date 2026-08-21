import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/app_restart_scope.dart';
import '../../../branches/domain/models/tenant_unit.dart';
import '../../../branches/presentation/providers/branches_provider.dart';
import '../providers/church_selector_provider.dart';

/// Seletor de unidade da rede (matriz/filial, CHU-300).
///
/// Dois modos, decididos pela navegação: chegado via `context.push` (aba
/// Mais → "Trocar de igreja", com tela anterior no stack) mostra botão
/// voltar e reinicia o cache dos providers após trocar; chegado via
/// `context.go` (fluxo forçado pós-login, primeira vez com >1 unidade) não
/// mostra botão voltar e não precisa reiniciar nada — ainda não houve leitura
/// de dado tenant-scoped nesta sessão.
class ChurchSelectorScreen extends ConsumerStatefulWidget {
  const ChurchSelectorScreen({super.key});

  @override
  ConsumerState<ChurchSelectorScreen> createState() =>
      _ChurchSelectorScreenState();
}

class _ChurchSelectorScreenState extends ConsumerState<ChurchSelectorScreen> {
  String? _switchingTenantId;

  Future<void> _selectUnit(TenantUnit unit) async {
    if (_switchingTenantId != null) return;
    setState(() => _switchingTenantId = unit.tenantId);

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (unit.tenantId != SupabaseConstants.currentTenantId) {
        final repo = ref.read(churchSelectorRepositoryProvider);
        await repo.trocarDeIgreja(unit.tenantId);
        await SupabaseConstants.syncTenantFromServer(
          client,
          persist: true,
          syncJwt: true,
        );
      }

      if (userId != null) {
        await SupabaseConstants.markChosenActiveUnit(userId);
      }

      if (!mounted) return;

      final canPop = context.canPop();
      if (canPop) {
        AppRestartScope.restart(context);
        context.go('/home');
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _switchingTenantId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível trocar de igreja: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitsAsync = ref.watch(myNetworkUnitsProvider);
    final canPop = context.canPop();

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  if (canPop)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Voltar',
                      onPressed: () => context.pop(),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selecione sua igreja',
                          style: CommunityDesign.titleStyle(context).copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          canPop
                              ? 'Escolha para qual unidade deseja trocar'
                              : 'Você tem acesso a mais de uma unidade',
                          style: CommunityDesign.metaStyle(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: unitsAsync.when(
                data: (units) {
                  final sorted = [...units]
                    ..sort((a, b) {
                      if (a.isMatriz != b.isMatriz) {
                        return a.isMatriz ? -1 : 1;
                      }
                      return a.name.compareTo(b.name);
                    });

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final unit = sorted[index];
                      final isSelected =
                          unit.tenantId == SupabaseConstants.currentTenantId;
                      final isSwitching = _switchingTenantId == unit.tenantId;
                      return _UnitTile(
                        unit: unit,
                        isSelected: isSelected,
                        isLoading: isSwitching,
                        onTap: () => _selectUnit(unit),
                      );
                    },
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
                          'Erro ao carregar suas unidades',
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
      ),
    );
  }
}

class _UnitTile extends StatelessWidget {
  final TenantUnit unit;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onTap;

  const _UnitTile({
    required this.unit,
    required this.isSelected,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = cs.primary;

    return Container(
      decoration: CommunityDesign.overlayDecoration(cs).copyWith(
        border: isSelected
            ? Border.all(color: color, width: 2)
            : Border.all(color: Colors.transparent, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isLoading ? null : onTap,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unit.name,
                        style: CommunityDesign.titleStyle(
                          context,
                        ).copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      CommunityDesign.badge(
                        context,
                        unit.isMatriz ? 'Matriz' : 'Filial',
                        unit.isMatriz ? Colors.blue : Colors.grey,
                      ),
                    ],
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (isSelected)
                  Icon(Icons.check_circle, color: color)
                else
                  const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
