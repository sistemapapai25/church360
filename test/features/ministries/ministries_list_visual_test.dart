import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/core/widgets/glass_card.dart';
import 'package:church360_app/core/widgets/status_badge.dart';
import 'package:church360_app/features/ministries/domain/models/ministry.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:church360_app/features/ministries/presentation/screens/ministries_list_screen.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 9, 20);

Ministry _ministry(String id, String name, {bool active = true}) {
  return Ministry(
    id: id,
    name: name,
    description: 'Descrição de $name',
    icon: 'church',
    color: '#2563EB',
    isActive: active,
    createdAt: _now,
    updatedAt: _now,
  );
}

MinistryMember _member(String ministryId, String name) {
  return MinistryMember(
    id: 'member-$name',
    ministryId: ministryId,
    memberId: 'user-$name',
    memberName: name,
    role: MinistryRole.member,
    joinedAt: _now,
    createdAt: _now,
  );
}

Widget _host(List<Ministry> ministries) {
  return ProviderScope(
    overrides: [
      visibleMinistriesProvider.overrideWith((ref) async => ministries),
      ministriesCanSeeAllProvider.overrideWith((ref) async => true),
      currentUserHasPermissionProvider(
        'ministries.create',
      ).overrideWith((ref) async => true),
      for (final ministry in ministries)
        ministryMembersProvider(
          ministry.id,
        ).overrideWith((ref) async => [_member(ministry.id, 'Ana')]),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const MinistriesListScreen(),
    ),
  );
}

void main() {
  testWidgets('usa vidro e badge compartilhados na listagem', (tester) async {
    await tester.pumpWidget(
      _host([
        _ministry('m1', 'Louvor'),
        _ministry('m2', 'Recepção', active: false),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassCard), findsNWidgets(3));
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.text('INATIVO'), findsOneWidget);
    expect(find.text('1 membro'), findsNWidgets(2));
  });

  testWidgets('busca filtra nome e descrição dos ministérios', (tester) async {
    await tester.pumpWidget(
      _host([_ministry('m1', 'Louvor'), _ministry('m2', 'Recepção')]),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'recep');
    await tester.pumpAndSettle();

    expect(find.text('Recepção'), findsOneWidget);
    expect(find.text('Louvor'), findsNothing);
  });
}
