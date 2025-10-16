import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/devotional.dart';

/// Repository para gerenciar devocionais
class DevotionalRepository {
  final SupabaseClient _supabase;

  DevotionalRepository(this._supabase);

  // =====================================================
  // DEVOTIONALS - CRUD
  // =====================================================

  /// Buscar todos os devocionais publicados
  Future<List<Devotional>> getAllDevotionals() async {
    final response = await _supabase
        .from('devotionals')
        .select()
        .eq('is_published', true)
        .order('devotional_date', ascending: false);

    return (response as List)
        .map((json) => Devotional.fromJson(json))
        .toList();
  }

  /// Buscar todos os devocionais (incluindo rascunhos) - apenas Coordenadores+
  Future<List<Devotional>> getAllDevotionalsIncludingDrafts() async {
    final response = await _supabase
        .from('devotionals')
        .select()
        .order('devotional_date', ascending: false);

    return (response as List)
        .map((json) => Devotional.fromJson(json))
        .toList();
  }

  /// Buscar devocional por ID
  Future<Devotional?> getDevotionalById(String id) async {
    final response = await _supabase
        .from('devotionals')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Devotional.fromJson(response);
  }

  /// Buscar devocional do dia
  Future<Devotional?> getTodayDevotional() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    final response = await _supabase
        .from('devotionals')
        .select()
        .eq('devotional_date', today)
        .eq('is_published', true)
        .maybeSingle();

    if (response == null) return null;
    return Devotional.fromJson(response);
  }

  /// Buscar devocional por data
  Future<Devotional?> getDevotionalByDate(DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    
    final response = await _supabase
        .from('devotionals')
        .select()
        .eq('devotional_date', dateStr)
        .eq('is_published', true)
        .maybeSingle();

    if (response == null) return null;
    return Devotional.fromJson(response);
  }

  /// Criar novo devocional
  Future<Devotional> createDevotional({
    required String title,
    required String content,
    String? scriptureReference,
    required DateTime devotionalDate,
    required String authorId,
    bool isPublished = false,
  }) async {
    final data = {
      'title': title,
      'content': content,
      'scripture_reference': scriptureReference,
      'devotional_date': devotionalDate.toIso8601String().split('T')[0],
      'author_id': authorId,
      'is_published': isPublished,
    };

    final response = await _supabase
        .from('devotionals')
        .insert(data)
        .select()
        .single();

    return Devotional.fromJson(response);
  }

  /// Atualizar devocional
  Future<Devotional> updateDevotional({
    required String id,
    String? title,
    String? content,
    String? scriptureReference,
    DateTime? devotionalDate,
    bool? isPublished,
  }) async {
    final data = <String, dynamic>{};
    
    if (title != null) data['title'] = title;
    if (content != null) data['content'] = content;
    if (scriptureReference != null) data['scripture_reference'] = scriptureReference;
    if (devotionalDate != null) {
      data['devotional_date'] = devotionalDate.toIso8601String().split('T')[0];
    }
    if (isPublished != null) data['is_published'] = isPublished;

    final response = await _supabase
        .from('devotionals')
        .update(data)
        .eq('id', id)
        .select()
        .single();

    return Devotional.fromJson(response);
  }

  /// Deletar devocional
  Future<void> deleteDevotional(String id) async {
    await _supabase
        .from('devotionals')
        .delete()
        .eq('id', id);
  }

  /// Publicar devocional
  Future<Devotional> publishDevotional(String id) async {
    return updateDevotional(id: id, isPublished: true);
  }

  /// Despublicar devocional
  Future<Devotional> unpublishDevotional(String id) async {
    return updateDevotional(id: id, isPublished: false);
  }

  // =====================================================
  // DEVOTIONAL READINGS - CRUD
  // =====================================================

  /// Buscar leituras de um devocional
  Future<List<DevotionalReading>> getDevotionalReadings(String devotionalId) async {
    final response = await _supabase
        .from('devotional_readings')
        .select()
        .eq('devotional_id', devotionalId)
        .order('read_at', ascending: false);

    return (response as List)
        .map((json) => DevotionalReading.fromJson(json))
        .toList();
  }

  /// Buscar leituras de um usuário
  Future<List<DevotionalReading>> getUserReadings(String userId) async {
    final response = await _supabase
        .from('devotional_readings')
        .select()
        .eq('user_id', userId)
        .order('read_at', ascending: false);

    return (response as List)
        .map((json) => DevotionalReading.fromJson(json))
        .toList();
  }

  /// Verificar se usuário já leu um devocional
  Future<bool> hasUserReadDevotional(String userId, String devotionalId) async {
    final response = await _supabase
        .from('devotional_readings')
        .select()
        .eq('user_id', userId)
        .eq('devotional_id', devotionalId)
        .maybeSingle();

    return response != null;
  }

  /// Buscar leitura específica
  Future<DevotionalReading?> getUserDevotionalReading(
    String userId,
    String devotionalId,
  ) async {
    final response = await _supabase
        .from('devotional_readings')
        .select()
        .eq('user_id', userId)
        .eq('devotional_id', devotionalId)
        .maybeSingle();

    if (response == null) return null;
    return DevotionalReading.fromJson(response);
  }

  /// Marcar devocional como lido
  Future<DevotionalReading> markAsRead({
    required String devotionalId,
    required String userId,
    String? notes,
  }) async {
    final data = {
      'devotional_id': devotionalId,
      'user_id': userId,
      'notes': notes,
    };

    final response = await _supabase
        .from('devotional_readings')
        .upsert(data)
        .select()
        .single();

    return DevotionalReading.fromJson(response);
  }

  /// Atualizar anotações de leitura
  Future<DevotionalReading> updateReadingNotes({
    required String readingId,
    required String notes,
  }) async {
    final response = await _supabase
        .from('devotional_readings')
        .update({'notes': notes})
        .eq('id', readingId)
        .select()
        .single();

    return DevotionalReading.fromJson(response);
  }

  /// Deletar leitura
  Future<void> deleteReading(String readingId) async {
    await _supabase
        .from('devotional_readings')
        .delete()
        .eq('id', readingId);
  }

  // =====================================================
  // ESTATÍSTICAS
  // =====================================================

  /// Obter estatísticas de um devocional
  Future<DevotionalStats> getDevotionalStats(String devotionalId) async {
    final response = await _supabase
        .rpc('get_devotional_stats', params: {'devotional_uuid': devotionalId});

    if (response == null || response.isEmpty) {
      return const DevotionalStats(totalReads: 0, uniqueReaders: 0);
    }

    return DevotionalStats.fromJson(response[0]);
  }

  /// Obter streak de leituras do usuário
  Future<int> getUserReadingStreak(String userId) async {
    final response = await _supabase
        .rpc('get_user_reading_streak', params: {'user_uuid': userId});

    return response as int? ?? 0;
  }

  /// Obter total de leituras do usuário
  Future<int> getUserTotalReadings(String userId) async {
    final response = await _supabase
        .from('devotional_readings')
        .select('id')
        .eq('user_id', userId)
        .count();

    return response.count;
  }

  /// Obter devocionais mais lidos
  Future<List<Map<String, dynamic>>> getMostReadDevotionals({int limit = 10}) async {
    final response = await _supabase
        .from('devotional_readings')
        .select('devotional_id, devotionals(title, devotional_date)')
        .order('read_at', ascending: false)
        .limit(limit);

    return (response as List).cast<Map<String, dynamic>>();
  }
}

