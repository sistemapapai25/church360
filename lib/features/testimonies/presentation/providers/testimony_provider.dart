import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/testimony_repository.dart';
import '../../domain/models/testimony.dart';

// =====================================================
// REPOSITORY PROVIDER
// =====================================================

final testimonyRepositoryProvider = Provider<TestimonyRepository>((ref) {
  return TestimonyRepository(Supabase.instance.client);
});

// =====================================================
// DATA PROVIDERS
// =====================================================

/// Provider: TODOS os testemunhos (admin)
final allTestimoniesProvider = FutureProvider<List<Testimony>>((ref) async {
  final repository = ref.watch(testimonyRepositoryProvider);
  return repository.getAllTestimonies();
});

/// Provider: Todos os testemunhos públicos
final publicTestimoniesProvider = FutureProvider<List<Testimony>>((ref) async {
  final repository = ref.watch(testimonyRepositoryProvider);
  return repository.getAllPublicTestimonies();
});

/// Provider: Meus testemunhos
final myTestimoniesProvider = FutureProvider<List<Testimony>>((ref) async {
  final repository = ref.watch(testimonyRepositoryProvider);
  return repository.getMyTestimonies();
});

/// Provider: Testemunho por ID
final testimonyByIdProvider = FutureProvider.family<Testimony?, String>((ref, id) async {
  final repository = ref.watch(testimonyRepositoryProvider);
  return repository.getTestimonyById(id);
});

/// Provider: Contar meus testemunhos
final myTestimoniesCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(testimonyRepositoryProvider);
  return repository.countMyTestimonies();
});

// =====================================================
// ACTIONS
// =====================================================

/// Classe de ações para testemunhos
class TestimonyActions {
  final Ref ref;

  TestimonyActions(this.ref);

  /// Criar testemunho
  Future<Testimony> createTestimony({
    required String title,
    required String description,
    required bool isPublic,
    required bool allowWhatsappContact,
  }) async {
    final repository = ref.read(testimonyRepositoryProvider);
    final testimony = await repository.createTestimony(
      title: title,
      description: description,
      isPublic: isPublic,
      allowWhatsappContact: allowWhatsappContact,
    );

    // Invalidar providers para atualizar a lista
    ref.invalidate(publicTestimoniesProvider);
    ref.invalidate(myTestimoniesProvider);
    ref.invalidate(myTestimoniesCountProvider);

    return testimony;
  }

  /// Atualizar testemunho
  Future<Testimony> updateTestimony({
    required String id,
    String? title,
    String? description,
    bool? isPublic,
    bool? allowWhatsappContact,
  }) async {
    final repository = ref.read(testimonyRepositoryProvider);
    final testimony = await repository.updateTestimony(
      id: id,
      title: title,
      description: description,
      isPublic: isPublic,
      allowWhatsappContact: allowWhatsappContact,
    );

    // Invalidar providers
    ref.invalidate(publicTestimoniesProvider);
    ref.invalidate(myTestimoniesProvider);
    ref.invalidate(testimonyByIdProvider(id));

    return testimony;
  }

  /// Deletar testemunho
  Future<void> deleteTestimony(String id) async {
    final repository = ref.read(testimonyRepositoryProvider);
    await repository.deleteTestimony(id);

    // Invalidar providers
    ref.invalidate(publicTestimoniesProvider);
    ref.invalidate(myTestimoniesProvider);
    ref.invalidate(myTestimoniesCountProvider);
  }
}

/// Provider de ações
final testimonyActionsProvider = Provider<TestimonyActions>((ref) {
  return TestimonyActions(ref);
});

