import 'package:church360_app/core/design/app_icons.dart';
import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/core/widgets/glass_card.dart';
import 'package:church360_app/core/widgets/status_badge.dart';
import 'package:church360_app/features/ministries/domain/models/ministry.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:church360_app/features/ministries/presentation/screens/ministry_detail_screen.dart';
import 'package:church360_app/features/ministries/presentation/screens/ministry_form_screen.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 9, 21);

Ministry _ministry() {
  return Ministry(
    id: 'm1',
    name: 'Louvor',
    description: 'Equipe de música e adoração',
    icon: 'church',
    color: '0xFF2563EB',
    isActive: true,
    createdAt: _now,
    updatedAt: _now,
  );
}

Override _permission(String code, bool value) {
  return currentUserHasPermissionProvider(
    code,
  ).overrideWith((ref) async => value);
}

void main() {
  testWidgets('formulário novo usa superfícies de vidro e catálogo semântico', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [_permission('ministries.create', true)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MinistryFormScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassCard), findsNWidgets(4));
    expect(find.byIcon(AppIcons.church), findsNWidgets(2));
    expect(find.byIcon(AppIcons.description), findsOneWidget);
    expect(find.text('Salvar'), findsOneWidget);
  });

  testWidgets(
    'detalhe usa card principal, badge e estados vazios compartilhados',
    (tester) async {
      final ministry = _ministry();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ministryByIdProvider('m1').overrideWith((ref) async => ministry),
            currentMemberMinistriesProvider.overrideWith((ref) async => []),
            ministryMembersProvider('m1').overrideWith((ref) async => []),
            ministrySchedulesProvider('m1').overrideWith((ref) async => []),
            _permission('ministries.edit', true),
            _permission('ministries.delete', true),
            _permission('ministries.manage_members', true),
            _permission('ministries.manage_schedule', true),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MinistryDetailScreen(ministryId: 'm1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GlassCard), findsNWidgets(2));
      expect(find.byType(StatusBadge), findsOneWidget);
      expect(find.byIcon(AppIcons.church), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -1800));
      await tester.pumpAndSettle();

      expect(find.byType(GlassCard), findsNWidgets(3));
      expect(find.text('Nenhum membro neste ministério'), findsOneWidget);
      expect(find.text('Nenhuma escala registrada'), findsOneWidget);
    },
  );
}
