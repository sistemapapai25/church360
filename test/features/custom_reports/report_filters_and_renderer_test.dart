import 'package:church360_app/features/custom_reports/domain/enums/report_enums.dart';
import 'package:church360_app/features/custom_reports/domain/models/report_filter_state.dart';
import 'package:church360_app/features/custom_reports/presentation/widgets/custom_report_chart_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filtros mandam o valor do enum e mostram o rótulo em português', () {
    final members = ReportFilterState.getAvailableFilters(DataSource.members);
    final status = members.firstWhere((f) => f.key == 'status').options!;
    expect(status['member_active'], 'Membro ativo');
    expect(status.keys, contains('new_convert'));
    final gender = members.firstWhere((f) => f.key == 'gender').options!;
    expect(gender, {'male': 'Masculino', 'female': 'Feminino', 'other': 'Outro'});

    final events = ReportFilterState.getAvailableFilters(DataSource.events);
    expect(events.firstWhere((f) => f.key == 'status').options!.keys,
        ['draft', 'published', 'ongoing', 'completed', 'cancelled']);

    // Sem coluna de status/tipo filtrável: só período.
    for (final source in [
      DataSource.contributions,
      DataSource.expenses,
      DataSource.financialGoals,
    ]) {
      expect(ReportFilterState.getAvailableFilters(source).map((f) => f.key),
          ['period']);
    }
    expect(reportValueLabel('member_active'), 'Membro ativo');
    expect(reportValueLabel('Jovens (18-29)'), 'Jovens (18-29)');
  });

  Future<void> pump(WidgetTester tester, VisualizationType type) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CustomReportChartRenderer(
            visualizationType: type,
            data: const [
              {'label': 'Membro ativo', 'value': 120},
              {'label': 'Visitante', 'value': 10},
            ],
          ),
        ),
      ));

  testWidgets('Tabela e KPI aparecem como são, não como barras', (tester) async {
    await pump(tester, VisualizationType.table);
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Membro ativo'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);

    await pump(tester, VisualizationType.kpi);
    expect(find.byType(DataTable), findsNothing);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('Visitante'), findsOneWidget);
  });
}
