import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/core/design/app_icons.dart';
import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/core/widgets/glass_card.dart';
import 'package:church360_app/core/widgets/status_badge.dart';
import 'package:church360_app/features/groups/domain/models/group.dart';
import 'package:church360_app/features/groups/presentation/providers/groups_provider.dart';
import 'package:church360_app/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:church360_app/features/groups/presentation/screens/groups_list_screen.dart';
import 'package:church360_app/features/members/presentation/providers/members_provider.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';

final _now = DateTime(2026, 9, 25);

Group _group(String id, String name, {bool active = true}) {
  return Group(
    id: id,
    name: name,
    description: 'Descrição de $name',
    leaderName: 'Ana Souza',
    meetingDayOfWeek: 3,
    meetingTime: '19:30',
    meetingAddress: 'Salão principal',
    isActive: active,
    memberCount: 8,
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
  testWidgets('listagem de grupos usa vidro, status e catálogo semântico', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const GroupsListScreen(), [
        allGroupsProvider.overrideWith(
          (ref) async => [
            _group('g1', 'Jovens'),
            _group('g2', 'Casais', active: false),
          ],
        ),
        currentUserHasPermissionProvider(
          'groups.create',
        ).overrideWith((ref) async => false),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassCard), findsNWidgets(2));
    expect(find.byType(StatusBadge), findsNWidgets(2));
    expect(find.text('ATIVO'), findsOneWidget);
    expect(find.text('INATIVO'), findsOneWidget);
    expect(find.byIcon(AppIcons.filterList), findsOneWidget);
  });

  testWidgets(
    'detalhe público de grupo organiza cabeçalho e descrição em vidro',
    (tester) async {
      final group = _group('g1', 'Jovens');
      await tester.pumpWidget(
        _host(const GroupDetailScreen(groupId: 'g1'), [
          groupByIdProvider('g1').overrideWith((ref) async => group),
          currentMemberProvider.overrideWith((ref) async => null),
          currentUserHasPermissionProvider.overrideWith((
            ref,
            permission,
          ) async {
            return false;
          }),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jovens'), findsOneWidget);
      expect(find.text('Descrição de Jovens'), findsOneWidget);
      expect(find.byType(GlassCard), findsNWidgets(2));
      expect(find.byType(StatusBadge), findsOneWidget);
      expect(find.byIcon(AppIcons.group), findsOneWidget);
    },
  );
}
