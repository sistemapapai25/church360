import 'package:church360_app/features/custom_reports/domain/enums/report_enums.dart';
import 'package:church360_app/features/custom_reports/domain/models/metric_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // O editor reencontra a métrica salva por (campo, agregação); o par tem de ser único por fonte.
  test('métrica e agrupamento salvos voltam ao editar', () {
    for (final source in DataSource.values) {
      final metrics = MetricTemplates.getTemplatesForDataSource(source);
      final keys = metrics.map((m) => '${m.fieldName}|${m.aggregationType}').toList();
      expect(keys.toSet().length, keys.length, reason: 'métrica repetida em $source');

      for (final m in metrics) {
        for (final g in m.groupByOptions) {
          final saved = m.toAggregation(groupBy: g.type, groupByField: g.fieldName);
          final metric = metrics
              .where((x) => x.fieldName == saved.fieldName && x.aggregationType == saved.aggregationType)
              .first;
          final group = metric.groupByOptions
              .where((x) => x.type == saved.groupBy && x.fieldName == saved.groupByField)
              .toList();
          expect(metric.id, m.id);
          expect(group, hasLength(1), reason: '${m.id} / ${g.label}');
        }
      }
    }
  });
}
