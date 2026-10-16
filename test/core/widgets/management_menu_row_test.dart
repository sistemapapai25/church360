// Frente G (roadmap Home/culto/Dashboard, 16/10/2026): cada seção do Menu de
// Gestão mostra só os itens permitidos e some sem nenhuma permissão;
// "Vincular pessoas" ganha a bolinha com os cadastros esperando vínculo.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/core/domain/models/management_menu.dart';
import 'package:church360_app/core/widgets/management_menu_row.dart';
import 'package:church360_app/features/branches/presentation/providers/branches_provider.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';

Widget _app(
  Set<String> granted, {
  int pending = 0,
  void Function(String route)? onNavigate,
}) {
  return ProviderScope(
    overrides: [
      currentUserHasPermissionProvider.overrideWith(
        (ref, code) async => granted.contains(code),
      ),
      isMatrizAdminProvider.overrideWith((ref) async => false),
      pendingLinkCountProvider.overrideWith((ref) async => pending),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ManagementMenuSection(
          category: kPeopleMenu,
          onNavigate: onNavigate == null ? null : (_, r) => onNavigate(r),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('sem permissão nenhuma a seção some', (tester) async {
    await tester.pumpWidget(_app(const {}));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNothing);
    expect(find.text('Pessoas'), findsNothing);
  });

  testWidgets('só members.view: só o item Membros, e ele navega', (
    tester,
  ) async {
    String? aberto;
    await tester.pumpWidget(
      _app(const {'members.view'}, onNavigate: (r) => aberto = r),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('Visitantes'), findsNothing);
    expect(find.text('Vincular pessoas'), findsNothing);

    await tester.tap(find.text('Membros'));
    expect(aberto, '/members');
  });

  testWidgets('Vincular pessoas mostra a contagem pendente', (tester) async {
    await tester.pumpWidget(
      _app(const {'members.merge_duplicates'}, pending: 3),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vincular pessoas'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('3 cadastros esperando vínculo'), findsOneWidget);
  });
}
