import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/church_onboarding/domain/onboarding_status.dart';
import 'package:church360_app/features/church_onboarding/presentation/providers/onboarding_provider.dart';
import 'package:church360_app/features/church_onboarding/presentation/screens/onboarding_steps_screen.dart';

OnboardingStatus _status(Map<String, bool> steps, {bool dismissed = false}) =>
    OnboardingStatus.fromJson({
      'steps': steps,
      'pains': const ['finances'],
      'done': steps.values.every((v) => v) && steps.length == 6,
      'dismissed': dismissed,
    });

void main() {
  test('fromJson: etapa ausente conta como não feita', () {
    final s = _status({'identity': true, 'cultos': true});
    expect(s.isDone(OnboardingStep.identity), isTrue);
    expect(s.isDone(OnboardingStep.location), isFalse);
    expect(s.doneCount, 2);
    expect(s.total, 6);
    expect(s.pains, ['finances']);
    expect(s.done, isFalse);
  });

  test('toda dor tem código único', () {
    final codes = kOnboardingPains.map((p) => p.code).toSet();
    expect(codes.length, kOnboardingPains.length);
  });

  testWidgets('tela mostra progresso, 6 etapas e Pular só nas pendentes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingStatusProvider.overrideWith(
            (ref) async => _status({
              'identity': true,
              'location': false,
              'cultos': true,
              'ministries': true,
              'pains': true,
              'leaders': false,
            }),
          ),
        ],
        child: const MaterialApp(home: OnboardingStepsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4 de 6 etapas concluídas'), findsOneWidget);
    for (final s in OnboardingStep.values) {
      expect(find.byKey(ValueKey('step-${s.code}')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('skip-location')), findsOneWidget);
    expect(find.byKey(const ValueKey('skip-leaders')), findsOneWidget);
    expect(find.byKey(const ValueKey('skip-identity')), findsNothing);
    expect(find.text('Esconder da Dashboard'), findsOneWidget);
  });
}
