import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../data/devotional_repository.dart';
import '../../domain/models/devotional.dart';
import '../../../members/presentation/providers/members_provider.dart';

// =====================================================
// REPOSITORY PROVIDER
// =====================================================

final devotionalRepositoryProvider = Provider<DevotionalRepository>((ref) {
  return DevotionalRepository(Supabase.instance.client);
});

Future<List<Devotional>> _withDevotionalReactions(
  SupabaseClient supabase,
  List<Devotional> devotionals,
) async {
  if (devotionals.isEmpty) return devotionals;

  final ids = devotionals
      .map((d) => d.id)
      .where((id) => id.trim().isNotEmpty)
      .toList(growable: false);
  if (ids.isEmpty) return devotionals;

  final likesById = <String, int>{};
  final reactsForCount = await supabase
      .from('community_reactions')
      .select('item_id')
      .eq('item_type', 'devotional')
      .eq('tenant_id', SupabaseConstants.currentTenantId)
      .inFilter('item_id', ids);
  for (final r in (reactsForCount as List)) {
    final itemId = (r as Map)['item_id']?.toString();
    if (itemId == null || itemId.trim().isEmpty) continue;
    likesById[itemId] = (likesById[itemId] ?? 0) + 1;
  }

  final myReactions = <String, String?>{};
  final userId = supabase.auth.currentUser?.id;
  if (userId != null) {
    final reacts = await supabase
        .from('community_reactions')
        .select('item_id, reaction')
        .eq('item_type', 'devotional')
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .inFilter('item_id', ids);
    for (final r in (reacts as List)) {
      final itemId = (r as Map)['item_id']?.toString();
      if (itemId == null || itemId.trim().isEmpty) continue;
      myReactions[itemId] = r['reaction']?.toString();
    }
  }

  return devotionals
      .map(
        (d) => d.copyWith(
          likesCount: likesById[d.id] ?? 0,
          myReaction: myReactions[d.id],
          isLikedByMe: myReactions[d.id] != null,
        ),
      )
      .toList(growable: false);
}

Future<List<Devotional>> _withDevotionalBookmarks(
  SupabaseClient supabase,
  List<Devotional> devotionals,
) async {
  if (devotionals.isEmpty) return devotionals;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return devotionals;

  final ids = devotionals
      .map((d) => d.id)
      .where((id) => id.trim().isNotEmpty)
      .toList(growable: false);
  if (ids.isEmpty) return devotionals;

  final rows = await supabase
      .from('devotional_bookmarks')
      .select('devotional_id')
      .eq('tenant_id', SupabaseConstants.currentTenantId)
      .eq('user_id', userId)
      .inFilter('devotional_id', ids);

  final savedIds = (rows as List)
      .map((e) => (e as Map)['devotional_id']?.toString())
      .whereType<String>()
      .where((id) => id.trim().isNotEmpty)
      .toSet();

  if (savedIds.isEmpty) return devotionals;

  return devotionals
      .map((d) => d.copyWith(isSavedByMe: savedIds.contains(d.id)))
      .toList(growable: false);
}

// =====================================================
// DEVOTIONALS PROVIDERS
// =====================================================

/// Provider para todos os devocionais publicados
final allDevotionalsProvider = FutureProvider<List<Devotional>>((ref) async {
  ref.watch(authStateProvider);
  final repository = ref.watch(devotionalRepositoryProvider);
  final devotionals = await repository.getAllDevotionals();
  final withReacts = await _withDevotionalReactions(
    Supabase.instance.client,
    devotionals,
  );
  return _withDevotionalBookmarks(Supabase.instance.client, withReacts);
});

/// Provider para todos os devocionais (incluindo rascunhos)
final allDevotionalsIncludingDraftsProvider = FutureProvider<List<Devotional>>((ref) async {
  ref.watch(authStateProvider);
  final repository = ref.watch(devotionalRepositoryProvider);
  final devotionals = await repository.getAllDevotionalsIncludingDrafts();
  final withReacts = await _withDevotionalReactions(
    Supabase.instance.client,
    devotionals,
  );
  return _withDevotionalBookmarks(Supabase.instance.client, withReacts);
});

