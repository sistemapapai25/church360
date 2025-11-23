import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/custom_report.dart';
import '../../domain/enums/report_enums.dart';

/// Repositório para gerenciar relatórios customizados
class CustomReportRepository {
  final SupabaseClient _supabase;

  CustomReportRepository(this._supabase);

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
    final userId = _supabase.auth.currentUser?.id;
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
    final userId = _supabase.auth.currentUser?.id;
    
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

    final userId = _supabase.auth.currentUser?.id;

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
  Stream<List<CustomReport>> watchMyReports() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value([]);

    return _supabase
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

  // ==========================================
  // PERMISSÕES
  // ==========================================

  /// Buscar permissões de um relatório
  Future<List<CustomReportPermission>> getReportPermissions(String reportId) async {
    final response = await _supabase
        .from('custom_report_permission')
        .select()
        .eq('report_id', reportId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => CustomReportPermission.fromJson(json))
        .toList();
  }

  /// Adicionar permissão
  Future<CustomReportPermission> addPermission(CustomReportPermission permission) async {
    final response = await _supabase
        .from('custom_report_permission')
        .insert(permission.toInsertJson())
        .select()
        .single();

    return CustomReportPermission.fromJson(response);
  }

  /// Atualizar permissão
  Future<CustomReportPermission> updatePermission(CustomReportPermission permission) async {
    final response = await _supabase
        .from('custom_report_permission')
        .update({
          'can_view': permission.canView,
          'can_edit': permission.canEdit,
          'can_delete': permission.canDelete,
        })
        .eq('id', permission.id)
        .select()
        .single();

    return CustomReportPermission.fromJson(response);
  }

  /// Remover permissão
  Future<void> removePermission(String permissionId) async {
    await _supabase
        .from('custom_report_permission')
        .delete()
        .eq('id', permissionId);
  }

  /// Tornar relatório público
  Future<CustomReportPermission> makeReportPublic(String reportId) async {
    // Verificar se já existe permissão pública
    final existing = await _supabase
        .from('custom_report_permission')
        .select()
        .eq('report_id', reportId)
        .eq('permission_type', 'public')
        .maybeSingle();

    if (existing != null) {
      return CustomReportPermission.fromJson(existing);
    }

    // Criar nova permissão pública
    final permission = CustomReportPermission(
      id: '',
      reportId: reportId,
      permissionType: PermissionType.public,
      canView: true,
      canEdit: false,
      canDelete: false,
      createdAt: DateTime.now(),
    );

    return await addPermission(permission);
  }

  /// Remover acesso público
  Future<void> removePublicAccess(String reportId) async {
    await _supabase
        .from('custom_report_permission')
        .delete()
        .eq('report_id', reportId)
        .eq('permission_type', 'public');
  }

  /// Compartilhar relatório com usuário
  Future<CustomReportPermission> shareWithUser({
    required String reportId,
    required String userId,
    bool canView = true,
    bool canEdit = false,
    bool canDelete = false,
  }) async {
    final permission = CustomReportPermission(
      id: '',
      reportId: reportId,
      permissionType: PermissionType.user,
      userId: userId,
      canView: canView,
      canEdit: canEdit,
      canDelete: canDelete,
      createdAt: DateTime.now(),
    );

    return await addPermission(permission);
  }

  /// Compartilhar relatório com grupo
  Future<CustomReportPermission> shareWithGroup({
    required String reportId,
    required String groupId,
    bool canView = true,
    bool canEdit = false,
    bool canDelete = false,
  }) async {
    final permission = CustomReportPermission(
      id: '',
      reportId: reportId,
      permissionType: PermissionType.group,
      groupId: groupId,
      canView: canView,
      canEdit: canEdit,
      canDelete: canDelete,
      createdAt: DateTime.now(),
    );

    return await addPermission(permission);
  }
}
