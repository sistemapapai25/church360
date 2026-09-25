import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:church360_app/core/design/app_icons.dart';
import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/core/widgets/glass_card.dart';
import 'package:church360_app/core/widgets/status_badge.dart';
import 'package:church360_app/features/church_schedule/domain/models/church_schedule.dart';
import 'package:church360_app/features/church_schedule/presentation/providers/church_schedule_provider.dart';
import 'package:church360_app/features/church_schedule/presentation/screens/church_schedule_form_screen.dart';
import 'package:church360_app/features/church_schedule/presentation/screens/church_schedule_list_screen.dart';
import 'package:church360_app/features/events/domain/models/event.dart';
import 'package:church360_app/features/events/presentation/providers/events_provider.dart';
import 'package:church360_app/features/members/presentation/providers/members_provider.dart';
import 'package:church360_app/features/news/presentation/screens/manage_news_screen.dart';
import 'package:church360_app/features/news/presentation/screens/news_screen.dart';
import 'package:church360_app/features/news/presentation/screens/news_form_screen.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';

final _now = DateTime(2026, 9, 25, 19, 30);

ChurchSchedule _schedule(String id, {bool active = true}) => ChurchSchedule(
  id: id,
  title: 'Ensaio do louvor',
  description: 'Preparação do culto de domingo',
  scheduleType: 'rehearsal',
  startDatetime: _now,
  endDatetime: _now.add(const Duration(hours: 2)),
  location: 'Templo principal',
  isActive: active,
);

Event _news(String id, {String status = 'published'}) => Event(
  id: id,
  name: 'Conferência Church360',
  description: 'Uma notícia de teste para a comunidade.',
  eventType: 'news',
  startDate: _now,
  endDate: _now.add(const Duration(days: 30)),
  location: 'Auditório',
  status: status,
  createdAt: _now,
);

Widget _host(Widget child, List<Override> overrides) => ProviderScope(
  key: UniqueKey(),
  overrides: overrides,
  child: MaterialApp(theme: AppTheme.lightTheme, home: child),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('agenda usa GlassCard, StatusBadge e ícones semânticos', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const ChurchScheduleListScreen(), [
        activeChurchSchedulesProvider.overrideWith(
          (ref) => Stream<List<ChurchSchedule>>.value([_schedule('s1')]),
        ),
        currentUserHasPermissionProvider(
          'church_schedule.edit',
        ).overrideWith((ref) async => false),
        currentUserHasPermissionProvider(
          'church_schedule.delete',
        ).overrideWith((ref) async => false),
        currentUserHasPermissionProvider(
          'church_schedule.create',
        ).overrideWith((ref) async => false),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassCard), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.text('ATIVA'), findsOneWidget);
    expect(find.byIcon(AppIcons.calendar), findsOneWidget);
  });

  testWidgets('formulário de agenda agrupa campos em superfície de vidro', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const ChurchScheduleFormScreen(), [
        allMembersProvider.overrideWith((ref) async => []),
        currentUserHasPermissionProvider(
          'church_schedule.create',
        ).overrideWith((ref) async => true),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassCard), findsOneWidget);
    expect(find.text('Nova Agenda'), findsOneWidget);
    expect(find.byIcon(AppIcons.location), findsAtLeastNWidgets(1));
    expect(find.byIcon(AppIcons.repeat), findsAtLeastNWidgets(1));
  });

  testWidgets('notícias públicas usam card de vidro e badge de publicação', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const NewsScreen(), [
        recentNewsProvider.overrideWith((ref) async => [_news('n1')]),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassCard), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.text('PUBLICADA'), findsOneWidget);
    expect(find.byIcon(AppIcons.article), findsOneWidget);
  });

  testWidgets(
    'gestão e formulário de notícias usam superfícies compartilhadas',
    (tester) async {
      await tester.pumpWidget(
        _host(const ManageNewsScreen(), [
          allEventsProvider.overrideWith(
            (ref) async => [_news('n1'), _news('n2', status: 'draft')],
          ),
          currentUserHasPermissionProvider(
            'news.create',
          ).overrideWith((ref) async => false),
          currentUserHasPermissionProvider(
            'news.edit',
          ).overrideWith((ref) async => false),
          currentUserHasPermissionProvider(
            'news.delete',
          ).overrideWith((ref) async => false),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GlassCard), findsNWidgets(2));
      expect(find.byType(StatusBadge), findsNWidgets(2));

      await tester.pumpWidget(
        _host(const NewsFormScreen(), [
          currentUserHasPermissionProvider(
            'news.create',
          ).overrideWith((ref) async => true),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GlassCard), findsNWidgets(4));
      expect(find.byIcon(AppIcons.save), findsNWidgets(2));
    },
  );
}
