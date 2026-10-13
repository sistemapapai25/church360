import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/custom_report.dart';
import '../../../../core/constants/supabase_constants.dart';

/// Repositório para gerenciar relatórios customizados
class CustomReportRepository {
  final SupabaseClient _supabase;

  CustomReportRepository(this._supabase);

  Future<String?> _currentMemberId() async {
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

  /// Buscar todos os relatórios ativos
  Future<List<CustomReport>> getAllReports() async {
    final response = await _supabase
        .from('custom_report')
        .select()
        .eq('is_active', true)
        .order('name', ascending: true);

    return (response as List)
        .map((json) => CustomReport.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Buscar relatórios criados pelo usuário atual
  Future<List<CustomReport>> getMyReports() async {
    final userId = await _currentMemberId();
    if (userId == null) return [];

    final response = await _supabase
        .from('custom_report')
        .select()
        .eq('created_by', userId)
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => CustomReport.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Buscar relatório por ID
  Future<CustomReport?> getReportById(String id) async {
    final response = await _supabase
        .from('custom_report')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;

    return CustomReport.fromJson(response);
  }

  /// Criar novo relatório
  Future<CustomReport> createReport(CustomReport report) async {
    final userId = await _currentMemberId();
    
    final reportData = report.toInsertJson();
    reportData['created_by'] = userId;

    final response = await _supabase
        .from('custom_report')
        .insert(reportData)
        .select()
        .single();

    return CustomReport.fromJson(response);
  }

  /// Atualizar relatório
  Future<CustomReport> updateReport(CustomReport report) async {
    final response = await _supabase
        .from('custom_report')
        .update(report.toUpdateJson())
        .eq('id', report.id)
        .select()
        .single();

    return CustomReport.fromJson(response);
  }

  /// Deletar relatório (soft delete)
  Future<void> deleteReport(String id) async {
    await _supabase
        .from('custom_report')
        .update({'is_active': false, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id);
    // Tira o card do relatório da Dashboard (antes ficava lá, abrindo o excluído).
    await _supabase
        .from('dashboard_widget')
        .delete()
        .eq('widget_key', 'custom_report_$id');
  }

  /// Deletar relatório permanentemente
  Future<void> permanentlyDeleteReport(String id) async {
    await _supabase.from('custom_report').delete().eq('id', id);
  }

  /// Duplicar relatório
  Future<CustomReport> duplicateReport(String id) async {
    final original = await getReportById(id);
    if (original == null) {
      throw Exception('Relatório não encontrado');
    }

    final userId = await _currentMemberId();

    final duplicateData = {
      'name': '${original.name} (Cópia)',
      'description': original.description,
      'data_source': original.dataSource.value,
      'visualization_type': original.visualizationType.value,
      'config': original.config.toJson(),
      'is_active': true,
      'created_by': userId,
    };

    final response = await _supabase
        .from('custom_report')
        .insert(duplicateData)
        .select()
        .single();

    return CustomReport.fromJson(response);
  }

  /// Stream de relatórios (real-time)
  Stream<List<CustomReport>> watchReports() {
    return _supabase
        .from('custom_report')
        .stream(primaryKey: ['id'])
        .order('name', ascending: true)
        .map((data) {
          final reports = data
              .map((json) => CustomReport.fromJson(json))
              .where((report) => report.isActive)
              .toList();
          return reports;
        });
  }

  /// Stream de relatórios do usuário (real-time)
  Stream<List<CustomReport>> watchMyReports() async* {
    final userId = await _currentMemberId();
    if (userId == null) {
      yield [];
      return;
    }
    yield* _supabase
        .from('custom_report')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          final reports = data
              .map((json) => CustomReport.fromJson(json))
              .where((report) => report.createdBy == userId && report.isActive)
              .toList();
          return reports;
        });
  }
}
