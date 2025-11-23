import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/contribution_info.dart';

/// Repository para gerenciar informações de contribuição
class ContributionRepository {
  final SupabaseClient _supabase;

  ContributionRepository(this._supabase);

  // =====================================================
  // CONTRIBUTION INFO - CRUD
  // =====================================================

  /// Buscar informação de contribuição ativa
  Future<ContributionInfo?> getActiveContributionInfo() async {
    try {
      final response = await _supabase
          .from('contribution_info')
          .select()
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return null;
      return ContributionInfo.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar todas as informações de contribuição
  Future<List<ContributionInfo>> getAllContributionInfo() async {
    try {
      final response = await _supabase
          .from('contribution_info')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ContributionInfo.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar informação de contribuição por ID
  Future<ContributionInfo?> getContributionInfoById(String id) async {
    try {
      final response = await _supabase
          .from('contribution_info')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return ContributionInfo.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Criar informação de contribuição
  Future<ContributionInfo> createContributionInfo(Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from('contribution_info')
          .insert(data)
          .select()
          .single();

      return ContributionInfo.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Atualizar informação de contribuição
  Future<ContributionInfo> updateContributionInfo(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _supabase
          .from('contribution_info')
          .update({
            ...data,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .select()
          .single();

      return ContributionInfo.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar informação de contribuição
  Future<void> deleteContributionInfo(String id) async {
    try {
      await _supabase
          .from('contribution_info')
          .delete()
          .eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  /// Ativar/Desativar informação de contribuição
  Future<ContributionInfo> toggleActiveStatus(String id, bool isActive) async {
    try {
      final response = await _supabase
          .from('contribution_info')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .select()
          .single();

      return ContributionInfo.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }
}

