import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/role_context.dart';

/// Repository para gerenciar contextos de cargos
class RoleContextsRepository {
  final SupabaseClient _supabase;

  RoleContextsRepository(this._supabase);

  /// Buscar todos os contextos
  Future<List<RoleContext>> getAllContexts() async {
    try {
      final response = await _supabase
          .from('role_contexts')
          .select()
          .order('context_name');

      return (response as List)
          .map((json) => RoleContext.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Erro ao buscar contextos: $e');
    }
  }

  /// Buscar contextos por cargo
  Future<List<RoleContext>> getContextsByRole(String roleId) async {
    try {
      final response = await _supabase
          .from('role_contexts')
          .select()
          .eq('role_id', roleId)
          .eq('is_active', true)
          .order('context_name');

      return (response as List)
          .map((json) => RoleContext.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Erro ao buscar contextos do cargo: $e');
    }
  }

  /// Buscar contextos vinculados a um ministério (via metadata.ministry_id)
  Future<List<RoleContext>> getContextsByMinistry(String ministryId) async {
    try {
      final response = await _supabase
          .from('role_contexts')
          .select()
          .contains('metadata', {'ministry_id': ministryId})
          .eq('is_active', true)
          .order('context_name');

      return (response as List)
          .map((json) => RoleContext.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Erro ao buscar contextos por ministério: $e');
    }
  }

  /// Buscar contexto por ID
  Future<RoleContext?> getContextById(String contextId) async {
    try {
      final response = await _supabase
          .from('role_contexts')
          .select()
          .eq('id', contextId)
          .maybeSingle();

      if (response == null) return null;
      return RoleContext.fromJson(response);
    } catch (e) {
      throw Exception('Erro ao buscar contexto: $e');
    }
  }

  /// Criar novo contexto
  Future<RoleContext> createContext({
    required String roleId,
    required String contextName,
    String? description,
    Map<String, dynamic>? metadata,
    bool isActive = true,
  }) async {
    try {
      final response = await _supabase
          .from('role_contexts')
          .insert({
            'role_id': roleId,
            'context_name': contextName,
            'description': description,
            'metadata': metadata ?? {},
            'is_active': isActive,
          })
          .select()
          .single();

      return RoleContext.fromJson(response);
    } catch (e) {
      throw Exception('Erro ao criar contexto: $e');
    }
  }

  /// Atualizar contexto existente
  Future<void> updateContext({
    required String contextId,
    String? contextName,
    String? description,
    Map<String, dynamic>? metadata,
    bool? isActive,
  }) async {
    try {
      final Map<String, dynamic> updates = {};
      
      if (contextName != null) updates['context_name'] = contextName;
      if (description != null) updates['description'] = description;
      if (metadata != null) updates['metadata'] = metadata;
      if (isActive != null) updates['is_active'] = isActive;
      
      if (updates.isEmpty) return;

      updates['updated_at'] = DateTime.now().toIso8601String();

      await _supabase
          .from('role_contexts')
          .update(updates)
          .eq('id', contextId);
    } catch (e) {
      throw Exception('Erro ao atualizar contexto: $e');
    }
  }

  /// Ativar/Desativar contexto
  Future<void> toggleContextStatus(String contextId, bool isActive) async {
    try {
      await _supabase
          .from('role_contexts')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', contextId);
    } catch (e) {
      throw Exception('Erro ao alterar status do contexto: $e');
    }
  }

  /// Deletar contexto
  Future<void> deleteContext(String contextId) async {
    try {
      await _supabase
          .from('role_contexts')
          .delete()
          .eq('id', contextId);
    } catch (e) {
      throw Exception('Erro ao deletar contexto: $e');
    }
  }

  /// Verificar se contexto está em uso
  Future<bool> isContextInUse(String contextId) async {
    try {
      final response = await _supabase
          .from('user_roles')
          .select('id')
          .eq('role_context_id', contextId)
          .eq('is_active', true)
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e) {
      throw Exception('Erro ao verificar uso do contexto: $e');
    }
  }

  /// Contar usuários com este contexto
  Future<int> countUsersWithContext(String contextId) async {
    try {
      final response = await _supabase
          .from('user_roles')
          .select('id')
          .eq('role_context_id', contextId)
          .eq('is_active', true);

      return (response as List).length;
    } catch (e) {
      throw Exception('Erro ao contar usuários: $e');
    }
  }
}
