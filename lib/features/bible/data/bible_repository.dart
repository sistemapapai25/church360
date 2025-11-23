import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/bible_book.dart';
import '../domain/models/bible_verse.dart';
import '../domain/models/bible_bookmark.dart';

/// Repository para gerenciar dados da Bíblia
class BibleRepository {
  final SupabaseClient _supabase;

  BibleRepository(this._supabase);

  // =====================================================
  // LIVROS
  // =====================================================

  /// Buscar todos os livros da Bíblia
  Future<List<BibleBook>> getAllBooks() async {
    final response = await _supabase
        .from('bible_book')
        .select()
        .order('order_number', ascending: true);

    return (response as List)
        .map((json) => BibleBook.fromJson(json))
        .toList();
  }

  /// Buscar livros por testamento
  Future<List<BibleBook>> getBooksByTestament(String testament) async {
    final response = await _supabase
        .from('bible_book')
        .select()
        .eq('testament', testament)
        .order('order_number', ascending: true);

    return (response as List)
        .map((json) => BibleBook.fromJson(json))
        .toList();
  }

  /// Buscar livro por ID
  Future<BibleBook?> getBookById(int id) async {
    final response = await _supabase
        .from('bible_book')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return BibleBook.fromJson(response);
  }

  // =====================================================
  // VERSÍCULOS
  // =====================================================

  /// Buscar versículos de um capítulo
  Future<List<BibleVerse>> getVersesByChapter(int bookId, int chapter) async {
    final response = await _supabase
        .from('bible_verse')
        .select('''
          *,
          bible_book!inner(name, abbrev)
        ''')
        .eq('book_id', bookId)
        .eq('chapter', chapter)
        .order('verse', ascending: true);

    return (response as List).map((json) {
      return BibleVerse.fromJson({
        ...json,
        'book_name': json['bible_book']['name'],
        'book_abbrev': json['bible_book']['abbrev'],
      });
    }).toList();
  }

  /// Buscar um versículo específico
  Future<BibleVerse?> getVerse(int bookId, int chapter, int verse) async {
    final response = await _supabase
        .from('bible_verse')
        .select('''
          *,
          bible_book!inner(name, abbrev)
        ''')
        .eq('book_id', bookId)
        .eq('chapter', chapter)
        .eq('verse', verse)
        .maybeSingle();

    if (response == null) return null;

    return BibleVerse.fromJson({
      ...response,
      'book_name': response['bible_book']['name'],
      'book_abbrev': response['bible_book']['abbrev'],
    });
  }

  /// Buscar versículo por ID
  Future<BibleVerse?> getVerseById(int id) async {
    final response = await _supabase
        .from('bible_verse')
        .select('''
          *,
          bible_book!inner(name, abbrev)
        ''')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;

    return BibleVerse.fromJson({
      ...response,
      'book_name': response['bible_book']['name'],
      'book_abbrev': response['bible_book']['abbrev'],
    });
  }

  /// Buscar versículos por texto (busca)
  Future<List<BibleVerse>> searchVerses(String query, {int? bookId, String? testament}) async {
    var queryBuilder = _supabase
        .from('bible_verse')
        .select('''
          *,
          bible_book!inner(name, abbrev, testament)
        ''')
        .ilike('text', '%$query%');

    if (bookId != null) {
      queryBuilder = queryBuilder.eq('book_id', bookId);
    }

    if (testament != null) {
      queryBuilder = queryBuilder.eq('bible_book.testament', testament);
    }

    final response = await queryBuilder
        .order('book_id', ascending: true)
        .order('chapter', ascending: true)
        .order('verse', ascending: true)
        .limit(100); // Limitar resultados para performance

    return (response as List).map((json) {
      return BibleVerse.fromJson({
        ...json,
        'book_name': json['bible_book']['name'],
        'book_abbrev': json['bible_book']['abbrev'],
      });
    }).toList();
  }

  // =====================================================
  // FAVORITOS/MARCADORES
  // =====================================================

  /// Buscar favoritos do usuário
  Future<List<BibleBookmark>> getUserBookmarks(String memberId) async {
    final response = await _supabase
        .from('bible_bookmark')
        .select('''
          *,
          bible_verse!inner(
            id,
            book_id,
            chapter,
            verse,
            text,
            bible_book!inner(name, abbrev)
          )
        ''')
        .eq('member_id', memberId)
        .order('created_at', ascending: false);

    return (response as List).map((json) {
      final verse = json['bible_verse'];
      final book = verse['bible_book'];
      final reference = '${book['abbrev']} ${verse['chapter']}:${verse['verse']}';

      return BibleBookmark.fromJson({
        ...json,
        'verse_text': verse['text'],
        'verse_reference': reference,
      });
    }).toList();
  }

  /// Verificar se versículo está favoritado
  Future<bool> isBookmarked(String memberId, int verseId) async {
    final response = await _supabase
        .from('bible_bookmark')
        .select('id')
        .eq('member_id', memberId)
        .eq('verse_id', verseId)
        .maybeSingle();

    return response != null;
  }

  /// Adicionar favorito
  Future<BibleBookmark> addBookmark(String memberId, int verseId, {String? note}) async {
    final response = await _supabase
        .from('bible_bookmark')
        .insert({
          'member_id': memberId,
          'verse_id': verseId,
          if (note != null) 'note': note,
        })
        .select()
        .single();

    return BibleBookmark.fromJson(response);
  }

  /// Remover favorito
  Future<void> removeBookmark(String memberId, int verseId) async {
    await _supabase
        .from('bible_bookmark')
        .delete()
        .eq('member_id', memberId)
        .eq('verse_id', verseId);
  }

  /// Atualizar nota do favorito
  Future<BibleBookmark> updateBookmarkNote(String bookmarkId, String? note) async {
    final response = await _supabase
        .from('bible_bookmark')
        .update({'note': note})
        .eq('id', bookmarkId)
        .select()
        .single();

    return BibleBookmark.fromJson(response);
  }

  /// Deletar favorito por ID
  Future<void> deleteBookmark(String bookmarkId) async {
    await _supabase
        .from('bible_bookmark')
        .delete()
        .eq('id', bookmarkId);
  }
}

