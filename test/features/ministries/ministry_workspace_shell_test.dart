import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/ministries/domain/models/ministry.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:church360_app/features/ministries/shared/presentation/widgets/ministry_workspace_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ministryId = 'm1';

Ministry _ministry(String name) {
  final now = DateTime(2026, 9, 18);
  return Ministry(
    id: _ministryId,
    name: name,
    color: '#2563EB',
    isActive: true,
    createdAt: now,
    updatedAt: now,
    ministryType: MinistryType.batismo,
  );
}

Widget _host({
  String name = 'Batismo nas Aguas',
  List<MinistryWorkspaceStat> stats = const [],
  Brightness brightness = Brightness.light,
  double width = 800,
}) {
  return ProviderScope(
    overrides: [
      ministryByIdProvider(_ministryId).overrideWith((ref) async {
        return _ministry(name);
      }),
    ],
    child: MaterialApp(
      theme: brightness == Brightness.dark
          ? AppTheme.darkTheme
          : AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: MinistryWorkspaceShell(
          ministryId: _ministryId,
          fallbackTitle: 'Batismo',
          stats: stats,
          tabs: [
            MinistryWorkspaceTab(
              label: 'Equipe',
              count: '3',
              builder: (_) => const Text('corpo-equipe'),
            ),
            MinistryWorkspaceTab(
              label: 'Alunos',
              builder: (_) => const Text('corpo-alunos'),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('mostra as abas e o corpo da primeira', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.text('Equipe'), findsOneWidget);
    expect(find.text('Alunos'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('corpo-equipe'), findsOneWidget);
    expect(find.text('corpo-alunos'), findsNothing);
  });

  testWidgets('tocar numa aba troca o corpo', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alunos'));
    await tester.pumpAndSettle();

    expect(find.text('corpo-alunos'), findsOneWidget);
    expect(find.text('corpo-equipe'), findsNothing);
  });

  testWidgets('so monta a aba ativa', (tester) async {
    var alunosBuilds = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ministryByIdProvider(_ministryId)
              .overrideWith((ref) async => _ministry('Batismo nas Aguas')),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: MinistryWorkspaceShell(
            ministryId: _ministryId,
            fallbackTitle: 'Batismo',
            tabs: [
              MinistryWorkspaceTab(
                label: 'Equipe',
                builder: (_) => const Text('corpo-equipe'),
              ),
              MinistryWorkspaceTab(
                label: 'Alunos',
                builder: (_) {
                  alunosBuilds++;
                  return const Text('corpo-alunos');
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A aba que ninguem abriu nao pode ter sido construida: com sete abas,
    // montar todas dispararia o carregamento de dados de telas nao vistas.
    expect(alunosBuilds, 0);
  });

  testWidgets('destaca a ultima palavra do nome', (tester) async {
    await tester.pumpWidget(_host(name: 'Batismo nas Aguas'));
    await tester.pumpAndSettle();

    // O nome tambem aparece no AppBar, como Text simples. O titulo do corpo
    // e o unico que quebra o nome em spans.
    final rich = tester.widget<RichText>(
      find.byWidgetPredicate(
        (w) =>
            w is RichText &&
            w.text.toPlainText() == 'Batismo nas Aguas' &&
            (w.text as TextSpan).children != null,
      ),
    );
    final spans = (rich.text as TextSpan).children!;
    expect((spans.first as TextSpan).text, 'Batismo nas ');
    final tail = spans.last as TextSpan;
    expect(tail.text, 'Aguas');
    expect(tail.style!.fontStyle, FontStyle.italic);
  });

  testWidgets('nome de uma palavra so nao ganha destaque', (tester) async {
    await tester.pumpWidget(_host(name: 'Raizes'));
    await tester.pumpAndSettle();

    // Um unico Text simples, sem TextSpan de destaque.
    expect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == 'Raizes',
      ),
      findsWidgets,
    );
    final titulo = tester.widget<RichText>(
      find
          .byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText() == 'Raizes',
          )
          .last,
    );
    expect((titulo.text as TextSpan).children, isNull);
  });

  testWidgets('mostra os indicadores quando existem', (tester) async {
    await tester.pumpWidget(
      _host(
        stats: const [
          MinistryWorkspaceStat(
            label: 'na equipe',
            value: '12',
            icon: Icons.groups_outlined,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('12'), findsOneWidget);
    expect(find.text('na equipe'), findsOneWidget);
  });

  testWidgets('cabe em 360px sem estourar', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        width: 360,
        stats: const [
          MinistryWorkspaceStat(
            label: 'na equipe',
            value: '12',
            icon: Icons.groups_outlined,
          ),
          MinistryWorkspaceStat(
            label: 'turmas',
            value: '3',
            icon: Icons.school_outlined,
          ),
          MinistryWorkspaceStat(
            label: 'alunos',
            value: '41',
            icon: Icons.person_outline,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
