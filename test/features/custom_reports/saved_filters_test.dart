import 'package:church360_app/features/custom_reports/domain/enums/report_enums.dart';
import 'package:church360_app/features/custom_reports/domain/models/report_config.dart';
import 'package:church360_app/features/custom_reports/domain/models/report_filter_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filtros salvos voltam iguais pelo json do config', () {
    final state = ReportFilterState(
      dataSource: DataSource.members,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 3, 31),
      status: 'member_active',
      gender: 'female',
    );
    final config = ReportConfig.fromJson(
      const ReportConfig().copyWith(savedFilters: {'main': state.toJson()}).toJson(),
    );
    final back = ReportFilterState.fromJson(
        DataSource.members, config.savedFilters?['main'] as Map<String, dynamic>?);

    expect(back.startDate, DateTime(2026, 1, 1));
    expect(back.endDate, DateTime(2026, 3, 31));
    expect(back.status, 'member_active');
    expect(back.gender, 'female');
    expect(back.activeFilterCount, 4);
  });

  test('relatório sem filtros salvos abre sem filtro', () {
    final config = ReportConfig.fromJson(const ReportConfig().toJson());
    final state = ReportFilterState.fromJson(
        DataSource.members, config.savedFilters?['main'] as Map<String, dynamic>?);
    expect(state.hasActiveFilters, isFalse);
  });
}
