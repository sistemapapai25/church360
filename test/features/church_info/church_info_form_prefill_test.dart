import 'package:church360_app/features/church_info/domain/models/church_info.dart';
import 'package:church360_app/features/church_info/presentation/providers/church_info_provider.dart';
import 'package:church360_app/features/church_info/presentation/screens/church_info_form_screen.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // O bug de 13/10/2026: os dados já vinham carregados (o topo da aba Igreja
  // usa o mesmo provider) e o formulário abria vazio, porque só um `listen`
  // preenchia, e ele não dispara sem mudança.
  testWidgets('Editar Igreja preenche com os dados já carregados', (
    tester,
  ) async {
    final info = ChurchInfo(
      id: 'ci1',
      name: 'Igreja Teste',
      address: 'Avenida B, Quadra F',
      phone: '62 984127321',
      createdAt: DateTime(2026),
    );
    final container = ProviderContainer(
      overrides: [
        churchInfoProvider.overrideWith((ref) async => info),
        currentUserHasPermissionProvider.overrideWith((ref, _) async => true),
      ],
    );
    addTearDown(container.dispose);
    await container.read(churchInfoProvider.future);
    // Tela alta: o ListView só monta o que está visível.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ChurchInfoFormScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Igreja Teste'), findsOneWidget);
    expect(find.text('Avenida B, Quadra F'), findsOneWidget);
    expect(find.text('Editar Igreja'), findsOneWidget);
  });
}
