// =====================================================
// CHURCH 360 - FINANCIAL REPOSITORY: LANCAMENTOS
// =====================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../domain/models/lancamento.dart';

/// Repository de Lançamentos Financeiros
/// Responsável por toda comunicação com a tabela 'lancamentos' no Supabase
class LancamentosRepository {
  final SupabaseClient _supabase;

  LancamentosRepository(this._supabase);

  /// Buscar todos os lançamentos com filtros opcionais
  Future<List<Lancamento>> getAllLancamentos({
    DateTime? startDate,
    DateTime? endDate,
    TipoLancamento? tipo,
    StatusLancamento? status,
    String? categoriaId,
    String? beneficiarioId,
    String? contaId,
  }) async {
    try {
      dynamic query = _supabase
          .from('lancamentos')
          .select('''
            *,
            beneficiario:beneficiaries(name),
            categoria:categories(name),
            conta:contas_financeiras(nome)
          ''')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .isFilter('deleted_at', null);

      if (startDate != null) {
        query = query.gte('vencimento', startDate.toIso8601String().split('T')[0]);
      }
      if (endDate != null) {
        query = query.lte('vencimento', endDate.toIso8601String().split('T')[0]);
      }
      if (tipo != null) {
        query = query.eq('tipo', tipo.value);
      }
      if (status != null) {
        query = query.eq('status', status.value);
      }
      if (categoriaId != null) {
        query = query.eq('categoria_id', categoriaId);
      }
      if (beneficiarioId != null) {
        query = query.eq('beneficiario_id', beneficiarioId);
      }
      if (contaId != null) {
        query = query.eq('conta_id', contaId);
      }

      query = query.order('vencimento', ascending: false);

      final response = await query;
      return (response as List).map((json) => Lancamento.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar lançamento por ID
  Future<Lancamento?> getLancamentoById(String id) async {
    try {
      final response = await _supabase
          .from('lancamentos')
          .select('''
            *,
            beneficiario:beneficiaries(name),
            categoria:categories(name),
            conta:contas_financeiras(nome)
          ''')
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .maybeSingle();

      if (response == null) return null;
      return Lancamento.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Criar novo lançamento
  Future<Lancamento> createLancamento(Map<String, dynamic> data) async {
    try {
      data['tenant_id'] = SupabaseConstants.currentTenantId;
      data['created_by'] = _supabase.auth.currentUser?.id;

      final response = await _supabase
          .from('lancamentos')
          .insert(data)
          .select('''
            *,
            beneficiario:beneficiaries(name),
            categoria:categories(name),
            conta:contas_financeiras(nome)
          ''')
          .single();

      return Lancamento.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Atualizar lançamento
  Future<Lancamento> updateLancamento(String id, Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('lancamentos')
          .update(data)
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .select('''
            *,
            beneficiario:beneficiaries(name),
            categoria:categories(name),
            conta:contas_financeiras(nome)
          ''')
          .single();

      return Lancamento.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar lançamento (soft delete)
  Future<void> deleteLancamento(String id) async {
    try {
      await _supabase
          .from('lancamentos')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId);
    } catch (e) {
      rethrow;
    }
  }

  /// Pagar lançamento
  Future<Lancamento> pagarLancamento({
    required String id,
    required DateTime dataPagamento,
    required double valorPago,
    String? comprovanteUrl,
  }) async {
    try {
      final response = await _supabase
          .from('lancamentos')
          .update({
            'status': 'PAGO',
            'data_pagamento': dataPagamento.toIso8601String().split('T')[0],
            'valor_pago': valorPago,
            if (comprovanteUrl != null) 'comprovante_url': comprovanteUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .select('''
            *,
            beneficiario:beneficiaries(name),
            categoria:categories(name),
            conta:contas_financeiras(nome)
          ''')
          .single();

      return Lancamento.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Cancelar lançamento
  Future<Lancamento> cancelarLancamento(String id) async {
    try {
      final response = await _supabase
          .from('lancamentos')
          .update({
            'status': 'CANCELADO',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .select('''
            *,
            beneficiario:beneficiaries(name),
            categoria:categories(name),
            conta:contas_financeiras(nome)
          ''')
          .single();

      return Lancamento.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar lançamentos vencidos
  Future<List<Lancamento>> getLancamentosVencidos() async {
    try {
      final hoje = DateTime.now().toIso8601String().split('T')[0];
      final response = await _supabase
          .from('lancamentos')
          .select('''
            *,
            beneficiario:beneficiaries(name),
            categoria:categories(name),
            conta:contas_financeiras(nome)
          ''')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('status', 'EM_ABERTO')
          .lt('vencimento', hoje)
          .isFilter('deleted_at', null)
          .order('vencimento', ascending: true);

      return (response as List).map((json) => Lancamento.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }
}

