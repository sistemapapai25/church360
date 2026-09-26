import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/courses/presentation/turma/adapters/batismo_turma_adapter.dart';
import 'package:church360_app/features/courses/presentation/turma/adapters/generica_turma_adapter.dart';
import 'package:church360_app/features/courses/presentation/turma/adapters/turma_surfaces.dart';
import 'package:church360_app/features/courses/presentation/turma/tabs/turma_aulas_tab.dart';
import 'package:church360_app/features/courses/presentation/turma/tabs/turma_materiais_tab.dart';
import 'package:church360_app/features/courses/presentation/turma/turma_access.dart';
import 'package:church360_app/features/courses/presentation/turma/turma_origin.dart';
import 'package:church360_app/features/members/domain/models/member_directory_entry.dart';
import 'package:church360_app/features/members/presentation/providers/members_provider.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_attendance.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_my_meeting.dart';
import 'package:church360_app/features/ministries/batismo/presentation/providers/baptism_providers.dart';
import 'package:church360_app/features/ministries/batismo/presentation/screens/tabs/batismo_alunos_tab.dart';
import 'package:church360_app/features/ministries/batismo/presentation/screens/tabs/batismo_presenca_tab.dart';
import 'package:church360_app/features/study_groups/data/study_group_repository.dart';
import 'package:church360_app/features/study_groups/domain/models/study_group.dart';
import 'package:church360_app/features/study_groups/presentation/providers/study_group_provider.dart';
import 'package:church360_app/features/support_materials/data/support_materials_repository.dart';
import 'package:church360_app/features/support_materials/domain/models/support_material.dart';
import 'package:church360_app/features/support_materials/domain/models/support_material_link.dart';
import 'package:church360_app/features/support_materials/presentation/providers/support_materials_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Etapa 5.2 do ROADMAP-FORMACAO: as abas da tela da turma. Repositórios
// falsos por baixo dos providers de verdade — o que se testa é o que a aba
// pede ao banco e o que ela mostra.

const _sgId = 'sg-1';
final _t0 = DateTime(2026, 9, 1);

StudyLesson _lesson(int n, LessonStatus status, {String? id}) => StudyLesson(
  id: id ?? 'l$n',
  studyGroupId: _sgId,
  lessonNumber: n,
  title: 'Tema $n',
  status: status,
  createdAt: _t0,
  updatedAt: _t0,
);

StudyParticipant _participant(
  String userId, {
  ParticipantRole role = ParticipantRole.participant,
}) => StudyParticipant(
  id: 'sp-$userId',
  studyGroupId: _sgId,
  userId: userId,
  role: role,
  isActive: true,
  joinedAt: _t0,
  createdAt: _t0,
  updatedAt: _t0,
);

StudyAttendance _att(String lessonId, String userId, AttendanceStatus s) =>
    StudyAttendance(
      id: 'a-$lessonId-$userId',
      studyLessonId: lessonId,
      userId: userId,
      status: s,
      createdAt: _t0,
      updatedAt: _t0,
    );

SupportMaterial _material(String id, {String? createdBy}) => SupportMaterial(
  id: id,
  title: 'Material $id',
  materialType: SupportMaterialType.pdf,
  createdBy: createdBy,
  createdAt: _t0,
  updatedAt: _t0,
);

class _FakeStudyRepo implements StudyGroupRepository {
  final List<StudyLesson> lessons;
  final List<StudyParticipant> participants;
  final Map<String, List<StudyAttendance>> attendance;
  final List<StudyAttendance> mine;

  final created = <({String groupId, int number, String title})>[];
  final statusUpdates = <({String id, LessonStatus? status})>[];
  final marked = <({String lessonId, String userId, AttendanceStatus s})>[];
  final updatedAttendance = <({String id, AttendanceStatus? s})>[];

  _FakeStudyRepo({
    this.lessons = const [],
    this.participants = const [],
    this.attendance = const {},
    this.mine = const [],
  });

  @override
  Future<List<StudyLesson>> getGroupLessons(String groupId) async => lessons;

