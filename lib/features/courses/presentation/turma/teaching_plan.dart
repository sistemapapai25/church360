import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/community_design.dart';
import '../../../events/domain/models/event.dart';
import '../../../schedule/presentation/providers/schedule_provider.dart';
import '../../../study_groups/domain/models/study_group.dart';
import '../../../study_groups/presentation/providers/study_group_provider.dart';
import '../../domain/models/course_subject.dart';
import '../../domain/models/course_turma.dart';
import '../providers/courses_provider.dart';
import '../widgets/course_subjects_section.dart';
import 'tabs/turma_aulas_tab.dart';
import 'widgets/turma_sheet.dart';

// PR 2b — "Distribuir aulas" e "Escala de ensino" da aba Aulas da turma.
// As regras ficam nas funções puras abaixo (testadas); as folhas só mostram
// a prévia e gravam.

/// Aula que o Distribuir vai criar. [start] em minutos desde 00:00.
typedef PlannedLesson = ({
  CourseSubject subject,
  int lessonNumber,
  String title,
  int start,
});

/// Aulas que faltam para cada matéria chegar a `lessonCount`, num bloco
/// sequencial a partir de [start]. Matérias na ordem recebida (criação);
/// conta toda aula da turma com o `subject_id`, até arquivada. Nunca
/// altera nem apaga aula: só devolve a diferença.
List<PlannedLesson> planLessons({
  required List<CourseSubject> subjects,
  required List<StudyLesson> lessons,
  required int start,
  required int duration,
  int interval = 0,
}) {
  var number = lessons.fold(
    0,
    (max, l) => l.lessonNumber > max ? l.lessonNumber : max,
  );
  var at = start;
  final planned = <PlannedLesson>[];
  for (final s in subjects) {
    final existing = lessons.where((l) => l.subjectId == s.id).length;
    for (var i = existing + 1; i <= s.lessonCount; i++) {
      planned.add((
        subject: s,
        lessonNumber: ++number,
        title: '${s.title} — $i/${s.lessonCount}',
        start: at,
      ));
      at += duration + interval;
    }
  }
  return planned;
}

/// Linha do Distribuir: a aula, o dia, a duração e o encontro (evento
/// tipo Aula) em que ela fica, se houver.
typedef PlannedRow = ({
  PlannedLesson lesson,
  DateTime date,
  int duration,
  String? eventId,
});

/// Distribuir pelos encontros (D1), como os 23 tópicos do Batismo: as aulas
/// que faltam entram em sequência (uma rodada de cada matéria, depois a
/// próxima) e são espalhadas por igual entre os encontros, os primeiros
/// levando a sobra (23 em 10 → 3,3,3,2,...). Um encontro nunca leva mais
/// aulas do que matérias ainda pendentes, e o horário dele é dividido entre
/// as aulas que recebeu. Encontro que já tem aula desta turma é pulado
/// (rodar de novo não duplica); encontro sem término ou com menos de 1 min
/// por aula também.
List<PlannedRow> planEventLessons({
  required List<CourseSubject> subjects,
  required List<StudyLesson> lessons,
  required List<Event> events,
}) {
  var number = lessons.fold(
    0,
    (max, l) => l.lessonNumber > max ? l.lessonNumber : max,
  );
  final done = {
    for (final s in subjects)
      s.id: lessons.where((l) => l.subjectId == s.id).length,
  };
  final queue = <CourseSubject>[];
  for (var round = 0; ; round++) {
    final next = [
      for (final s in subjects)
        if (done[s.id]! + round < s.lessonCount) s,
    ];
    if (next.isEmpty) break;
    queue.addAll(next);
  }
  final used = {for (final l in lessons) ?l.eventId};
  final free = [
    for (final e in events)
      if (!used.contains(e.id) && e.endDate != null) e,
  ];
  final rows = <PlannedRow>[];
  var u = 0;
  for (var i = 0; i < free.length && u < queue.length; i++) {
    final left = queue.length - u, slots = free.length - i;
    final pending = {for (final s in queue.skip(u)) s.id}.length;
    final take = min(pending, (left + slots - 1) ~/ slots);
    final e = free[i];
    final slot = e.endDate!.difference(e.startDate).inMinutes ~/ take;
    if (slot < 1) continue;
    final start = e.startDate.hour * 60 + e.startDate.minute;
    for (var j = 0; j < take; j++) {
      final s = queue[u + j];
      final n = done[s.id] = done[s.id]! + 1;
      rows.add((
        lesson: (
          subject: s,
          lessonNumber: ++number,
          title: '${s.title} — $n/${s.lessonCount}',
          start: start + j * slot,
        ),
        date: DateTime(e.startDate.year, e.startDate.month, e.startDate.day),
        duration: slot,
        eventId: e.id,
      ));
    }
    u += take;
  }
  return rows;
}

