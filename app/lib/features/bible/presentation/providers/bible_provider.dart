import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/bible_repository.dart';
import '../../domain/models/bible_book.dart';
import '../../domain/models/bible_verse.dart';
import '../../domain/models/bible_bookmark.dart';

/// Provider do repository da Bíblia
final bibleRepositoryProvider = Provider<BibleRepository>((ref) {
  return BibleRepository(Supabase.instance.client);
});

/// Provider de todos os livros da Bíblia
final allBibleBooksProvider = FutureProvider<List<BibleBook>>((ref) async {
  final repo = ref.watch(bibleRepositoryProvider);
  return repo.getAllBooks();
});

/// Provider de livros do Antigo Testamento
final oldTestamentBooksProvider = FutureProvider<List<BibleBook>>((ref) async {
  final repo = ref.watch(bibleRepositoryProvider);
  return repo.getBooksByTestament('OT');
});

/// Provider de livros do Novo Testamento
final newTestamentBooksProvider = FutureProvider<List<BibleBook>>((ref) async {
  final repo = ref.watch(bibleRepositoryProvider);
  return repo.getBooksByTestament('NT');
});

/// Provider de livro por ID
final bibleBookByIdProvider = FutureProvider.family<BibleBook?, int>((ref, id) async {
  final repo = ref.watch(bibleRepositoryProvider);
  return repo.getBookById(id);
});

/// Provider de versículos de um capítulo
final bibleChapterVersesProvider = FutureProvider.family<List<BibleVerse>, ({int bookId, int chapter})>((ref, params) async {
  final repo = ref.watch(bibleRepositoryProvider);
  return repo.getVersesByChapter(params.bookId, params.chapter);
});

/// Provider de versículo específico
final bibleVerseProvider = FutureProvider.family<BibleVerse?, ({int bookId, int chapter, int verse})>((ref, params) async {
  final repo = ref.watch(bibleRepositoryProvider);
  return repo.getVerse(params.bookId, params.chapter, params.verse);
});

/// Provider de versículo por ID
final bibleVerseByIdProvider = FutureProvider.family<BibleVerse?, int>((ref, id) async {
  final repo = ref.watch(bibleRepositoryProvider);
  return repo.getVerseById(id);
});

/// Provider de contagem de versículos por capítulo
final verseCountsByBookProvider = FutureProvider.family<Map<int, int>, int>((ref, bookId) async {
  final repo = ref.watch(bibleRepositoryProvider);
  return repo.getVerseCountsByChapter(bookId);
});

/// Provider de busca de versículos
final bibleSearchProvider = FutureProvider.family<List<BibleVerse>, ({String query, int? bookId, String? testament})>((ref, params) async {
  final repo = ref.watch(bibleRepositoryProvider);
  return repo.searchVerses(params.query, bookId: params.bookId, testament: params.testament);
});

/// Provider de favoritos do usuário
final userBibleBookmarksProvider = FutureProvider.family<List<BibleBookmark>, String>((ref, memberId) async {
  final repo = ref.watch(bibleRepositoryProvider);
  return repo.getUserBookmarks(memberId);
});

/// Provider para verificar se versículo está favoritado
final isVerseBookmarkedProvider = FutureProvider.family<bool, ({String memberId, int verseId})>((ref, params) async {
  final repo = ref.watch(bibleRepositoryProvider);
  return repo.isBookmarked(params.memberId, params.verseId);
});
