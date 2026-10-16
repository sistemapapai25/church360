import 'package:church360_app/features/worship/data/worship_repository.dart';
import 'package:church360_app/features/worship/domain/models/worship_service.dart';
import 'package:church360_app/features/worship/presentation/providers/worship_provider.dart';
import 'package:church360_app/features/worship/presentation/screens/geo_checkin_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

WorshipAttendance _att(String user, String name, {String source = 'geo', DateTime? validatedAt}) =>
    WorshipAttendance(
      id: 'a-$user',
      worshipServiceId: 'ev',
      memberId: user,
      memberName: name,
      checkedInAt: DateTime(2026, 10, 16, 19, 28),
      createdAt: DateTime(2026, 10, 16, 19, 28),
      source: source,
      distanceM: 12,
      validatedAt: validatedAt,
    );

class _FakeRepo extends WorshipRepository {
  _FakeRepo()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final calls = <(String, bool)>[];

  @override
  Future<List<WorshipAttendance>> getWorshipAttendance(String worshipServiceId) async => [
    _att('u1', 'Maria Silva'),
    _att('u2', 'João Souza'),
    _att('u3', 'Já Validada', validatedAt: DateTime(2026, 10, 16)),
    _att('u4', 'Check-in Manual', source: 'manual'),
  ];

  @override
  Future<void> validateCheckin(String worshipServiceId, String memberId, {required bool ok}) async =>
      calls.add((memberId, ok));
}

void main() {
  testWidgets('só os geo pendentes viram carta; desfazer é local; salvar grava e devolve os recusados', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _FakeRepo();
    Set<String>? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [worshipRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await GeoCheckinReviewScreen.open(context, 'ev'),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 de 2'), findsOneWidget);
    expect(find.text('Já Validada'), findsNothing);
    expect(find.text('Check-in Manual'), findsNothing);

    await tester.tap(find.byTooltip('Não está aqui')); // Maria, por engano
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Desfazer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 de 2'), findsOneWidget);
    expect(repo.calls, isEmpty);

    await tester.tap(find.byTooltip('Presente')); // Maria
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Não está aqui')); // João
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salvar conferência'));
    await tester.pumpAndSettle();

    expect(repo.calls, [('u1', true), ('u2', false)]);
    expect(result, {'u2'});
    await tester.pump(const Duration(seconds: 5)); // deixa o SnackBar sair
  });
}
