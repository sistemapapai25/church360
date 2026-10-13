import 'package:church360_app/features/custom_reports/data/custom_report_data_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('faixa etária usa as faixas do filtro de idade, limites inclusivos', () {
    expect(CustomReportDataService.ageGroupLabel(null), 'Sem data de nascimento');
    expect(CustomReportDataService.ageGroupLabel(0), 'Crianças (0-11)');
    expect(CustomReportDataService.ageGroupLabel(11), 'Crianças (0-11)');
    expect(CustomReportDataService.ageGroupLabel(12), 'Adolescentes (12-17)');
    expect(CustomReportDataService.ageGroupLabel(29), 'Jovens (18-29)');
    expect(CustomReportDataService.ageGroupLabel(59), 'Adultos (30-59)');
    expect(CustomReportDataService.ageGroupLabel(60), 'Idosos (60+)');
  });
}
