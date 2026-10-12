import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/custom_report_data_service.dart';
import '../../domain/models/custom_report.dart';
import '../../domain/models/report_filter_state.dart';
import 'custom_report_providers.dart';

/// Relatório salvo de uma fonte que o usuário não pode ler (ex.: financeiro
/// sem permissão): a tela mostra aviso de acesso em vez de zeros.
class ReportAccessDenied implements Exception {
  const ReportAccessDenied();
  @override
  String toString() =>
      'Você não tem permissão para ver os dados desta fonte. '
      'Peça acesso ao financeiro a um administrador.';
}

/// Provider do serviço de dados
final customReportDataServiceProvider = Provider<CustomReportDataService>((ref) {
  return CustomReportDataService(Supabase.instance.client);
});

/// Provider para buscar dados de um relatório customizado
/// Usa .family para aceitar parâmetros (report e filterState)
final customReportDataProvider = FutureProvider.family<
    List<Map<String, dynamic>>,
    ({CustomReport report, ReportFilterState? filterState})
>((ref, params) async {
  final allowed =
      await ref.watch(reportSourceAllowedProvider(params.report.dataSource).future);
  if (!allowed) throw const ReportAccessDenied();
  final service = ref.watch(customReportDataServiceProvider);
  return service.fetchReportData(
    params.report,
    filterState: params.filterState,
  );
});

