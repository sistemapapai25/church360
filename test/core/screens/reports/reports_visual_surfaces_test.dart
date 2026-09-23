import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:church360_app/core/providers/dashboard_stats_provider.dart';
import 'package:church360_app/core/screens/reports/active_groups_report.dart';
import 'package:church360_app/core/screens/reports/attendance_report_screen.dart';
import 'package:church360_app/core/screens/reports/events_report_screen.dart';
import 'package:church360_app/core/screens/reports/groups_report_screen.dart';
import 'package:church360_app/core/screens/reports/member_growth_report.dart';
import 'package:church360_app/core/screens/reports/upcoming_events_report.dart';
import 'package:church360_app/core/screens/reports/upcoming_expenses_report.dart';
import 'package:church360_app/features/events/domain/models/event.dart';
import 'package:church360_app/features/financial/domain/models/contribution.dart';
import 'package:church360_app/core/widgets/glass_card.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

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
    await tester.pump();
    await tester.pump();
    await tester.pump();
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
    await tester.pump();

    expect(find.byType(GlassCard), findsOneWidget);
    expect(find.text('Comunhão Jovem'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('grupos ativos usam GlassCard no filtro, resumo e detalhes', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeGroupsByPeriodProvider.overrideWith(
            (ref, _) async => [
              {
                'group_id': 'group-1',
                'group_name': 'Comunhão Jovem',
                'group_type': 'communion',
                'description': 'Grupo de jovens',
                'member_count': 12,
                'meeting_count': 4,
                'total_attendance': 40,
                'average_attendance': 10.0,
                'last_meeting_date': DateTime(2026, 9, 20),
              },
            ],
          ),
        ],
        child: const MaterialApp(home: ActiveGroupsReportScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
    await tester.pump();

    expect(find.byType(GlassCard), findsAtLeastNWidgets(1));
    expect(find.text('Comunhão Jovem'), findsOneWidget);
  });

  testWidgets('próximos eventos usam GlassCard no resumo e nos eventos', (
    tester,
  ) async {
    final start = DateTime.now().add(const Duration(days: 2));
    final event = Event(
      id: 'event-1',
      name: 'Culto de Celebração',
      description: 'Uma noite de comunhão',
      startDate: start,
      endDate: null,
      location: 'Templo central',
      requiresRegistration: true,
      maxCapacity: 100,
      price: 0,
      isFree: true,
      status: 'published',
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          upcomingEventsByPeriodProvider.overrideWith(
            (ref, _) async => [event],
          ),
        ],
        child: const MaterialApp(home: UpcomingEventsReportScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
    await tester.pump();

    expect(find.byType(GlassCard), findsAtLeastNWidgets(1));
    expect(find.text('Culto de Celebração'), findsOneWidget);
    expect(find.text('Templo central'), findsOneWidget);
  });

  testWidgets('próximas despesas usam GlassCard no resumo e na listagem', (
    tester,
  ) async {
    final expense = Expense(
      id: 'expense-1',
      category: 'Aluguel',
      amount: 1500,
      paymentMethod: PaymentMethod.transfer,
      date: DateTime.now().add(const Duration(days: 5)),
      description: 'Aluguel do templo',
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          upcomingExpensesByPeriodProvider.overrideWith(
            (ref, _) async => [expense],
          ),
        ],
        child: const MaterialApp(home: UpcomingExpensesReportScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
    await tester.pump();

    expect(find.byType(GlassCard), findsAtLeastNWidgets(1));
    expect(find.text('Aluguel do templo'), findsOneWidget);
    expect(find.text('Aluguel'), findsOneWidget);
  });

  testWidgets('crescimento de membros usa GlassCard nos resumos e gráficos', (
    tester,
  ) async {
    final today = DateTime.now();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memberGrowthByPeriodProvider.overrideWith(
            (ref, _) async => [
              {
                'date': '2026-09-22',
                'dateObj': today.subtract(const Duration(days: 1)),
                'day': today.day - 1,
                'month': today.month,
                'year': today.year,
                'newMembers': 2,
                'totalMembers': 10,
              },
              {
                'date': '2026-09-23',
                'dateObj': today,
                'day': today.day,
                'month': today.month,
                'year': today.year,
                'newMembers': 1,
                'totalMembers': 11,
              },
            ],
          ),
        ],
        child: const MaterialApp(home: MemberGrowthReportScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
    await tester.pump();

    expect(find.byType(GlassCard), findsAtLeastNWidgets(3));
    expect(find.text('Detalhamento Diário'), findsOneWidget);
  });
}
