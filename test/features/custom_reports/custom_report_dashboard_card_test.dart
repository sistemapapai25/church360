// B4 (roadmap Home/culto/Dashboard, 14/10/2026): o card do relatório na
// Dashboard mostra o gráfico; sem acesso à fonte (reports.view sem
// financial.view_reports) mostra só o título.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/custom_reports/domain/enums/report_enums.dart';
import 'package:church360_app/features/custom_reports/domain/models/custom_report.dart';
import 'package:church360_app/features/custom_reports/domain/models/report_config.dart';
import 'package:church360_app/features/custom_reports/presentation/providers/custom_report_data_provider.dart';
import 'package:church360_app/features/custom_reports/presentation/providers/custom_report_providers.dart';
import 'package:church360_app/features/custom_reports/presentation/widgets/custom_report_chart_renderer.dart';
import 'package:church360_app/features/custom_reports/presentation/widgets/custom_report_dashboard_card.dart';

final _report = CustomReport(
  id: 'r1',
  name: 'Dízimos por mês',
  description: 'Soma dos dízimos pagos',
  dataSource: DataSource.contributions,
  visualizationType: VisualizationType.table,
  config: const ReportConfig(
    aggregations: [
      ReportAggregation(
        fieldName: 'valor',
        aggregationType: AggregationType.sum,
        groupBy: GroupByType.month,
      ),
    ],
  ),
  createdAt: DateTime(2026, 10, 14),
  updatedAt: DateTime(2026, 10, 14),
);

Widget _app(List<Override> overrides) {
  return ProviderScope(
    overrides: [
      customReportByIdProvider.overrideWith((ref, id) async => _report),
      ...overrides,
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CustomReportDashboardCard(reportId: 'r1'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('sem acesso à fonte: só o título, sem gráfico nem erro', (
    tester,
  ) async {
    await tester.pumpWidget(_app([
      reportSourceAllowedProvider.overrideWith((ref, source) async => false),
    ]));
    await tester.pump();
    await tester.pump();

    expect(find.text('Dízimos por mês'), findsOneWidget);
    expect(find.byType(CustomReportChartRenderer), findsNothing);
    expect(find.text('Não foi possível carregar os dados'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('com acesso: renderiza o gráfico com até 12 grupos', (
    tester,
  ) async {
    await tester.pumpWidget(_app([
      customReportDataProvider.overrideWith(
        (ref, params) async => [
          for (var i = 0; i < 20; i++) {'label': 'Grupo $i', 'value': i},
        ],
      ),
    ]));
    await tester.pump();
    await tester.pump();

    expect(find.text('Dízimos por mês'), findsOneWidget);
    final renderer = tester.widget<CustomReportChartRenderer>(
      find.byType(CustomReportChartRenderer),
    );
    expect(renderer.data.length, CustomReportDashboardCard.maxRows);
    expect(find.text('Grupo 0'), findsOneWidget);
    expect(find.text('Grupo 19'), findsNothing);
  });
}
