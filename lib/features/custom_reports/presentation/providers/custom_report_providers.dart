import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/custom_report_repository.dart';
import '../../domain/models/custom_report.dart';

/// Provider do repositório
final customReportRepositoryProvider = Provider<CustomReportRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return CustomReportRepository(supabase);
});

/// Provider para todos os relatórios ativos
final allCustomReportsProvider = FutureProvider<List<CustomReport>>((ref) async {
  final repository = ref.watch(customReportRepositoryProvider);
  return await repository.getAllReports();
});

/// Provider para relatórios do usuário atual
final myCustomReportsProvider = FutureProvider<List<CustomReport>>((ref) async {
  final repository = ref.watch(customReportRepositoryProvider);
  return await repository.getMyReports();
});

/// Provider para stream de relatórios (real-time)
final customReportsStreamProvider = StreamProvider<List<CustomReport>>((ref) {
  final repository = ref.watch(customReportRepositoryProvider);
  return repository.watchReports();
});

/// Provider para stream de relatórios do usuário (real-time)
final myCustomReportsStreamProvider = StreamProvider<List<CustomReport>>((ref) {
  final repository = ref.watch(customReportRepositoryProvider);
  return repository.watchMyReports();
});

/// Provider para um relatório específico
final customReportByIdProvider = FutureProvider.family<CustomReport?, String>((ref, id) async {
  final repository = ref.watch(customReportRepositoryProvider);
  return await repository.getReportById(id);
});

/// Provider para permissões de um relatório
final reportPermissionsProvider = FutureProvider.family<List<CustomReportPermission>, String>((ref, reportId) async {
  final repository = ref.watch(customReportRepositoryProvider);
  return await repository.getReportPermissions(reportId);
});

/// Provider para criar relatório
final createCustomReportProvider = Provider<Future<CustomReport> Function(CustomReport)>((ref) {
  final repository = ref.watch(customReportRepositoryProvider);
  return (report) async {
    final created = await repository.createReport(report);
    // Invalidar providers para atualizar listas
    ref.invalidate(allCustomReportsProvider);
    ref.invalidate(myCustomReportsProvider);
    return created;
  };
});

/// Provider para atualizar relatório
final updateCustomReportProvider = Provider<Future<CustomReport> Function(CustomReport)>((ref) {
  final repository = ref.watch(customReportRepositoryProvider);
  return (report) async {
    final updated = await repository.updateReport(report);
    // Invalidar providers para atualizar listas
    ref.invalidate(allCustomReportsProvider);
    ref.invalidate(myCustomReportsProvider);
    ref.invalidate(customReportByIdProvider(report.id));
    return updated;
  };
});

/// Provider para deletar relatório
final deleteCustomReportProvider = Provider<Future<void> Function(String)>((ref) {
  final repository = ref.watch(customReportRepositoryProvider);
  return (id) async {
    await repository.deleteReport(id);
    // Invalidar providers para atualizar listas
    ref.invalidate(allCustomReportsProvider);
    ref.invalidate(myCustomReportsProvider);
  };
});

/// Provider para duplicar relatório
final duplicateCustomReportProvider = Provider<Future<CustomReport> Function(String)>((ref) {
  final repository = ref.watch(customReportRepositoryProvider);
  return (id) async {
    final duplicated = await repository.duplicateReport(id);
    // Invalidar providers para atualizar listas
    ref.invalidate(allCustomReportsProvider);
    ref.invalidate(myCustomReportsProvider);
    return duplicated;
  };
});

/// Provider para adicionar permissão
final addReportPermissionProvider = Provider<Future<CustomReportPermission> Function(CustomReportPermission)>((ref) {
  final repository = ref.watch(customReportRepositoryProvider);
  return (permission) async {
    final added = await repository.addPermission(permission);
    // Invalidar provider de permissões
    ref.invalidate(reportPermissionsProvider(permission.reportId));
    return added;
  };
});

/// Provider para remover permissão
final removeReportPermissionProvider = Provider<Future<void> Function(String, String)>((ref) {
  final repository = ref.watch(customReportRepositoryProvider);
  return (permissionId, reportId) async {
    await repository.removePermission(permissionId);
    // Invalidar provider de permissões
    ref.invalidate(reportPermissionsProvider(reportId));
  };
});

/// Provider para tornar relatório público
final makeReportPublicProvider = Provider<Future<CustomReportPermission> Function(String)>((ref) {
  final repository = ref.watch(customReportRepositoryProvider);
  return (reportId) async {
    final permission = await repository.makeReportPublic(reportId);
    // Invalidar provider de permissões
    ref.invalidate(reportPermissionsProvider(reportId));
    return permission;
  };
});

/// Provider para remover acesso público
final removePublicAccessProvider = Provider<Future<void> Function(String)>((ref) {
  final repository = ref.watch(customReportRepositoryProvider);
  return (reportId) async {
    await repository.removePublicAccess(reportId);
    // Invalidar provider de permissões
    ref.invalidate(reportPermissionsProvider(reportId));
  };
});

/// Provider para compartilhar com usuário
final shareReportWithUserProvider = Provider<Future<CustomReportPermission> Function({
  required String reportId,
  required String userId,
  bool canView,
  bool canEdit,
  bool canDelete,
})>((ref) {
  final repository = ref.watch(customReportRepositoryProvider);
  return ({
    required String reportId,
    required String userId,
    bool canView = true,
    bool canEdit = false,
    bool canDelete = false,
  }) async {
    final permission = await repository.shareWithUser(
      reportId: reportId,
      userId: userId,
      canView: canView,
      canEdit: canEdit,
      canDelete: canDelete,
    );
    // Invalidar provider de permissões
    ref.invalidate(reportPermissionsProvider(reportId));
    return permission;
  };
});

/// Provider para compartilhar com grupo
final shareReportWithGroupProvider = Provider<Future<CustomReportPermission> Function({
  required String reportId,
  required String groupId,
  bool canView,
  bool canEdit,
  bool canDelete,
})>((ref) {
  final repository = ref.watch(customReportRepositoryProvider);
  return ({
    required String reportId,
    required String groupId,
    bool canView = true,
    bool canEdit = false,
    bool canDelete = false,
  }) async {
    final permission = await repository.shareWithGroup(
      reportId: reportId,
      groupId: groupId,
      canView: canView,
      canEdit: canEdit,
      canDelete: canDelete,
    );
    // Invalidar provider de permissões
    ref.invalidate(reportPermissionsProvider(reportId));
    return permission;
  };
});

