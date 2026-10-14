import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/worship/data/geo_checkin_service.dart';
import 'package:church360_app/features/worship/presentation/widgets/presence_reaction_panel.dart';

/// Servidor de mentira: [status] é o que `worship_geo_status` responde;
/// [afterAsk] é o que o check-in com permissão devolve.
class FakeGeoCheckinService extends GeoCheckinService {
  final GeoCheckinResult status_;
  final GeoCheckinResult? afterAsk;
  final reactions = <String>[];

  FakeGeoCheckinService(this.status_, {this.afterAsk})
    : super(
        // Sem auto-refresh: o timer do token derrubaria o teste de widget.
        SupabaseClient(
          'http://x',
          'k',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  Future<GeoCheckinResult> status() async => status_;

  @override
  Future<GeoCheckinResult> checkIn({required bool ask}) async =>
      (ask ? afterAsk : null) ?? status_;

  @override
  Future<bool> react(String reaction) async {
    reactions.add(reaction);
    return true;
  }
}

Widget host(GeoCheckinService geo, {bool compact = true}) => ProviderScope(
  overrides: [geoCheckinServiceProvider.overrideWithValue(geo)],
  child: MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: PresenceReactionPanel(compact: compact)),
  ),
);

void main() {
  testWidgets('janela aberta: pergunta, responder marca presença e reage', (
    tester,
  ) async {
    final geo = FakeGeoCheckinService(
      const GeoCheckinResult(GeoCheckinStatus.aberta, eventName: 'Culto'),
      afterAsk: const GeoCheckinResult(
        GeoCheckinStatus.presente,
        eventName: 'Culto',
      ),
    );
    await tester.pumpWidget(host(geo));
    await tester.pump();
    await tester.pump();

    expect(find.text('Chegou bem?'), findsOneWidget);
    expect(find.text('Tá ótimo! 🙌'), findsOneWidget);
    expect(find.text('Mais ou menos 😐'), findsOneWidget);

    await tester.tap(find.text('Tá ótimo! 🙌'));
    await tester.pump();
    await tester.pump();

    expect(geo.reactions, ['otimo']);
    expect(find.text('Presença confirmada. Bom culto!'), findsOneWidget);
    expect(find.text('Tá ótimo! 🙌'), findsNothing);
  });

  testWidgets('já respondeu antes: só a linha de confirmação', (tester) async {
    final geo = FakeGeoCheckinService(
      const GeoCheckinResult(
        GeoCheckinStatus.jaMarcado,
        eventName: 'Culto',
        reaction: 'gostando',
      ),
    );
    await tester.pumpWidget(host(geo));
    await tester.pump();
    await tester.pump();

    expect(find.text('Presença confirmada. Bom culto!'), findsOneWidget);
    expect(find.text('Tô gostando 🙂'), findsNothing);
    expect(geo.reactions, isEmpty);
  });

  testWidgets('fora da janela: na Home não aparece; em /presenca explica', (
    tester,
  ) async {
    final geo = FakeGeoCheckinService(
      const GeoCheckinResult(GeoCheckinStatus.fechada),
    );
    await tester.pumpWidget(host(geo));
    await tester.pump();
    await tester.pump();
    expect(find.byType(Text), findsNothing);

    await tester.pumpWidget(host(geo, compact: false));
    await tester.pump();
    await tester.pump();
    expect(find.text('Nenhum culto agora'), findsOneWidget);
  });

  test('fromJson lê a reação do ja_marcado', () {
    final r = GeoCheckinResult.fromJson({
      'status': 'ja_marcado',
      'event_name': 'Culto',
      'reaction': 'otimo',
    });
    expect(r.status, GeoCheckinStatus.jaMarcado);
    expect(r.reaction, 'otimo');
    expect(GeoCheckinResult.fromJson({'status': 'aberta'}).reaction, isNull);
  });
}
