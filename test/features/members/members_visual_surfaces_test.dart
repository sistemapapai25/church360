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
import 'package:go_router/go_router.dart';
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
    // 3 seções: o QR saiu do perfil (QR E1, 19/10) e "Pendências do
    // Cadastro" virou o card sempre aberto do topo (22/10).
    expect(find.byType(GlassCard), findsAtLeastNWidgets(3));
    expect(find.byIcon(AppIcons.back), findsOneWidget);
    expect(find.byIcon(AppIcons.expand), findsAtLeastNWidgets(1));
  });

  testWidgets('pendência do cadastro é link direto para o campo', (
    tester,
  ) async {
    String? destino;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const MemberProfileScreen(memberId: 'member-visual-1'),
        ),
        GoRoute(
          path: '/members/:id/edit',
          builder: (_, state) {
            destino = state.uri.toString();
            return const SizedBox();
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memberByIdProvider(
            'member-visual-1',
          ).overrideWith((ref) async => _member()),
          currentMemberProvider.overrideWith((ref) async => null),
          familyRelationshipsStreamProvider(
            'member-visual-1',
          ).overrideWith((ref) => Stream.value(const [])),
          currentUserHasPermissionProvider.overrideWith(
            (ref, permission) async => permission == 'members.edit',
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Membresia e conversão saíram da régua (22/10/2026).
    expect(find.text('Data de Membresia'), findsNothing);
    final cpf = find.byKey(const ValueKey('pendencia-cpf'));
    expect(cpf, findsOneWidget);
    await tester.ensureVisible(cpf);
    await tester.tap(cpf);
    await tester.pumpAndSettle();

    expect(destino, '/members/member-visual-1/edit?section=personal&field=cpf');
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
