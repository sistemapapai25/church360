import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../domain/models/support_material.dart';
import '../domain/models/support_material_module.dart';
import '../domain/models/support_material_link.dart';

/// Repository para gerenciar materiais de apoio
class SupportMaterialsRepository {
  final SupabaseClient _supabase;

  SupportMaterialsRepository(this._supabase);

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
  // MATERIAIS
  // =====================================================

  /// Buscar todos os materiais ativos
  Future<List<SupportMaterial>> getAllMaterials() async {
    try {
      final response = await _supabase
          .from('support_material')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => SupportMaterial.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar material por ID
  Future<SupportMaterial?> getMaterialById(String id) async {
    try {
      final response = await _supabase
          .from('support_material')
          .select()
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .maybeSingle();

      if (response == null) return null;
      return SupportMaterial.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar materiais por categoria
  Future<List<SupportMaterial>> getMaterialsByCategory(String category) async {
    try {
      final response = await _supabase
          .from('support_material')
          .select()
          .eq('category', category)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => SupportMaterial.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar materiais por tipo
  Future<List<SupportMaterial>> getMaterialsByType(SupportMaterialType type) async {
    try {
      final response = await _supabase
          .from('support_material')
          .select()
          .eq('material_type', type.value)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => SupportMaterial.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Criar material
  Future<SupportMaterial> createMaterial(Map<String, dynamic> data) async {
    try {
      final userId = await _effectiveUserId();
      
      final response = await _supabase
          .from('support_material')
          .insert({
            ...data,
            'created_by': userId,
            'updated_by': userId,
            'tenant_id': SupabaseConstants.currentTenantId,
          })
          .select()
          .single();

      return SupportMaterial.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Atualizar material
  Future<SupportMaterial> updateMaterial(String id, Map<String, dynamic> data) async {
    try {
      final userId = await _effectiveUserId();
      
      final response = await _supabase
          .from('support_material')
          .update({
            ...data,
            'updated_by': userId,
          })
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .select()
          .single();

      return SupportMaterial.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar material (soft delete)
  Future<void> deleteMaterial(String id) async {
    try {
      await _supabase
          .from('support_material')
          .update({'is_active': false})
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar material permanentemente
  Future<void> deleteMaterialPermanently(String id) async {
    try {
      await _supabase
          .from('support_material')
          .delete()
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      rethrow;
    }
  }

  // =====================================================
  // MÓDULOS
  // =====================================================

  /// Buscar módulos de um material
  Future<List<SupportMaterialModule>> getModulesByMaterial(String materialId) async {
    try {
      final response = await _supabase
          .from('support_material_module')
          .select()
          .eq('material_id', materialId)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('order_index', ascending: true);

      return (response as List)
          .map((json) => SupportMaterialModule.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar módulo por ID
  Future<SupportMaterialModule?> getModuleById(String id) async {
    try {
      final response = await _supabase
          .from('support_material_module')
          .select()
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .maybeSingle();

      if (response == null) return null;
      return SupportMaterialModule.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Criar módulo
  Future<SupportMaterialModule> createModule(Map<String, dynamic> data) async {
    try {
      final userId = await _effectiveUserId();
      
      final response = await _supabase
          .from('support_material_module')
          .insert({
            ...data,
            'created_by': userId,
            'updated_by': userId,
            'tenant_id': SupabaseConstants.currentTenantId,
          })
          .select()
          .single();

      return SupportMaterialModule.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Atualizar módulo
  Future<SupportMaterialModule> updateModule(String id, Map<String, dynamic> data) async {
    try {
      final userId = await _effectiveUserId();
      
      final response = await _supabase
          .from('support_material_module')
          .update({
            ...data,
            'updated_by': userId,
          })
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .select()
          .single();

      return SupportMaterialModule.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar módulo
  Future<void> deleteModule(String id) async {
    try {
      await _supabase
          .from('support_material_module')
          .delete()
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      rethrow;
    }
  }

  // =====================================================
  // VINCULAÇÕES
  // =====================================================

  /// Buscar vinculações de um material
  Future<List<SupportMaterialLink>> getLinksByMaterial(String materialId) async {
    try {
      final response = await _supabase
          .from('support_material_link')
          .select()
          .eq('material_id', materialId)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => SupportMaterialLink.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar materiais vinculados a uma entidade
  Future<List<SupportMaterial>> getMaterialsByEntity(
    MaterialLinkType linkType,
    String entityId,
  ) async {
    try {
      final response = await _supabase
          .from('support_material_link')
          .select('material_id')
          .eq('link_type', linkType.value)
          .eq('linked_entity_id', entityId)
          .eq('tenant_id', SupabaseConstants.currentTenantId);

      final materialIds = (response as List)
          .map((json) => json['material_id'] as String)
          .toList();

      if (materialIds.isEmpty) return [];

      final materialsResponse = await _supabase
          .from('support_material')
          .select()
          .inFilter('id', materialIds)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (materialsResponse as List)
          .map((json) => SupportMaterial.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Criar vinculação
  Future<SupportMaterialLink> createLink(Map<String, dynamic> data) async {
    try {
      final userId = await _effectiveUserId();
      
      final response = await _supabase
          .from('support_material_link')
          .insert({
            ...data,
            'created_by': userId,
            'tenant_id': SupabaseConstants.currentTenantId,
          })
          .select()
          .single();

      return SupportMaterialLink.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar vinculação
  Future<void> deleteLink(String id) async {
    try {
      await _supabase
          .from('support_material_link')
          .delete()
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar todas as vinculações de um material
  Future<void> deleteLinksByMaterial(String materialId) async {
    try {
      await _supabase
          .from('support_material_link')
          .delete()
          .eq('material_id', materialId)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      rethrow;
    }
  }
}
