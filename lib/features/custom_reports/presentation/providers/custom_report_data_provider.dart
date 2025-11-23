import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/custom_report_data_service.dart';
import '../../domain/models/custom_report.dart';
import '../../domain/models/report_filter_state.dart';

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
  final service = ref.watch(customReportDataServiceProvider);
  return service.fetchReportData(
    params.report,
    filterState: params.filterState,
  );
});

