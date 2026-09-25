import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/core/design/app_icons.dart';
import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/core/widgets/glass_card.dart';
import 'package:church360_app/core/widgets/status_badge.dart';
import 'package:church360_app/features/groups/domain/models/group.dart';
import 'package:church360_app/features/groups/presentation/providers/groups_provider.dart';
import 'package:church360_app/features/groups/presentation/screens/group_form_screen.dart';
import 'package:church360_app/features/groups/presentation/screens/meeting_form_screen.dart';
import 'package:church360_app/features/groups/presentation/screens/visitor_form_dialog.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';
import 'package:church360_app/features/members/presentation/providers/members_provider.dart';

final _now = DateTime(2026, 9, 25);

Group _group() {
  return Group(
    id: 'g1',
    name: 'Jovens',
    description: 'Grupo de jovens',
    meetingDayOfWeek: 3,
    meetingTime: '19:30',
    isActive: true,
    createdAt: _now,
  );
}

Widget _host(Widget child, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(theme: AppTheme.lightTheme, home: child),
  );
}

void main() {
  testWidgets('formulário de grupo organiza seções em vidro e expõe status', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const GroupFormScreen(), [
        allMembersProvider.overrideWith((ref) async => []),
        currentUserHasPermissionProvider(
          'groups.create',
        ).overrideWith((ref) async => true),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassCard), findsAtLeastNWidgets(2));
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.text('ATIVO'), findsOneWidget);
    expect(find.byIcon(AppIcons.back), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byIcon(AppIcons.eventNote),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byIcon(AppIcons.eventNote), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byIcon(AppIcons.save),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byIcon(AppIcons.save), findsOneWidget);
  });

  testWidgets('formulário de reunião separa contexto, data e conteúdo', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const MeetingFormScreen(groupId: 'g1'), [
        groupByIdProvider('g1').overrideWith((ref) async => _group()),
        currentUserHasPermissionProvider(
          'groups.manage_meetings',
        ).overrideWith((ref) async => true),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassCard), findsNWidgets(3));
    expect(find.text('Jovens'), findsOneWidget);
    expect(find.text('Conteúdo da reunião'), findsOneWidget);
    expect(find.byIcon(AppIcons.calendarFilled), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byIcon(AppIcons.save),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byIcon(AppIcons.save), findsOneWidget);
  });

  testWidgets('diálogo de visitante usa vidro e catálogo semântico', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      const VisitorFormDialog(meetingId: 'meeting-1'),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.byType(GlassCard), findsOneWidget);
    expect(find.text('Cadastrar Visitante'), findsOneWidget);
    expect(find.byIcon(AppIcons.personAdd), findsOneWidget);
    expect(find.byIcon(AppIcons.save), findsOneWidget);
    expect(find.byIcon(AppIcons.close), findsOneWidget);
  });
}