/// Encontros (eventos tipo Aula) de hoje até daqui a um ano.
final upcomingAulaEventsProvider = FutureProvider.autoDispose<List<Event>>((
  ref,
) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final events = await ref
      .read(scheduleRepositoryProvider)
      .getEventsByDateRange(today, DateTime(now.year + 1, now.month, now.day));
  return [
    for (final e in events)
      // O encontro que as aulas de uma turma mantêm não recebe Distribuir.
      if (e.eventType == 'aula' && e.autoStudyGroupId == null) e,
  ];
});

/// Fim da última aula do bloco, em minutos desde 00:00.
int planEnd(List<PlannedLesson> planned, int duration) =>
    planned.isEmpty ? 0 : planned.last.start + duration;

enum TeacherSource { kept, subjectDefault, rotation, none }

/// Professor de cada aula do bloco, na ordem recebida:
/// 1. quem já está na aula ([current]) nunca muda;
/// 2. o padrão da matéria, se ainda está em [eligible];
/// 3. o resto, rodízio em [rotation]: sempre o menos usado no bloco,
///    empate pela ordem da lista (5 aulas, G/D/B → G, D, B, G, D).
/// Curso sem ministério passa [rotation] vazio e o resto fica sem professor.
List<({String? teacherId, TeacherSource source})> assignTeachers(
  List<({String? current, String? subjectDefault})> slots, {
  required Set<String> eligible,
  required List<String> rotation,
}) {
  final result = [
    for (final s in slots)
      if (s.current != null)
        (teacherId: s.current, source: TeacherSource.kept)
      else if (s.subjectDefault != null && eligible.contains(s.subjectDefault))
        (teacherId: s.subjectDefault, source: TeacherSource.subjectDefault)
      else
        (teacherId: null as String?, source: TeacherSource.none),
  ];
  if (rotation.isEmpty) return result;
  final uses = {for (final id in rotation) id: 0};
  for (final r in result) {
    final id = r.teacherId;
    if (uses.containsKey(id)) uses[id!] = uses[id]! + 1;
  }
  for (var i = 0; i < result.length; i++) {
    if (result[i].source != TeacherSource.none) continue;
    final pick = rotation.reduce((a, b) => uses[b]! < uses[a]! ? b : a);
    uses[pick] = uses[pick]! + 1;
    result[i] = (teacherId: pick, source: TeacherSource.rotation);
  }
  return result;
}

/// Ordem do bloco da Escala de ensino: data, horário, número; sem data no fim.
List<StudyLesson> lessonsInScheduleOrder(Iterable<StudyLesson> lessons) {
  return lessons.toList()..sort((a, b) {
    final da = a.scheduledDate, db = b.scheduledDate;
    if (da != db) {
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    }
    final ta = a.startTime ?? '99:99', tb = b.startTime ?? '99:99';
    if (ta != tb) return ta.compareTo(tb);
    return a.lessonNumber.compareTo(b.lessonNumber);
  });
}

