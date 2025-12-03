import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/prayer_request_repository.dart';
import '../../domain/models/prayer_request.dart';

// =====================================================
// REPOSITORY PROVIDER
// =====================================================

final prayerRequestRepositoryProvider = Provider<PrayerRequestRepository>((ref) {
  return PrayerRequestRepository(Supabase.instance.client);
});

// =====================================================
// PRAYER REQUESTS PROVIDERS
// =====================================================

/// Provider: Todos os pedidos de oração
final allPrayerRequestsProvider = FutureProvider<List<PrayerRequest>>((ref) async {
  final repository = ref.watch(prayerRequestRepositoryProvider);
  return repository.getAllPrayerRequests();
});

/// Provider: Pedidos por status
final prayerRequestsByStatusProvider = FutureProvider.family<List<PrayerRequest>, PrayerStatus>(
  (ref, status) async {
    final repository = ref.watch(prayerRequestRepositoryProvider);
    return repository.getPrayerRequestsByStatus(status);
  },
);

/// Provider: Pedidos por categoria
final prayerRequestsByCategoryProvider = FutureProvider.family<List<PrayerRequest>, PrayerCategory>(
  (ref, category) async {
    final repository = ref.watch(prayerRequestRepositoryProvider);
    return repository.getPrayerRequestsByCategory(category);
  },
);

/// Provider: Meus pedidos de oração
final myPrayerRequestsProvider = FutureProvider<List<PrayerRequest>>((ref) async {
  final repository = ref.watch(prayerRequestRepositoryProvider);
  return repository.getMyPrayerRequests();
});

/// Provider: Pedido por ID
final prayerRequestByIdProvider = FutureProvider.family<PrayerRequest?, String>(
  (ref, id) async {
    final repository = ref.watch(prayerRequestRepositoryProvider);
    return repository.getPrayerRequestById(id);
  },
);

// =====================================================
// PRAYERS PROVIDERS
// =====================================================

/// Provider: Orações de um pedido
final prayerRequestPrayersProvider = FutureProvider.family<List<PrayerRequestPrayer>, String>(
  (ref, prayerRequestId) async {
    final repository = ref.watch(prayerRequestRepositoryProvider);
    return repository.getPrayerRequestPrayers(prayerRequestId);
  },
);

/// Provider: Verificar se usuário já orou
final hasUserPrayedProvider = FutureProvider.family<bool, String>(
  (ref, prayerRequestId) async {
    final repository = ref.watch(prayerRequestRepositoryProvider);
    return repository.hasUserPrayed(prayerRequestId);
  },
);

/// Provider: Contar orações
final prayerCountProvider = FutureProvider.family<int, String>(
  (ref, prayerRequestId) async {
    final repository = ref.watch(prayerRequestRepositoryProvider);
    return repository.countPrayers(prayerRequestId);
  },
);

// =====================================================
// TESTIMONIES PROVIDERS
// =====================================================

/// Provider: Testemunho de um pedido
final prayerRequestTestimonyProvider = FutureProvider.family<PrayerRequestTestimony?, String>(
  (ref, prayerRequestId) async {
    final repository = ref.watch(prayerRequestRepositoryProvider);
    return repository.getTestimony(prayerRequestId);
  },
);

// =====================================================
// STATISTICS PROVIDERS
// =====================================================

/// Provider: Estatísticas de um pedido
final prayerRequestStatsProvider = FutureProvider.family<PrayerRequestStats, String>(
  (ref, prayerRequestId) async {
    final repository = ref.watch(prayerRequestRepositoryProvider);
    return repository.getPrayerRequestStats(prayerRequestId);
  },
);

/// Provider: Contar por status
final prayerRequestsByStatusCountProvider = FutureProvider<Map<PrayerStatus, int>>((ref) async {
  final repository = ref.watch(prayerRequestRepositoryProvider);
  return repository.countByStatus();
});

/// Provider: Contar por categoria
final prayerRequestsByCategoryCountProvider = FutureProvider<Map<PrayerCategory, int>>((ref) async {
  final repository = ref.watch(prayerRequestRepositoryProvider);
  return repository.countByCategory();
});

// =====================================================
// ACTIONS
// =====================================================

/// Classe de ações para pedidos de oração
class PrayerRequestActions {
  final dynamic baseRef;

  PrayerRequestActions(this.baseRef);
  PrayerRequestActions.fromWidgetRef(WidgetRef ref) : baseRef = ref;

