import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/live_stream/domain/models/current_culto.dart';
import 'package:church360_app/features/live_stream/presentation/providers/live_stream_provider.dart';
import 'package:church360_app/features/live_stream/presentation/widgets/culto_home_block.dart';
import 'package:church360_app/features/worship/data/geo_checkin_service.dart';

import '../worship/presence_reaction_panel_test.dart'
    show FakeGeoCheckinService;

Widget _host(CurrentCulto culto) => ProviderScope(
  overrides: [
    currentCultoProvider.overrideWith((ref) => Stream.value(culto)),
    // Presença pelo celular: janela aberta, ninguém marcou ainda.
    geoCheckinServiceProvider.overrideWithValue(
      FakeGeoCheckinService(
        const GeoCheckinResult(GeoCheckinStatus.aberta, eventName: 'Culto'),
      ),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.lightTheme,
    home: const Scaffold(body: CultoHomeBlock()),
  ),
);

void main() {
  testWidgets('culto da Agenda sem chave e sem slides: só a linha e o painel', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const CurrentCulto(
          isLive: true,
          title: 'Culto Quarta',
          startHhmm: '19:30',
          checkinEnabled: true,
        ),
      ),
    );
    await tester.pump();
    // O painel da presença responde ao servidor de mentira num microtask.
    await tester.pump();

    expect(find.byKey(const ValueKey('video-card')), findsNothing);
    expect(find.byKey(const ValueKey('slides-card')), findsNothing);
    expect(find.byKey(const ValueKey('culto-max')), findsNothing);
    expect(find.text('Culto Quarta · 19:30'), findsOneWidget);
    expect(find.text('CULTO AGORA'), findsOneWidget);
    expect(find.text('Chegou bem?'), findsOneWidget);
    expect(find.text('Tá ótimo! 🙌'), findsOneWidget);
  });

  testWidgets('chave ligada sem culto na Agenda: AO VIVO, player, mensagem', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const CurrentCulto(
          isLive: true,
          // Link que não é YouTube: o player do YouTube precisa de WebView.
          streamUrl: 'https://x.test/live',
          message: 'Em instantes',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('AO VIVO'), findsOneWidget);
    expect(find.text('Culto ao vivo'), findsOneWidget);
    expect(find.text('Em instantes'), findsOneWidget);
    expect(find.byKey(const ValueKey('video-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('video-expand')), findsOneWidget);
    expect(find.text('Assistir no navegador'), findsOneWidget);
    expect(find.byKey(const ValueKey('slides-card')), findsNothing);
    expect(find.text('Chegou bem?'), findsNothing);
  });

  testWidgets('transmissão + slides: dois cards e "ampliar os dois"', (
    tester,
  ) async {
    // Android/iOS montam a WebView (sem plugin no teste); desktop abre fora.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await tester.pumpWidget(
      _host(
        const CurrentCulto(
          isLive: true,
          eventId: 'e1',
          title: 'Culto',
          streamUrl: 'https://x.test/live',
          slidesUrl: 'https://x.test/culto.pptx',
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('video-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('slides-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('slides-expand')), findsOneWidget);
    expect(find.byKey(const ValueKey('culto-max')), findsOneWidget);
    expect(find.text('Abrir slides'), findsOneWidget);
    // O framework cobra a variável zerada antes dos tearDowns.
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('min recolhe para a faixa; tocar na faixa expande', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const CurrentCulto(
          isLive: true,
          eventId: 'e1',
          title: 'Culto Quarta',
          startHhmm: '19:30',
          checkinEnabled: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('culto-min')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('culto-strip')), findsOneWidget);
    expect(find.byKey(const ValueKey('culto-min')), findsNothing);
    expect(find.text('Culto Quarta'), findsOneWidget);
    expect(find.text('Chegou bem?'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('culto-strip')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('culto-min')), findsOneWidget);
    expect(find.byKey(const ValueKey('culto-strip')), findsNothing);
  });

  testWidgets('sem culto: nada', (tester) async {
    await tester.pumpWidget(_host(CurrentCulto.none));
    await tester.pump();

    expect(find.byType(Text), findsNothing);
  });

  test('fromJson lê o contrato da RPC', () {
    final c = CurrentCulto.fromJson({
      'is_live': true,
      'event_id': 'e1',
      'title': 'Culto',
      'start_hhmm': '09:00',
      'stream_url': null,
      'message': null,
      'slides_url': 'https://x.test/culto.pdf',
      'checkin_enabled': false,
    });
    expect(c.isLive, isTrue);
    expect(c.eventId, 'e1');
    expect(c.streamUrl, isNull);
    expect(c.hasStream, isFalse);
    expect(c.slidesUrl, 'https://x.test/culto.pdf');
    expect(c.hasSlides, isTrue);
    expect(CurrentCulto.fromJson(null).isLive, isFalse);
  });
}
