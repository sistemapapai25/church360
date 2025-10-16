import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/devotional_repository.dart';
import '../../domain/models/devotional.dart';

// =====================================================
// REPOSITORY PROVIDER
// =====================================================

final devotionalRepositoryProvider = Provider<DevotionalRepository>((ref) {
  return DevotionalRepository(Supabase.instance.client);
});

// =====================================================
// DEVOTIONALS PROVIDERS
// =====================================================

/// Provider para todos os devocionais publicados
final allDevotionalsProvider = FutureProvider<List<Devotional>>((ref) async {
  final repository = ref.watch(devotionalRepositoryProvider);
  return repository.getAllDevotionals();
});

/// Provider para todos os devocionais (incluindo rascunhos)
final allDevotionalsIncludingDraftsProvider = FutureProvider<List<Devotional>>((ref) async {
  final repository = ref.watch(devotionalRepositoryProvider);
  return repository.getAllDevotionalsIncludingDrafts();
});

/// Provider para devocional por ID
final devotionalByIdProvider = FutureProvider.family<Devotional?, String>((ref, id) async {
  final repository = ref.watch(devotionalRepositoryProvider);
  return repository.getDevotionalById(id);
});

/// Provider para devocional do dia
final todayDevotionalProvider = FutureProvider<Devotional?>((ref) async {
  final repository = ref.watch(devotionalRepositoryProvider);
  return repository.getTodayDevotional();
});

/// Provider para devocional por data
final devotionalByDateProvider = FutureProvider.family<Devotional?, DateTime>((ref, date) async {
  final repository = ref.watch(devotionalRepositoryProvider);
  return repository.getDevotionalByDate(date);
});

// =====================================================
// READINGS PROVIDERS
// =====================================================

/// Provider para leituras de um devocional
final devotionalReadingsProvider = FutureProvider.family<List<DevotionalReading>, String>((ref, devotionalId) async {
  final repository = ref.watch(devotionalRepositoryProvider);
  return repository.getDevotionalReadings(devotionalId);
});

/// Provider para leituras do usuário atual
final currentUserReadingsProvider = FutureProvider<List<DevotionalReading>>((ref) async {
  final repository = ref.watch(devotionalRepositoryProvider);
  final userId = Supabase.instance.client.auth.currentUser?.id;
  
  if (userId == null) return [];
  
  return repository.getUserReadings(userId);
});

/// Provider para leituras de um usuário específico
final userReadingsProvider = FutureProvider.family<List<DevotionalReading>, String>((ref, userId) async {
  final repository = ref.watch(devotionalRepositoryProvider);
  return repository.getUserReadings(userId);
});

/// Provider para verificar se usuário leu um devocional
final hasUserReadDevotionalProvider = FutureProvider.family<bool, String>((ref, devotionalId) async {
  final repository = ref.watch(devotionalRepositoryProvider);
  final userId = Supabase.instance.client.auth.currentUser?.id;
  
  if (userId == null) return false;
  
  return repository.hasUserReadDevotional(userId, devotionalId);
});

/// Provider para leitura específica do usuário
final userDevotionalReadingProvider = FutureProvider.family<DevotionalReading?, String>((ref, devotionalId) async {
  final repository = ref.watch(devotionalRepositoryProvider);
  final userId = Supabase.instance.client.auth.currentUser?.id;
  
  if (userId == null) return null;
  
  return repository.getUserDevotionalReading(userId, devotionalId);
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
  final userId = Supabase.instance.client.auth.currentUser?.id;
  
  if (userId == null) return 0;
  
  return repository.getUserReadingStreak(userId);
});

/// Provider para total de leituras do usuário atual
final currentUserTotalReadingsProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(devotionalRepositoryProvider);
  final userId = Supabase.instance.client.auth.currentUser?.id;
  
  if (userId == null) return 0;
  
  return repository.getUserTotalReadings(userId);
});

/// Provider para devocionais mais lidos
final mostReadDevotionalsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(devotionalRepositoryProvider);
  return repository.getMostReadDevotionals(limit: 10);
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
  }) async {
    final repository = ref.read(devotionalRepositoryProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    
    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }

    await repository.createDevotional(
      title: title,
      content: content,
      scriptureReference: scriptureReference,
      devotionalDate: devotionalDate,
      authorId: userId,
      isPublished: isPublished,
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
  }) async {
    final repository = ref.read(devotionalRepositoryProvider);

    await repository.updateDevotional(
      id: id,
      title: title,
      content: content,
      scriptureReference: scriptureReference,
      devotionalDate: devotionalDate,
      isPublished: isPublished,
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
    final userId = Supabase.instance.client.auth.currentUser?.id;
    
    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }

    await repository.markAsRead(
      devotionalId: devotionalId,
      userId: userId,
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
}

/// Provider para ações de devocionais
final devotionalActionsProvider = Provider<DevotionalActions>((ref) {
  return DevotionalActions(ref);
});

