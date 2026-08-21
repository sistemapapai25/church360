import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/supabase_constants.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../data/branches_repository.dart';
import '../../domain/models/tenant_unit.dart';

final branchesRepositoryProvider = Provider<BranchesRepository>((ref) {
  return BranchesRepository(Supabase.instance.client);
});

/// Matriz + filiais da rede do usuário atual.
final myNetworkUnitsProvider = FutureProvider<List<TenantUnit>>((ref) async {
  final repo = ref.watch(branchesRepositoryProvider);
  return repo.listMyNetworkUnits();
});

/// True quando o tenant atual é `kind == 'matriz'` e o usuário tem
/// `access_level_number >= 5` nele. Gate de tenant-kind + nível, não uma
/// permissão RBAC — mesmo raciocínio de `currentUserIsOwnerProvider`. Defesa
/// em profundidade no cliente: a autorização real é feita pelo `criar_filial`
/// no servidor.
///
/// Não usa a flag `is_current` de `listar_minhas_igrejas()` (calculada via
/// `jwt_tenant_id()`, que prioriza claims do JWT sobre o header `x-tenant-id`
/// — pode ficar desatualizada). Compara direto com
/// `SupabaseConstants.currentTenantId`, a mesma fonte de verdade que todo
/// outro repository do app usa pra saber o tenant atual.
final isMatrizAdminProvider = FutureProvider<bool>((ref) async {
  final units = await ref.watch(myNetworkUnitsProvider.future);
  final current = units.where(
    (u) => u.tenantId == SupabaseConstants.currentTenantId,
  );
  if (current.isEmpty || !current.first.isMatriz) return false;

  final repo = ref.watch(branchesRepositoryProvider);
  final level = await repo.getMyAccessLevelNumber(
    SupabaseConstants.currentTenantId,
  );
  return (level ?? 0) >= 5;
});

/// OR lógico entre owner e admin de matriz — decide se a categoria
/// "CONFIGURAÇÕES" do drawer deve aparecer quando o único item visível para
/// o usuário seria "Filiais".
final currentUserSeesConfigCategoryExtrasProvider = FutureProvider<bool>((
  ref,
) async {
  final owner = await ref.watch(currentUserIsOwnerProvider.future);
  if (owner) return true;
  return ref.watch(isMatrizAdminProvider.future);
});
