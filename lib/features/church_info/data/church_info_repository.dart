import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../domain/models/church_info.dart';

/// Repository para gerenciar informações da igreja
class ChurchInfoRepository {
  final SupabaseClient _supabase;

  ChurchInfoRepository(this._supabase);

  /// Buscar informações da igreja
  /// Normalmente só existe um registro, então pegamos o primeiro
  Future<ChurchInfo?> getChurchInfo() async {
    try {
      // Tenta buscar o registro mais recentemente atualizado
      final response = await _supabase
          .from('church_info')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        // Se não encontrar por updated_at, tenta por created_at
         final fallbackResponse = await _supabase
          .from('church_info')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
          
          if (fallbackResponse == null) return null;
          return ChurchInfo.fromJson(fallbackResponse);
      }

      return ChurchInfo.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Criar informações da igreja
  Future<ChurchInfo> createChurchInfo(Map<String, dynamic> data) async {
    try {
      data['tenant_id'] = SupabaseConstants.currentTenantId;
      final response = await _supabase
          .from('church_info')
          .insert(data)
          .select()
          .single();

      return ChurchInfo.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Atualizar informações da igreja
  Future<ChurchInfo> updateChurchInfo(String id, Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from('church_info')
          .update(data)
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .select()
          .single();

      return ChurchInfo.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar informações da igreja
  Future<void> deleteChurchInfo(String id) async {
    try {
      await _supabase
          .from('church_info')
          .delete()
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      rethrow;
    }
  }
}
