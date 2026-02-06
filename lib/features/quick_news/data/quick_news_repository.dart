import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';

import '../domain/models/quick_news.dart';

/// Repository para gerenciar avisos rápidos (Fique por Dentro)
class QuickNewsRepository {
  final SupabaseClient _supabase;

  QuickNewsRepository(this._supabase);

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
  // QUICK NEWS - CRUD
  // =====================================================

  /// Buscar todos os avisos ativos e não expirados (para usuários)
  Future<List<QuickNews>> getActiveNews() async {
    final response = await _supabase
        .from('quick_news')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('is_active', true)
        .or('expires_at.is.null,expires_at.gt.${DateTime.now().toIso8601String()}')
        .order('priority', ascending: false)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => QuickNews.fromJson(json))
        .toList();
  }

  /// Stream de avisos ativos (realtime)
  Stream<List<QuickNews>> watchActiveNews() {
    return _supabase
        .from('quick_news')
        .stream(primaryKey: ['id'])
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('priority', ascending: false)
        .map((data) => data
            .map((json) => QuickNews.fromJson(json))
            .where((news) => news.isVisible)
            .toList());
  }

  /// Buscar todos os avisos (para admin - incluindo inativos e expirados)
  Future<List<QuickNews>> getAllNews() async {
    final response = await _supabase
        .from('quick_news')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('priority', ascending: false)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => QuickNews.fromJson(json))
        .toList();
  }

  /// Buscar aviso por ID
  Future<QuickNews?> getNewsById(String id) async {
    final response = await _supabase
        .from('quick_news')
        .select()
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();

    if (response == null) return null;
    return QuickNews.fromJson(response);
  }

  /// Criar aviso
  Future<QuickNews> createNews({
    required String title,
    required String description,
    String? imageUrl,
    String? linkUrl,
    int priority = 0,
    bool isActive = true,
    DateTime? expiresAt,
  }) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    final response = await _supabase
        .from('quick_news')
        .insert({
          'title': title,
          'description': description,
          'image_url': imageUrl,
          'link_url': linkUrl,
          'priority': priority,
          'is_active': isActive,
          'expires_at': expiresAt?.toIso8601String(),
          'created_by': userId,
          'tenant_id': SupabaseConstants.currentTenantId,
        })
        .select()
        .single();

    return QuickNews.fromJson(response);
  }

  /// Atualizar aviso
  Future<QuickNews> updateNews({
    required String id,
    String? title,
    String? description,
    String? imageUrl,
    String? linkUrl,
    int? priority,
    bool? isActive,
    DateTime? expiresAt,
  }) async {
    final updateData = <String, dynamic>{};
    if (title != null) updateData['title'] = title;
    if (description != null) updateData['description'] = description;
    if (imageUrl != null) updateData['image_url'] = imageUrl;
    if (linkUrl != null) updateData['link_url'] = linkUrl;
    if (priority != null) updateData['priority'] = priority;
    if (isActive != null) updateData['is_active'] = isActive;
    if (expiresAt != null) updateData['expires_at'] = expiresAt.toIso8601String();

    final response = await _supabase
        .from('quick_news')
        .update(updateData)
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select()
        .single();

    return QuickNews.fromJson(response);
  }

  /// Deletar aviso
  Future<void> deleteNews(String id) async {
    await _supabase
        .from('quick_news')
        .delete()
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  /// Alternar status ativo/inativo
  Future<QuickNews> toggleActive(String id, bool isActive) async {
    final response = await _supabase
        .from('quick_news')
        .update({'is_active': isActive})
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select()
        .single();

    return QuickNews.fromJson(response);
  }
}