/// Provider para devocional por ID
final devotionalByIdProvider = FutureProvider.family<Devotional?, String>((ref, id) async {
  ref.watch(authStateProvider);
  final repository = ref.watch(devotionalRepositoryProvider);
  return repository.getDevotionalById(id);
});

final isDevotionalSavedProvider = FutureProvider.family<bool, String>((ref, devotionalId) async {
  ref.watch(authStateProvider);
  final repository = ref.watch(devotionalRepositoryProvider);
  final member = await ref.watch(currentMemberProvider.future);
  if (member == null) return false;
  return repository.isDevotionalSaved(
    devotionalId: devotionalId,
    userId: member.id,
  );
});

final savedDevotionalsProvider = FutureProvider<List<Devotional>>((ref) async {
  ref.watch(authStateProvider);
  final repository = ref.watch(devotionalRepositoryProvider);
  final member = await ref.watch(currentMemberProvider.future);
  if (member == null) return const [];
  final devotionals = await repository.getSavedDevotionals(member.id);
  final withReacts = await _withDevotionalReactions(
    Supabase.instance.client,
    devotionals,
  );
  return withReacts;
});

/// Provider para devocional do dia
final todayDevotionalProvider = FutureProvider<Devotional?>((ref) async {
  ref.watch(authStateProvider);
  final repository = ref.watch(devotionalRepositoryProvider);
  return repository.getTodayDevotional();
});

/// Provider para devocional por data
final devotionalByDateProvider = FutureProvider.family<Devotional?, DateTime>((ref, date) async {
  ref.watch(authStateProvider);
  final repository = ref.watch(devotionalRepositoryProvider);
  return repository.getDevotionalByDate(date);
});

// =====================================================
// READINGS PROVIDERS
// =====================================================

/// Provider para leituras de um devocional
final devotionalReadingsProvider = FutureProvider.family<List<DevotionalReading>, String>((ref, devotionalId) async {
  ref.watch(authStateProvider);
  final repository = ref.watch(devotionalRepositoryProvider);
  return repository.getDevotionalReadings(devotionalId);
});

/// Provider para leituras do usuário atual
final currentUserReadingsProvider = FutureProvider<List<DevotionalReading>>((ref) async {
  ref.watch(authStateProvider);
  final repository = ref.watch(devotionalRepositoryProvider);
  final member = await ref.watch(currentMemberProvider.future);
  if (member == null) return [];
  return repository.getUserReadings(member.id);
});

final currentUserReadingsWithDevotionalProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authStateProvider);
  final repository = ref.watch(devotionalRepositoryProvider);
  final member = await ref.watch(currentMemberProvider.future);
  if (member == null) return const [];
  return repository.getUserReadingsWithDevotional(member.id);
});

/// Provider para leituras de um usuário específico
final userReadingsProvider = FutureProvider.family<List<DevotionalReading>, String>((ref, userId) async {
  ref.watch(authStateProvider);
  final repository = ref.watch(devotionalRepositoryProvider);
  return repository.getUserReadings(userId);
});

/// Provider para verificar se usuário leu um devocional
final hasUserReadDevotionalProvider = FutureProvider.family<bool, String>((ref, devotionalId) async {
  ref.watch(authStateProvider);
  final repository = ref.watch(devotionalRepositoryProvider);
  final member = await ref.watch(currentMemberProvider.future);
  if (member == null) return false;
  return repository.hasUserReadDevotional(member.id, devotionalId);
});

/// Provider para leitura específica do usuário
final userDevotionalReadingProvider = FutureProvider.family<DevotionalReading?, String>((ref, devotionalId) async {
  final repository = ref.watch(devotionalRepositoryProvider);
  final member = await ref.watch(currentMemberProvider.future);
  if (member == null) return null;
  return repository.getUserDevotionalReading(member.id, devotionalId);
});

