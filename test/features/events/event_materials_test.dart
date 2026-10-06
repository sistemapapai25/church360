import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/events/domain/models/event.dart';
import 'package:church360_app/features/events/presentation/providers/events_provider.dart';
import 'package:church360_app/features/events/presentation/widgets/event_materials.dart';
import 'package:church360_app/features/support_materials/domain/models/support_material.dart';
import 'package:church360_app/features/support_materials/domain/models/support_material_link.dart';
import 'package:church360_app/features/support_materials/presentation/providers/support_materials_provider.dart';

Event _event({
  String? type,
  String modality = 'presencial',
  String? pdf,
  String? video,
}) => Event(
  id: 'e1',
  name: 'Culto',
  eventType: type,
  modality: modality,
  pdfUrl: pdf,
  videoUrl: video,
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
  Event? event,
  bool canSeeVideo = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        materialsByEntityProvider((
          linkType: MaterialLinkType.event,
          entityId: 'e1',
        )).overrideWith((ref) async => materials),
        eventByIdProvider('e1').overrideWith((ref) async => event),
        canSeeReferenceVideoProvider(
          'e1',
        ).overrideWith((ref) async => canSeeVideo),
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

    testWidgets('PDF para todos; vídeo de referência só p/ professor e '
        'liderança, presencial também', (tester) async {
      final event = _event(pdf: 'https://x/a.pdf', video: 'https://youtu.be/v');
      await _pump(tester, EventMaterialsSection(event: event), materials: []);
      expect(find.text('PDF do evento'), findsOneWidget);
      expect(find.text('Vídeo de referência'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await _pump(
        tester,
        EventMaterialsSection(event: event),
        materials: [],
        canSeeVideo: true,
      );
      expect(find.text('Vídeo de referência'), findsOneWidget);
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
    testWidgets('presencial: modalidade, enviar PDF e vídeo de referência', (
      tester,
    ) async {
      await _pump(
        tester,
        const EventMaterialsManager(eventId: 'e1'),
        materials: [],
        event: _event(),
      );
      expect(find.text('Presencial'), findsOneWidget);
      expect(find.byKey(const ValueKey('event-upload-pdf')), findsOneWidget);
      expect(find.byKey(const ValueKey('event-upload-video')), findsOneWidget);
    });

    testWidgets('PDF preenchido e vídeo de referência preenchido', (
      tester,
    ) async {
      await _pump(
        tester,
        const EventMaterialsManager(eventId: 'e1'),
        materials: [],
        event: _event(pdf: 'https://x/a.pdf', video: 'https://youtu.be/v'),
      );
      expect(find.text('PDF do evento'), findsOneWidget);
      expect(find.text('Vídeo de referência'), findsOneWidget);
    });

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
