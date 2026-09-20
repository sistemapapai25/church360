import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_student.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_turma.dart';
import 'package:church360_app/features/ministries/batismo/presentation/providers/baptism_providers.dart';
import 'package:church360_app/features/ministries/batismo/presentation/screens/tabs/batismo_alunos_tab.dart';
import 'package:church360_app/features/ministries/batismo/presentation/widgets/student_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ministryId = 'm1';

BaptismStudent _student(
  String name, {
  String turmaId = 'turma-1',
  String? turmaName = 'Sexta 19h',
  String? phone,
  DateTime? birthDate,
  BaptismStudentStatus status = BaptismStudentStatus.ativo,
  BaptismStudentSource source = BaptismStudentSource.manual,
}) {
  return BaptismStudent(
    id: 'id-$name',
    tenantId: 't1',
    turmaId: turmaId,
    fullName: name,
    phone: phone,
    birthDate: birthDate,
    status: status,
    source: source,
    createdAt: DateTime(2026, 9, 18),
    turmaName: turmaName,
  );
}

BaptismTurma _turma(String id, String name) {
  return BaptismTurma(
    id: id,
    tenantId: 't1',
    ministryId: _ministryId,
    name: name,
    status: BaptismTurmaStatus.ativa,
    createdAt: DateTime(2026, 9, 18),
  );
}

Widget _host({
  required List<BaptismStudent> students,
  List<BaptismTurma> turmas = const [],
  bool canCreate = true,
  bool canEdit = true,
  bool canDelete = true,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) {
  bool valueFor(BaptismWriteAction action) => switch (action) {
    BaptismWriteAction.create => canCreate,
    BaptismWriteAction.edit => canEdit,
    BaptismWriteAction.delete => canDelete,
  };

  return ProviderScope(
    overrides: [
      baptismStudentsProvider(
        _ministryId,
      ).overrideWith((ref) async => students),
      baptismTurmasProvider(_ministryId).overrideWith((ref) async => turmas),
      baptismChecklistTallyProvider(
        _ministryId,
      ).overrideWith((ref) async => {}),
      for (final action in BaptismWriteAction.values)
        baptismCanWriteProvider((
          ministryId: _ministryId,
          action: action,
        )).overrideWith((ref) async => valueFor(action)),
    ],
    child: MaterialApp(
      theme: brightness == Brightness.dark
          ? AppTheme.darkTheme
          : AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const Scaffold(body: BatismoAlunosTab(ministryId: _ministryId)),
    ),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    for (final width in [360.0, 1280.0]) {
      testWidgets('grade responsiva em $width / $brightness', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _host(
            brightness: brightness,
            students: [
              _student(
                'Ana Carolina de Souza Albuquerque',
                source: BaptismStudentSource.publica,
              ),
              _student('Bruno Lima', status: BaptismStudentStatus.concluido),
              _student('Carla Santos', status: BaptismStudentStatus.desistente),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final first = tester.getTopLeft(find.byType(StudentCard).at(0));
        final second = tester.getTopLeft(find.byType(StudentCard).at(1));
        if (width > 900) {
          expect(first.dy, second.dy);
          expect(second.dx, greaterThan(first.dx));
        } else {
          expect(first.dx, second.dx);
          expect(second.dy, greaterThan(first.dy));
        }
      });
    }
  }

  testWidgets('nome e turma longos cabem com texto ampliado no celular', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        textScale: 2,
        students: [
          _student(
            'Ana Carolina de Souza Albuquerque',
            turmaName:
                'Turma de preparação para o batismo de domingo pela manhã',
            source: BaptismStudentSource.publica,
            status: BaptismStudentStatus.concluido,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('CONCLUÍDO'), findsOneWidget);
  });

  testWidgets('abre formulário e cancela sem alterar a lista', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        students: [_student('Ana Souza')],
        turmas: [_turma('turma-1', 'Sexta 19h')],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo aluno'));
    await tester.pumpAndSettle();
    expect(find.text('Nome completo *'), findsOneWidget);
    await tester.ensureVisible(find.text('Cancelar'));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Nome completo *'), findsNothing);
    expect(find.text('Ana Souza'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lista os alunos e conta o total', (tester) async {
    await tester.pumpWidget(
      _host(
        students: [_student('Ana Souza'), _student('Bruno Lima')],
        turmas: [_turma('turma-1', 'Sexta 19h')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('Bruno Lima'), findsOneWidget);
    expect(find.text('2 alunos'), findsOneWidget);
  });

  testWidgets('busca por nome recorta a lista e muda a contagem', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        students: [_student('Ana Souza'), _student('Bruno Lima')],
        turmas: [_turma('turma-1', 'Sexta 19h')],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'bruno');
    await tester.pumpAndSettle();

    expect(find.text('Ana Souza'), findsNothing);
    expect(find.text('Bruno Lima'), findsOneWidget);
    expect(find.text('1 de 2 alunos'), findsOneWidget);
  });

  testWidgets('busca por telefone ignora a formatacao do numero', (
    tester,
  ) async {
    // O telefone esta gravado como "(11) 91234-5678"; quem digita so os
    // digitos tem que achar assim mesmo.
    await tester.pumpWidget(
      _host(
        students: [
          _student('Ana Souza', phone: '(11) 91234-5678'),
          _student('Bruno Lima', phone: '(21) 98888-0000'),
        ],
        turmas: [_turma('turma-1', 'Sexta 19h')],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '11912345678');
    await tester.pumpAndSettle();

    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('Bruno Lima'), findsNothing);
  });

  testWidgets('sem permissao de criar, o botao Novo aluno nao aparece', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        students: [_student('Ana Souza')],
        turmas: [_turma('turma-1', 'Sexta 19h')],
        canCreate: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Novo aluno'), findsNothing);
    // A porta de leitura continua aberta: quem so enxerga a lista segue
    // vendo a lista.
    expect(find.text('Ana Souza'), findsOneWidget);
  });

  testWidgets('sem permissao de editar nem excluir, o menu do card some', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        students: [_student('Ana Souza')],
        turmas: [_turma('turma-1', 'Sexta 19h')],
        canEdit: false,
        canDelete: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('sem turma cadastrada, o vazio manda criar a turma primeiro', (
    tester,
  ) async {
    await tester.pumpWidget(_host(students: const []));
    await tester.pumpAndSettle();

    expect(
      find.text('Crie a primeira turma para começar a cadastrar alunos.'),
      findsOneWidget,
    );
  });

  testWidgets('a lista cabe em 360px sem overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        students: [
          _student(
            'Ana Carolina de Souza Albuquerque',
            phone: '(11) 91234-5678',
            source: BaptismStudentSource.publica,
            birthDate: DateTime(1998, 4, 12),
          ),
        ],
        turmas: [_turma('turma-1', 'Sexta 19h')],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(StudentCard), findsOneWidget);
  });

  testWidgets('com permissao de edicao a barra oferece o link', (tester) async {
    await tester.pumpWidget(
      _host(students: const [], turmas: [_turma('turma-1', 'Sexta 19h')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Link de inscrição'), findsOneWidget);
  });

  testWidgets('sem permissao de edicao o link nao aparece', (tester) async {
    await tester.pumpWidget(
      _host(
        students: const [],
        turmas: [_turma('turma-1', 'Sexta 19h')],
        canEdit: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Link de inscrição'), findsNothing);
  });
}
