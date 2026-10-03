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

    // 3 desde 01/10: saíram a cor e o "Ministério ativo"; ficam dados
    // básicos, tipo e prévia.
    expect(find.byType(GlassCard), findsNWidgets(3));
    expect(find.byIcon(AppIcons.church), findsNWidgets(2));
    expect(find.byIcon(AppIcons.description), findsOneWidget);
    expect(find.text('Salvar'), findsOneWidget);
  });

  testWidgets('criação mostra o seletor de tipo e a prévia das abas', (
    tester,
  ) async {
    // O formulário é alto: fora de uma superfície grande o card de tipo não
    // chega a ser construído e o tap cai no vazio.
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    expect(find.text('Tipo do Ministério'), findsOneWidget);
    // Os quatro tipos que abrem tela própria — kids/louvor/midia ficam fora.
    expect(find.text('Comum'), findsOneWidget);
    expect(find.text('Batismo'), findsOneWidget);
    expect(find.text('Raízes'), findsOneWidget);
    expect(find.text('Diaconato'), findsOneWidget);
    expect(find.text('Kids'), findsNothing);

    // Prévia do tipo padrão: as cinco de base.
    expect(find.text('Vai abrir com 5 abas:'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Turmas'), findsNothing);

    // Trocar o tipo troca a prévia — é o que justifica o card existir.
    await tester.ensureVisible(find.text('Batismo'));
    await tester.tap(find.text('Batismo'));
    await tester.pumpAndSettle();

    expect(find.text('Vai abrir com 7 abas:'), findsOneWidget);
    expect(find.text('Turmas'), findsOneWidget);
    expect(find.text('Checklist'), findsOneWidget);
    // WhatsApp segue na lista: desde 24/09 as duas abas se chamam igual — o
    // que muda entre os tipos e' o que ela fala com (equipe x alunos).
  });

}
