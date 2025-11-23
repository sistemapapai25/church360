import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/support_material.dart';
import '../domain/models/support_material_module.dart';
import '../domain/models/support_material_link.dart';

/// Repository para gerenciar materiais de apoio
class SupportMaterialsRepository {
  final SupabaseClient _supabase;

  SupportMaterialsRepository(this._supabase);

  // =====================================================
  // MATERIAIS
  // =====================================================

  /// Buscar todos os materiais ativos
  Future<List<SupportMaterial>> getAllMaterials() async {
    try {
      final response = await _supabase
          .from('support_material')
          .select()
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
      final userId = _supabase.auth.currentUser?.id;
      
      final response = await _supabase
          .from('support_material')
          .insert({
            ...data,
            'created_by': userId,
            'updated_by': userId,
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
      final userId = _supabase.auth.currentUser?.id;
      
      final response = await _supabase
          .from('support_material')
          .update({
            ...data,
            'updated_by': userId,
          })
          .eq('id', id)
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
          .eq('id', id);
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
          .eq('id', id);
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
      final userId = _supabase.auth.currentUser?.id;
      
      final response = await _supabase
          .from('support_material_module')
          .insert({
            ...data,
            'created_by': userId,
            'updated_by': userId,
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
      final userId = _supabase.auth.currentUser?.id;
      
      final response = await _supabase
          .from('support_material_module')
          .update({
            ...data,
            'updated_by': userId,
          })
          .eq('id', id)
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
          .eq('id', id);
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
          .eq('linked_entity_id', entityId);

      final materialIds = (response as List)
          .map((json) => json['material_id'] as String)
          .toList();

      if (materialIds.isEmpty) return [];

      final materialsResponse = await _supabase
          .from('support_material')
          .select()
          .inFilter('id', materialIds)
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
      final userId = _supabase.auth.currentUser?.id;
      
      final response = await _supabase
          .from('support_material_link')
          .insert({
            ...data,
            'created_by': userId,
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
          .eq('id', id);
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
          .eq('material_id', materialId);
    } catch (e) {
      rethrow;
    }
  }
}

