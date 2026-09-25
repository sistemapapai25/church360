import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/core/design/app_icons.dart';
import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/core/widgets/glass_card.dart';
import 'package:church360_app/core/widgets/status_badge.dart';
import 'package:church360_app/features/bible/domain/models/bible_book.dart';
import 'package:church360_app/features/bible/presentation/providers/bible_provider.dart';
import 'package:church360_app/features/bible/presentation/screens/bible_books_screen.dart';
import 'package:church360_app/features/bible/presentation/screens/bible_chapters_screen.dart';
import 'package:church360_app/features/reading_plans/domain/models/reading_plan.dart';
import 'package:church360_app/features/reading_plans/presentation/providers/reading_plans_provider.dart';
import 'package:church360_app/features/reading_plans/presentation/screens/reading_plan_module_screen.dart';
import 'package:church360_app/features/reading_plans/presentation/screens/reading_plans_list_screen.dart';
import 'package:church360_app/features/members/presentation/providers/members_provider.dart';

BibleBook _book({
  required int id,
  required String name,
  required String testament,
}) => BibleBook(
  id: id,
  name: name,
  abbrev: name.substring(0, 3),
  testament: testament,
  orderNumber: id,
  chapters: 2,
);

ReadingPlan _plan() => ReadingPlan(
  id: 'plan-1',
  title: 'Evangelhos em 30 dias',
  description: 'Uma jornada pelos Evangelhos.',
  durationDays: 30,
  category: 'new_testament',
  modules: const [
    ReadingPlanModule(
      order: 1,
      title: 'Dia 1 — Mateus 1',
      reference: 'Mateus 1',
    ),
  ],
  createdAt: DateTime(2026, 1, 1),
);

Widget _host(Widget child, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(theme: AppTheme.lightTheme, home: child),
);

void main() {
  testWidgets('livros da Bíblia usam vidro e atalhos semânticos', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const BibleBooksScreen(), [
        oldTestamentBooksProvider.overrideWith(
          (ref) async => [_book(id: 1, name: 'Gênesis', testament: 'OT')],
        ),
        newTestamentBooksProvider.overrideWith(
          (ref) async => [_book(id: 40, name: 'Mateus', testament: 'NT')],
        ),
      ]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(GlassCardTrace), findsAtLeastNWidgets(1));
    expect(find.byIcon(AppIcons.book), findsAtLeastNWidgets(1));
    expect(find.text('Planos de Leitura'), findsOneWidget);
  });

  testWidgets('capítulos da Bíblia usam GlassCard e ação de leitura', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const BibleChaptersScreen(bookId: 1), [
        bibleBookByIdProvider(1).overrideWith(
          (ref) async => _book(id: 1, name: 'Gênesis', testament: 'OT'),
        ),
        verseCountsByBookProvider(
          1,
        ).overrideWith((ref) async => {1: 31, 2: 25}),
      ]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(GlassCard), findsAtLeastNWidgets(2));
    expect(find.text('Capítulo 1'), findsOneWidget);
    expect(find.byIcon(AppIcons.book), findsAtLeastNWidgets(1));
  });

  testWidgets('lista de planos usa vidro e badge de disponibilidade', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const ReadingPlansListScreen(), [
        activeReadingPlansProvider.overrideWith((ref) async => [_plan()]),
      ]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(GlassCard), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.text('DISPONÍVEL'), findsOneWidget);
    expect(find.byIcon(AppIcons.book), findsAtLeastNWidgets(1));
  });

  testWidgets('módulo do plano expõe estado e superfície de leitura', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const ReadingPlanModuleScreen(planId: 'plan-1', moduleDay: 1), [
        readingPlanByIdProvider('plan-1').overrideWith((ref) async => _plan()),
        currentMemberProvider.overrideWith((ref) async => null),
      ]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(GlassCard), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.text('DISPONÍVEL'), findsOneWidget);
    expect(find.text('Dia 1 — Mateus 1'), findsOneWidget);
  });
}
