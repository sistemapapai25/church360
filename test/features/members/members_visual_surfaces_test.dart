import 'package:church360_app/core/design/app_icons.dart';
import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/core/widgets/glass_card.dart';
import 'package:church360_app/features/access_levels/presentation/providers/access_level_provider.dart';
import 'package:church360_app/features/members/domain/models/member.dart';
import 'package:church360_app/features/members/presentation/providers/members_provider.dart';
import 'package:church360_app/features/members/presentation/screens/member_form_screen.dart';
import 'package:church360_app/features/members/presentation/screens/member_profile_screen.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Member _member() {
  final now = DateTime(2026, 9, 25);
  return Member(
    id: 'member-visual-1',
    email: 'ana@example.com',
    firstName: 'Ana',
    lastName: 'Souza',
    phone: '(11) 99999-9999',
    status: 'member_active',
    memberType: 'membro',
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
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('perfil de membro usa GlassCard nas seções e AppIcons', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const MemberProfileScreen(memberId: 'member-visual-1'), [
        memberByIdProvider(
          'member-visual-1',
        ).overrideWith((ref) async => _member()),
        currentMemberProvider.overrideWith((ref) async => null),
        familyRelationshipsStreamProvider(
          'member-visual-1',
        ).overrideWith((ref) => Stream.value(const [])),
        currentUserHasPermissionProvider.overrideWith((ref, permission) async {
          return false;
        }),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.byType(GlassCard), findsAtLeastNWidgets(5));
    expect(find.byIcon(AppIcons.back), findsOneWidget);
    expect(find.byIcon(AppIcons.expand), findsAtLeastNWidgets(1));
  });

  testWidgets('formulário de membro agrupa seções em GlassCard', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const MemberFormScreen(), [
        isLeaderOrAboveProvider.overrideWith((ref) async => true),
        currentUserHasPermissionProvider.overrideWith((ref, permission) async {
          return true;
        }),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dados Pessoais'), findsOneWidget);
    expect(find.text('Informações Eclesiásticas'), findsOneWidget);
    expect(find.byType(GlassCard), findsAtLeastNWidgets(4));
    expect(find.byIcon(AppIcons.back), findsOneWidget);
    expect(find.byIcon(AppIcons.check), findsOneWidget);
  });
}
