import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/community_design.dart';
import '../../../study_groups/domain/models/study_group.dart';
import '../../../study_groups/presentation/providers/study_group_provider.dart';
import '../../domain/models/course_subject.dart';
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
    List<PlannedLesson> planned,
    List<({String? teacherId, TeacherSource source})> teachers,
    int duration,
  ) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(studyGroupRepositoryProvider);
    var created = 0;
    try {
      for (var i = 0; i < planned.length; i++) {
        final p = planned[i];
        await repo.createLesson(
          studyGroupId: widget.studyGroupId,
          lessonNumber: p.lessonNumber,
          title: p.title,
          scheduledDate: _date,
          subjectId: p.subject.id,
          teacherId: teachers[i].teacherId,
          startTime: hhmm(p.start),
          durationMinutes: duration,
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
            'Parou em $created de ${planned.length} aulas: $error. '
            'Feche e toque em Distribuir de novo para criar o resto.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(courseSubjectsProvider(widget.courseId));
    final optionsAsync = ref.watch(teacherOptionsProvider(widget.courseId));
    final course = ref.watch(courseByIdProvider(widget.courseId)).valueOrNull;
    final date = _date;
    final start = _start;
    final duration = _minutes(_duration, min: 1);
    final interval = _minutes(_interval, min: 0);

    Widget preview;
    VoidCallback? onApply;
    final subjects = subjectsAsync.valueOrNull;
    final options = optionsAsync.valueOrNull;
    if (subjects == null || options == null) {
      preview = subjectsAsync.hasError || optionsAsync.hasError
          ? const Text(
              'Não foi possível carregar as matérias e os professores.',
            )
          : const Center(child: CircularProgressIndicator());
    } else if (subjects.isEmpty) {
      preview = const Text(
        'O curso não tem matérias. Cadastre-as na tela do curso, em Matérias.',
      );
    } else if (date == null ||
        start == null ||
        duration == null ||
        interval == null) {
      preview = Text(
        'Preencha data, início, duração (1 a 600 min) e intervalo (0 a 600 '
        'min) para ver a prévia.',
        style: CommunityDesign.metaStyle(context),
      );
    } else {
      final planned = planLessons(
        subjects: subjects,
        lessons: widget.lessons,
        start: start.hour * 60 + start.minute,
        duration: duration,
        interval: interval,
      );
      final names = {for (final o in options) o.id: o.name};
      final teachers = assignTeachers(
        [
          for (final p in planned)
            (current: null, subjectDefault: p.subject.defaultTeacherId),
        ],
        eligible: names.keys.toSet(),
        rotation: course?.ministryId == null ? const [] : names.keys.toList(),
      );
      if (planned.isEmpty) {
        preview = const Text(
          'Nada a criar: a turma já tem as aulas de todas as matérias.',
        );
      } else if (planEnd(planned, duration) > 24 * 60) {
        preview = Text(
          'As ${planned.length} aulas passariam da meia-noite. Comece mais '
          'cedo ou diminua a duração ou o intervalo.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        );
      } else {
        if (!_stale) onApply = () => _apply(planned, teachers, duration);
        preview = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${planned.length} '
              '${planned.length == 1 ? 'aula será criada' : 'aulas serão criadas'}'
              ' em ${DateFormat('dd/MM/yyyy').format(date)}, como rascunho:',
              style: CommunityDesign.metaStyle(
                context,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < planned.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${hhmm(planned[i].start)}–'
                  '${hhmm(planned[i].start + duration)} · '
                  'Aula ${planned[i].lessonNumber} · ${planned[i].title} · '
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
          'turma, uma depois da outra. Nenhuma aula existente é alterada.',
          style: CommunityDesign.metaStyle(context),
        ),
        const SizedBox(height: 12),
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
                    initialTime: start ?? const TimeOfDay(hour: 19, minute: 30),
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
                decoration: const InputDecoration(labelText: 'Intervalo (min)'),
              ),
            ),
          ],
        ),
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
                (current: l.teacherId, subjectDefault: defaults[l.subjectId]),
            ],
            eligible: pool.names.keys.toSet(),
            rotation: pool.rotation,
          );
          int count(TeacherSource s) =>
              result.where((r) => r.source == s).length;
          final changes = [
            for (var i = 0; i < block.length; i++)
              if (result[i].source == TeacherSource.subjectDefault ||
                  result[i].source == TeacherSource.rotation)
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
