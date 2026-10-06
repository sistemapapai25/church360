import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/events/domain/models/event.dart';
import 'package:church360_app/features/events/presentation/widgets/event_materials.dart';
import 'package:church360_app/features/support_materials/domain/models/support_material.dart';
import 'package:church360_app/features/support_materials/domain/models/support_material_link.dart';
import 'package:church360_app/features/support_materials/presentation/providers/support_materials_provider.dart';

Event _event({String? type}) => Event(
  id: 'e1',
  name: 'Culto',
  eventType: type,
  startDate: DateTime(2026, 10, 10, 19),
  status: 'published',
  createdAt: DateTime(2026, 10, 1),
);

final _material = SupportMaterial(
  id: 'm1',
  title: 'Apostila',
  materialType: SupportMaterialType.text,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required List<SupportMaterial> materials,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        materialsByEntityProvider((
          linkType: MaterialLinkType.event,
          entityId: 'e1',
        )).overrideWith((ref) async => materials),
      ],
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('exibição (tela do evento)', () {
    testWidgets('sem material, a seção não aparece', (tester) async {
      await _pump(
        tester,
        EventMaterialsSection(event: _event()),
        materials: [],
      );
      expect(find.text('Materiais'), findsNothing);
    });

    testWidgets('mostra o material sem ações de gestão', (tester) async {
      await _pump(
        tester,
        EventMaterialsSection(event: _event()),
        materials: [_material],
      );
      expect(find.text('Materiais'), findsOneWidget);
      expect(find.text('Apostila'), findsWidgets);
      expect(find.text('Vincular material'), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('notícia não mostra materiais', (tester) async {
      await _pump(
        tester,
        EventMaterialsSection(event: _event(type: 'news')),
        materials: [_material],
      );
      expect(find.text('Materiais'), findsNothing);
    });
  });

  group('gestão (edição do evento)', () {
    testWidgets('aviso público, vincular e desvincular', (tester) async {
      await _pump(
        tester,
        const EventMaterialsManager(eventId: 'e1'),
        materials: [_material],
      );
      expect(
        find.textContaining('visíveis para toda a igreja'),
        findsOneWidget,
      );
      expect(find.text('Vincular material'), findsOneWidget);
      expect(find.textContaining('fale com quem cuida'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desvincular'));
      await tester.pumpAndSettle();
      expect(find.textContaining('continua na biblioteca'), findsOneWidget);
    });
  });
}