// =====================================================
// STATISTICS PROVIDERS
// =====================================================

/// Provider para estatísticas de um devocional
final devotionalStatsProvider = FutureProvider.family<DevotionalStats, String>((ref, devotionalId) async {
  final repository = ref.watch(devotionalRepositoryProvider);
  return repository.getDevotionalStats(devotionalId);
});

/// Provider para streak de leituras do usuário atual
final currentUserReadingStreakProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(devotionalRepositoryProvider);
  final member = await ref.watch(currentMemberProvider.future);
  if (member == null) return 0;
  return repository.getUserReadingStreak(member.id);
});

/// Provider para total de leituras do usuário atual
final currentUserTotalReadingsProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(devotionalRepositoryProvider);
  final member = await ref.watch(currentMemberProvider.future);
  if (member == null) return 0;
  return repository.getUserTotalReadings(member.id);
});

/// Provider para devocionais mais lidos
final mostReadDevotionalsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(devotionalRepositoryProvider);
  return repository.getMostReadDevotionals(limit: 10);
});

final weeklyReadingsCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(devotionalRepositoryProvider);
  final since = DateTime.now().subtract(const Duration(days: 7));
  return repository.getReadingsCountSince(since);
});

final todayReadingsCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(devotionalRepositoryProvider);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  return repository.getReadingsCountSince(startOfDay);
});

final weeklyUniqueReadersCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(devotionalRepositoryProvider);
  final since = DateTime.now().subtract(const Duration(days: 7));
  return repository.getUniqueReadersCountSince(since);
});

// =====================================================
// ACTIONS CLASS
// =====================================================

/// Classe para ações de devocionais (mutations)
class DevotionalActions {
  final Ref ref;

  DevotionalActions(this.ref);

  // =====================================================
  // DEVOTIONALS ACTIONS
  // =====================================================

  /// Criar novo devocional
  Future<void> createDevotional({
    required String title,
    required String content,
    String? scriptureReference,
    required DateTime devotionalDate,
    bool isPublished = false,
    String? imageUrl,
    String? category,
    String? preacher,
    String? youtubeUrl,
  }) async {
    final repository = ref.read(devotionalRepositoryProvider);
    final member = await ref.read(currentMemberProvider.future);
    if (member == null) {
      throw Exception('Usuário não autenticado');
    }

    await repository.createDevotional(
      title: title,
      content: content,
      scriptureReference: scriptureReference,
      devotionalDate: devotionalDate,
      authorId: member.id,
      isPublished: isPublished,
      imageUrl: imageUrl,
      category: category,
      preacher: preacher,
      youtubeUrl: youtubeUrl,
    );

    // Invalidar providers
    ref.invalidate(allDevotionalsProvider);
    ref.invalidate(allDevotionalsIncludingDraftsProvider);
    ref.invalidate(todayDevotionalProvider);
  }

  /// Atualizar devocional
  Future<void> updateDevotional({
    required String id,
    String? title,
    String? content,
    String? scriptureReference,
    DateTime? devotionalDate,
    bool? isPublished,
    String? imageUrl,
    String? category,
    String? preacher,
    String? youtubeUrl,
  }) async {
    final repository = ref.read(devotionalRepositoryProvider);

    await repository.updateDevotional(
      id: id,
      title: title,
      content: content,
      scriptureReference: scriptureReference,
      devotionalDate: devotionalDate,
      isPublished: isPublished,
      imageUrl: imageUrl,
      category: category,
      preacher: preacher,
      youtubeUrl: youtubeUrl,
    );

    // Invalidar providers
    ref.invalidate(allDevotionalsProvider);
    ref.invalidate(allDevotionalsIncludingDraftsProvider);
    ref.invalidate(devotionalByIdProvider(id));
    ref.invalidate(todayDevotionalProvider);
  }

