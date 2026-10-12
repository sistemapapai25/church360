import 'package:church360_app/features/custom_reports/data/custom_report_data_service.dart';
import 'package:church360_app/features/custom_reports/domain/enums/report_enums.dart';
import 'package:church360_app/features/custom_reports/domain/models/report_config.dart';
import 'package:church360_app/features/custom_reports/domain/models/report_filter_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('data escolhida agrupa por pagamento; sem escolha, por vencimento', () {
    final service = CustomReportDataService(SupabaseClient('http://x', 'k'));
    const agg = ReportAggregation(
      fieldName: 'valor',
      aggregationType: AggregationType.sum,
      groupBy: GroupByType.month,
      groupByField: 'vencimento',
    );
    final rows = [
      {'valor': 10, 'vencimento': '2026-09-30', 'data_pagamento': '2026-10-02'},
    ];
    expect(
      service.processData(rows, agg, DataSource.contributions, 'data_pagamento')
          .single['label'],
      'Out/2026',
    );
    expect(
      service.processData(rows, agg, DataSource.contributions, null)
          .single['label'],
      'Set/2026',
    );
  });

  test('config guarda a data; relatório antigo vem sem escolha', () {
    final saved = ReportConfig.fromJson(
        const ReportConfig(dateField: 'data_pagamento').toJson());
    expect(saved.dateField, 'data_pagamento');
    expect(ReportConfig.fromJson(const {}).dateField, isNull);
  });

  test('filtro Status de Membros não oferece Visitante', () {
    final status = ReportFilterState.getAvailableFilters(DataSource.members)
        .firstWhere((f) => f.key == 'status');
    expect(status.options!.containsKey('visitor'), isFalse);
  });
}
