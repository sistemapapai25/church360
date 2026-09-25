import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:church360_app/features/courses/domain/models/course.dart';
import 'package:church360_app/features/courses/presentation/providers/courses_provider.dart';
import 'package:church360_app/features/events/domain/models/event.dart';
import 'package:church360_app/features/events/presentation/providers/events_provider.dart';
import 'package:church360_app/features/events/presentation/screens/event_detail_screen.dart';
import 'package:church360_app/features/members/presentation/providers/members_provider.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';

// Etapa 4b da Formação: event.course_id e o card "Ver curso".

Map<String, dynamic> _row({String? courseId, bool withKey = true}) => {
  'id': 'ev-1',
  'name': 'Inscrições abertas para o Batismo',
  'start_date': '2099-01-01T19:00:00',
  'created_at': '2026-09-25T00:00:00',
  if (withKey) 'course_id': courseId,
};

Event _event({String? courseId}) {
  final now = DateTime.now();
  return Event(
    id: 'ev-1',
    name: 'Inscrições abertas para o Batismo',
    startDate: now.add(const Duration(days: 2)),
    status: 'published',
    createdAt: now,
    courseId: courseId,
  );
}

Future<void> _pumpDetail(
  WidgetTester tester,
  Event event, {
  Course? course,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => EventDetailScreen(eventId: event.id),
      ),
      GoRoute(
        path: '/courses/:id/view',
        builder: (_, state) =>
            Text('curso aberto ${state.pathParameters['id']}'),
      ),
    ],
  );
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
        if (event.courseId != null)
          courseByIdProvider(
            event.courseId!,
          ).overrideWith((ref) async => course),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Event.course_id', () {
    test('linha sem a coluna (build antigo) vira null', () {
      expect(Event.fromJson(_row(withKey: false)).courseId, isNull);
    });

    test('linha com curso preenche courseId', () {
      expect(Event.fromJson(_row(courseId: 'c-1')).courseId, 'c-1');
    });

    test('toJson não manda a chave quando não há curso', () {
      final json = Event.fromJson(_row(courseId: null)).toJson();
      expect(json.containsKey('course_id'), isFalse);
    });

    test('toJson manda course_id quando há curso', () {
      final json = Event.fromJson(_row(courseId: 'c-1')).toJson();
      expect(json['course_id'], 'c-1');
    });
  });

  group('card Ver curso no detalhe', () {
    testWidgets('evento sem curso não mostra o card', (tester) async {
      await _pumpDetail(tester, _event());
      expect(find.text('Ver curso'), findsNothing);
    });

    testWidgets('evento com curso mostra o título e abre o curso', (
      tester,
    ) async {
      final course = Course(
        id: 'c-1',
        title: 'Batismo',
        createdAt: DateTime(2026, 9, 25),
      );
      await _pumpDetail(tester, _event(courseId: 'c-1'), course: course);

      expect(find.text('Batismo'), findsOneWidget);
      expect(find.text('Ver curso'), findsOneWidget);

      await tester.tap(find.text('Ver curso'));
      await tester.pumpAndSettle();
      expect(find.text('curso aberto c-1'), findsOneWidget);
    });

    testWidgets('curso que não volta (RLS/removido) esconde o card', (
      tester,
    ) async {
      await _pumpDetail(tester, _event(courseId: 'c-sumiu'));
      expect(find.text('Ver curso'), findsNothing);
    });
  });
}
