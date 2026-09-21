import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/core/widgets/glass_card.dart';
import 'package:church360_app/core/widgets/status_badge.dart';
import 'package:church360_app/features/events/domain/models/event.dart';
import 'package:church360_app/features/events/presentation/providers/events_provider.dart';
import 'package:church360_app/features/events/presentation/screens/events_list_screen.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';

Event _event({String status = 'published'}) {
  final now = DateTime.now();
  return Event(
    id: 'event-1',
    name: 'Culto de celebração',
    description: 'Um encontro para toda a igreja.',
    startDate: now.add(const Duration(days: 2)),
    endDate: now.add(const Duration(days: 2, hours: 2)),
    location: 'Templo principal',
    requiresRegistration: true,
    registrationCount: 12,
    maxCapacity: 100,
    status: status,
    createdAt: now,
  );
}

Future<void> _pumpList(WidgetTester tester, Event event) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        upcomingEventsProvider.overrideWith((ref) async => [event]),
        currentUserHasPermissionProvider(
          'events.create',
        ).overrideWith((ref) async => false),
        currentUserHasPermissionProvider(
          'events.edit',
        ).overrideWith((ref) async => false),
        currentUserHasPermissionProvider(
          'events.delete',
        ).overrideWith((ref) async => false),
      ],
      child: const MaterialApp(home: EventsListScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lista de eventos usa vidro, badge e metadados semânticos', (
    tester,
  ) async {
    await _pumpList(tester, _event());

    expect(find.byType(GlassCard), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.text('Culto de celebração'), findsOneWidget);
    expect(find.text('12 inscritos'), findsOneWidget);
    expect(find.byIcon(Icons.event_outlined), findsNWidgets(2));
  });

  testWidgets('evento cancelado usa tom neutro de status', (tester) async {
    await _pumpList(tester, _event(status: 'cancelled'));

    final badge = tester.widget<StatusBadge>(find.byType(StatusBadge));
    expect(badge.tone, AppStatusTone.dropped);
    expect(find.text('CANCELADO'), findsOneWidget);
  });
}