  /// Deletar devocional
  Future<void> deleteDevotional(String id) async {
    final repository = ref.read(devotionalRepositoryProvider);

    await repository.deleteDevotional(id);

    // Invalidar providers
    ref.invalidate(allDevotionalsProvider);
    ref.invalidate(allDevotionalsIncludingDraftsProvider);
    ref.invalidate(devotionalByIdProvider(id));
    ref.invalidate(todayDevotionalProvider);
  }

  /// Publicar devocional
  Future<void> publishDevotional(String id) async {
    final repository = ref.read(devotionalRepositoryProvider);

    await repository.publishDevotional(id);

    // Invalidar providers
    ref.invalidate(allDevotionalsProvider);
    ref.invalidate(allDevotionalsIncludingDraftsProvider);
    ref.invalidate(devotionalByIdProvider(id));
    ref.invalidate(todayDevotionalProvider);
  }

  /// Despublicar devocional
  Future<void> unpublishDevotional(String id) async {
    final repository = ref.read(devotionalRepositoryProvider);

    await repository.unpublishDevotional(id);

    // Invalidar providers
    ref.invalidate(allDevotionalsProvider);
    ref.invalidate(allDevotionalsIncludingDraftsProvider);
    ref.invalidate(devotionalByIdProvider(id));
    ref.invalidate(todayDevotionalProvider);
  }

  // =====================================================
  // READINGS ACTIONS
  // =====================================================

  /// Marcar devocional como lido
  Future<void> markAsRead({
    required String devotionalId,
    String? notes,
  }) async {
    final repository = ref.read(devotionalRepositoryProvider);
    final member = await ref.read(currentMemberProvider.future);
    if (member == null) {
      throw Exception('Usuário não autenticado');
    }

    await repository.markAsRead(
      devotionalId: devotionalId,
      userId: member.id,
      notes: notes,
    );

    // Invalidar providers
    ref.invalidate(currentUserReadingsProvider);
    ref.invalidate(hasUserReadDevotionalProvider(devotionalId));
    ref.invalidate(userDevotionalReadingProvider(devotionalId));
    ref.invalidate(devotionalReadingsProvider(devotionalId));
    ref.invalidate(devotionalStatsProvider(devotionalId));
    ref.invalidate(currentUserReadingStreakProvider);
    ref.invalidate(currentUserTotalReadingsProvider);
  }

  /// Atualizar anotações de leitura
  Future<void> updateReadingNotes({
    required String readingId,
    required String notes,
  }) async {
    final repository = ref.read(devotionalRepositoryProvider);

    await repository.updateReadingNotes(
      readingId: readingId,
      notes: notes,
    );

    // Invalidar providers
    ref.invalidate(currentUserReadingsProvider);
  }

  /// Deletar leitura
  Future<void> deleteReading(String readingId) async {
    final repository = ref.read(devotionalRepositoryProvider);

    await repository.deleteReading(readingId);

    // Invalidar providers
    ref.invalidate(currentUserReadingsProvider);
    ref.invalidate(currentUserReadingStreakProvider);
    ref.invalidate(currentUserTotalReadingsProvider);
  }

  Future<bool> toggleSaveDevotional(String devotionalId) async {
    final repository = ref.read(devotionalRepositoryProvider);
    final member = await ref.read(currentMemberProvider.future);
    if (member == null) {
      throw Exception('Usuário não autenticado');
    }

    final isSaved = await repository.isDevotionalSaved(
      devotionalId: devotionalId,
      userId: member.id,
    );

    if (isSaved) {
      await repository.removeSavedDevotional(
        devotionalId: devotionalId,
        userId: member.id,
      );
    } else {
      await repository.saveDevotional(
        devotionalId: devotionalId,
        userId: member.id,
      );
    }

    ref.invalidate(isDevotionalSavedProvider(devotionalId));
    ref.invalidate(savedDevotionalsProvider);
    ref.invalidate(allDevotionalsProvider);
    ref.invalidate(allDevotionalsIncludingDraftsProvider);
    return !isSaved;
  }
}

/// Provider para ações de devocionais
final devotionalActionsProvider = Provider<DevotionalActions>((ref) {
  return DevotionalActions(ref);
});
