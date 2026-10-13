import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/custom_report_repository.dart';
import '../../../permissions/providers/permissions_providers.dart'
    show currentUserHasPermissionProvider, currentUserIsElevatedProvider;
import '../../domain/enums/report_enums.dart';
import '../../domain/models/custom_report.dart';

/// O usuário atual consegue ler a fonte? Espelha a RLS de leitura:
/// lancamentos = financial.view OU financial.view_reports;
/// financial_goal = financial.view OU elevado. As demais fontes ficam livres.
/// Erro vira false (fail-closed na tela; a RLS segue sendo a autoridade).
final reportSourceAllowedProvider =
    FutureProvider.family<bool, DataSource>((ref, source) async {
  Future<bool> has(String code) async {
    try {
      return await ref.watch(currentUserHasPermissionProvider(code).future);
    } catch (_) {
      return false;
    }
  }

  switch (source) {
    case DataSource.contributions:
    case DataSource.expenses:
      return await has('financial.view') || await has('financial.view_reports');
    case DataSource.financialGoals:
      return await has('financial.view') ||
          await ref.watch(currentUserIsElevatedProvider.future);
    default:
      return true;
  }
});

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
