import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../access_levels/presentation/providers/access_level_provider.dart';
import '../../../../permissions/providers/permissions_providers.dart';
import '../../../../financeiro/domain/models/lancamento.dart';
import '../../../presentation/providers/ministries_provider.dart';
import '../../data/ministry_finance_repository.dart';
import '../../domain/ministry_finance.dart';

final ministryFinanceRepositoryProvider = Provider<MinistryFinanceRepository>((
  ref,
) {
  return MinistryFinanceRepository(Supabase.instance.client);
});

/// Vínculo do usuário atual **neste** ministério, sem nenhum atalho.
///
/// Não usa `ministryAccessProvider`: aquele devolve `true` para quem tem
/// visão global de ministérios, e é justamente essa a régua que o caixa não
/// pode herdar (ver [ministryFinanceAccessProvider]). Aqui a pergunta é a
/// mesma que `current_user_in_ministry()` faz no banco: existe linha em
/// `ministry_member` para esta pessoa e este ministério?
final ministryFinanceLinkProvider = FutureProvider.family<bool, String>((
  ref,
  ministryId,
) async {
  final mine = await ref.watch(currentMemberMinistriesProvider.future);
  return mine.any((m) => m.id == ministryId);
});

/// Quem manda no financeiro da igreja inteira.
///
/// Espelha `can_manage_financial()`, que é o que a policy antiga
/// `financial_lancamentos_all` exige — e ela cobre `ministry_id` nulo e não
/// nulo, então quem passa por ela enxerga e escreve no caixa de qualquer
/// departamento.
///
/// São os dois ramos da função do banco: a permissão RBAC `financial.manage`
/// e o fallback histórico de nível de acesso >= 4 (coordenador ou
/// administrativo). Sem o segundo, os dois owners e os dois admins — que não
/// têm cargo RBAC — veriam a aba fechada numa tela que o banco deixa abrir.
///
/// Uma ressalva honesta: o app lê o nível de `user_access_level` e a função
/// do banco lê de `user_tenant_membership`. As duas nasceram espelhadas
/// (`20260105000001`), mas são tabelas diferentes e podem divergir.
final ministryFinanceChurchWideProvider = FutureProvider<bool>((ref) async {
  final hasPermission = await ref.watch(
    currentUserHasPermissionProvider('financial.manage').future,
  );
  if (hasPermission) return true;
  return ref.watch(isCoordinatorOrAboveProvider.future);
});

/// O que o usuário atual pode fazer no caixa deste ministério.
class MinistryFinanceAccess {
  final bool canView;
  final bool canCreate;
  final bool canApprove;

  const MinistryFinanceAccess({
    required this.canView,
    required this.canCreate,
    required this.canApprove,
  });

  static const none = MinistryFinanceAccess(
    canView: false,
    canCreate: false,
    canApprove: false,
  );
}

/// A régua da aba, espelhando as policies de 21/09 termo a termo:
///
/// ```
/// ministry_finance.<ação>  E  vínculo no ministério
/// OU
/// can_manage_financial     (o financeiro da igreja)
/// ```
///
/// **`ministriesCanSeeAll` não entra aqui**, e a diferença em relação ao
/// `baptismCanWriteProvider` é deliberada: visão global de *ministérios* não
/// é visão global de *caixa*, e a migration de 21/09 não usa
/// `ministries_user_can_see_all()` em nenhuma das três policies. Copiar
/// aquele provider abriria botão que o banco recusa — a divergência tela ×
/// banco que este projeto já pagou várias vezes.
final ministryFinanceAccessProvider =
    FutureProvider.family<MinistryFinanceAccess, String>((
      ref,
      ministryId,
    ) async {
      final churchWide = await ref.watch(
        ministryFinanceChurchWideProvider.future,
      );
      if (churchWide) {
        return const MinistryFinanceAccess(
          canView: true,
          canCreate: true,
          canApprove: true,
        );
      }

      final linked = await ref.watch(
        ministryFinanceLinkProvider(ministryId).future,
      );
      if (!linked) return MinistryFinanceAccess.none;

      final results = await Future.wait<bool>([
        ref.watch(
          currentUserHasPermissionProvider('ministry_finance.view').future,
        ),
        ref.watch(
          currentUserHasPermissionProvider('ministry_finance.create').future,
        ),
        ref.watch(
          currentUserHasPermissionProvider('ministry_finance.approve').future,
        ),
      ]);

      // Quem cria ou aprova também vê: é o que as policies de SELECT e
      // UPDATE somadas fazem, e uma tela que deixa lançar sem deixar ler
      // seria inútil.
      return MinistryFinanceAccess(
        canView: results[0] || results[1] || results[2],
        canCreate: results[1],
        canApprove: results[2],
      );
    });

/// Catálogo de categorias e beneficiários para este ministério.
final ministryFinanceCatalogProvider =
    FutureProvider.family<MinistryFinanceCatalog, String>((
      ref,
      ministryId,
    ) async {
      final repo = ref.watch(ministryFinanceRepositoryProvider);
      return repo.getCatalog(ministryId);
    });

/// Lançamentos do caixa deste ministério, com o nome da rubrica e do
/// beneficiário já resolvidos pelo catálogo.
///
/// A junção é feita aqui, e não por embed do PostgREST, porque embed de
/// tabela fechada volta NULL sem erro — ver [MinistryFinanceRepository].
final ministryFinanceLancamentosProvider =
    FutureProvider.family<List<Lancamento>, String>((ref, ministryId) async {
      final repo = ref.watch(ministryFinanceRepositoryProvider);
      final lancamentos = await repo.getLancamentos(ministryId);
      final catalog = await ref.watch(
        ministryFinanceCatalogProvider(ministryId).future,
      );

      return [
        for (final l in lancamentos)
          l.copyWith(
            categoriaNome: catalog.nomeDeCategoria(l.categoriaId),
            beneficiarioNome: catalog.nomeDeBeneficiario(l.beneficiarioId),
          ),
      ];
    });

/// Os números do caixa do departamento.
final ministryFinanceSummaryProvider =
    FutureProvider.family<MinistryFinanceSummary, String>((
      ref,
      ministryId,
    ) async {
      final lancamentos = await ref.watch(
        ministryFinanceLancamentosProvider(ministryId).future,
      );
      return MinistryFinanceSummary.from(lancamentos);
    });

/// Invalida o caixa do ministério depois de qualquer gravação.
///
/// Realtime nunca é habilitado por migration neste banco: `onPostgresChanges`
/// pode nunca disparar, então toda gravação invalida na mão. O resumo entra
/// junto porque `invalidate` não sobe para quem depende — invalidar só a
/// lista deixaria o saldo velho na tela.
void invalidateMinistryFinance(WidgetRef ref, String ministryId) {
  ref.invalidate(ministryFinanceLancamentosProvider(ministryId));
  ref.invalidate(ministryFinanceSummaryProvider(ministryId));
}
