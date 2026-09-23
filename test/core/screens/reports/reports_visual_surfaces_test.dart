import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/core/providers/dashboard_stats_provider.dart';
import 'package:church360_app/core/screens/reports/attendance_report_screen.dart';
import 'package:church360_app/core/screens/reports/events_report_screen.dart';
import 'package:church360_app/core/screens/reports/groups_report_screen.dart';
import 'package:church360_app/core/widgets/glass_card.dart';

void main() {
  testWidgets('relatório de presença usa vidro no resumo e nos grupos', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attendanceByGroupProvider.overrideWith(
            (ref) async => [
              {
                'group_name': 'Célula Esperança',
                'total_present': 8,
                'total_expected': 10,
              },
            ],
          ),
        ],
        child: const MaterialApp(home: AttendanceReportScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(GlassCard), findsNWidgets(2));
    expect(find.text('Célula Esperança'), findsOneWidget);
    expect(find.text('80.0%'), findsNWidgets(2));
  });

  testWidgets('relatório de eventos usa GlassCard na listagem', (tester) async {
    final start = DateTime.now().add(const Duration(days: 2));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          upcomingEventsProvider.overrideWith(
            (ref) async => [
              {
                'title': 'Culto de Celebração',
                'start_date': start,
                'location': 'Templo central',
              },
            ],
          ),
        ],
        child: const MaterialApp(home: EventsReportScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(GlassCard), findsOneWidget);
    expect(find.text('Culto de Celebração'), findsOneWidget);
    expect(find.text('Templo central'), findsOneWidget);
  });

  testWidgets('relatório de grupos usa GlassCard nos resultados', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          topActiveGroupsProvider.overrideWith(
            (ref) async => [
              {
                'name': 'Comunhão Jovem',
                'meeting_count': 4,
                'type': 'communion',
              },
            ],
          ),
        ],
        child: const MaterialApp(home: GroupsReportScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(GlassCard), findsOneWidget);
    expect(find.text('Comunhão Jovem'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });
}
