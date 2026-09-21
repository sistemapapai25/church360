import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:church360_app/core/widgets/glass_card.dart';
import 'package:church360_app/core/widgets/status_badge.dart';
import 'package:church360_app/features/events/domain/models/event.dart';
import 'package:church360_app/features/events/presentation/providers/events_provider.dart';
import 'package:church360_app/features/events/presentation/screens/event_detail_screen.dart';
import 'package:church360_app/features/events/presentation/screens/event_form_screen.dart';
import 'package:church360_app/features/events/presentation/screens/event_registration_screen.dart';
import 'package:church360_app/features/members/presentation/providers/members_provider.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';

Event _event() {
  final now = DateTime.now();
  return Event(
    id: 'event-visual-1',
    name: 'Encontro de integração',
    description: 'Um encontro para a comunidade.',
    startDate: now.add(const Duration(days: 2)),
    endDate: now.add(const Duration(days: 2, hours: 2)),
    location: 'Salão principal',
    eventType: 'encontro',
    requiresRegistration: true,
    registrationCount: 8,
    maxCapacity: 80,
    status: 'published',
    createdAt: now,
  );
}

void main() {
  testWidgets('detalhe de evento usa cards compartilhados e badge de status', (
    tester,
  ) async {
    final event = _event();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventByIdProvider(event.id).overrideWith((ref) async => event),
          currentMemberProvider.overrideWith((ref) async => null),
          eventRegistrationsProvider(event.id).overrideWith((ref) async => []),
          eventSchedulesProvider(event.id).overrideWith((ref) async => []),
          activeMinistriesProvider.overrideWith((ref) async => []),
          currentUserHasPermissionProvider(
            'events.create',
          ).overrideWith((ref) async => false),
          currentUserHasPermissionProvider(
            'events.edit',
          ).overrideWith((ref) async => false),
        ],
        child: MaterialApp(home: EventDetailScreen(eventId: event.id)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassCard), findsNWidgets(8));
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.text('Encontro de integração'), findsNWidgets(2));
    expect(find.text('Salão principal'), findsOneWidget);
  });

  testWidgets('formulário de evento começa em uma superfície GlassCard', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserHasPermissionProvider(
            'events.create',
          ).overrideWith((ref) async => false),
          currentUserHasPermissionProvider(
            'events.edit',
          ).overrideWith((ref) async => false),
        ],
        child: const MaterialApp(home: EventFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassCard), findsOneWidget);
    expect(find.text('Nome do Evento *'), findsOneWidget);
    expect(find.text('Criar Evento'), findsOneWidget);
  });

  testWidgets('inscrição pública usa GlassCard no formulário de convidado', (
    tester,
  ) async {
    final event = _event();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventByIdProvider(event.id).overrideWith((ref) async => event),
          currentMemberProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(home: EventRegistrationScreen(eventId: event.id)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassCard), findsOneWidget);
    expect(find.text('Inscreva-se sem precisar de conta'), findsOneWidget);
    expect(find.text('Nome completo *'), findsOneWidget);
  });
}
