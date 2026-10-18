import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';

import '../domain/models/bible_book.dart';
import '../domain/models/bible_verse.dart';
import '../domain/models/bible_bookmark.dart';
import '../domain/models/bible_lexeme.dart';
import '../domain/models/bible_verse_token.dart';
import '../domain/models/bible_word_study.dart';

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

  /// Contagem de versículos por capítulo de um livro
  Future<Map<int, int>> getVerseCountsByChapter(int bookId) async {
    final response = await _supabase
        .from('bible_verse')
        .select('chapter, verse')
        .eq('book_id', bookId);

    final counts = <int, int>{};
    for (final row in response as List) {
      final chapter = row['chapter'] as int;
      counts[chapter] = (counts[chapter] ?? 0) + 1;
    }
    return counts;
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
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('user_id', memberId)
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
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('user_id', memberId)
        .eq('verse_id', verseId)
        .maybeSingle();

    return response != null;
  }

  /// Adicionar favorito
  Future<BibleBookmark> addBookmark(String memberId, int verseId, {String? note}) async {
    final response = await _supabase
        .from('bible_bookmark')
        .insert({
          'user_id': memberId,
          'verse_id': verseId,
          'tenant_id': SupabaseConstants.currentTenantId,
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
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('user_id', memberId)
        .eq('verse_id', verseId);
  }

  /// Atualizar nota do favorito
  Future<BibleBookmark> updateBookmarkNote(String bookmarkId, String? note) async {
    final response = await _supabase
        .from('bible_bookmark')
        .update({'note': note})
        .eq('id', bookmarkId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select()
        .single();

    return BibleBookmark.fromJson(response);
  }

  /// Deletar favorito por ID
  Future<void> deleteBookmark(String bookmarkId) async {
    await _supabase
        .from('bible_bookmark')
        .delete()
        .eq('id', bookmarkId)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  // =====================================================
  // DICIONÁRIO / TOKENS
  // =====================================================

  Future<Map<int, List<BibleVerseToken>>> getVerseTokensByChapter(int bookId, int chapter) async {
    final verseRows = await _supabase
        .from('bible_verse')
        .select('id')
        .eq('book_id', bookId)
        .eq('chapter', chapter);

    final verseIds = (verseRows as List).map((e) => e['id'] as int).toList();
    if (verseIds.isEmpty) return {};

    final tokenRows = await _supabase
        .from('bible_verse_token')
        .select('''
          *,
          bible_lexeme(*)
        ''')
        .inFilter('verse_id', verseIds)
        .order('verse_id', ascending: true)
        .order('token_index', ascending: true);

    final byVerseId = <int, List<BibleVerseToken>>{};
    for (final row in tokenRows as List) {
      final token = BibleVerseToken.fromJson(row as Map<String, dynamic>);
      byVerseId.putIfAbsent(token.verseId, () => []).add(token);
    }

    return byVerseId;
  }

  /// Estudos publicados do capítulo, por versículo (RLS só entrega 'publicado').
  Future<Map<int, List<BibleWordStudy>>> getWordStudiesByChapter(int bookId, int chapter) async {
    final rows = await _supabase
        .from('bible_word_study_occurrence')
        .select('verse_id, palavra_pt, secoes, bible_word_study!inner(*), bible_verse!inner(book_id, chapter)')
        .eq('bible_verse.book_id', bookId)
        .eq('bible_verse.chapter', chapter)
        .order('ordem', ascending: true);

    final byVerseId = <int, List<BibleWordStudy>>{};
    for (final row in rows as List) {
      final study = BibleWordStudy.fromOccurrenceJson(row as Map<String, dynamic>);
      byVerseId.putIfAbsent(study.verseId, () => []).add(study);
    }
    return byVerseId;
  }

  Future<BibleLexeme?> getLexemeByStrongCode(String strongCode) async {
    String canonicalize(String value) {
      final trimmed = value.trim();
      final match = RegExp(r'^([HhGg])\s*0*([0-9]{1,5})([A-Za-z]*)$').firstMatch(trimmed);
      if (match == null) return trimmed;
      final prefix = match.group(1)!.toUpperCase();
      final digits = match.group(2)!;
      final suffix = (match.group(3) ?? '').toUpperCase();
      final paddedDigits = digits.length >= 4 ? digits : digits.padLeft(4, '0');
      return '$prefix$paddedDigits$suffix';
    }

    String stripLeadingZeros(String value) {
      final match = RegExp(r'^([HhGg])0*([0-9]{1,5})([A-Za-z]*)$').firstMatch(value.trim());
      if (match == null) return value.trim();
      final prefix = match.group(1)!.toUpperCase();
      final digits = match.group(2)!;
      final suffix = (match.group(3) ?? '').toUpperCase();
      return '$prefix$digits$suffix';
    }

    final trimmed = strongCode.trim();
    final candidates = <String>{
      trimmed,
      trimmed.toUpperCase(),
      canonicalize(trimmed),
      stripLeadingZeros(trimmed),
    }.where((e) => e.isNotEmpty).toList();

    dynamic response;
    for (final code in candidates) {
      response = await _supabase.from('bible_lexeme').select().eq('strong_code', code).maybeSingle();
      if (response != null) break;
    }

    if (response == null) return null;
    return BibleLexeme.fromJson(response);
  }
}
