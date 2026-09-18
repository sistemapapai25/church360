import 'dart:async';
import 'dart:convert';

import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/ministries/batismo/domain/baptism_pdf_renderer.dart';
import 'package:church360_app/features/ministries/batismo/domain/baptism_report_data.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_student.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_turma.dart';
import 'package:church360_app/features/ministries/batismo/presentation/providers/baptism_providers.dart';
import 'package:church360_app/features/ministries/batismo/presentation/screens/tabs/batismo_relatorios_tab.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ministryId = 'm1';

BaptismStudent _student(
  String name, {
  String turmaId = 'turma-1',
  BaptismStudentStatus status = BaptismStudentStatus.ativo,
  DateTime? birthDate,
  String? phone,
  String? email,
}) {
  return BaptismStudent(
    id: 'id-$name',
    tenantId: 't1',
    turmaId: turmaId,
    fullName: name,
    phone: phone,
    email: email,
    birthDate: birthDate,
    status: status,
    source: BaptismStudentSource.manual,
    createdAt: DateTime(2026, 9, 18),
  );
}

BaptismTurma _turma(
  String id,
  String name, {
  DateTime? start,
  DateTime? end,
  BaptismTurmaStatus status = BaptismTurmaStatus.ativa,
}) {
  return BaptismTurma(
    id: id,
    tenantId: 't1',
    ministryId: _ministryId,
    name: name,
    startDate: start,
    endDate: end,
    status: status,
    createdAt: DateTime(2026, 9, 1),
  );
}

Widget _host({
  required List<BaptismStudent> students,
  required List<BaptismTurma> turmas,
}) {
  return ProviderScope(
    overrides: [
      baptismStudentsProvider(_ministryId).overrideWith((ref) async => students),
      baptismTurmasProvider(_ministryId).overrideWith((ref) async => turmas),
      // Sem este a aba tentaria falar com o Supabase no teste.
      ministryByIdProvider(_ministryId).overrideWith((ref) async => null),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Scaffold(body: BatismoRelatoriosTab(ministryId: _ministryId)),
    ),
  );
}

