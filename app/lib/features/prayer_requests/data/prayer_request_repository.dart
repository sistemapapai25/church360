import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';

import '../domain/models/prayer_request.dart';

/// Repository para gerenciar pedidos de oração
class PrayerRequestRepository {
  final SupabaseClient _supabase;

  PrayerRequestRepository(this._supabase);

  Future<String?> _effectiveUserId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final email = user.email;
    if (email != null && email.trim().isNotEmpty) {
      try {
        final nickname = email.trim().split('@').first;
        await _supabase.rpc('ensure_my_account', params: {
          '_tenant_id': SupabaseConstants.currentTenantId,
          '_email': email,
          '_nickname': nickname,
        });
      } catch (_) {}
    }
    return user.id;
  }

  // =====================================================
  // PRAYER REQUESTS - CRUD
  // =====================================================

  /// Buscar todos os pedidos de oração (respeitando RLS)
  Future<List<PrayerRequest>> getAllPrayerRequests() async {
    final response = await _supabase
        .from('prayer_requests')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => PrayerRequest.fromJson(json))
        .toList();
  }

  /// Buscar pedidos por status
  Future<List<PrayerRequest>> getPrayerRequestsByStatus(PrayerStatus status) async {
    final response = await _supabase
        .from('prayer_requests')
        .select()
        .eq('status', status.value)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => PrayerRequest.fromJson(json))
        .toList();
  }

  /// Buscar pedidos por categoria
  Future<List<PrayerRequest>> getPrayerRequestsByCategory(PrayerCategory category) async {
    final response = await _supabase
        .from('prayer_requests')
        .select()
        .eq('category', category.value)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => PrayerRequest.fromJson(json))
        .toList();
  }

  /// Buscar pedidos do usuário atual
  Future<List<PrayerRequest>> getMyPrayerRequests() async {
    final userId = await _effectiveUserId();
    if (userId == null) return [];

    final response = await _supabase
        .from('prayer_requests')
        .select()
        .eq('author_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => PrayerRequest.fromJson(json))
        .toList();
  }

  /// Buscar pedido por ID
  Future<PrayerRequest?> getPrayerRequestById(String id) async {
    final response = await _supabase
        .from('prayer_requests')
        .select()
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();

    if (response == null) return null;
    return PrayerRequest.fromJson(response);
  }

  /// Criar pedido de oração
  Future<PrayerRequest> createPrayerRequest({
    required String title,
    required String description,
    required PrayerCategory category,
    required PrayerPrivacy privacy,
    bool isPublic = false,
    bool allowWhatsappContact = true,
  }) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    final response = await _supabase
        .from('prayer_requests')
        .insert({
          'title': title,
          'description': description,
          'category': category.value,
          'privacy': privacy.value,
          'is_public': isPublic,
          'allow_whatsapp_contact': allowWhatsappContact,
          'author_id': userId,
          'status': PrayerStatus.pending.value,
          'tenant_id': SupabaseConstants.currentTenantId,
        })
        .select()
        .single();

    return PrayerRequest.fromJson(response);
  }

  /// Atualizar pedido de oração
  Future<PrayerRequest> updatePrayerRequest({
    required String id,
    String? title,
    String? description,
    PrayerCategory? category,
    PrayerStatus? status,
    PrayerPrivacy? privacy,
    bool? isPublic,
    bool? allowWhatsappContact,
  }) async {
    final data = <String, dynamic>{};
    
    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (category != null) data['category'] = category.value;
    if (status != null) data['status'] = status.value;
    if (privacy != null) data['privacy'] = privacy.value;
    if (isPublic != null) data['is_public'] = isPublic;
    if (allowWhatsappContact != null) data['allow_whatsapp_contact'] = allowWhatsappContact;

    final response = await _supabase
        .from('prayer_requests')
        .update(data)
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select()
        .single();

    return PrayerRequest.fromJson(response);
  }

  /// Deletar pedido de oração
  Future<void> deletePrayerRequest(String id) async {
    await _supabase
        .from('prayer_requests')
        .delete()
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  /// Marcar pedido como respondido
  Future<PrayerRequest> markAsAnswered(String id) async {
    return updatePrayerRequest(
      id: id,
      status: PrayerStatus.answered,
    );
  }

  /// Marcar pedido como cancelado
  Future<PrayerRequest> markAsCancelled(String id) async {
    return updatePrayerRequest(
      id: id,
      status: PrayerStatus.cancelled,
    );
  }

  // =====================================================
  // PRAYER REQUEST PRAYERS - CRUD
  // =====================================================

  /// Buscar orações de um pedido
  Future<List<PrayerRequestPrayer>> getPrayerRequestPrayers(String prayerRequestId) async {
    final response = await _supabase
        .from('prayer_request_prayers')
        .select()
        .eq('prayer_request_id', prayerRequestId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('prayed_at', ascending: false);

    return (response as List)
        .map((json) => PrayerRequestPrayer.fromJson(json))
        .toList();
  }

  /// Verificar se usuário atual já orou
  Future<bool> hasUserPrayed(String prayerRequestId) async {
    final userId = await _effectiveUserId();
    if (userId == null) return false;

    final response = await _supabase
        .from('prayer_request_prayers')
        .select()
        .eq('prayer_request_id', prayerRequestId)
        .eq('user_id', userId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();

    return response != null;
  }

  /// Marcar "eu orei"
  Future<PrayerRequestPrayer> markAsPrayed({
    required String prayerRequestId,
    String? note,
  }) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    final response = await _supabase
        .from('prayer_request_prayers')
        .insert({
          'prayer_request_id': prayerRequestId,
          'user_id': userId,
          'note': note,
          'tenant_id': SupabaseConstants.currentTenantId,
        })
        .select()
        .single();

    return PrayerRequestPrayer.fromJson(response);
  }

  /// Contar orações de um pedido
  Future<int> countPrayers(String prayerRequestId) async {
    final response = await _supabase
        .from('prayer_request_prayers')
        .select()
        .eq('prayer_request_id', prayerRequestId)
        .eq('tenant_id', SupabaseConstants.currentTenantId);

    return (response as List).length;
  }

  // =====================================================
  // PRAYER REQUEST TESTIMONIES - CRUD
  // =====================================================

  /// Buscar testemunho de um pedido
  Future<PrayerRequestTestimony?> getTestimony(String prayerRequestId) async {
    final response = await _supabase
        .from('prayer_request_testimonies')
        .select()
        .eq('prayer_request_id', prayerRequestId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();

    if (response == null) return null;
    return PrayerRequestTestimony.fromJson(response);
  }

  /// Criar testemunho
  Future<PrayerRequestTestimony> createTestimony({
    required String prayerRequestId,
    required String testimony,
  }) async {
    final response = await _supabase
        .from('prayer_request_testimonies')
        .insert({
          'prayer_request_id': prayerRequestId,
          'testimony': testimony,
          'tenant_id': SupabaseConstants.currentTenantId,
        })
        .select()
        .single();

    return PrayerRequestTestimony.fromJson(response);
  }

  /// Atualizar testemunho
  Future<PrayerRequestTestimony> updateTestimony({
    required String prayerRequestId,
    required String testimony,
  }) async {
    final response = await _supabase
        .from('prayer_request_testimonies')
        .update({'testimony': testimony})
        .eq('prayer_request_id', prayerRequestId)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select()
        .single();

    return PrayerRequestTestimony.fromJson(response);
  }

  /// Deletar testemunho
  Future<void> deleteTestimony(String prayerRequestId) async {
    await _supabase
        .from('prayer_request_testimonies')
        .delete()
        .eq('prayer_request_id', prayerRequestId)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  // =====================================================
  // STATISTICS
  // =====================================================

  /// Buscar estatísticas de um pedido
  Future<PrayerRequestStats> getPrayerRequestStats(String prayerRequestId) async {
    final response = await _supabase
        .rpc('get_prayer_request_stats', params: {'request_uuid': prayerRequestId})
        .single();

    return PrayerRequestStats.fromJson(response);
  }

  /// Contar pedidos por status
  Future<Map<PrayerStatus, int>> countByStatus() async {
    final response = await _supabase.rpc('get_prayer_requests_by_status');

    final Map<PrayerStatus, int> result = {};
    for (final item in response as List) {
      final status = PrayerStatus.fromString(item['status'] as String);
      final count = item['total_count'] as int;
      result[status] = count;
    }

    return result;
  }

  /// Contar pedidos por categoria
  Future<Map<PrayerCategory, int>> countByCategory() async {
    final response = await _supabase.rpc('get_prayer_requests_by_category');

    final Map<PrayerCategory, int> result = {};
    for (final item in response as List) {
      final category = PrayerCategory.fromString(item['category'] as String);
      final count = item['total_count'] as int;
      result[category] = count;
    }

    return result;
  }
}
