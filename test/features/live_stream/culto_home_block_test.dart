import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/live_stream/domain/models/current_culto.dart';
import 'package:church360_app/features/live_stream/presentation/providers/live_stream_provider.dart';
import 'package:church360_app/features/live_stream/presentation/widgets/culto_home_block.dart';

Widget _host(CurrentCulto culto) => ProviderScope(
  overrides: [
    currentCultoProvider.overrideWith((ref) => Stream.value(culto)),
  ],
  child: MaterialApp(
    theme: AppTheme.lightTheme,
    home: const Scaffold(body: CultoHomeBlock()),
  ),
);

void main() {
  testWidgets('culto da Agenda sem chave: título, hora, sem Assistir', (
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

    expect(find.text('Culto Quarta'), findsOneWidget);
    expect(find.text('desde 19:30'), findsOneWidget);
    expect(find.text('CULTO AGORA'), findsOneWidget);
    expect(find.text('Estou na igreja'), findsOneWidget);
    expect(find.text('Assistir'), findsNothing);
  });

  testWidgets('chave ligada sem culto na Agenda: AO VIVO e Assistir', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const CurrentCulto(
          isLive: true,
          streamUrl: 'https://www.youtube.com/watch?v=x',
          message: 'Em instantes',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('AO VIVO'), findsOneWidget);
    expect(find.text('Culto ao vivo'), findsOneWidget);
    expect(find.text('Em instantes'), findsOneWidget);
    expect(find.text('Assistir'), findsOneWidget);
    expect(find.text('Estou na igreja'), findsNothing);
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
      'checkin_enabled': false,
    });
    expect(c.isLive, isTrue);
    expect(c.eventId, 'e1');
    expect(c.streamUrl, isNull);
    expect(CurrentCulto.fromJson(null).isLive, isFalse);
  });
}
