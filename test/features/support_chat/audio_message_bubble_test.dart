import 'package:church360_app/features/support_chat/presentation/widgets/audio_message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ondas: volume alto vira barra alta, silêncio vira barra baixa', () {
    final bars = waveformBars([-160, -160, 0, 0], count: 2);
    expect(bars, [closeTo(0.15, 0.001), closeTo(1, 0.001)]);
  });

  test('ondas: sem níveis do aparelho, barras médias', () {
    expect(waveformBars(const [], count: 3), [0.4, 0.4, 0.4]);
  });

  test('ondas: menos níveis que barras não quebra', () {
    expect(waveformBars([-10], count: 4), hasLength(4));
  });

  test('duração em m:ss', () {
    expect(formatAudioDuration(65400), '1:05');
    expect(formatAudioDuration(0), '0:00');
  });

  test('fala do agente: palavra longa vira barra alta, texto curto não quebra', () {
    expect(speechBars('a paralelepípedo', count: 2), [closeTo(0.325, 0.001), closeTo(1, 0.001)]);
    expect(speechBars('oi', count: 32), hasLength(32));
    expect(speechBars('   ', count: 2), [0.4, 0.4]);
  });

  test('fala do agente: duração estimada pelas palavras, mínimo 1 s', () {
    expect(speechDurationMs('uma duas três quatro cinco'), 2000);
    expect(speechDurationMs('oi'), 1000);
  });

  testWidgets('Transcrição abre e fecha o texto', (tester) async {
    var open = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => AudioMessageBubble(
            isUser: true,
            accent: Colors.indigo,
            bars: waveformBars(const []),
            durationMs: 3000,
            progress: 0,
            isPlaying: false,
            avatar: const SizedBox(),
            transcript: 'Quero saber das escalas',
            showTranscript: open,
            onToggleTranscript: () => setState(() => open = !open),
          ),
        ),
      ),
    ));
    expect(find.text('0:03'), findsOneWidget);
    expect(find.text('Quero saber das escalas'), findsNothing);
    await tester.tap(find.text('Transcrição'));
    await tester.pump();
    expect(find.text('Quero saber das escalas'), findsOneWidget);
    expect(find.text('Ocultar transcrição'), findsOneWidget);
  });

  testWidgets('sem transcrição, sem botão', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AudioMessageBubble(
          isUser: false,
          accent: Colors.indigo,
          bars: waveformBars(const []),
          durationMs: 1000,
          progress: 0,
          isPlaying: false,
          avatar: const SizedBox(),
        ),
      ),
    ));
    expect(find.text('Transcrição'), findsNothing);
  });
}
