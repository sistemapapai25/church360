import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/ministry_stock_repository.dart';
import '../../domain/ministry_stock.dart';

final ministryStockRepositoryProvider = Provider<MinistryStockRepository>(
  (ref) => MinistryStockRepository(Supabase.instance.client),
);

/// O que a pessoa pode no estoque e na auditoria deste ministério.
///
/// Vem das funções do banco (`ministry_stock_can_view/manage`,
/// `ministry_audit_can_view`), e não de uma régua refeita no app: é a mesma
/// pergunta que a RLS e as RPCs fazem.
class MinistryStockCaps {
  final bool canView;
  final bool canManage;
  final bool canAudit;

  const MinistryStockCaps({
    required this.canView,
    required this.canManage,
    required this.canAudit,
  });
}

final ministryStockCapsProvider =
    FutureProvider.family<MinistryStockCaps, String>((ref, ministryId) async {
      final repo = ref.watch(ministryStockRepositoryProvider);
      final r = await Future.wait([
        repo.canView(ministryId),
        repo.canManage(ministryId),
        repo.canAudit(ministryId),
      ]);
      return MinistryStockCaps(canView: r[0], canManage: r[1], canAudit: r[2]);
    });

final ministryStockItemsProvider =
    FutureProvider.family<List<StockItem>, String>((ref, ministryId) {
      return ref.watch(ministryStockRepositoryProvider).getItems(ministryId);
    });

final ministryStockHistoryProvider =
    FutureProvider.family<List<StockMovement>, String>((ref, itemId) {
      return ref.watch(ministryStockRepositoryProvider).getHistory(itemId);
    });

final ministryAuditFeedProvider =
    FutureProvider.family<List<AuditEntry>, String>((ref, ministryId) {
      return ref.watch(ministryStockRepositoryProvider).getAuditFeed(ministryId);
    });

/// Sem realtime neste banco: toda gravação invalida na mão.
void invalidateMinistryStock(
  WidgetRef ref,
  String ministryId, {
  String? itemId,
}) {
  ref.invalidate(ministryStockItemsProvider(ministryId));
  ref.invalidate(ministryAuditFeedProvider(ministryId));
  if (itemId != null) ref.invalidate(ministryStockHistoryProvider(itemId));
}
