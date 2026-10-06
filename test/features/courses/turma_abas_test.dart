import 'dart:typed_data';

import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/core/widgets/media/inline_video.dart';
import 'package:church360_app/features/courses/domain/models/course_subject.dart';
import 'package:church360_app/features/courses/domain/models/course_turma.dart';
import 'package:church360_app/features/courses/presentation/providers/courses_provider.dart';
import 'package:church360_app/features/courses/presentation/widgets/course_subjects_section.dart';
import 'package:church360_app/features/courses/presentation/turma/adapters/batismo_turma_adapter.dart';
import 'package:church360_app/features/courses/presentation/turma/adapters/generica_turma_adapter.dart';
import 'package:church360_app/features/courses/presentation/turma/adapters/turma_surfaces.dart';
import 'package:church360_app/features/courses/presentation/turma/lesson_media.dart';
import 'package:church360_app/features/courses/presentation/turma/tabs/aula_observacoes_tab.dart';
import 'package:church360_app/features/courses/presentation/turma/tabs/turma_aulas_tab.dart';
import 'package:church360_app/features/courses/presentation/turma/tabs/turma_materiais_tab.dart';
import 'package:church360_app/features/courses/presentation/turma/turma_access.dart';
import 'package:church360_app/features/courses/presentation/turma/turma_aula_screen.dart';
import 'package:church360_app/features/courses/presentation/turma/turma_origin.dart';
import 'package:church360_app/features/members/domain/models/member_directory_entry.dart';
import 'package:church360_app/features/members/presentation/providers/members_provider.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_attendance.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_my_meeting.dart';
import 'package:church360_app/features/ministries/batismo/presentation/providers/baptism_providers.dart';
import 'package:church360_app/features/ministries/batismo/presentation/screens/tabs/batismo_alunos_tab.dart';
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

