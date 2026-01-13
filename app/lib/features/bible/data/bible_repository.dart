import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';

import '../domain/models/bible_book.dart';
import '../domain/models/bible_verse.dart';
import '../domain/models/bible_bookmark.dart';
import '../domain/models/bible_lexeme.dart';
import '../domain/models/bible_verse_token.dart';

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

  Future<List<BibleLexeme>> searchLexemes(String query, {int limit = 50}) async {
    final normalized = query.trim();

    PostgrestFilterBuilder<dynamic> queryBuilder = _supabase.from('bible_lexeme').select();

    if (normalized.isNotEmpty) {
      final trimmed = normalized.toUpperCase();
      final q = trimmed.replaceAll('%', r'\%').replaceAll('_', r'\_');

      final match = RegExp(r'^([HhGg])\s*0*([0-9]{1,5})([A-Za-z]*)$').firstMatch(trimmed);
      if (match != null) {
        final prefix = match.group(1)!.toUpperCase();
        final suffix = (match.group(3) ?? '').toUpperCase();
        final numPart = int.tryParse(match.group(2) ?? '');
        if (numPart != null) {
          try {
            final response = await _supabase.rpc(
              'search_normalized_lexemes',
              params: {
                'p_prefix': prefix,
                'p_num_part': numPart,
                'p_suffix': suffix.isEmpty ? null : suffix,
                'p_limit': limit,
              },
            );

            return (response as List)
                .map((json) => BibleLexeme.fromJson(json as Map<String, dynamic>))
                .toList();
          } catch (_) {}
        }
      }

      queryBuilder = queryBuilder.or(
        [
          'strong_code.ilike.%$q%',
          'pt_gloss.ilike.%$q%',
          'lemma.ilike.%$q%',
          'transliteration.ilike.%$q%',
        ].where((e) => e.trim().isNotEmpty).join(','),
      );
    }

    final response = await queryBuilder.order('strong_code', ascending: true).limit(limit);

    return (response as List).map((json) => BibleLexeme.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<void> setTokenLexeme({
    required int tokenId,
    required int? lexemeId,
  }) async {
    await _supabase
        .from('bible_verse_token')
        .update({'lexeme_id': lexemeId})
        .eq('id', tokenId);
  }

  Future<BibleLexeme> updateLexemePt(
    int lexemeId, {
    String? ptGloss,
    String? ptDefinition,
  }) async {
    String? normalizeNullableText(String? value) {
      final v = value?.trim();
      if (v == null || v.isEmpty) return null;
      return v;
    }

    final response = await _supabase
        .from('bible_lexeme')
        .update({
          'pt_gloss': normalizeNullableText(ptGloss),
          'pt_definition': normalizeNullableText(ptDefinition),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', lexemeId)
        .select()
        .single();

    return BibleLexeme.fromJson(response);
  }
}