/// "19:30" a partir de minutos desde 00:00.
String hhmm(int minutes) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(minutes ~/ 60)}:${two(minutes % 60)}';
}

/// Elegíveis e rodízio do curso: com ministério, os professores do
/// ministério nas duas coisas; sem ministério, qualquer membro é elegível
/// para o padrão da matéria, mas não há rodízio.
Future<({Map<String, String> names, List<String> rotation})> _teacherPool(
  WidgetRef ref,
  String courseId,
) async {
  final course = await ref.read(courseByIdProvider(courseId).future);
  final options = await ref.read(teacherOptionsProvider(courseId).future);
  return (
    names: {for (final o in options) o.id: o.name},
    rotation: course?.ministryId == null
        ? const <String>[]
        : [for (final o in options) o.id],
  );
}

/// Aulas (não arquivadas) dos encontros tipo Aula em [events] cujo curso é
/// do ministério [ministryId], por curso.
Future<Map<String, List<StudyLesson>>> ministryEventLessons(
  WidgetRef ref, {
  required String ministryId,
  required List<Event> events,
}) async {
  final repo = ref.read(studyGroupRepositoryProvider);
  final lessons = [
    for (final l in await repo.getLessonsByEvents([
      for (final e in events)
        if (e.eventType == 'aula') e.id,
    ]))
      if (l.status != LessonStatus.archived) l,
  ];
  final courseOf = await repo.getGroupCourseIds({
    for (final l in lessons) l.studyGroupId,
  });
  final byCourse = <String, List<StudyLesson>>{};
  for (final l in lessons) {
    final courseId = courseOf[l.studyGroupId];
    if (courseId == null) continue;
    final course = await ref.read(courseByIdProvider(courseId).future);
    if (course?.ministryId != ministryId) continue;
    byCourse.putIfAbsent(courseId, () => []).add(l);
  }
  return byCourse;
}

/// Gerador do ministério (D1, PR C): nos encontros tipo Aula com aulas de
/// curso deste ministério, a aula sem professor recebe um pela regra da
/// Escala de ensino (padrão da matéria → rodízio dos professores do
/// ministério), num rodízio só por curso em todo o período. Quem já está
/// na aula não muda. A escala do evento acompanha pelo banco (trigger da
/// 20261006000100). Devolve os encontros tratados aqui — o gerador por
/// função não deve mexer neles — e quantas aulas ficaram sem professor.
Future<({Set<String> eventIds, int lessons, int filled, int missing})>
fillMinistryEventTeachers(
  WidgetRef ref, {
  required String ministryId,
  required List<Event> events,
}) async {
  final byCourse = await ministryEventLessons(
    ref,
    ministryId: ministryId,
    events: events,
  );
  final repo = ref.read(studyGroupRepositoryProvider);
  var total = 0, filled = 0, missing = 0;
  for (final MapEntry(key: courseId, value: lessons) in byCourse.entries) {
    final subjects = await ref.read(courseSubjectsProvider(courseId).future);
    final defaults = {for (final s in subjects) s.id: s.defaultTeacherId};
    final pool = await _teacherPool(ref, courseId);
    final block = lessonsInScheduleOrder(lessons);
    final result = assignTeachers(
      [
        for (final l in block)
          (current: l.teacherId, subjectDefault: defaults[l.subjectId]),
      ],
      eligible: pool.names.keys.toSet(),
      rotation: pool.rotation,
    );
    total += block.length;
    for (var i = 0; i < block.length; i++) {
      final r = result[i];
      if (r.source == TeacherSource.none) {
        missing++;
      } else if (r.source != TeacherSource.kept) {
        await repo.setLessonTeacher(block[i].id, r.teacherId);
        invalidateTurmaLessons(ref, block[i].studyGroupId);
        filled++;
      }
    }
  }
  return (
    eventIds: {
      for (final lessons in byCourse.values)
        for (final l in lessons) l.eventId!,
    },
    lessons: total,
    filled: filled,
    missing: missing,
  );
}

