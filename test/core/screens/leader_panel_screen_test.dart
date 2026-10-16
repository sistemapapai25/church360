import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/core/screens/leader_panel_screen.dart';
import 'package:church360_app/core/theme/app_theme.dart';

Widget _app(Map<String, dynamic>? panel, Widget home) => ProviderScope(
  key: UniqueKey(),
  overrides: [leaderPanelProvider.overrideWith((ref) async => panel)],
  child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: home)),
);

void main() {
  testWidgets('G5: líder vê os ministérios dele, a atenção e sem financeiro', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app({
        'scope': 'leader',
        'ministries': ['Louvor'],
        'can_message': false,
        'can_reports': false,
        'can_analytics': false,
        'presence': {'cultos': 4, 'avg': 120, 'prev_avg': 100},
        'absent_3': {
          'total': 1,
          'people': [
            {'id': 'u1', 'name': 'Ana Souza', 'photo_url': null},
          ],
        },
        'schedule_gaps': {'total': 0, 'items': []},
        'birthdays': [],
        'ministry_health': [
          {'id': 'm1', 'name': 'Louvor', 'members': 8, 'scheduled': 5, 'missing': 2},
        ],
      }, const LeaderPanelScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Seus ministérios'), findsOneWidget);
    expect(find.text('1 item pede sua atenção'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('▲ 20%'), findsOneWidget);
    expect(find.text('Faltaram nos 3 últimos cultos'), findsOneWidget);
    expect(find.text('faltam 2'), findsOneWidget);
    expect(find.text('Contribuições recebidas'), findsNothing);
    expect(find.text('Mensagem para todos os líderes'), findsNothing);

    await tester.tap(find.text('Faltaram nos 3 últimos cultos'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Souza'), findsOneWidget);
  });

  testWidgets('G5: cartão some para quem não é pastor nem líder', (
    tester,
  ) async {
    await tester.pumpWidget(_app(null, const LeaderPanelCard()));
    await tester.pumpAndSettle();
    expect(find.text('Seu painel'), findsNothing);

    await tester.pumpWidget(
      _app({
        'scope': 'global',
        'prayer_pending': 3,
        'absent_3': {'total': 2, 'people': []},
      }, const LeaderPanelCard()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Seu painel'), findsOneWidget);
    expect(find.text('5 itens precisam da sua atenção'), findsOneWidget);
  });
}
