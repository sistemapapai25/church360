import 'package:church360_app/core/design/app_icons.dart';
import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/core/widgets/glass_card.dart';
import 'package:church360_app/features/ministries/presentation/screens/ministry_form_screen.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
