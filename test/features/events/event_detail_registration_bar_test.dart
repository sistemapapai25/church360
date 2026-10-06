import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/core/widgets/pearl_button.dart';
import 'package:church360_app/features/events/domain/models/event.dart';
import 'package:church360_app/features/events/presentation/providers/events_provider.dart';
import 'package:church360_app/features/events/presentation/screens/event_detail_screen.dart';

Event _event({int registrationCount = 3, int? maxCapacity = 10}) {
  final now = DateTime.now();
  return Event(
    id: 'ev-bar',
    name: 'Encontro de jovens',
    startDate: now.add(const Duration(days: 3)),
    requiresRegistration: true,
    registrationCount: registrationCount,
    maxCapacity: maxCapacity,
    status: 'published',
    createdAt: now,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Event event,
  required Future<bool> Function() elegivel,
  EventRegistration? registration,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        amIEligibleToRegisterProvider(
          event.id,
        ).overrideWith((ref) => elegivel()),
      ],
      child: MaterialApp(
        home: Scaffold(
          bottomNavigationBar: EventRegistrationBar(
            event: event,
            registration: registration,
            memberId: 'm1',
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

bool _habilitado(WidgetTester tester) =>
    tester.widget<PearlButton>(find.byType(PearlButton)).onTap != null;

void main() {
  testWidgets('elegível: Inscrever-se habilitado', (tester) async {
    await _pump(tester, event: _event(), elegivel: () async => true);
    expect(find.text('Inscrever-se'), findsOneWidget);
    expect(_habilitado(tester), isTrue);
  });

  testWidgets('carregando: Verificando, desabilitado', (tester) async {
    await _pump(
      tester,
      event: _event(),
      elegivel: () => Completer<bool>().future,
    );
    expect(find.text('Verificando sua inscrição...'), findsOneWidget);
    expect(_habilitado(tester), isFalse);
  });

  testWidgets('inelegível: cadeado com motivo que cita turmas', (
    tester,
  ) async {
    await _pump(tester, event: _event(), elegivel: () async => false);
    expect(find.text(EventRegistrationBar.motivoInelegivel), findsOneWidget);
    expect(EventRegistrationBar.motivoInelegivel, contains('turmas'));
    expect(find.byType(Tooltip), findsOneWidget);
    expect(_habilitado(tester), isFalse);
  });

  testWidgets('erro na elegibilidade não bloqueia (T-08-05)', (tester) async {
    await _pump(
      tester,
      event: _event(),
      elegivel: () async => throw Exception('rede'),
    );
    expect(find.text('Inscrever-se'), findsOneWidget);
    expect(_habilitado(tester), isTrue);
  });

  testWidgets('lotado: Evento lotado, desabilitado', (tester) async {
    await _pump(
      tester,
      event: _event(registrationCount: 10, maxCapacity: 10),
      elegivel: () async => true,
    );
    expect(find.text('Evento lotado'), findsOneWidget);
    expect(_habilitado(tester), isFalse);
  });

  testWidgets('inscrito: Ver meu ingresso abre o sheet com o QR', (
    tester,
  ) async {
    await _pump(
      tester,
      event: _event(),
      elegivel: () async => true,
      registration: EventRegistration(
        id: 'r1',
        eventId: 'ev-bar',
        memberId: 'm1',
        registeredAt: DateTime.now(),
      ),
    );
    expect(find.text('Ver meu ingresso'), findsOneWidget);
    await tester.tap(find.text('Ver meu ingresso'));
    await tester.pumpAndSettle();
    expect(find.text('Seu ingresso'), findsOneWidget);
    expect(find.text('Apresente este código na entrada.'), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
    expect(find.text('Seu ingresso'), findsNothing);
  });
}