/// Os dois cards não cabem na tela padrão de teste (800x600), e a `ListView`
/// nem constrói o que fica fora da viewport.
Future<void> _pumpTab(WidgetTester tester, Widget host) async {
  await tester.binding.setSurfaceSize(const Size(900, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(host);
  await tester.pumpAndSettle();
}

void main() {
  group('BaptismStatusTally', () {
    test('conta cada situação e o total', () {
      final tally = BaptismStatusTally.of([
        _student('Ana'),
        _student('Bruno'),
        _student('Carla', status: BaptismStudentStatus.concluido),
        _student('Davi', status: BaptismStudentStatus.desistente),
      ]);

      expect(tally.ativo, 2);
      expect(tally.concluido, 1);
      expect(tally.desistente, 1);
      expect(tally.total, 4);
      expect(tally.forStatus(BaptismStudentStatus.concluido), 1);
    });

    test('lista vazia zera tudo', () {
      final tally = BaptismStatusTally.of(const []);
      expect(tally.total, 0);
      expect(tally.ativo, 0);
    });
  });

  group('BaptismTurmaReport', () {
    test('pega só os alunos da turma pedida e ordena por nome', () {
      final report = BaptismTurmaReport.build(
        turma: _turma('turma-1', 'Sexta 19h'),
        ministryName: 'Batismo nas Águas',
        allStudents: [
          _student('Carla'),
          _student('ana'),
          _student('Bruno'),
          _student('Zeca', turmaId: 'turma-2'),
        ],
      );

      expect(
        report.students.map((s) => s.fullName),
        ['ana', 'Bruno', 'Carla'],
      );
      expect(report.tally.total, 3);
      expect(report.isEmpty, isFalse);
    });

    test('turma sem aluno fica vazia, não estoura', () {
      final report = BaptismTurmaReport.build(
        turma: _turma('turma-9', 'Turma nova'),
        ministryName: 'Batismo nas Águas',
        allStudents: [_student('Ana')],
      );

      expect(report.students, isEmpty);
      expect(report.isEmpty, isTrue);
      expect(report.tally.total, 0);
    });
  });

  group('BaptismMinistryReport', () {
    test('agrupa por turma e mantém o total geral', () {
      final report = BaptismMinistryReport.build(
        ministryName: 'Batismo nas Águas',
        turmas: [
          _turma('turma-1', 'Sexta 19h', start: DateTime(2026, 8, 1)),
          _turma(
            'turma-2',
            'Turma de março',
            start: DateTime(2026, 3, 1),
            status: BaptismTurmaStatus.encerrada,
          ),
        ],
        allStudents: [
          _student('Ana'),
          _student('Bruno', status: BaptismStudentStatus.desistente),
          _student('Carla', turmaId: 'turma-2'),
          _student(
            'Davi',
            turmaId: 'turma-2',
            status: BaptismStudentStatus.concluido,
          ),
        ],
      );

      expect(report.turmaCount, 2);
      expect(report.activeTurmaCount, 1);
      expect(report.tally.total, 4);
      // Mais recente primeiro.
      expect(report.lines.first.turma.name, 'Sexta 19h');
      expect(report.lines.first.tally.ativo, 1);
      expect(report.lines.first.tally.desistente, 1);
      expect(report.lines.last.tally.concluido, 1);
      expect(report.orphanStudents, 0);
    });

    test('turma sem período vai para o fim da lista', () {
      final report = BaptismMinistryReport.build(
        ministryName: 'Batismo nas Águas',
        turmas: [
          _turma('sem-data', 'Sem janela'),
          _turma('com-data', 'Com janela', start: DateTime(2026, 5, 1)),
        ],
        allStudents: const [],
      );

      expect(report.lines.first.turma.name, 'Com janela');
      expect(report.lines.last.turma.name, 'Sem janela');
    });

    test('aluno de turma fora da lista é contado como órfão', () {
      // O total por turma somaria 1 e o total geral 2. Sem este número, a
      // diferença sumiria da folha sem explicação.
      final report = BaptismMinistryReport.build(
        ministryName: 'Batismo nas Águas',
        turmas: [_turma('turma-1', 'Sexta 19h')],
        allStudents: [
          _student('Ana'),
          _student('Fantasma', turmaId: 'turma-apagada'),
        ],
      );

      expect(report.tally.total, 2);
      expect(report.lines.single.tally.total, 1);
      expect(report.orphanStudents, 1);
    });
  });

  group('formatação', () {
    test('data nula vira travessão', () {
      expect(formatReportDate(null), '—');
      expect(formatReportDate(DateTime(2026, 9, 5)), '05/09/2026');
    });

    test('período usa as duas pontas quando existem', () {
      expect(
        formatTurmaPeriod(
          _turma(
            't',
            'x',
            start: DateTime(2026, 8, 1),
            end: DateTime(2026, 10, 25),
          ),
        ),
        '01/08/2026 a 25/10/2026',
      );
      expect(formatTurmaPeriod(_turma('t', 'x')), 'Sem período');
      expect(
        formatTurmaPeriod(_turma('t', 'x', start: DateTime(2026, 8, 1))),
        'A partir de 01/08/2026',
      );
    });
  });

  group('PDF', () {
    // O cabeçalho de um PDF válido. Sem isto, um erro de geração viraria
    // "arquivo de 0 byte" na mão de quem for imprimir.
    void expectPdf(List<int> bytes) {
      expect(bytes.length, greaterThan(500));
      expect(utf8.decode(bytes.take(4).toList()), '%PDF');
    }

    test('relatório da turma gera um PDF', () async {
      final report = BaptismTurmaReport.build(
        turma: _turma(
          'turma-1',
          'Sexta 19h',
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 10, 25),
        ),
        ministryName: 'Batismo nas Águas',
        allStudents: [
          _student(
            'Ana Paula',
            birthDate: DateTime(2010, 4, 2),
            phone: '(11) 99999-0000',
            email: 'ana@exemplo.com',
          ),
          _student('Bruno', status: BaptismStudentStatus.concluido),
        ],
      );

      final bytes = await buildBaptismTurmaPdf(
        report,
        generatedAt: DateTime(2026, 9, 18, 14, 30),
      );
      expectPdf(bytes);
    });

    test('turma sem aluno gera PDF com estado vazio, não erro', () async {
      final report = BaptismTurmaReport.build(
        turma: _turma('turma-vazia', 'Turma nova'),
        ministryName: 'Batismo nas Águas',
        allStudents: const [],
      );

      final bytes = await buildBaptismTurmaPdf(
        report,
        generatedAt: DateTime(2026, 9, 18, 14, 30),
      );
      expectPdf(bytes);
    });

    test('resumo do ministério gera um PDF, mesmo sem turma nenhuma',
        () async {
      final comTurmas = BaptismMinistryReport.build(
        ministryName: 'Batismo nas Águas',
        turmas: [_turma('turma-1', 'Sexta 19h', start: DateTime(2026, 8, 1))],
        allStudents: [_student('Ana')],
      );
      expectPdf(
        await buildBaptismMinistryPdf(
          comTurmas,
          generatedAt: DateTime(2026, 9, 18, 14, 30),
        ),
      );

      final vazio = BaptismMinistryReport.build(
        ministryName: 'Batismo nas Águas',
        turmas: const [],
        allStudents: const [],
      );
      expectPdf(
        await buildBaptismMinistryPdf(
          vazio,
          generatedAt: DateTime(2026, 9, 18, 14, 30),
        ),
      );
    });
  });

  group('pdfSafeText', () {
    test('troca o que a fonte do PDF nao desenha', () {
      expect(pdfSafeText('a \u2014 b'), 'a - b');
      expect(
        pdfSafeText('\u201caspas\u201d e \u2018curvas\u2019'),
        '"aspas" e \'curvas\'',
      );
      expect(pdfSafeText('etc\u2026'), 'etc...');
      expect(pdfSafeText('a \u2022 b'), 'a \u00b7 b');
    });

    test('preserva o que a fonte desenha, inclusive acento', () {
      expect(
        pdfSafeText('Situa\u00e7\u00e3o da turma'),
        'Situa\u00e7\u00e3o da turma',
      );
      expect(pdfSafeText('Batismo nas \u00c1guas'), 'Batismo nas \u00c1guas');
    });

    test('o que nao tem equivalente vira ?, e nao um vao', () {
      // Nome colado do WhatsApp com emoji: o pacote nao avisa o usuario,
      // so deixa o buraco no papel.
      expect(pdfSafeText('Ana \u{1F64F}'), 'Ana ?');
      expect(pdfSafeText('\u4e2d\u6587'), '??');
    });
  });

  group('PDF nao deixa vao na folha', () {
    // O aviso no console e o unico lugar onde um caractere sem desenho
    // aparece: nada estoura, o PDF sai com um vao e so quem imprime
    // descobre. Este grupo e o que impede o proximo travessao de passar.
    Future<List<String>> fontWarnings(Future<void> Function() body) async {
      final logs = <String>[];
      await runZoned(
        body,
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => logs.add(line),
        ),
      );
      return logs.where((l) => l.contains('Unable to find a font')).toList();
    }

    test('nem com nome cheio de caractere colado de fora', () async {
      final report = BaptismTurmaReport.build(
        turma: _turma(
          'turma-1',
          'Turma \u2014 sexta \u201cespecial\u201d',
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 10, 25),
        ),
        ministryName: 'Batismo nas \u00c1guas',
        allStudents: [
          _student('Ana \u{1F64F} Concei\u00e7\u00e3o'),
          _student('Jo\u00e3o \u2013 filho', email: 'joao\u2026@exemplo.com'),
          // Sem telefone nem nascimento: e o caminho que usa o travessao.
          _student('Maria'),
        ],
      );

      final avisos = await fontWarnings(() async {
        await buildBaptismTurmaPdf(
          report,
          generatedAt: DateTime(2026, 9, 18, 14, 30),
        );
      });

      expect(avisos, isEmpty, reason: avisos.join('\n'));
    });

    test('nem no resumo do ministerio', () async {
      final report = BaptismMinistryReport.build(
        ministryName: 'Batismo nas \u00c1guas',
        turmas: [
          _turma('t1', 'Turma \u2014 A', start: DateTime(2026, 8, 1)),
          _turma('t2', 'Sem janela'),
        ],
        allStudents: [
          _student('Ana'),
          _student('Fantasma', turmaId: 'sumiu'),
        ],
      );

      final avisos = await fontWarnings(() async {
        await buildBaptismMinistryPdf(
          report,
          generatedAt: DateTime(2026, 9, 18, 14, 30),
        );
      });

      expect(avisos, isEmpty, reason: avisos.join('\n'));
    });
  });

  group('aba Relatórios', () {
    testWidgets('mostra os dois relatórios com os números da turma',
        (tester) async {
      await _pumpTab(
        tester,
        _host(
          turmas: [
            _turma(
              'turma-1',
              'Sexta 19h',
              start: DateTime(2026, 8, 1),
              end: DateTime(2026, 10, 25),
            ),
          ],
          students: [
            _student('Ana'),
            _student('Bruno', status: BaptismStudentStatus.concluido),
          ],
        ),
      );

      expect(find.text('Relatório da turma'), findsOneWidget);
      expect(find.text('Resumo do ministério'), findsOneWidget);
      expect(find.text('Sexta 19h'), findsOneWidget);
      expect(find.text('01/08/2026 a 25/10/2026 · Ativa'), findsOneWidget);
      // A contagem aparece nos dois cards: turma e ministério.
      expect(find.text('2 alunos · 1 Ativo · 1 Concluído'), findsNWidgets(2));
    });

    testWidgets('sem turma, explica o que fazer em vez de oferecer o PDF',
        (tester) async {
      await _pumpTab(tester, _host(turmas: const [], students: const []));

      expect(
        find.textContaining('Crie a primeira turma'),
        findsOneWidget,
      );
      expect(find.text('Nenhuma turma cadastrada'), findsOneWidget);
      expect(find.text('Nenhum aluno cadastrado ainda'), findsOneWidget);

      // O botão do relatório de turma existe, mas desativado — sumir com o
      // card seria pior: a pessoa não saberia que o relatório existe.
      //
      // `byType` não serve aqui: `FilledButton.icon` devolve uma subclasse
      // (`_FilledButtonWithIcon`) e `byType` casa por tipo exato.
      final botoes = tester.widgetList<FilledButton>(
        find.byWidgetPredicate((w) => w is FilledButton),
      );
      expect(botoes.first.onPressed, isNull);
      expect(botoes.last.onPressed, isNotNull);
    });

    testWidgets('com mais de uma turma, dá para trocar a turma do relatório',
        (tester) async {
      await _pumpTab(
        tester,
        _host(
          turmas: [
            _turma('turma-1', 'Sexta 19h', start: DateTime(2026, 8, 1)),
            _turma('turma-2', 'Turma de março', start: DateTime(2026, 3, 1)),
          ],
          students: [
            _student('Ana'),
            _student('Bruno', turmaId: 'turma-2'),
            _student('Carla', turmaId: 'turma-2'),
          ],
        ),
      );

      // A primeira da lista ordenada é a mais recente.
      expect(find.text('Sexta 19h'), findsOneWidget);
      expect(find.text('1 aluno · 1 Ativo'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turma de março').last);
      await tester.pumpAndSettle();

      expect(find.text('Turma de março'), findsOneWidget);
      expect(find.text('2 alunos · 2 Ativo'), findsOneWidget);
    });
  });
}
