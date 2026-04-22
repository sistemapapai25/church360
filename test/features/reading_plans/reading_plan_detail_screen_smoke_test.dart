import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/features/members/presentation/providers/members_provider.dart';
import 'package:church360_app/features/reading_plans/data/reading_plans_repository.dart';
import 'package:church360_app/features/reading_plans/domain/models/reading_plan.dart';
import 'package:church360_app/features/reading_plans/presentation/providers/reading_plans_provider.dart';
import 'package:church360_app/features/reading_plans/presentation/screens/reading_plan_detail_screen.dart';

class _FakeReadingPlansRepository extends ReadingPlansRepository {
  final ReadingPlan plan;

  _FakeReadingPlansRepository(this.plan)
      : super(SupabaseClient('http://localhost', 'test-key'));

  @override
  Future<ReadingPlan?> getPlanById(String id) async {
    return plan;
  }
}

void main() {
  testWidgets('ReadingPlanDetailScreen renders action button', (tester) async {
    final plan = ReadingPlan(
      id: 'plan-1',
      title: 'Pentateuco em 60 Dias',
      durationDays: 60,
      status: 'active',
      category: 'old_testament',
      createdAt: DateTime(2026, 1, 1),
    );

    final repo = _FakeReadingPlansRepository(plan);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readingPlansRepositoryProvider.overrideWithValue(repo),
          currentMemberProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          home: ReadingPlanDetailScreen(planId: 'plan-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('INICIAR PLANO'), findsOneWidget);
  });
}

