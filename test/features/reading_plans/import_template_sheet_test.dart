import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/core/design/app_icons.dart';
import 'package:church360_app/features/reading_plans/data/reading_plans_repository.dart';
import 'package:church360_app/features/reading_plans/domain/models/reading_plan.dart';
import 'package:church360_app/features/reading_plans/presentation/providers/reading_plans_provider.dart';
import 'package:church360_app/features/reading_plans/presentation/screens/manage_reading_plans_screen.dart';

class _FakeRepo extends ReadingPlansRepository {
  final List<ReadingPlan> plans;
  final List<ReadingPlanTemplate> templates;
  final imported = <String>[];

  _FakeRepo({required this.plans, required this.templates})
    : super(
        SupabaseClient(
          'http://localhost',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  Future<List<ReadingPlan>> getAllPlans() async => plans;

  @override
  Future<List<ReadingPlanTemplate>> getTemplates() async => templates;

  @override
  Future<String> importTemplate(String code) async {
    imported.add(code);
    return 'novo-$code';
  }
}

void main() {
  testWidgets('folha de modelos: importado vira selo, o outro importa', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _FakeRepo(
      plans: [
        ReadingPlan(
          id: 'p1',
          title: 'Bíblia em 1 ano',
          durationDays: 365,
          templateCode: 'biblia_1_ano',
          createdAt: DateTime(2026, 10, 14),
        ),
      ],
      templates: const [
        ReadingPlanTemplate(
          code: 'biblia_1_ano',
          title: 'Bíblia em 1 ano',
          durationDays: 365,
          category: 'complete_bible',
        ),
        ReadingPlanTemplate(
          code: 'nt_salmos_1_ano',
          title: 'Novo Testamento + Salmos em 1 ano',
          durationDays: 365,
          category: 'new_testament',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [readingPlansRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ManageReadingPlansScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Importar modelo'));
    await tester.pumpAndSettle();

    // StatusBadge escreve o rótulo em caixa alta.
    expect(find.text('IMPORTADO'), findsOneWidget);
    expect(find.text('Novo Testamento + Salmos em 1 ano'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Importar'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Importar'));
    await tester.pumpAndSettle();

    expect(repo.imported, ['nt_salmos_1_ano']);
    expect(
      find.text('Plano "Novo Testamento + Salmos em 1 ano" importado e ativo.'),
      findsOneWidget,
    );
    expect(find.byIcon(AppIcons.download), findsOneWidget);
  });
}
