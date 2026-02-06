// =====================================================
// CHURCH 360 - FINANCIAL REPOSITORY: CATEGORIAS
// =====================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../domain/models/categoria.dart';

/// Repository de Categorias Financeiras
/// Responsável por toda comunicação com a tabela 'categories' no Supabase
class CategoriasRepository {
  final SupabaseClient _supabase;

  CategoriasRepository(this._supabase);

  /// Buscar todas as categorias
  Future<List<Categoria>> getAllCategorias({TipoCategoria? tipo}) async {
    try {
      dynamic query = _supabase
          .from('categories')
          .select('''
            *,
            parent:categories!parent_id(name)
          ''')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .isFilter('deleted_at', null);

      if (tipo != null) {
        query = query.eq('tipo', tipo.value);
      }

      query = query.order('ordem', ascending: true);

      final response = await query;
      return (response as List).map((json) => Categoria.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar categorias hierárquicas (com subcategorias)
  Future<List<Categoria>> getCategoriasHierarquicas({TipoCategoria? tipo}) async {
    try {
      // Buscar categorias principais (sem parent_id)
      dynamic query = _supabase
          .from('categories')
          .select('''
            *,
            subcategorias:categories!parent_id(*)
          ''')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .isFilter('deleted_at', null)
          .isFilter('parent_id', null);

      if (tipo != null) {
        query = query.eq('tipo', tipo.value);
      }

      query = query.order('ordem', ascending: true);

      final response = await query;
      return (response as List).map((json) => Categoria.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar categoria por ID
  Future<Categoria?> getCategoriaById(String id) async {
    try {
      final response = await _supabase
          .from('categories')
          .select('''
            *,
            parent:categories!parent_id(name),
            subcategorias:categories!parent_id(*)
          ''')
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .maybeSingle();

      if (response == null) return null;
      return Categoria.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Criar nova categoria
  Future<Categoria> createCategoria(Categoria categoria) async {
    try {
      final data = categoria.toJson();
      data['tenant_id'] = SupabaseConstants.currentTenantId;
      data['created_by'] = _supabase.auth.currentUser?.id;

      final response = await _supabase
          .from('categories')
          .insert(data)
          .select('''
            *,
            parent:categories!parent_id(name)
          ''')
          .single();

      return Categoria.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Atualizar categoria
  Future<Categoria> updateCategoria(Categoria categoria) async {
    try {
      final data = categoria.toJson();

      final response = await _supabase
          .from('categories')
          .update(data)
          .eq('id', categoria.id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .select('''
            *,
            parent:categories!parent_id(name)
          ''')
          .single();

      return Categoria.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar categoria (soft delete)
  Future<void> deleteCategoria(String id) async {
    try {
      await _supabase
          .from('categories')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      rethrow;
    }
  }

  /// Reordenar categorias
  Future<void> reordenarCategorias(List<String> categoriaIds) async {
    try {
      for (var i = 0; i < categoriaIds.length; i++) {
        await _supabase
            .from('categories')
            .update({'ordem': i})
            .eq('id', categoriaIds[i])
            .eq('tenant_id', SupabaseConstants.currentTenantId);
      }
    } catch (e) {
      rethrow;
    }
  }
}