StudyLesson _lesson(
  int n,
  LessonStatus status, {
  String? id,
  String? pdfUrl,
  String? videoUrl,
}) => StudyLesson(
  id: id ?? 'l$n',
  studyGroupId: _sgId,
  lessonNumber: n,
  title: 'Tema $n',
  status: status,
  pdfUrl: pdfUrl,
  videoUrl: videoUrl,
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
  final createdFields = <Map<String, Object?>>[];
  final replaced = <Map<String, Object?>>[];
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
    String? subjectId,
    String? teacherId,
    String? startTime,
    int? durationMinutes,
    String? eventId,
  }) async {
    created.add((groupId: studyGroupId, number: lessonNumber, title: title));
    createdFields.add({
      'subject_id': subjectId,
      'teacher_id': teacherId,
      'start_time': startTime,
      'duration_minutes': durationMinutes,
      'description': description,
      'bible_references': bibleReferences,
      'content': content,
      'discussion_questions': discussionQuestions,
      'video_url': videoUrl,
      'pdf_url': pdfUrl,
    });
    return _lesson(lessonNumber, status);
  }

  @override
  Future<StudyLesson> replaceLessonContent(
    String id, {
    required String title,
    String? description,
    String? bibleReferences,
    String? content,
    List<String>? discussionQuestions,
    DateTime? scheduledDate,
    String? videoUrl,
    String? pdfUrl,
    String? subjectId,
    String? teacherId,
    String? startTime,
    int? durationMinutes,
  }) async {
    replaced.add({
      'subject_id': subjectId,
      'teacher_id': teacherId,
      'start_time': startTime,
      'duration_minutes': durationMinutes,
      'id': id,
      'title': title,
      'description': description,
      'bible_references': bibleReferences,
      'content': content,
      'discussion_questions': discussionQuestions,
      'video_url': videoUrl,
      'pdf_url': pdfUrl,
    });
    return lessons.firstWhere((l) => l.id == id);
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

  final notes = <StudyLessonNote>[];
  final noteRequests = <LessonNoteVisibility>[];
  final addedNotes = <({String lessonId, LessonNoteVisibility v, String body})>[];

  @override
  Future<List<StudyLessonNote>> getLessonNotes(
    String lessonId,
    LessonNoteVisibility visibility,
  ) async {
    noteRequests.add(visibility);
    return [
      for (final n in notes)
        if (n.studyLessonId == lessonId && n.visibility == visibility) n,
    ];
  }

  @override
  Future<void> addLessonNote({
    required String lessonId,
    required LessonNoteVisibility visibility,
    required String body,
  }) async {
    addedNotes.add((lessonId: lessonId, v: visibility, body: body));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMaterialsRepo implements SupportMaterialsRepository {
  final List<SupportMaterial> all;

  /// Vínculos `study_lesson` pedidos um a um (leitura da aula).
  final List<SupportMaterial> linked;

  /// Vínculos `study_group` (seção "Material da turma").
  final List<SupportMaterial> groupLinked;

  /// Vínculos `study_lesson` por aula, como estão no banco — inclusive de
  /// aula em rascunho. A regra (d) é a aba nunca pedir esses ids ao aluno.
  final Map<String, List<SupportMaterial>> byLesson;

  final links = <Map<String, dynamic>>[];
  final unlinked = <({String materialId, MaterialLinkType type})>[];

  /// Cada chamada de [getMaterialsByEntities]: os ids pedidos.
  final requestedIds = <List<String>>[];

  _FakeMaterialsRepo({
    this.all = const [],
    this.linked = const [],
    this.groupLinked = const [],
    this.byLesson = const {},
  });

  @override
  Future<List<SupportMaterial>> getAllMaterials() async => all;

  @override
  Future<List<SupportMaterial>> getMaterialsByEntity(
    MaterialLinkType linkType,
    String entityId,
  ) async => linkType == MaterialLinkType.studyGroup ? groupLinked : linked;

  @override
  Future<Map<String, List<SupportMaterial>>> getMaterialsByEntities(
    MaterialLinkType linkType,
    List<String> entityIds,
  ) async {
    requestedIds.add(entityIds);
    return {
      for (final id in entityIds)
        if (byLesson[id] != null) id: byLesson[id]!,
    };
  }

  @override
  Future<void> deleteLinkFor({
    required String materialId,
    required MaterialLinkType linkType,
    required String entityId,
  }) async {
    unlinked.add((materialId: materialId, type: linkType));
  }

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

/// Storage falso da aula: escolher devolve sempre "aula.pdf"/"aula.mp4";
/// enviar devolve `https://up/<tipo>/<aula>`.
class _FakeMedia implements LessonMediaService {
  final int size;
  int failUploads;
  final uploads = <({LessonMediaKind kind, String lessonId})>[];
  final removed = <({LessonMediaKind kind, String? url})>[];

  _FakeMedia({this.size = 1024, this.failUploads = 0});

  @override
  Future<PickedLessonFile?> pick(LessonMediaKind kind) async =>
      PickedLessonFile(
        name: kind == LessonMediaKind.pdf ? 'aula.pdf' : 'aula.mp4',
        size: size,
        bytes: Uint8List(1),
      );

  @override
  Future<String> upload({
    required LessonMediaKind kind,
    required String lessonId,
    required PickedLessonFile file,
  }) async {
    if (failUploads > 0) {
      failUploads--;
      throw Exception('rede caiu');
    }
    uploads.add((kind: kind, lessonId: lessonId));
    return 'https://up/${kind.name}/$lessonId';
  }

  @override
  Future<void> removeIfLessonFile({
    required LessonMediaKind kind,
    required String lessonId,
    required String? url,
  }) async {
    removed.add((kind: kind, url: url));
  }
}

const _leader = TurmaAccess(role: TurmaRole.leadership, canWriteLessons: true);

/// Turma do curso c1 com a matéria "Doutrina" (professor padrão: Bruno).
final _courseOverrides = <Override>[
  turmaByIdProvider.overrideWith(
    (ref, id) async => CourseTurma(
      id: id,
      name: 'Turma',
      status: StudyGroupStatus.active,
      courseId: 'c1',
    ),
  ),
  courseSubjectsProvider.overrideWith(
    (ref, courseId) async => const [
      CourseSubject(
        id: 's1',
        courseId: 'c1',
        title: 'Doutrina',
        lessonCount: 4,
        defaultTeacherId: 'u2',
      ),
    ],
  ),
];

void _noop(StudyLesson _) {}

Widget _host(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      memberDirectoryProvider.overrideWith(
        (ref) async => [
          MemberDirectoryEntry(id: 'u1', fullName: 'Ana', nickname: 'Aninha'),
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
          const TurmaAulasTab(onOpenLesson: _noop, studyGroupId: _sgId, access: TurmaAccess.student),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      expect(find.text('Aula 1 · Tema 1'), findsOneWidget);
      expect(find.text('Aula 2 · Tema 2'), findsNothing);
      expect(find.text('Aula 3 · Tema 3'), findsNothing);
      expect(find.text('Nova aula'), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('card mostra horário, matéria e professor pelo apelido', (
      tester,
    ) async {
      final repo = _FakeStudyRepo(
        lessons: [
          StudyLesson(
            id: 'l1',
            studyGroupId: _sgId,
            lessonNumber: 1,
            title: 'Tema 1',
            status: LessonStatus.published,
            subjectId: 's1',
            teacherId: 'u1',
            startTime: '19:30',
            durationMinutes: 15,
            createdAt: _t0,
            updatedAt: _t0,
          ),
        ],
      );
      await _pump(
        tester,
        _host(
          const TurmaAulasTab(onOpenLesson: _noop, studyGroupId: _sgId, access: TurmaAccess.student),
          overrides: [
            studyGroupRepositoryProvider.overrideWithValue(repo),
            ..._courseOverrides,
          ],
        ),
      );

      expect(find.text('19:30–19:45'), findsOneWidget);
      expect(find.text('Doutrina'), findsOneWidget);
      expect(find.text('Professor(a): Aninha'), findsOneWidget);
    });

    testWidgets('liderança vê todas com status', (tester) async {
      final repo = _FakeStudyRepo(lessons: lessons);
      await _pump(
        tester,
        _host(
          const TurmaAulasTab(onOpenLesson: _noop, studyGroupId: _sgId, access: _leader),
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
            onOpenLesson: _noop,
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
          const TurmaAulasTab(onOpenLesson: _noop, studyGroupId: _sgId, access: _leader),
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

    // PR 1b: tocar na aula abre a tela da aula; a chamada saiu do menu.
    testWidgets('tocar na aula abre a tela da aula', (tester) async {
      final repo = _FakeStudyRepo(lessons: lessons);
      final opened = <String>[];
      await _pump(
        tester,
        _host(
          TurmaAulasTab(
            studyGroupId: _sgId,
            access: _leader,
            onOpenLesson: (lesson) => opened.add(lesson.id),
          ),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      await tester.tap(find.text('Aula 2 · Tema 2'));
      await tester.pumpAndSettle();
      expect(opened, ['l2']);
    });

    testWidgets('menu da aula sem Registrar presença', (tester) async {
      final repo = _FakeStudyRepo(lessons: lessons);
      await _pump(
        tester,
        _host(
          const TurmaAulasTab(onOpenLesson: _noop, studyGroupId: _sgId, access: _leader),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      expect(find.text('Registrar presença'), findsNothing);
      expect(find.text('Editar'), findsOneWidget);
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
          const TurmaAulasTab(onOpenLesson: _noop, studyGroupId: _sgId, access: _leader),
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

  // Formulário da aula com vídeo/PDF principais por link, referências e
  // perguntas (modelo híbrido do ROADMAP-FORMACAO, passo 2).
  group('Formulário da aula', () {
    StudyLesson withMedia() => StudyLesson(
      id: 'l9',
      studyGroupId: _sgId,
      lessonNumber: 9,
      title: 'Batismo nas águas',
      bibleReferences: 'Atos 2:38',
      discussionQuestions: const ['Por que batizar?', 'Quando?'],
      videoUrl: 'https://youtube.com/watch?v=abc',
      pdfUrl: 'https://exemplo.com/aula9.pdf',
      status: LessonStatus.draft,
      createdAt: _t0,
      updatedAt: _t0,
    );

    Future<void> tapSave(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Salvar'));
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
    }

    testWidgets('nova aula grava referências, perguntas, vídeo e PDF', (
      tester,
    ) async {
      final repo = _FakeStudyRepo(lessons: const []);
      await _pump(
        tester,
        _host(
          const TurmaAulasTab(onOpenLesson: _noop, studyGroupId: _sgId, access: _leader),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      await tester.tap(find.text('Nova aula'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Título da aula *'),
        'Arrependimento',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Referências bíblicas'),
        ' Atos 2:38 ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Perguntas para discussão'),
        'Primeira?\n\n  Segunda?  \n',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Link do vídeo'),
        'https://youtube.com/watch?v=x',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Link do PDF'),
        'https://exemplo.com/a.pdf',
      );
      await tapSave(tester);

      final f = repo.createdFields.single;
      expect(f['bible_references'], 'Atos 2:38');
      expect(f['discussion_questions'], ['Primeira?', 'Segunda?']);
      expect(f['video_url'], 'https://youtube.com/watch?v=x');
      expect(f['pdf_url'], 'https://exemplo.com/a.pdf');
      // Campo em branco vai como null, não como texto vazio.
      expect(f['description'], isNull);
      expect(f['content'], isNull);
    });

    testWidgets('matéria preenche o professor padrão e os dois são gravados', (
      tester,
    ) async {
      final repo = _FakeStudyRepo(lessons: const []);
      await _pump(
        tester,
        _host(
          const TurmaAulasTab(onOpenLesson: _noop, studyGroupId: _sgId, access: _leader),
          overrides: [
            studyGroupRepositoryProvider.overrideWithValue(repo),
            ..._courseOverrides,
          ],
        ),
      );

      await tester.tap(find.text('Nova aula'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Título da aula *'),
        'Trindade',
      );
      await tester.tap(find.byKey(const ValueKey('lesson-subject')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Doutrina').last);
      await tester.pumpAndSettle();
      expect(find.text('Bruno'), findsOneWidget);
      await tapSave(tester);

      final f = repo.createdFields.single;
      expect(f['duration_minutes'], isNull);
      expect(f['subject_id'], 's1');
      expect(f['teacher_id'], 'u2');
      expect(f['start_time'], isNull);
    });

    testWidgets('link inválido barra o salvamento', (tester) async {
      final repo = _FakeStudyRepo(lessons: const []);
      await _pump(
        tester,
        _host(
          const TurmaAulasTab(onOpenLesson: _noop, studyGroupId: _sgId, access: _leader),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      await tester.tap(find.text('Nova aula'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Título da aula *'),
        'Aula',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Link do PDF'),
        'javascript:alert(1)',
      );
      await tapSave(tester);

      expect(repo.created, isEmpty);
      expect(find.text('Informe um link que comece com https://'), findsOne);
    });

    // Emenda (c): a edição grava o formulário inteiro; apagar o link
    // remove o vídeo de verdade (null), em vez de ser ignorado.
    testWidgets('editar e apagar o link do vídeo manda null', (tester) async {
      final repo = _FakeStudyRepo(lessons: [withMedia()]);
      await _pump(
        tester,
        _host(
          const TurmaAulasTab(onOpenLesson: _noop, studyGroupId: _sgId, access: _leader),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      expect(find.text('https://youtube.com/watch?v=abc'), findsOneWidget);
      expect(find.text('Por que batizar?\nQuando?'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Link do vídeo'),
        '',
      );
      await tapSave(tester);

      final r = repo.replaced.single;
      expect(r['id'], 'l9');
      expect(r.containsKey('video_url'), isTrue);
      expect(r['video_url'], isNull);
      expect(r['pdf_url'], 'https://exemplo.com/aula9.pdf');
      expect(r['discussion_questions'], ['Por que batizar?', 'Quando?']);
      expect(repo.statusUpdates, isEmpty);
    });

    testWidgets('Conteúdo toca o vídeo no app e mostra Abrir PDF', (
      tester,
    ) async {
      await _pump(tester, _host(LessonContentTab(lesson: withMedia())));

      expect(find.byType(InlineVideo), findsOneWidget);
      expect(find.text('Abrir PDF'), findsOneWidget);
      expect(find.text('Esta aula ainda não tem conteúdo.'), findsNothing);
    });

    testWidgets('Conteúdo vazio avisa', (tester) async {
      await _pump(
        tester,
        _host(LessonContentTab(lesson: _lesson(1, LessonStatus.published))),
      );
      expect(find.text('Esta aula ainda não tem conteúdo.'), findsOneWidget);
    });

    testWidgets('Conteúdo mostra o professor no topo', (tester) async {
      await _pump(
        tester,
        _host(
          LessonContentTab(
            lesson: _lesson(1, LessonStatus.published),
            teacher: 'Professor(a): Clarissa',
          ),
        ),
      );
      expect(find.text('Professor(a): Clarissa'), findsOneWidget);
    });

    test('regras dos campos', () {
      expect(normalizeLessonUrl('  '), isNull);
      expect(normalizeLessonUrl(' https://a.com/x '), 'https://a.com/x');
      expect(lessonUrlError('ftp://a.com'), isNotNull);
      expect(lessonUrlError('https://'), isNotNull);
      expect(lessonUrlError('http://a.com'), isNull);
      expect(parseLessonQuestions(' \n '), isNull);
      expect(parseLessonQuestions('a\r\nb'), ['a', 'b']);
    });
  });

  // Passo 3 do modelo híbrido: arquivo principal enviado pela aula. O envio
  // só acontece ao salvar (a pasta leva o id da aula) e o arquivo antigo da
  // própria aula é apagado depois que o banco grava.
  group('Envio de arquivo da aula', () {
    const tenant = 't1';
    const uid = 'u1';
    String lessonFile(String lessonId, String name) =>
        'https://x.supabase.co/storage/v1/object/public/support-material-files/'
        '$tenant/$uid/study-lessons/$lessonId/$name';

    StudyLesson uploaded() => StudyLesson(
      id: 'l9',
      studyGroupId: _sgId,
      lessonNumber: 9,
      title: 'Batismo nas águas',
      videoUrl: 'https://youtube.com/watch?v=abc',
      pdfUrl: lessonFile('l9', 'antigo.pdf'),
      status: LessonStatus.draft,
      createdAt: _t0,
      updatedAt: _t0,
    );

    Future<void> tapSave(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Salvar'));
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
    }

    Future<void> pickPdf(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const ValueKey('lesson-pick-pdf')));
      await tester.tap(find.byKey(const ValueKey('lesson-pick-pdf')));
      await tester.pumpAndSettle();
    }

    testWidgets('aula nova: cria, envia na pasta da aula e grava o link', (
      tester,
    ) async {
      final repo = _FakeStudyRepo(lessons: const []);
      final media = _FakeMedia();
      await _pump(
        tester,
        _host(
          const TurmaAulasTab(onOpenLesson: _noop, studyGroupId: _sgId, access: _leader),
          overrides: [
            studyGroupRepositoryProvider.overrideWithValue(repo),
            lessonMediaServiceProvider.overrideWithValue(media),
          ],
        ),
      );

      await tester.tap(find.text('Nova aula'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Título da aula *'),
        'Arrependimento',
      );
      await pickPdf(tester);
      expect(find.text('aula.pdf · enviado ao salvar'), findsOneWidget);
      await tapSave(tester);

      // Criada sem PDF; o envio usa o id devolvido; o link vai no replace.
      expect(repo.createdFields.single['pdf_url'], isNull);
      expect(media.uploads.single, (kind: LessonMediaKind.pdf, lessonId: 'l1'));
      expect(repo.replaced.single['id'], 'l1');
      expect(repo.replaced.single['pdf_url'], 'https://up/pdf/l1');
      expect(media.removed, isEmpty);
    });

    testWidgets('trocar o PDF enviado apaga o antigo depois de gravar', (
      tester,
    ) async {
      final repo = _FakeStudyRepo(lessons: [uploaded()]);
      final media = _FakeMedia();
      await _pump(
        tester,
        _host(
          const TurmaAulasTab(onOpenLesson: _noop, studyGroupId: _sgId, access: _leader),
          overrides: [
            studyGroupRepositoryProvider.overrideWithValue(repo),
            lessonMediaServiceProvider.overrideWithValue(media),
          ],
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await pickPdf(tester);
      await tapSave(tester);

      expect(media.uploads.single, (kind: LessonMediaKind.pdf, lessonId: 'l9'));
      expect(repo.replaced.single['pdf_url'], 'https://up/pdf/l9');
      // O vídeo não mudou: nada a apagar do lado dele.
      expect(media.removed, [
        (kind: LessonMediaKind.pdf, url: lessonFile('l9', 'antigo.pdf')),
      ]);
    });

    testWidgets('falha no envio: a aula não é criada de novo', (tester) async {
      final repo = _FakeStudyRepo(lessons: const []);
      final media = _FakeMedia(failUploads: 1);
      await _pump(
        tester,
        _host(
          const TurmaAulasTab(onOpenLesson: _noop, studyGroupId: _sgId, access: _leader),
          overrides: [
            studyGroupRepositoryProvider.overrideWithValue(repo),
            lessonMediaServiceProvider.overrideWithValue(media),
          ],
        ),
      );

      await tester.tap(find.text('Nova aula'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Título da aula *'),
        'Aula',
      );
      await pickPdf(tester);
      await tapSave(tester);

      expect(repo.created, hasLength(1));
      expect(repo.replaced, isEmpty);
      expect(find.textContaining('A aula foi criada'), findsOneWidget);

      await tapSave(tester);
      expect(repo.created, hasLength(1));
      expect(repo.replaced.single['id'], 'l1');
      expect(repo.replaced.single['pdf_url'], 'https://up/pdf/l1');
    });

    testWidgets('arquivo acima de 50 MB é recusado antes de enviar', (
      tester,
    ) async {
      final repo = _FakeStudyRepo(lessons: const []);
      final media = _FakeMedia(size: lessonMediaMaxBytes + 1);
      await _pump(
        tester,
        _host(
          const TurmaAulasTab(onOpenLesson: _noop, studyGroupId: _sgId, access: _leader),
          overrides: [
            studyGroupRepositoryProvider.overrideWithValue(repo),
            lessonMediaServiceProvider.overrideWithValue(media),
          ],
        ),
      );

      await tester.tap(find.text('Nova aula'));
      await tester.pumpAndSettle();
      await pickPdf(tester);
      expect(find.text('O arquivo passa de 50 MB.'), findsOneWidget);
      expect(find.textContaining('enviado ao salvar'), findsNothing);
    });

    test('só arquivo da pasta da própria aula é apagável', () {
      expect(
        lessonMediaObjectPath(
          lessonFile('l9', 'a.pdf'),
          kind: LessonMediaKind.pdf,
          lessonId: 'l9',
        ),
        '$tenant/$uid/study-lessons/l9/a.pdf',
      );
      // Outra aula, outro bucket, link externo, material de apoio comum.
      expect(
        lessonMediaObjectPath(
          lessonFile('l8', 'a.pdf'),
          kind: LessonMediaKind.pdf,
          lessonId: 'l9',
        ),
        isNull,
      );
      expect(
        lessonMediaObjectPath(
          lessonFile('l9', 'a.pdf'),
          kind: LessonMediaKind.video,
          lessonId: 'l9',
        ),
        isNull,
      );
      expect(
        lessonMediaObjectPath(
          'https://youtube.com/watch?v=abc',
          kind: LessonMediaKind.video,
          lessonId: 'l9',
        ),
        isNull,
      );
      expect(
        lessonMediaObjectPath(
          'https://x.supabase.co/storage/v1/object/public/'
          'support-material-files/$tenant/$uid/123.pdf',
          kind: LessonMediaKind.pdf,
          lessonId: 'l9',
        ),
        isNull,
      );
      expect(
        buildLessonMediaPath(
          tenantId: tenant,
          userId: uid,
          lessonId: 'l9',
          timestamp: 5,
          extension: 'pdf',
        ),
        '$tenant/$uid/study-lessons/l9/5.pdf',
      );
    });
  });

  group('Materiais complementares da aula', () {
    testWidgets('vídeo do material aparece tocável na lista', (tester) async {
      final materials = _FakeMaterialsRepo(
        linked: [
          _material('m1').copyWith(videoUrl: 'https://youtu.be/abc12345678'),
        ],
      );
      await _pump(
        tester,
        _host(
          const LessonComplementaryMaterials(lessonId: 'l1', canWrite: false),
          overrides: [
            supportMaterialsRepositoryProvider.overrideWithValue(materials),
          ],
        ),
      );

      expect(find.text('Material m1'), findsOneWidget);
      expect(find.byType(InlineVideo), findsOneWidget);
    });

    testWidgets('material aparece aberto na aula, com Abrir e Baixar', (
      tester,
    ) async {
      const file =
          'https://x.supabase.co/storage/v1/object/public/support-material-files/t/u/a.pdf';
      final materials = _FakeMaterialsRepo(
        linked: [
          _material(
            'm1',
          ).copyWith(description: 'Leia antes da aula', fileUrl: file),
        ],
      );
      await _pump(
        tester,
        _host(
          const LessonComplementaryMaterials(lessonId: 'l1', canWrite: false),
          overrides: [
            supportMaterialsRepositoryProvider.overrideWithValue(materials),
          ],
        ),
      );

      // Sem janela: descrição e botões já estão na lista.
      expect(find.text('Leia antes da aula'), findsOneWidget);
      expect(find.text('Abrir arquivo'), findsOneWidget);
      expect(find.text('Baixar'), findsOneWidget);
    });

    test('Baixar só para arquivo do Storage', () {
      expect(
        TurmaMaterialContent.downloadUrl(
          'https://x.supabase.co/storage/v1/object/public/b/a.pdf',
        ),
        'https://x.supabase.co/storage/v1/object/public/b/a.pdf?download=',
      );
      expect(
        TurmaMaterialContent.downloadUrl('https://drive.google.com/file/d/1'),
        isNull,
      );
    });

    testWidgets('liderança vincula material à aula (tipo study_lesson)', (
      tester,
    ) async {
      final materials = _FakeMaterialsRepo(
        all: [_material('alheio', createdBy: 'outro')],
      );
      await _pump(
        tester,
        _host(
          const LessonComplementaryMaterials(lessonId: 'l1', canWrite: true),
          overrides: [
            supportMaterialsRepositoryProvider.overrideWithValue(materials),
          ],
        ),
      );

      expect(find.text('Nenhum material vinculado a esta aula.'), findsOne);
      await tester.tap(find.byKey(const ValueKey('lesson-link-material')));
      await tester.pumpAndSettle();
      // Material de outra pessoa aparece: quem edita a aula vincula o que vê.
      await tester.tap(find.text('Material alheio'));
      await tester.pumpAndSettle();

      expect(materials.links.single['material_id'], 'alheio');
      expect(materials.links.single['link_type'], 'study_lesson');
      expect(materials.links.single['linked_entity_id'], 'l1');
    });

    testWidgets('aluno vê os vinculados, sem Vincular', (tester) async {
      final materials = _FakeMaterialsRepo(linked: [_material('m1')]);
      await _pump(
        tester,
        _host(
          const LessonComplementaryMaterials(lessonId: 'l1', canWrite: false),
          overrides: [
            supportMaterialsRepositoryProvider.overrideWithValue(materials),
          ],
        ),
      );

      expect(find.text('Materiais complementares'), findsOneWidget);
      expect(find.text('Material m1'), findsOneWidget);
      expect(find.byType(InlineVideo), findsNothing);
      expect(find.byKey(const ValueKey('lesson-link-material')), findsNothing);
      expect(find.byTooltip('Desvincular'), findsNothing);
    });
  });

  group('Materiais', () {
    List<Override> overrides(
      _FakeStudyRepo study,
      _FakeMaterialsRepo materials, {
      String? memberId = 'me',
      bool canEditAny = false,
    }) => [
      studyGroupRepositoryProvider.overrideWithValue(study),
      supportMaterialsRepositoryProvider.overrideWithValue(materials),
      turmaMaterialRightsProvider.overrideWith(
        (ref) async =>
            TurmaMaterialRights(memberId: memberId, canEditAny: canEditAny),
      ),
    ];

    // Aula 1 publicada com tudo; aula 2 em rascunho com PDF e complementar;
    // aula 3 publicada sem material nenhum.
    _FakeStudyRepo turma() => _FakeStudyRepo(
      lessons: [
        _lesson(
          1,
          LessonStatus.published,
          pdfUrl: 'https://x/aula1.pdf',
          videoUrl: 'https://x/aula1.mp4',
        ),
        _lesson(2, LessonStatus.draft, pdfUrl: 'https://x/rascunho.pdf'),
        _lesson(3, LessonStatus.published),
      ],
    );
    _FakeMaterialsRepo materiais({List<SupportMaterial> group = const []}) =>
        _FakeMaterialsRepo(
          byLesson: {
            'l1': [_material('pub')],
            'l2': [_material('rascunho')],
          },
          groupLinked: group,
        );

    testWidgets('aluno: só aulas publicadas, e só os ids delas são pedidos', (
      tester,
    ) async {
      final materials = materiais();
      await _pump(
        tester,
        _host(
          const TurmaMateriaisTab(
            studyGroupId: _sgId,
            access: TurmaAccess.student,
          ),
          overrides: overrides(turma(), materials),
        ),
      );

      expect(find.text('Aula 1 · Tema 1'), findsOneWidget);
      expect(find.text('PDF da aula'), findsOneWidget);
      expect(find.text('Vídeo da aula'), findsOneWidget);
      expect(find.text('Material pub'), findsOneWidget);

      // Rascunho: nem a seção, nem o PDF, nem o complementar.
      expect(find.text('Aula 2 · Tema 2'), findsNothing);
      expect(find.text('Material rascunho'), findsNothing);
      // Aula publicada sem material não aparece.
      expect(find.text('Aula 3 · Tema 3'), findsNothing);

      // Regra (d): a consulta dos complementares só leva as aulas visíveis.
      expect(materials.requestedIds, isNotEmpty);
      for (final ids in materials.requestedIds) {
        expect(ids, isNot(contains('l2')));
        expect(ids.toSet(), {'l1', 'l3'});
      }

      expect(find.text('Vincular material'), findsNothing);
      expect(find.text('Material da turma'), findsNothing);
      expect(find.textContaining('Enviar'), findsNothing);
      expect(find.text('RASCUNHO'), findsNothing);
    });

    testWidgets('liderança: vê o rascunho marcado, sem Vincular material', (
      tester,
    ) async {
      final materials = materiais();
      await _pump(
        tester,
        _host(
          const TurmaMateriaisTab(studyGroupId: _sgId, access: _leader),
          overrides: overrides(turma(), materials),
        ),
      );

      expect(find.text('Aula 1 · Tema 1'), findsOneWidget);
      expect(find.text('Aula 2 · Tema 2'), findsOneWidget);
      expect(find.text('Material rascunho'), findsOneWidget);
      // Só a aula que não está publicada leva o selo.
      expect(find.text('RASCUNHO'), findsOneWidget);
      expect(find.text('PUBLICADA'), findsNothing);
      expect(find.text('PDF da aula'), findsNWidgets(2));
      expect(materials.requestedIds.last.toSet(), {'l1', 'l2', 'l3'});

      expect(find.text('Vincular material'), findsNothing);
      expect(find.text('Material da turma'), findsNothing);
      expect(find.textContaining('abra a aula na aba Aulas'), findsOneWidget);
    });

    testWidgets(
      'vínculo antigo da turma: seção própria, desvincula só o autor',
      (tester) async {
        final materials = materiais(
          group: [
            _material('meu', createdBy: 'me'),
            _material('alheio', createdBy: 'outro'),
          ],
        );
        await _pump(
          tester,
          _host(
            const TurmaMateriaisTab(studyGroupId: _sgId, access: _leader),
            overrides: overrides(turma(), materials),
          ),
        );

        expect(find.text('Material da turma'), findsOneWidget);
        expect(find.text('Material meu'), findsOneWidget);
        expect(find.text('Material alheio'), findsOneWidget);
        expect(find.byTooltip('Ações do material'), findsOneWidget);

        await tester.tap(find.byTooltip('Ações do material'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Desvincular'));
        await tester.pumpAndSettle();
        expect(materials.unlinked.single.materialId, 'meu');
        expect(materials.unlinked.single.type, MaterialLinkType.studyGroup);
      },
    );

    testWidgets('support_materials.edit desvincula qualquer um', (
      tester,
    ) async {
      final materials = materiais(
        group: [
          _material('meu', createdBy: 'me'),
          _material('alheio', createdBy: 'outro'),
        ],
      );
      await _pump(
        tester,
        _host(
          const TurmaMateriaisTab(studyGroupId: _sgId, access: _leader),
          overrides: overrides(turma(), materials, canEditAny: true),
        ),
      );

      expect(find.byTooltip('Ações do material'), findsNWidgets(2));
    });

    testWidgets('aluno vê o material da turma sem ações', (tester) async {
      final materials = materiais(group: [_material('meu', createdBy: 'me')]);
      await _pump(
        tester,
        _host(
          const TurmaMateriaisTab(
            studyGroupId: _sgId,
            access: TurmaAccess.student,
          ),
          overrides: overrides(turma(), materials, canEditAny: true),
        ),
      );

      expect(find.text('Material da turma'), findsOneWidget);
      expect(find.byTooltip('Ações do material'), findsNothing);
    });

    testWidgets('sem aula: mensagem vazia e nenhuma consulta com id', (
      tester,
    ) async {
      final materials = materiais();
      await _pump(
        tester,
        _host(
          const TurmaMateriaisTab(
            studyGroupId: _sgId,
            access: TurmaAccess.student,
          ),
          overrides: overrides(_FakeStudyRepo(), materials),
        ),
      );

      expect(find.text('Nenhum material disponível ainda.'), findsOneWidget);
      for (final ids in materials.requestedIds) {
        expect(ids, isEmpty);
      }
    });

    testWidgets('aulas sem material: mensagem vazia da liderança', (
      tester,
    ) async {
      await _pump(
        tester,
        _host(
          const TurmaMateriaisTab(studyGroupId: _sgId, access: _leader),
          overrides: overrides(
            _FakeStudyRepo(lessons: [_lesson(1, LessonStatus.draft)]),
            _FakeMaterialsRepo(),
          ),
        ),
      );

      expect(
        find.text('Nenhuma aula desta turma tem material ainda.'),
        findsOneWidget,
      );
    });

    test('materialEntityIdsKey: estável, sem repetição', () {
      expect(materialEntityIdsKey(['b', 'a', 'b']), 'a,b');
      expect(materialEntityIdsKey(const []), '');
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

    testWidgets('aba Presença da aula: a marca do encontro daquela aula', (
      tester,
    ) async {
      const origin = BatismoTurmaOrigin(
        studyGroupId: _sgId,
        ministryId: 'min-1',
        baptismTurmaId: 'bt-1',
      );
      await _pump(
        tester,
        _host(
          turmaSurfacesFor(
            origin,
            TurmaAccess.student,
          ).lessonPresence(_lesson(2, LessonStatus.published)),
          overrides: [
            myBaptismAttendanceProvider('bt-1').overrideWith(
              (ref) async => [
                BaptismMyMeeting(
                  meetingId: '1',
                  meetingDate: DateTime(2026, 9, 6),
                  title: 'Aula 1',
                  status: BaptismAttendanceStatus.ausente,
                  studyLessonId: 'l1',
                ),
                BaptismMyMeeting(
                  meetingId: '2',
                  meetingDate: DateTime(2026, 9, 13),
                  title: 'Aula 2',
                  status: BaptismAttendanceStatus.presente,
                  studyLessonId: 'l2',
                ),
              ],
            ),
          ],
        ),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('minha-presenca-aula')))
            .data,
        BaptismAttendanceStatus.presente.label,
      );
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

  group('Presença — genérica (aba da aula)', () {
    const origin = GenericaTurmaOrigin(studyGroupId: _sgId);

    /// A aba Presença da tela da aula, como a origem entrega.
    Widget presence(TurmaAccess access, StudyLesson lesson) =>
        turmaSurfacesFor(origin, access).lessonPresence(lesson);

    testWidgets('liderança só por courses.* não ganha a chamada', (
      tester,
    ) async {
      await _pump(
        tester,
        _host(presence(_leader, _lesson(1, LessonStatus.published))),
      );
      expect(find.text('A chamada é feita pelo líder da turma.'), findsOne);
      expect(find.text('Salvar'), findsNothing);
    });

    testWidgets('vitrine de Cursos não oferece a chamada nem ao líder', (
      tester,
    ) async {
      const access = TurmaAccess(
        role: TurmaRole.leadership,
        leadsGroup: true,
        readOnly: true,
      );
      await _pump(
        tester,
        _host(presence(access, _lesson(1, LessonStatus.published))),
      );
      expect(find.text('Você não é aluno desta turma.'), findsOne);
      expect(find.text('Salvar'), findsNothing);
    });

    testWidgets('vitrine: liderança que é aluno vê só a própria marca', (
      tester,
    ) async {
      final repo = _FakeStudyRepo(
        lessons: [_lesson(1, LessonStatus.published)],
        mine: [_att('l1', 'auth-me', AttendanceStatus.present)],
      );
      const access = TurmaAccess(
        role: TurmaRole.leadership,
        elevated: true,
        readOnly: true,
        enrolled: true,
      );
      await _pump(
        tester,
        _host(
          presence(access, _lesson(1, LessonStatus.published)),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );
      expect(find.byKey(const ValueKey('minha-presenca-aula')), findsOne);
      expect(find.text('Salvar'), findsNothing);
    });

    testWidgets('aluno vê a própria marca naquela aula', (tester) async {
      final repo = _FakeStudyRepo(
        lessons: [
          _lesson(1, LessonStatus.published),
          _lesson(2, LessonStatus.published),
        ],
        mine: [_att('l2', 'auth-me', AttendanceStatus.justified)],
      );
      await _pump(
        tester,
        _host(
          presence(TurmaAccess.student, _lesson(2, LessonStatus.published)),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('minha-presenca-aula')))
            .data,
        AttendanceStatus.justified.displayName,
      );
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
          presence(
            const TurmaAccess(role: TurmaRole.leadership, leadsGroup: true),
            _lesson(1, LessonStatus.published),
          ),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );


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
          presence(
            const TurmaAccess(role: TurmaRole.leadership, elevated: true),
            _lesson(1, LessonStatus.published),
          ),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      expect(find.text('Ana'), findsOneWidget);
      expect(find.byKey(const ValueKey('roll-u1-present')), findsNothing);
      expect(find.text('Salvar'), findsNothing);
    });

    testWidgets('Alunos mostra a contagem de cada participante', (
      tester,
    ) async {
      final repo = _FakeStudyRepo(
        lessons: [
          _lesson(1, LessonStatus.published),
          _lesson(2, LessonStatus.published, id: 'l2'),
        ],
        participants: [_participant('u1'), _participant('u2')],
        attendance: {
          'l1': [
            _att('l1', 'u1', AttendanceStatus.present),
            _att('l1', 'u2', AttendanceStatus.absent),
          ],
          'l2': [_att('l2', 'u1', AttendanceStatus.justified)],
        },
      );
      await _pump(
        tester,
        _host(
          const GenericaParticipantes(
            studyGroupId: _sgId,
            access: TurmaAccess(role: TurmaRole.leadership, leadsGroup: true),
          ),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      expect(find.text('1 presentes · 0 faltas · 1 justificadas'), findsOne);
      expect(find.text('0 presentes · 1 faltas · 0 justificadas'), findsOne);
    });

    testWidgets('quem não vê a chamada não recebe contagem', (tester) async {
      final repo = _FakeStudyRepo(
        lessons: [_lesson(1, LessonStatus.published)],
        participants: [_participant('u1')],
        attendance: {
          'l1': [_att('l1', 'u1', AttendanceStatus.present)],
        },
      );
      await _pump(
        tester,
        _host(
          const GenericaParticipantes(studyGroupId: _sgId, access: _leader),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      expect(find.text('Ana'), findsOneWidget);
      expect(find.textContaining('presentes'), findsNothing);
    });
  });

  group('Tela da aula', () {
    TurmaAulaView view(TurmaAccess access) => TurmaAulaView(
      lesson: _lesson(1, LessonStatus.draft),
      access: access,
      surfaces: turmaSurfacesFor(
        const GenericaTurmaOrigin(studyGroupId: _sgId),
        access,
      ),
    );

    testWidgets('três abas, sem Materiais; ações só para quem escreve aula', (
      tester,
    ) async {
      await _pump(tester, _host(view(_leader)));
      expect(AulaTabId.values.map((t) => t.label), [
        'Conteúdo',
        'Presença',
        'Observações',
      ]);
      for (final tab in AulaTabId.values) {
        expect(find.text(tab.label), findsOneWidget);
      }
      // Os materiais da aula ficam dentro de Conteúdo.
      expect(find.text('Materiais complementares'), findsOneWidget);
      expect(find.text('RASCUNHO'), findsOneWidget);
      expect(find.byKey(const ValueKey('aula-acoes')), findsOneWidget);

      await _pump(tester, _host(view(_leader.asReadOnly())));
      expect(find.byKey(const ValueKey('aula-acoes')), findsNothing);
    });

    testWidgets('cabeçalho mostra horário, matéria e professor (PR 2a)', (
      tester,
    ) async {
      final lesson = StudyLesson(
        id: 'l1',
        studyGroupId: _sgId,
        lessonNumber: 1,
        title: 'Tema 1',
        status: LessonStatus.published,
        subjectId: 's1',
        teacherId: 'u1',
        startTime: '19:30',
        durationMinutes: 15,
        createdAt: _t0,
        updatedAt: _t0,
      );
      await _pump(
        tester,
        _host(
          TurmaAulaView(
            lesson: lesson,
            access: _leader,
            surfaces: turmaSurfacesFor(
              const GenericaTurmaOrigin(studyGroupId: _sgId),
              _leader,
            ),
          ),
          overrides: _courseOverrides,
        ),
      );
      expect(find.text('19:30–19:45'), findsOneWidget);
      expect(find.text('Doutrina'), findsOneWidget);
      expect(find.text('Professor(a): Aninha'), findsOneWidget);
    });

    test('rota segue a porta da turma', () {
      expect(
        turmaLessonRoute(courseId: 'c1', studyGroupId: _sgId, lessonId: 'l1'),
        '/courses/c1/turmas/$_sgId/aulas/l1',
      );
      expect(
        turmaLessonRoute(studyGroupId: _sgId, lessonId: 'l1'),
        '/turmas/$_sgId/gestao/aulas/l1',
      );
    });
  });

  group('Observações da aula', () {
    StudyLessonNote note(String id, LessonNoteVisibility v) => StudyLessonNote(
      id: id,
      studyLessonId: 'l1',
      authorId: 'u1',
      visibility: v,
      body: 'Nota $id',
      createdAt: _t0,
    );

    testWidgets('aluno lê e escreve só a pessoal', (tester) async {
      final repo = _FakeStudyRepo()
        ..notes.addAll([
          note('p', LessonNoteVisibility.pessoal),
          note('l', LessonNoteVisibility.lideranca),
        ]);
      await _pump(
        tester,
        _host(
          const AulaObservacoesTab(lessonId: 'l1', access: TurmaAccess.student),
          overrides: [studyGroupRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      expect(repo.noteRequests.toSet(), {LessonNoteVisibility.pessoal});
      expect(find.text('Nota p'), findsOneWidget);
      expect(find.text('Nota l'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('aula-nota-campo')),
        '  lembrar de ler Atos 2  ',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(repo.addedNotes.single.v, LessonNoteVisibility.pessoal);
      expect(repo.addedNotes.single.body, 'lembrar de ler Atos 2');
    });

    testWidgets('liderança lê a de liderança com o autor', (tester) async {
      final repo = _FakeStudyRepo()
        ..notes.add(note('l', LessonNoteVisibility.lideranca));
      await _pump(
        tester,
        _host(
          const AulaObservacoesTab(lessonId: 'l1', access: _leader),
          overrides: [
            studyGroupRepositoryProvider.overrideWithValue(repo),
            currentMemberProvider.overrideWith((ref) async => null),
          ],
        ),
      );

      expect(repo.noteRequests.toSet(), {LessonNoteVisibility.lideranca});
      expect(find.text('Nota l'), findsOneWidget);
      expect(find.textContaining('Ana · '), findsOneWidget);
      // Nota de outro líder: não apaga.
      expect(find.byTooltip('Apagar'), findsNothing);
    });

    testWidgets('liderança na vitrine só lê', (tester) async {
      final repo = _FakeStudyRepo();
      await _pump(
        tester,
        _host(
          AulaObservacoesTab(lessonId: 'l1', access: _leader.asReadOnly()),
          overrides: [
            studyGroupRepositoryProvider.overrideWithValue(repo),
            currentMemberProvider.overrideWith((ref) async => null),
          ],
        ),
      );
      expect(find.byKey(const ValueKey('aula-nota-campo')), findsNothing);
      expect(find.text('Nenhuma observação nesta aula.'), findsOneWidget);
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
    });

    test('genérica: participantes e frequência do aluno', () {
      const origin = GenericaTurmaOrigin(studyGroupId: _sgId);
      final surfaces = turmaSurfacesFor(origin, _leader);
      expect(surfaces.alunos(), isA<GenericaParticipantes>());
      expect(surfaces.minhaFrequencia(), isA<GenericaMinhaFrequencia>());
    });
  });
}