  /// Criar pedido de oração
  Future<void> createPrayerRequest({
    required String title,
    required String description,
    required PrayerCategory category,
    required PrayerPrivacy privacy,
    bool isPublic = false,
    bool allowWhatsappContact = true,
  }) async {
    final repository = baseRef.read(prayerRequestRepositoryProvider);
    
    await repository.createPrayerRequest(
      title: title,
      description: description,
      category: category,
      privacy: privacy,
      isPublic: isPublic,
      allowWhatsappContact: allowWhatsappContact,
    );

    // Invalidar providers
    baseRef.invalidate(allPrayerRequestsProvider);
    baseRef.invalidate(myPrayerRequestsProvider);
    baseRef.invalidate(prayerRequestsByStatusProvider);
    baseRef.invalidate(prayerRequestsByCategoryProvider);
    baseRef.invalidate(prayerRequestsByStatusCountProvider);
    baseRef.invalidate(prayerRequestsByCategoryCountProvider);
  }

  /// Atualizar pedido de oração
  Future<void> updatePrayerRequest({
    required String id,
    String? title,
    String? description,
    PrayerCategory? category,
    PrayerStatus? status,
    PrayerPrivacy? privacy,
    bool? isPublic,
    bool? allowWhatsappContact,
  }) async {
    final repository = baseRef.read(prayerRequestRepositoryProvider);
    
    await repository.updatePrayerRequest(
      id: id,
      title: title,
      description: description,
      category: category,
      status: status,
      privacy: privacy,
      isPublic: isPublic,
      allowWhatsappContact: allowWhatsappContact,
    );

    // Invalidar providers
    baseRef.invalidate(allPrayerRequestsProvider);
    baseRef.invalidate(myPrayerRequestsProvider);
    baseRef.invalidate(prayerRequestByIdProvider(id));
    baseRef.invalidate(prayerRequestsByStatusProvider);
    baseRef.invalidate(prayerRequestsByCategoryProvider);
    baseRef.invalidate(prayerRequestsByStatusCountProvider);
    baseRef.invalidate(prayerRequestsByCategoryCountProvider);
  }

  /// Deletar pedido de oração
  Future<void> deletePrayerRequest(String id) async {
    final repository = baseRef.read(prayerRequestRepositoryProvider);
    
    await repository.deletePrayerRequest(id);

    // Invalidar providers
    baseRef.invalidate(allPrayerRequestsProvider);
    baseRef.invalidate(myPrayerRequestsProvider);
    baseRef.invalidate(prayerRequestsByStatusProvider);
    baseRef.invalidate(prayerRequestsByCategoryProvider);
    baseRef.invalidate(prayerRequestsByStatusCountProvider);
    baseRef.invalidate(prayerRequestsByCategoryCountProvider);
  }

  /// Marcar como respondido
  Future<void> markAsAnswered(String id) async {
    await updatePrayerRequest(id: id, status: PrayerStatus.answered);
  }

  /// Marcar como cancelado
  Future<void> markAsCancelled(String id) async {
    await updatePrayerRequest(id: id, status: PrayerStatus.cancelled);
  }

  /// Marcar "eu orei"
  Future<void> markAsPrayed({
    required String prayerRequestId,
    String? note,
  }) async {
    final repository = baseRef.read(prayerRequestRepositoryProvider);
    
    await repository.markAsPrayed(
      prayerRequestId: prayerRequestId,
      note: note,
    );

    // Invalidar providers
    baseRef.invalidate(prayerRequestPrayersProvider(prayerRequestId));
    baseRef.invalidate(hasUserPrayedProvider(prayerRequestId));
    baseRef.invalidate(prayerCountProvider(prayerRequestId));
    baseRef.invalidate(prayerRequestStatsProvider(prayerRequestId));
  }

  /// Criar testemunho
  Future<void> createTestimony({
    required String prayerRequestId,
    required String testimony,
  }) async {
    final repository = baseRef.read(prayerRequestRepositoryProvider);
    
    await repository.createTestimony(
      prayerRequestId: prayerRequestId,
      testimony: testimony,
    );

    // Invalidar providers
    baseRef.invalidate(prayerRequestTestimonyProvider(prayerRequestId));
    baseRef.invalidate(prayerRequestStatsProvider(prayerRequestId));
  }

  /// Atualizar testemunho
  Future<void> updateTestimony({
    required String prayerRequestId,
    required String testimony,
  }) async {
    final repository = baseRef.read(prayerRequestRepositoryProvider);
    
    await repository.updateTestimony(
      prayerRequestId: prayerRequestId,
      testimony: testimony,
    );

    // Invalidar providers
    baseRef.invalidate(prayerRequestTestimonyProvider(prayerRequestId));
  }

  /// Deletar testemunho
  Future<void> deleteTestimony(String prayerRequestId) async {
    final repository = baseRef.read(prayerRequestRepositoryProvider);
    
    await repository.deleteTestimony(prayerRequestId);

    // Invalidar providers
    baseRef.invalidate(prayerRequestTestimonyProvider(prayerRequestId));
    baseRef.invalidate(prayerRequestStatsProvider(prayerRequestId));
}
}

/// Provider de ações
final prayerRequestActionsProvider = Provider<PrayerRequestActions>((ref) {
  return PrayerRequestActions(ref);
});