/// Encontros tipo Aula criados na Agenda (não os que as aulas mantêm) que
/// ainda não têm aula de nenhuma turma: o gerador distribui neles.
Future<List<Event>> emptyAgendaEncounters(
  WidgetRef ref,
  List<Event> events,
) async {
  final agenda = [
    for (final e in events)
      if (e.eventType == 'aula' && e.autoStudyGroupId == null) e,
  ];
  if (agenda.isEmpty) return const [];
  final used = {
    for (final l
        in await ref.read(studyGroupRepositoryProvider).getLessonsByEvents([
          for (final e in agenda) e.id,
        ]))
      ?l.eventId,
  };
  return [
    for (final e in agenda)
      if (!used.contains(e.id)) e,
  ];
}

/// Turmas ativas de cursos do ministério (candidatas do gerador).
Future<List<CourseTurma>> ministryActiveTurmas(
  WidgetRef ref,
  String ministryId,
) async {
  final turmas = <CourseTurma>[];
  for (final t in await ref.read(formacaoTurmasProvider.future)) {
    final courseId = t.courseId;
    if (t.status != StudyGroupStatus.active || courseId == null) continue;
    final course = await ref.read(courseByIdProvider(courseId).future);
    if (course?.ministryId == ministryId) turmas.add(t);
  }
  return turmas;
}

/// O Distribuir "Nos encontros" feito pelo gerador: cria em [encounters]
/// as aulas que faltam da [turma], em sequência, como rascunho e sem
/// professor (o gerador preenche logo depois). Devolve quantas criou.
Future<int> distributeIntoEncounters(
  WidgetRef ref, {
  required CourseTurma turma,
  required List<Event> encounters,
}) async {
  final repo = ref.read(studyGroupRepositoryProvider);
  final rows = planEventLessons(
    subjects: await ref.read(courseSubjectsProvider(turma.courseId!).future),
    lessons: await repo.getGroupLessons(turma.id),
    events: encounters,
  );
  for (final r in rows) {
    await repo.createLesson(
      studyGroupId: turma.id,
      lessonNumber: r.lesson.lessonNumber,
      title: r.lesson.title,
      scheduledDate: r.date,
      subjectId: r.lesson.subject.id,
      startTime: hhmm(r.lesson.start),
      durationMinutes: r.duration,
      eventId: r.eventId,
    );
  }
  if (rows.isNotEmpty) invalidateTurmaLessons(ref, turma.id);
  return rows.length;
}

String _teacherLabel(WidgetRef ref, Map<String, String> names, String? id) =>
    id == null ? 'sem professor' : names[id] ?? memberNameById(ref, id) ?? '…';

/// Abre o Distribuir; se criou aulas, recarrega a turma.
Future<void> openDistributeLessons(
  BuildContext context,
  WidgetRef ref, {
  required String studyGroupId,
  required String courseId,
  required List<StudyLesson> lessons,
}) async {
  final saved = await showTurmaSheet<bool>(
    context: context,
    builder: (_) => DistributeLessonsSheet(
      studyGroupId: studyGroupId,
      courseId: courseId,
      lessons: lessons,
    ),
  );
  if (saved == true) invalidateTurmaLessons(ref, studyGroupId);
}

/// Cria, a partir das matérias do curso, as aulas que faltam na turma,
/// num bloco de uma data só. Cada aula nasce rascunho com data, início,
/// duração, matéria e o professor previsto.
class DistributeLessonsSheet extends ConsumerStatefulWidget {
  final String studyGroupId;
  final String courseId;
  final List<StudyLesson> lessons;

  const DistributeLessonsSheet({
    super.key,
    required this.studyGroupId,
    required this.courseId,
    required this.lessons,
  });

  @override
  ConsumerState<DistributeLessonsSheet> createState() =>
      _DistributeLessonsSheetState();
}