  @override
  Future<List<StudyLesson>> getPublishedLessons(String groupId) async => [
    for (final l in lessons)
      if (l.status == LessonStatus.published) l,
  ];

  @override
  Future<StudyLesson> createLesson({
    required String studyGroupId,
    required int lessonNumber,
    required String title,
    String? description,
    String? bibleReferences,
    String? content,
    List<String>? discussionQuestions,
    LessonStatus status = LessonStatus.draft,
    DateTime? scheduledDate,
    String? videoUrl,
    String? audioUrl,
    String? pdfUrl,
  }) async {
    created.add((groupId: studyGroupId, number: lessonNumber, title: title));
    return _lesson(lessonNumber, status);
  }

  @override
  Future<StudyLesson> updateLesson(
    String id, {
    int? lessonNumber,
    String? title,
    String? description,
    String? bibleReferences,
    String? content,
    List<String>? discussionQuestions,
    LessonStatus? status,
    DateTime? scheduledDate,
    String? videoUrl,
    String? audioUrl,
    String? pdfUrl,
  }) async {
    statusUpdates.add((id: id, status: status));
    return lessons.firstWhere((l) => l.id == id);
  }

  @override
  Future<List<StudyParticipant>> getGroupParticipants(String groupId) async =>
      participants;

  @override
  Future<List<StudyAttendance>> getLessonAttendance(String lessonId) async =>
      attendance[lessonId] ?? const [];

  @override
  Future<List<StudyAttendance>> getMyAttendanceForLessons(
    List<String> lessonIds,
  ) async => [
    for (final a in mine)
      if (lessonIds.contains(a.studyLessonId)) a,
  ];

  @override
  Future<StudyAttendance> markAttendance({
    required String lessonId,
    required String userId,
    required AttendanceStatus status,
    String? justification,
    String? notes,
  }) async {
    marked.add((lessonId: lessonId, userId: userId, s: status));
    return _att(lessonId, userId, status);
  }

