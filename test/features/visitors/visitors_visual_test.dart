import 'package:church360_app/core/design/app_icons.dart';
import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/core/widgets/glass_card.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';
import 'package:church360_app/features/visitors/domain/models/visitor.dart';
import 'package:church360_app/features/visitors/presentation/providers/visitors_provider.dart';
import 'package:church360_app/features/visitors/presentation/screens/visitor_visit_form_screen.dart';
import 'package:church360_app/features/visitors/presentation/screens/visitors_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Visitor _visitor({
  VisitorStatus status = VisitorStatus.firstVisit,
  String followUpStatus = 'pending',
}) {
  final now = DateTime(2026, 9, 20);
  return Visitor(
    id: 'visitor-1',
    firstName: 'Ana',
    lastName: 'Souza',
    phone: '(11) 99999-9999',
    firstVisitDate: now,
    totalVisits: 1,
    status: status,
    age: 29,
    gender: 'female',
    state: 'SP',
    followUpStatus: followUpStatus,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _host(Widget child, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(theme: AppTheme.lightTheme, home: child),
  );
}

void main() {
  testWidgets('visitantes usam GlassCard e badges de ciclo e acompanhamento', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const VisitorsListScreen(), [
        allVisitorsProvider.overrideWith(
          (ref) async => [_visitor(followUpStatus: 'completed')],
        ),
        currentUserHasPermissionProvider(
          'visitors.create',
        ).overrideWith((ref) async => true),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('PRIMEIRA VISITA'), findsOneWidget);
    expect(find.text('CONCLUÍDO'), findsOneWidget);
    expect(find.byType(GlassCard), findsNWidgets(2));
    expect(find.byIcon(AppIcons.search), findsNWidgets(2));
  });

  testWidgets(
    'formulário de visita usa a superfície compartilhada e ícones semânticos',
    (tester) async {
      await tester.pumpWidget(
        _host(const VisitorVisitFormScreen(visitorId: 'visitor-1'), [
          visitorByIdProvider(
            'visitor-1',
          ).overrideWith((ref) async => _visitor()),
          currentUserHasPermissionProvider(
            'visitors.followup',
          ).overrideWith((ref) async => true),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ana Souza'), findsOneWidget);
      expect(find.byType(GlassCard), findsOneWidget);
      expect(find.byIcon(AppIcons.calendarFilled), findsOneWidget);
      expect(find.byIcon(AppIcons.note), findsOneWidget);
      expect(find.text('Registrar Visita'), findsNWidgets(2));
    },
  );
}
