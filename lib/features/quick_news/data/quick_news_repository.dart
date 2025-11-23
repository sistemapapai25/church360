import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/quick_news.dart';

/// Repository para gerenciar avisos rápidos (Fique por Dentro)
class QuickNewsRepository {
  final SupabaseClient _supabase;

  QuickNewsRepository(this._supabase);

  // =====================================================
  // QUICK NEWS - CRUD
  // =====================================================

  /// Buscar todos os avisos ativos e não expirados (para usuários)
  Future<List<QuickNews>> getActiveNews() async {
    final response = await _supabase
        .from('quick_news')
        .select()
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
        .eq('is_active', true)
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
    final userId = _supabase.auth.currentUser?.id;
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
        .select()
        .single();

    return QuickNews.fromJson(response);
  }

  /// Deletar aviso
  Future<void> deleteNews(String id) async {
    await _supabase
        .from('quick_news')
        .delete()
        .eq('id', id);
  }

  /// Alternar status ativo/inativo
  Future<QuickNews> toggleActive(String id, bool isActive) async {
    final response = await _supabase
        .from('quick_news')
        .update({'is_active': isActive})
        .eq('id', id)
        .select()
        .single();

    return QuickNews.fromJson(response);
  }
}

