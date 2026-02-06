import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';

import '../domain/models/testimony.dart';

/// Repository para gerenciar testemunhos
class TestimonyRepository {
  final SupabaseClient _supabase;

  TestimonyRepository(this._supabase);

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
  // TESTIMONIES - CRUD
  // =====================================================

  /// Buscar TODOS os testemunhos (admin)
  Future<List<Testimony>> getAllTestimonies() async {
    final response = await _supabase
        .from('testimonies')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Testimony.fromJson(json))
        .toList();
  }

  /// Buscar todos os testemunhos públicos
  Future<List<Testimony>> getAllPublicTestimonies() async {
    final response = await _supabase
        .from('testimonies')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('is_public', true)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Testimony.fromJson(json))
        .toList();
  }

  /// Buscar testemunhos do usuário atual
  Future<List<Testimony>> getMyTestimonies() async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    final response = await _supabase
        .from('testimonies')
        .select()
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .eq('author_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Testimony.fromJson(json))
        .toList();
  }

  /// Buscar testemunho por ID
  Future<Testimony?> getTestimonyById(String id) async {
    final response = await _supabase
        .from('testimonies')
        .select()
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .maybeSingle();

    if (response == null) return null;
    return Testimony.fromJson(response);
  }

  /// Criar testemunho
  Future<Testimony> createTestimony({
    required String title,
    required String description,
    required bool isPublic,
    required bool allowWhatsappContact,
  }) async {
    final userId = await _effectiveUserId();
    if (userId == null) throw Exception('Usuário não autenticado');

    final response = await _supabase
        .from('testimonies')
        .insert({
          'title': title,
          'description': description,
          'author_id': userId,
          'is_public': isPublic,
          'allow_whatsapp_contact': allowWhatsappContact,
          'tenant_id': SupabaseConstants.currentTenantId,
        })
        .select()
        .single();

    return Testimony.fromJson(response);
  }

  /// Atualizar testemunho
  Future<Testimony> updateTestimony({
    required String id,
    String? title,
    String? description,
    bool? isPublic,
    bool? allowWhatsappContact,
  }) async {
    final updateData = <String, dynamic>{};
    if (title != null) updateData['title'] = title;
    if (description != null) updateData['description'] = description;
    if (isPublic != null) updateData['is_public'] = isPublic;
    if (allowWhatsappContact != null) updateData['allow_whatsapp_contact'] = allowWhatsappContact;

    final response = await _supabase
        .from('testimonies')
        .update(updateData)
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId)
        .select()
        .single();

    return Testimony.fromJson(response);
  }

  /// Deletar testemunho
  Future<void> deleteTestimony(String id) async {
    await _supabase
        .from('testimonies')
        .delete()
        .eq('id', id)
        .eq('tenant_id', SupabaseConstants.currentTenantId);
  }

  /// Contar testemunhos do usuário
  Future<int> countMyTestimonies() async {
    final userId = await _effectiveUserId();
    if (userId == null) return 0;

    final response = await _supabase
        .rpc('count_user_testimonies', params: {'user_id': userId});

    return response as int;
  }
}
