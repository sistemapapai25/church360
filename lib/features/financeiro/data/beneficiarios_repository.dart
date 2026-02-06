// =====================================================
// CHURCH 360 - FINANCIAL REPOSITORY: BENEFICIARIOS
// =====================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../domain/models/beneficiario.dart';

/// Repository de Beneficiários
/// Responsável por toda comunicação com a tabela 'beneficiaries' no Supabase
class BeneficiariosRepository {
  final SupabaseClient _supabase;

  BeneficiariosRepository(this._supabase);

  /// Buscar todos os beneficiários
  Future<List<Beneficiario>> getAllBeneficiarios() async {
    try {
      final response = await _supabase
          .from('beneficiaries')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .isFilter('deleted_at', null)
          .order('name', ascending: true);

      return (response as List).map((json) => Beneficiario.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar beneficiário por ID
  Future<Beneficiario?> getBeneficiarioById(String id) async {
    try {
      final response = await _supabase
          .from('beneficiaries')
          .select()
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .maybeSingle();

      if (response == null) return null;
      return Beneficiario.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar beneficiários por nome (busca parcial)
  Future<List<Beneficiario>> searchBeneficiariosByName(String searchTerm) async {
    try {
      final response = await _supabase
          .from('beneficiaries')
          .select()
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .isFilter('deleted_at', null)
          .ilike('name', '%$searchTerm%')
          .order('name', ascending: true);

      return (response as List).map((json) => Beneficiario.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Criar novo beneficiário
  Future<Beneficiario> createBeneficiario(Beneficiario beneficiario) async {
    try {
      final data = beneficiario.toJson();
      data['tenant_id'] = SupabaseConstants.currentTenantId;
      data['created_by'] = _supabase.auth.currentUser?.id;

      final response = await _supabase
          .from('beneficiaries')
          .insert(data)
          .select()
          .single();

      return Beneficiario.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Atualizar beneficiário
  Future<Beneficiario> updateBeneficiario(Beneficiario beneficiario) async {
    try {
      final data = beneficiario.toJson();

      final response = await _supabase
          .from('beneficiaries')
          .update(data)
          .eq('id', beneficiario.id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .select()
          .single();

      return Beneficiario.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar beneficiário (soft delete)
  Future<void> deleteBeneficiario(String id) async {
    try {
      await _supabase
          .from('beneficiaries')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      rethrow;
    }
  }
}

