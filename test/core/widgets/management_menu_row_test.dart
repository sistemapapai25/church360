// B5a (roadmap Home/culto/Dashboard, 14/10/2026): a fileira de bolinhas da
// Dashboard mostra só as categorias com alguma permissão; o bottom sheet
// mostra só os itens permitidos; sem nenhuma permissão a fileira some.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/core/widgets/management_menu_row.dart';
import 'package:church360_app/features/branches/presentation/providers/branches_provider.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';

Widget _app(Set<String> granted, {void Function(String route)? onNavigate}) {
  return ProviderScope(
    overrides: [
      currentUserHasPermissionProvider.overrideWith(
        (ref, code) async => granted.contains(code),
      ),
      currentUserIsOwnerProvider.overrideWith((ref) async => false),
      isMatrizAdminProvider.overrideWith((ref) async => false),
      currentUserSeesConfigCategoryExtrasProvider.overrideWith(
        (ref) async => false,
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ManagementMenuRow(
          onNavigate: onNavigate == null ? null : (_, r) => onNavigate(r),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('sem permissão nenhuma a fileira some', (tester) async {
    await tester.pumpWidget(_app(const {}));
    await tester.pumpAndSettle();

    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.text('Pessoas'), findsNothing);
  });

  testWidgets('só members.view: só a bolinha Pessoas, só o item Membros', (
    tester,
  ) async {
    String? aberto;
    await tester.pumpWidget(
      _app(const {'members.view'}, onNavigate: (r) => aberto = r),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(find.text('Pessoas'), findsOneWidget);
    expect(find.text('Agenda'), findsNothing);
    expect(find.text('Configurações'), findsNothing);

    await tester.tap(find.text('Pessoas'));
    await tester.pumpAndSettle();

    expect(find.text('Membros'), findsOneWidget);
    expect(find.text('Visitantes'), findsNothing);
    expect(find.text('Tags'), findsNothing);

    await tester.tap(find.text('Membros'));
    await tester.pumpAndSettle();

    expect(aberto, '/members');
    expect(find.text('Membros'), findsNothing, reason: 'sheet fechou');
  });
}