  @override
  Future<StudyAttendance> updateAttendance(
    String attendanceId, {
    AttendanceStatus? status,
    String? justification,
    String? notes,
  }) async {
    updatedAttendance.add((id: attendanceId, s: status));
    return _att('x', 'x', status ?? AttendanceStatus.present);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMaterialsRepo implements SupportMaterialsRepository {
  final List<SupportMaterial> all;
  final List<SupportMaterial> linked;
  final links = <Map<String, dynamic>>[];

  _FakeMaterialsRepo({this.all = const [], this.linked = const []});

  @override
  Future<List<SupportMaterial>> getAllMaterials() async => all;

  @override
  Future<List<SupportMaterial>> getMaterialsByEntity(
    MaterialLinkType linkType,
    String entityId,
  ) async => linked;

  @override
  Future<SupportMaterialLink> createLink(Map<String, dynamic> data) async {
    links.add(data);
    return SupportMaterialLink(
      id: 'link',
      materialId: data['material_id'] as String,
      linkType: MaterialLinkType.studyGroup,
      linkedEntityId: data['linked_entity_id'] as String,
      createdAt: _t0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _leader = TurmaAccess(role: TurmaRole.leadership, canWriteLessons: true);

Widget _host(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      memberDirectoryProvider.overrideWith(
        (ref) async => [
          MemberDirectoryEntry(id: 'u1', fullName: 'Ana'),
          MemberDirectoryEntry(id: 'u2', fullName: 'Bruno'),
        ],
      ),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget host) async {
  await tester.binding.setSurfaceSize(const Size(900, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(host);
  await tester.pumpAndSettle();
}

void main() {
  group('Aulas', () {
    final lessons = [
      _lesson(1, LessonStatus.published),
      _lesson(2, LessonStatus.draft),
      _lesson(3, LessonStatus.archived),
    ];

    testWidgets('aluno só vê as publicadas, sem status nem ações', (
      tester,
    ) async {
      final repo = _FakeStudyRepo(lessons: lessons);
      await _pump(
        tester,
        _host(
          const TurmaAulasTab(studyGroupId: _sgId, access: TurmaAccess.student),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      expect(find.text('Aula 1 · Tema 1'), findsOneWidget);
      expect(find.text('Aula 2 · Tema 2'), findsNothing);
      expect(find.text('Aula 3 · Tema 3'), findsNothing);
      expect(find.text('Nova aula'), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('liderança vê todas com status', (tester) async {
      final repo = _FakeStudyRepo(lessons: lessons);
      await _pump(
        tester,
        _host(
          const TurmaAulasTab(studyGroupId: _sgId, access: _leader),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      expect(find.text('Aula 2 · Tema 2'), findsOneWidget);
      expect(find.text('RASCUNHO'), findsOneWidget);
      expect(find.text('ARQUIVADA'), findsOneWidget);
    });

    testWidgets('liderança sem escrita não cria nem mexe', (tester) async {
      final repo = _FakeStudyRepo(lessons: lessons);
      await _pump(
        tester,
        _host(
          const TurmaAulasTab(
            studyGroupId: _sgId,
            access: TurmaAccess(role: TurmaRole.leadership),
          ),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      expect(find.text('Nova aula'), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('não existe Excluir; rascunho oferece Publicar', (
      tester,
    ) async {
      final repo = _FakeStudyRepo(lessons: lessons);
      await _pump(
        tester,
        _host(
          const TurmaAulasTab(studyGroupId: _sgId, access: _leader),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>).at(1));
      await tester.pumpAndSettle();
      expect(find.text('Excluir'), findsNothing);
      await tester.tap(find.text('Publicar'));
      await tester.pumpAndSettle();

      expect(repo.statusUpdates.single.id, 'l2');
      expect(repo.statusUpdates.single.status, LessonStatus.published);
    });

    // Etapa 5.3: só a origem que registra presença pela aula (Batismo)
    // entrega a ação; a turma genérica não ganha o item.
    testWidgets('Registrar presença só quando a origem oferece', (
      tester,
    ) async {
      final repo = _FakeStudyRepo(lessons: lessons);
      final opened = <String>[];
      await _pump(
        tester,
        _host(
          TurmaAulasTab(
            studyGroupId: _sgId,
            access: _leader,
            lessonAttendance: (context, lesson) async => opened.add(lesson.id),
          ),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar presença'));
      await tester.pumpAndSettle();
      expect(opened, ['l1']);
    });

    testWidgets('sem ação da origem, sem Registrar presença', (tester) async {
      final repo = _FakeStudyRepo(lessons: lessons);
      await _pump(
        tester,
        _host(
          const TurmaAulasTab(studyGroupId: _sgId, access: _leader),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      expect(find.text('Registrar presença'), findsNothing);
    });

    test('ciclo: Publicar → Arquivar → Restaurar (volta a rascunho)', () {
      expect(lessonNextStep(LessonStatus.draft).to, LessonStatus.published);
      expect(lessonNextStep(LessonStatus.published).to, LessonStatus.archived);
      expect(lessonNextStep(LessonStatus.archived).label, 'Restaurar');
      expect(lessonNextStep(LessonStatus.archived).to, LessonStatus.draft);
    });

    testWidgets('nova aula grava o study_group_id e o próximo número', (
      tester,
    ) async {
      final repo = _FakeStudyRepo(lessons: lessons);
      await _pump(
        tester,
        _host(
          const TurmaAulasTab(studyGroupId: _sgId, access: _leader),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      await tester.tap(find.text('Nova aula'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Título da aula *'),
        'Arrependimento',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(repo.created.single.groupId, _sgId);
      expect(repo.created.single.number, 4);
      expect(repo.created.single.title, 'Arrependimento');
    });
  });

  group('Materiais', () {
    ({MaterialLinkType linkType, String entityId}) key = (
      linkType: MaterialLinkType.studyGroup,
      entityId: _sgId,
    );

    List<Override> overrides(
      _FakeMaterialsRepo repo, {
      String? memberId = 'me',
      bool canEditAny = false,
    }) => [
      supportMaterialsRepositoryProvider.overrideWithValue(repo),
      turmaMaterialRightsProvider.overrideWith(
        (ref) async =>
            TurmaMaterialRights(memberId: memberId, canEditAny: canEditAny),
      ),
    ];

    testWidgets('aluno lista e não vincula; ninguém tem upload', (
      tester,
    ) async {
      final repo = _FakeMaterialsRepo(linked: [_material('m1')]);
      await _pump(
        tester,
        _host(
          const TurmaMateriaisTab(
            studyGroupId: _sgId,
            access: TurmaAccess.student,
          ),
          overrides: overrides(repo),
        ),
      );

      expect(find.text('Material m1'), findsOneWidget);
      expect(find.text('Vincular material'), findsNothing);
      expect(find.textContaining('Enviar'), findsNothing);
      expect(find.textContaining('Upload'), findsNothing);
      expect(key.entityId, _sgId);
    });

    testWidgets('seletor: autor vê o seu, não o dos outros', (tester) async {
      final repo = _FakeMaterialsRepo(
        all: [
          _material('meu', createdBy: 'me'),
          _material('alheio', createdBy: 'outro'),
        ],
      );
      await _pump(
        tester,
        _host(
          const TurmaMateriaisTab(studyGroupId: _sgId, access: _leader),
          overrides: overrides(repo),
        ),
      );

      await tester.tap(find.text('Vincular material'));
      await tester.pumpAndSettle();
      expect(find.text('Material meu'), findsOneWidget);
      expect(find.text('Material alheio'), findsNothing);

      await tester.tap(find.text('Material meu'));
      await tester.pumpAndSettle();
      expect(repo.links.single['material_id'], 'meu');
      expect(repo.links.single['link_type'], 'study_group');
      expect(repo.links.single['linked_entity_id'], _sgId);
    });

    testWidgets('seletor: support_materials.edit vê todos', (tester) async {
      final repo = _FakeMaterialsRepo(
        all: [
          _material('meu', createdBy: 'me'),
          _material('alheio', createdBy: 'outro'),
        ],
      );
      await _pump(
        tester,
        _host(
          const TurmaMateriaisTab(studyGroupId: _sgId, access: _leader),
          overrides: overrides(repo, canEditAny: true),
        ),
      );

      await tester.tap(find.text('Vincular material'));
      await tester.pumpAndSettle();
      expect(find.text('Material alheio'), findsOneWidget);
    });
  });

  group('Minha frequência — Batismo', () {
    BaptismMyMeeting m(String id, BaptismAttendanceStatus? s) =>
        BaptismMyMeeting(
          meetingId: id,
          meetingDate: DateTime(2026, 9, 6),
          title: 'Encontro $id',
          status: s,
        );

    test('justificada conta como falta; sem marca fica fora', () {
      final f = BatismoMyFrequency.of([
        m('1', BaptismAttendanceStatus.presente),
        m('2', BaptismAttendanceStatus.justificado),
        m('3', null),
      ]);
      expect(f.marked, 2);
      expect(f.rateLabel, '50%');
      expect(f.justified, 1);
      expect(f.unmarked, 1);
    });

    test('nada marcado é "—", não 0%', () {
      expect(BatismoMyFrequency.of([m('1', null)]).rateLabel, '—');
    });

    testWidgets('mostra a taxa pela RPC da turma', (tester) async {
      await _pump(
        tester,
        _host(
          const BatismoMinhaFrequencia(baptismTurmaId: 'bt-1'),
          overrides: [
            myBaptismAttendanceProvider('bt-1').overrideWith(
              (ref) async => [
                m('1', BaptismAttendanceStatus.presente),
                m('2', BaptismAttendanceStatus.ausente),
                m('3', null),
              ],
            ),
          ],
        ),
      );

      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('batismo-minha-frequencia-taxa')),
            )
            .data,
        '50%',
      );
      expect(find.text('—'), findsOneWidget);
    });
  });

  group('Minha frequência — genérica', () {
    testWidgets('contagem crua, "—" sem linha, sem percentual', (tester) async {
      final repo = _FakeStudyRepo(
        lessons: [
          _lesson(1, LessonStatus.published),
          _lesson(2, LessonStatus.published),
          _lesson(3, LessonStatus.published),
        ],
        mine: [
          _att('l1', 'auth-me', AttendanceStatus.present),
          _att('l2', 'auth-me', AttendanceStatus.justified),
        ],
      );
      await _pump(
        tester,
        _host(
          const GenericaMinhaFrequencia(studyGroupId: _sgId),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      expect(
        find.text('1 presentes · 0 faltas · 1 justificadas'),
        findsOneWidget,
      );
      expect(find.text('—'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });
  });

  group('Presença — genérica', () {
    testWidgets('liderança só por courses.* não faz nem vê a chamada', (
      tester,
    ) async {
      final repo = _FakeStudyRepo(lessons: [_lesson(1, LessonStatus.draft)]);
      await _pump(
        tester,
        _host(
          const GenericaPresenca(studyGroupId: _sgId, access: _leader),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      expect(
        find.text('A chamada desta turma é feita pelo líder do grupo.'),
        findsOneWidget,
      );
      expect(find.text('Aula 1 · Tema 1'), findsNothing);
    });

    testWidgets('líder marca e salva: insere o novo, atualiza o existente', (
      tester,
    ) async {
      final repo = _FakeStudyRepo(
        lessons: [_lesson(1, LessonStatus.published)],
        participants: [
          _participant('u1'),
          _participant('u2'),
          _participant('lider', role: ParticipantRole.leader),
        ],
        attendance: {
          'l1': [_att('l1', 'u2', AttendanceStatus.absent)],
        },
      );
      await _pump(
        tester,
        _host(
          const GenericaPresenca(
            studyGroupId: _sgId,
            access: TurmaAccess(role: TurmaRole.leadership, leadsGroup: true),
          ),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      expect(find.text('0 presentes · 1 faltas · 0 justificadas'), findsOne);
      await tester.tap(find.text('Aula 1 · Tema 1'));
      await tester.pumpAndSettle();

      // Líder não entra na chamada.
      expect(find.byKey(const ValueKey('roll-lider-present')), findsNothing);
      expect(find.text('Ana'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('roll-u1-present')));
      await tester.tap(find.byKey(const ValueKey('roll-u2-justified')));
      await tester.pump();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(repo.marked.single.lessonId, 'l1');
      expect(repo.marked.single.userId, 'u1');
      expect(repo.marked.single.s, AttendanceStatus.present);
      expect(repo.updatedAttendance.single.id, 'a-l1-u2');
      expect(repo.updatedAttendance.single.s, AttendanceStatus.justified);
    });

    testWidgets('elevado lê a chamada mas não marca', (tester) async {
      final repo = _FakeStudyRepo(
        lessons: [_lesson(1, LessonStatus.published)],
        participants: [_participant('u1')],
      );
      await _pump(
        tester,
        _host(
          const GenericaPresenca(
            studyGroupId: _sgId,
            access: TurmaAccess(role: TurmaRole.leadership, elevated: true),
          ),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      await tester.tap(find.text('Aula 1 · Tema 1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('roll-u1-present')), findsNothing);
      expect(find.text('Salvar'), findsNothing);
    });
  });

  group('turmaSurfacesFor', () {
    test('Batismo: abas do workspace presas à turma', () {
      const origin = BatismoTurmaOrigin(
        studyGroupId: _sgId,
        ministryId: 'min-1',
        baptismTurmaId: 'bt-1',
      );
      final surfaces = turmaSurfacesFor(origin, _leader);

      final alunos = surfaces.alunos() as BatismoAlunosTab;
      expect(alunos.ministryId, 'min-1');
      expect(alunos.lockedTurmaId, 'bt-1');
      final presenca = surfaces.presenca() as BatismoPresencaTab;
      expect(presenca.lockedTurmaId, 'bt-1');
    });

    test('genérica: participantes e presença do grupo', () {
      const origin = GenericaTurmaOrigin(studyGroupId: _sgId);
      final surfaces = turmaSurfacesFor(origin, _leader);
      expect(surfaces.alunos(), isA<GenericaParticipantes>());
      expect(surfaces.presenca(), isA<GenericaPresenca>());
      expect(surfaces.minhaFrequencia(), isA<GenericaMinhaFrequencia>());
    });
  });
}