class _DistributeLessonsSheetState
    extends ConsumerState<DistributeLessonsSheet> {
  final _duration = TextEditingController();
  final _interval = TextEditingController(text: '0');
  DateTime? _date;
  TimeOfDay? _start;
  bool _saving = false;
  String? _error;

  /// Nos encontros (eventos tipo Aula) em vez de numa data.
  bool _byEvent = false;
  String? _eventId;
  bool _wholeSeries = true;

  /// Criou parte e falhou: a lista de aulas desta folha ficou velha, e
  /// Aplicar de novo duplicaria. Só reabrindo.
  bool _stale = false;

  @override
  void dispose() {
    _duration.dispose();
    _interval.dispose();
    super.dispose();
  }

  int? _minutes(TextEditingController c, {required int min}) {
    final n = int.tryParse(c.text.trim());
    return n == null || n < min || n > 600 ? null : n;
  }

  Future<void> _apply(
    List<PlannedRow> rows,
    List<({String? teacherId, TeacherSource source})> teachers,
  ) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(studyGroupRepositoryProvider);
    var created = 0;
    try {
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i];
        await repo.createLesson(
          studyGroupId: widget.studyGroupId,
          lessonNumber: r.lesson.lessonNumber,
          title: r.lesson.title,
          scheduledDate: r.date,
          subjectId: r.lesson.subject.id,
          teacherId: teachers[i].teacherId,
          startTime: hhmm(r.lesson.start),
          durationMinutes: r.duration,
          eventId: r.eventId,
        );
        created++;
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      // Distribuir de novo cria só o que ainda falta.
      if (created > 0) invalidateTurmaLessons(ref, widget.studyGroupId);
      setState(() {
        _saving = false;
        _stale = created > 0;
        _error =
            'Parou em $created de ${rows.length} aulas: $error. '
            'Feche e toque em Distribuir de novo para criar o resto.';
      });
    }
  }

  /// Encontros escolhidos: o encontro e, com "série", os seguintes dela.
  List<Event> _occurrences(List<Event> all) {
    final picked = all.where((e) => e.id == _eventId).firstOrNull;
    if (picked == null) return const [];
    if (!_wholeSeries || picked.batchId == null) return [picked];
    return [
      for (final e in all)
        if (e.batchId == picked.batchId &&
            !e.startDate.isBefore(picked.startDate))
          e,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(courseSubjectsProvider(widget.courseId));
    final optionsAsync = ref.watch(teacherOptionsProvider(widget.courseId));
    final eventsAsync = _byEvent
        ? ref.watch(upcomingAulaEventsProvider)
        : const AsyncValue<List<Event>>.data([]);
    final course = ref.watch(courseByIdProvider(widget.courseId)).valueOrNull;
    final date = _date;
    final start = _start;
    final duration = _minutes(_duration, min: 1);
    final interval = _minutes(_interval, min: 0);
    final events = eventsAsync.valueOrNull;
    final picked = events?.where((e) => e.id == _eventId).firstOrNull;

    Widget preview;
    VoidCallback? onApply;
    final subjects = subjectsAsync.valueOrNull;
    final options = optionsAsync.valueOrNull;
    if (subjects == null || options == null || events == null) {
      preview =
          subjectsAsync.hasError ||
              optionsAsync.hasError ||
              eventsAsync.hasError
          ? const Text(
              'Não foi possível carregar as matérias, os professores ou os '
              'encontros.',
            )
          : const Center(child: CircularProgressIndicator());
    } else if (subjects.isEmpty) {
      preview = const Text(
        'O curso não tem matérias. Cadastre-as na tela do curso, em Matérias.',
      );
    } else if (_byEvent && events.isEmpty) {
      preview = const Text(
        'Não há encontros do tipo Aula no próximo ano. Crie o evento na '
        'Agenda com o tipo "Aula" (pode ser recorrente) e volte aqui.',
      );
    } else if (_byEvent && picked == null) {
      preview = Text(
        'Escolha o encontro para ver a prévia.',
        style: CommunityDesign.metaStyle(context),
      );
    } else if (!_byEvent &&
        (date == null ||
            start == null ||
            duration == null ||
            interval == null)) {
      preview = Text(
        'Preencha data, início, duração (1 a 600 min) e intervalo (0 a 600 '
        'min) para ver a prévia.',
        style: CommunityDesign.metaStyle(context),
      );
    } else {
      final List<PlannedRow> rows = _byEvent
          ? planEventLessons(
              subjects: subjects,
              lessons: widget.lessons,
              events: _occurrences(events),
            )
          : [
              for (final p in planLessons(
                subjects: subjects,
                lessons: widget.lessons,
                start: start!.hour * 60 + start.minute,
                duration: duration!,
                interval: interval!,
              ))
                (lesson: p, date: date!, duration: duration, eventId: null),
            ];
      final names = {for (final o in options) o.id: o.name};
      final teachers = assignTeachers(
        [
          for (final r in rows)
            (current: null, subjectDefault: r.lesson.subject.defaultTeacherId),
        ],
        eligible: names.keys.toSet(),
        rotation: course?.ministryId == null ? const [] : names.keys.toList(),
      );
      if (rows.isEmpty) {
        preview = Text(
          _byEvent
              ? 'Nada a criar: as matérias já têm todas as aulas, ou os '
                    'encontros já têm aula desta turma ou não têm horário de '
                    'término.'
              : 'Nada a criar: a turma já tem as aulas de todas as matérias.',
        );
      } else if (!_byEvent &&
          planEnd([for (final r in rows) r.lesson], duration!) > 24 * 60) {
        preview = Text(
          'As ${rows.length} aulas passariam da meia-noite. Comece mais '
          'cedo ou diminua a duração ou o intervalo.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        );
      } else {
        if (!_stale) onApply = () => _apply(rows, teachers);
        preview = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${rows.length} '
              '${rows.length == 1 ? 'aula será criada' : 'aulas serão criadas'}'
              ', como rascunho:',
              style: CommunityDesign.metaStyle(
                context,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < rows.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${DateFormat('dd/MM').format(rows[i].date)} '
                  '${hhmm(rows[i].lesson.start)}–'
                  '${hhmm(rows[i].lesson.start + rows[i].duration)} · '
                  'Aula ${rows[i].lesson.lessonNumber} · '
                  '${rows[i].lesson.title} · '
                  '${_teacherLabel(ref, names, teachers[i].teacherId)}',
                ),
              ),
          ],
        );
      }
    }

    return TurmaSheetBody(
      title: 'Distribuir aulas',
      children: [
        Text(
          'Cria, para cada matéria do curso, as aulas que ainda faltam nesta '
          'turma. Nenhuma aula existente é alterada.',
          style: CommunityDesign.metaStyle(context),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          key: const ValueKey('distribute-mode'),
          segments: const [
            ButtonSegment(value: false, label: Text('Numa data')),
            ButtonSegment(value: true, label: Text('Nos encontros')),
          ],
          selected: {_byEvent},
          onSelectionChanged: _saving
              ? null
              : (v) => setState(() => _byEvent = v.first),
        ),
        const SizedBox(height: 12),
        if (_byEvent) ...[
          Text(
            'As aulas que faltam são espalhadas em sequência pelos encontros '
            '(eventos tipo Aula), por igual: 23 matérias em 10 encontros '
            'dão 2 ou 3 por encontro, e o horário dele é dividido entre '
            'elas. O professor entra na escala do evento.',
            style: CommunityDesign.metaStyle(context),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('distribute-event'),
            initialValue: picked?.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Encontro *'),
            items: [
              for (final e in events ?? const <Event>[])
                DropdownMenuItem(
                  value: e.id,
                  child: Text(
                    '${DateFormat('dd/MM HH:mm').format(e.startDate)}'
                    '${e.endDate == null ? '' : '–${DateFormat('HH:mm').format(e.endDate!)}'}'
                    ' · ${e.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _saving ? null : (v) => setState(() => _eventId = v),
          ),
          if (picked?.batchId != null)
            SwitchListTile(
              key: const ValueKey('distribute-series'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Este e os próximos encontros da série'),
              value: _wholeSeries,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _wholeSeries = v),
            ),
        ],
        if (!_byEvent) ...[
          InkWell(
            key: const ValueKey('distribute-date'),
            onTap: _saving
                ? null
                : () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date ?? now,
                      firstDate: DateTime(now.year - 5),
                      lastDate: DateTime(now.year + 5),
                      helpText: 'Data das aulas',
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Data *'),
              child: Text(
                date == null ? '—' : DateFormat('dd/MM/yyyy').format(date),
              ),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            key: const ValueKey('distribute-start'),
            onTap: _saving
                ? null
                : () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime:
                          start ?? const TimeOfDay(hour: 19, minute: 30),
                      helpText: 'Início da primeira aula',
                    );
                    if (picked != null) setState(() => _start = picked);
                  },
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Início *'),
              child: Text(
                start == null ? '—' : hhmm(start.hour * 60 + start.minute),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('distribute-duration'),
                  controller: _duration,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Duração por aula (min) *',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const ValueKey('distribute-interval'),
                  controller: _interval,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Intervalo (min)',
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        preview,
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 20),
        _SheetActions(saving: _saving, onApply: onApply),
      ],
    );
  }
}

/// Abre a Escala de ensino; se gravou, recarrega a turma.
Future<void> openTeachingSchedule(
  BuildContext context,
  WidgetRef ref, {
  required String studyGroupId,
  required String courseId,
  required List<StudyLesson> lessons,
}) async {
  final saved = await showTurmaSheet<bool>(
    context: context,
    builder: (_) => TeachingScheduleSheet(courseId: courseId, lessons: lessons),
  );
  if (saved != true) return;
  invalidateTurmaLessons(ref, studyGroupId);
  for (final l in lessons) {
    ref.invalidate(lessonByIdProvider(l.id));
  }
}

/// Preenche o professor das aulas não arquivadas da turma que estão sem
/// professor (padrão da matéria, depois rodízio). Nunca troca quem já está.
class TeachingScheduleSheet extends ConsumerStatefulWidget {
  final String courseId;
  final List<StudyLesson> lessons;

  const TeachingScheduleSheet({
    super.key,
    required this.courseId,
    required this.lessons,
  });

  @override
  ConsumerState<TeachingScheduleSheet> createState() =>
      _TeachingScheduleSheetState();
}

class _TeachingScheduleSheetState extends ConsumerState<TeachingScheduleSheet> {
  late final Future<({Map<String, String> names, List<String> rotation})>
  _pool = _teacherPool(ref, widget.courseId);
  bool _saving = false;
  String? _error;

  /// Refaz o professor das aulas de hoje em diante (e sem data).
  bool _redistribute = false;

  Future<void> _apply(List<(StudyLesson, String)> changes) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(studyGroupRepositoryProvider);
    var done = 0;
    try {
      for (final (lesson, teacherId) in changes) {
        await repo.setLessonTeacher(lesson.id, teacherId);
        done++;
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            'Parou em $done de ${changes.length} aulas: $error. Feche e '
            'abra a Escala de novo: ela só preenche o que ainda falta.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects =
        ref.watch(courseSubjectsProvider(widget.courseId)).valueOrNull ??
        const <CourseSubject>[];
    final defaults = {for (final s in subjects) s.id: s.defaultTeacherId};
    final block = lessonsInScheduleOrder(
      widget.lessons.where((l) => l.status != LessonStatus.archived),
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool reopen(StudyLesson l) =>
        _redistribute && !(l.scheduledDate?.isBefore(today) ?? false);

    return FutureBuilder(
      future: _pool,
      builder: (context, snapshot) {
        final pool = snapshot.data;
        Widget preview;
        VoidCallback? onApply;
        if (snapshot.hasError) {
          preview = const Text('Não foi possível carregar os professores.');
        } else if (pool == null) {
          preview = const Center(child: CircularProgressIndicator());
        } else if (block.isEmpty) {
          preview = const Text('A turma não tem aulas para escalar.');
        } else {
          final result = assignTeachers(
            [
              for (final l in block)
                (
                  current: reopen(l) ? null : l.teacherId,
                  subjectDefault: defaults[l.subjectId],
                ),
            ],
            eligible: pool.names.keys.toSet(),
            rotation: pool.rotation,
          );
          int count(TeacherSource s) =>
              result.where((r) => r.source == s).length;
          final changes = [
            for (var i = 0; i < block.length; i++)
              if ((result[i].source == TeacherSource.subjectDefault ||
                      result[i].source == TeacherSource.rotation) &&
                  result[i].teacherId != block[i].teacherId)
                (block[i], result[i].teacherId!),
          ];
          if (changes.isNotEmpty) onApply = () => _apply(changes);
          const sourceLabel = {
            TeacherSource.kept: 'já estava',
            TeacherSource.subjectDefault: 'padrão da matéria',
            TeacherSource.rotation: 'rodízio',
            TeacherSource.none: 'sem professor',
          };
          preview = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                [
                  '${block.length} aulas analisadas',
                  '${count(TeacherSource.kept)} já têm professor',
                  '${count(TeacherSource.subjectDefault)} professor padrão',
                  '${count(TeacherSource.rotation)} por rodízio',
                  if (count(TeacherSource.none) > 0)
                    '${count(TeacherSource.none)} sem professor',
                ].join(' · '),
                style: CommunityDesign.metaStyle(
                  context,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              if (pool.rotation.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    pool.names.isEmpty
                        ? 'Nenhum integrante do ministério tem a função '
                              'Professor: não há rodízio.'
                        : 'Curso sem ministério: só entra o professor padrão '
                              'da matéria.',
                    style: CommunityDesign.metaStyle(context),
                  ),
                ),
              const SizedBox(height: 8),
              for (var i = 0; i < block.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    [
                      'Aula ${block[i].lessonNumber}',
                      if (block[i].scheduledDate != null)
                        DateFormat('dd/MM').format(block[i].scheduledDate!),
                      ?block[i].timeRange,
                      '${_teacherLabel(ref, pool.names, result[i].teacherId)}'
                          ' (${sourceLabel[result[i].source]})',
                    ].join(' · '),
                  ),
                ),
            ],
          );
        }
        return TurmaSheetBody(
          title: 'Escala de ensino',
          children: [
            Text(
              'Preenche o professor das aulas sem professor: primeiro o '
              'padrão da matéria, depois um rodízio equilibrado entre os '
              'professores do ministério. Quem já está na aula não muda.',
              style: CommunityDesign.metaStyle(context),
            ),
            SwitchListTile(
              key: const ValueKey('teaching-redistribute'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Redistribuir as aulas futuras'),
              subtitle: const Text(
                'Refaz o rodízio das aulas de hoje em diante, inclusive as '
                'que já têm professor. Aulas passadas não mudam.',
              ),
              value: _redistribute,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _redistribute = v),
            ),
            const SizedBox(height: 8),
            preview,
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            _SheetActions(saving: _saving, onApply: onApply),
          ],
        );
      },
    );
  }
}

class _SheetActions extends StatelessWidget {
  final bool saving;
  final VoidCallback? onApply;

  const _SheetActions({required this.saving, required this.onApply});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          key: const ValueKey('teaching-apply'),
          onPressed: saving ? null : onApply,
          child: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Aplicar'),
        ),
      ],
    );
  }
}
