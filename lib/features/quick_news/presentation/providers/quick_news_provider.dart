import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/quick_news_repository.dart';
import '../../domain/models/quick_news.dart';

// =====================================================
// PROVIDERS: REPOSITORY
// =====================================================

final quickNewsRepositoryProvider = Provider<QuickNewsRepository>((ref) {
  return QuickNewsRepository(Supabase.instance.client);
});

// =====================================================
// PROVIDERS: DATA
// =====================================================

/// Provider: Todos os avisos (para admin)
final allQuickNewsProvider = FutureProvider<List<QuickNews>>((ref) async {
  final repo = ref.watch(quickNewsRepositoryProvider);
  return repo.getAllNews();
});

/// Provider: Avisos ativos (para usuários)
final activeQuickNewsProvider = StreamProvider<List<QuickNews>>((ref) {
  final repo = ref.watch(quickNewsRepositoryProvider);
  return repo.watchActiveNews();
});

/// Provider: Aviso por ID
final quickNewsByIdProvider = FutureProvider.family<QuickNews?, String>((ref, id) async {
  final repo = ref.watch(quickNewsRepositoryProvider);
  return repo.getNewsById(id);
});

