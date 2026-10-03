import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/utils/name_sort.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../../members/presentation/providers/members_provider.dart';
import '../../../../study_groups/domain/models/study_group.dart';
import '../../../../study_groups/presentation/providers/study_group_provider.dart';
import '../turma_access.dart';
import '../turma_origin.dart';
import '../widgets/turma_sheet.dart';
import 'turma_surfaces.dart';

/// Superfícies da turma genérica: participantes (com a contagem de
/// presença de cada um), a chamada dentro da aula e a frequência do próprio
/// aluno.
///
/// Semântica própria, **sem as regras do Batismo**: contagem crua por
/// status (presentes, faltas, justificadas), participante sem linha é "—",
/// sem percentual.
class GenericaTurmaAdapter implements TurmaSurfaces {
  final GenericaTurmaOrigin origin;
  final TurmaAccess access;

  const GenericaTurmaAdapter(this.origin, this.access);

  @override
  Widget alunos() =>
      GenericaParticipantes(studyGroupId: origin.studyGroupId, access: access);

  @override
  Widget minhaFrequencia() =>
      GenericaMinhaFrequencia(studyGroupId: origin.studyGroupId);

  /// A chamada fica na aba Presença da aula, como no Batismo.
  ///
  /// Só o líder ativo do grupo grava (`study_lesson_led_by_me`); o elevado
  /// só lê. Quem é liderança só por `courses.*` não enxerga a presença pela
  /// RLS — uma chamada vazia diria que ninguém foi marcado, então recebe um
  /// aviso. Na vitrine de Cursos também não há chamada.
  @override
  Widget lessonPresence(StudyLesson lesson) {
    if (access.isStudent) {
      return _MyLessonPresence(
        studyGroupId: origin.studyGroupId,
        lessonId: lesson.id,
      );
    }
    if (access.readOnly) {
      return const TurmaMessage(
        icon: AppIcons.lock,
        message: 'A chamada é feita em Gerenciar.',
      );
    }
    if (!access.leadsGroup && !access.elevated) {
      return const TurmaMessage(
        icon: AppIcons.lock,
        message: 'A chamada é feita pelo líder da turma.',
      );
    }
    return _LessonRoll(
      studyGroupId: origin.studyGroupId,
      lesson: lesson,
      canMark: access.leadsGroup,
    );
  }

  /// A turma genérica não tem ministério: a gestão dela é esta mesma tela,
  /// pela porta que grava.
  @override
  TurmaManageTarget? get manage =>
      (label: 'Gerenciar', route: '/turmas/${origin.studyGroupId}/gestao');
}

/// Contagem crua de presença.
class GenericaAttendanceCount {
  final int present;
  final int absent;
  final int justified;

  const GenericaAttendanceCount({
    required this.present,
    required this.absent,
    required this.justified,
  });

  factory GenericaAttendanceCount.of(Iterable<AttendanceStatus> statuses) {
    var present = 0, absent = 0, justified = 0;
    for (final s in statuses) {
      switch (s) {
        case AttendanceStatus.present:
          present++;
        case AttendanceStatus.absent:
          absent++;
        case AttendanceStatus.justified:
          justified++;
      }
    }
    return GenericaAttendanceCount(
      present: present,
      absent: absent,
      justified: justified,
    );
  }

  String get label =>
      '$present presentes · $absent faltas · $justified justificadas';
}

/// A contagem de cada participante somando as chamadas de várias aulas.
/// Chave: `study_attendance.user_id`.
Map<String, GenericaAttendanceCount> genericaCountsByUser(
  Iterable<StudyAttendance> rows,
) {
  final byUser = <String, List<AttendanceStatus>>{};
  for (final r in rows) {
    byUser.putIfAbsent(r.userId, () => []).add(r.status);
  }
  return {
    for (final e in byUser.entries) e.key: GenericaAttendanceCount.of(e.value),
  };
}

/// Nome de quem participa, pelo diretório de membros do tenant.
///
/// `study_participants.user_id` é `auth.uid()`; o diretório é por
/// `user_account.id`. Quando as duas chaves não coincidem o nome não é
/// achado e a linha diz "Participante".
final genericaParticipantNamesProvider = FutureProvider<Map<String, String>>((
  ref,
) async {
  final directory = await ref.watch(memberDirectoryProvider.future);
  return {for (final m in directory) m.id: m.displayName};
});

String _nameOf(Map<String, String> names, String userId) =>
    names[userId] ?? 'Participante';

/// Em ordem alfabética pelo nome que a tela vai mostrar.
List<StudyParticipant> _byName(
  Iterable<StudyParticipant> list,
  Map<String, String> names,
) => list.toList()
  ..sort(
    (a, b) => compareNames(_nameOf(names, a.userId), _nameOf(names, b.userId)),
  );

/// Participantes ativos que são alunos (sem líder e co-líder).
List<StudyParticipant> genericaStudents(List<StudyParticipant> all) => [
  for (final p in all)
    if (p.isActive && p.role == ParticipantRole.participant) p,
];

// ---------------------------------------------------------------------
// Alunos
// ---------------------------------------------------------------------

class GenericaParticipantes extends ConsumerWidget {
  final String studyGroupId;
  final TurmaAccess access;

  const GenericaParticipantes({
    super.key,
    required this.studyGroupId,
    required this.access,
  });

  /// Presença de cada participante em todas as aulas não arquivadas.
  ///
  /// Só quem enxerga a chamada pela RLS (líder do grupo ou elevado) recebe
  /// a contagem; para os demais o mapa fica vazio e a linha não diz nada,
  /// em vez de dizer "0 presentes".
  Map<String, GenericaAttendanceCount> _counts(WidgetRef ref) {
    if (!access.leadsGroup && !access.elevated) return const {};
    final lessons = ref.watch(groupLessonsProvider(studyGroupId)).valueOrNull;
    if (lessons == null) return const {};
    return genericaCountsByUser([
      for (final l in lessons)
        if (l.status != LessonStatus.archived)
          ...?ref.watch(lessonAttendanceProvider(l.id)).valueOrNull,
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantsAsync = ref.watch(
      groupParticipantsProvider(studyGroupId),
    );
    final names =
        ref.watch(genericaParticipantNamesProvider).valueOrNull ?? const {};
    final meta = CommunityDesign.metaStyle(context);
    final counts = _counts(ref);

    return participantsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => TurmaMessage.error(
        message: 'Não foi possível carregar os participantes.',
        onRetry: () => ref.invalidate(groupParticipantsProvider(studyGroupId)),
      ),
      data: (participants) {
        final active = _byName(participants.where((p) => p.isActive), names);
        if (active.isEmpty) {
          return const TurmaMessage(
            icon: AppIcons.student,
            message: 'Nenhum participante nesta turma ainda.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Text(
              '${active.length} '
              '${active.length == 1 ? 'participante' : 'participantes'}',
              style: meta,
            ),
            const SizedBox(height: 12),
            for (final p in active)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_nameOf(names, p.userId)),
                            if (p.role == ParticipantRole.participant &&
                                counts[p.userId] != null)
                              Text(counts[p.userId]!.label, style: meta),
                          ],
                        ),
                      ),
                      Text(p.role.displayName, style: meta),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------
// Presença
// ---------------------------------------------------------------------

/// A chamada de uma aula, na aba Presença: carrega o que já foi marcado e
/// entrega a lista.
class _LessonRoll extends ConsumerWidget {
  final String studyGroupId;
  final StudyLesson lesson;
  final bool canMark;

  const _LessonRoll({
    required this.studyGroupId,
    required this.lesson,
    required this.canMark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(lessonAttendanceProvider(lesson.id))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => TurmaMessage.error(
            message: 'Não foi possível carregar a chamada.',
            onRetry: () => ref.invalidate(lessonAttendanceProvider(lesson.id)),
          ),
          // Chave pelas linhas: depois de salvar, a chamada recarregada
          // recomeça do banco (senão a próxima gravação inseriria de novo).
          data: (rows) => _Roll(
            key: ObjectKey(rows),
            studyGroupId: studyGroupId,
            lesson: lesson,
            existing: rows,
            canMark: canMark,
          ),
        );
  }
}

/// A chamada de uma aula. Toque escolhe o status; nada vai ao banco até
/// "Salvar". Participante sem marca fica sem linha ("—").
class _Roll extends ConsumerStatefulWidget {
  final String studyGroupId;
  final StudyLesson lesson;
  final List<StudyAttendance> existing;
  final bool canMark;

  const _Roll({
    super.key,
    required this.studyGroupId,
    required this.lesson,
    required this.existing,
    required this.canMark,
  });

  @override
  ConsumerState<_Roll> createState() => _RollState();
}

class _RollState extends ConsumerState<_Roll> {
  late final Map<String, StudyAttendance> _byUser = {
    for (final a in widget.existing) a.userId: a,
  };
  late final Map<String, AttendanceStatus> _marks = {
    for (final a in widget.existing) a.userId: a.status,
  };
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(studyGroupRepositoryProvider);
    try {
      for (final entry in _marks.entries) {
        final current = _byUser[entry.key];
        if (current == null) {
          await repo.markAttendance(
            lessonId: widget.lesson.id,
            userId: entry.key,
            status: entry.value,
          );
        } else if (current.status != entry.value) {
          await repo.updateAttendance(current.id, status: entry.value);
        }
      }
      ref.invalidate(lessonAttendanceProvider(widget.lesson.id));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Presença salva.')));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Não foi possível salvar: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final participantsAsync = ref.watch(
      groupParticipantsProvider(widget.studyGroupId),
    );
    final names =
        ref.watch(genericaParticipantNamesProvider).valueOrNull ?? const {};
    final meta = CommunityDesign.metaStyle(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        participantsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) =>
              Text('Não foi possível carregar os participantes.', style: meta),
          data: (all) {
            final students = _byName(genericaStudents(all), names);
            if (students.isEmpty) {
              return Text('Nenhum participante nesta turma.', style: meta);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final p in students)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_nameOf(names, p.userId)),
                        const SizedBox(height: 4),
                        if (widget.canMark)
                          Wrap(
                            spacing: 6,
                            children: [
                              for (final s in AttendanceStatus.values)
                                ChoiceChip(
                                  key: ValueKey('roll-${p.userId}-${s.value}'),
                                  label: Text(s.displayName),
                                  selected: _marks[p.userId] == s,
                                  onSelected: _saving
                                      ? null
                                      : (_) => setState(
                                          () => _marks[p.userId] = s,
                                        ),
                                ),
                            ],
                          )
                        else
                          Text(
                            _marks[p.userId]?.displayName ?? '—',
                            style: meta,
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (widget.canMark) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Salvar'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Minha frequência
// ---------------------------------------------------------------------

/// A própria presença do aluno em cada aula publicada.
final genericaMyAttendanceProvider =
    FutureProvider.family<Map<String, AttendanceStatus>, String>((
      ref,
      studyGroupId,
    ) async {
      final lessons = await ref.watch(
        publishedLessonsProvider(studyGroupId).future,
      );
      final repo = ref.watch(studyGroupRepositoryProvider);
      final rows = await repo.getMyAttendanceForLessons([
        for (final l in lessons) l.id,
      ]);
      return {for (final r in rows) r.studyLessonId: r.status};
    });

/// A marca do próprio aluno numa aula.
class _MyLessonPresence extends ConsumerWidget {
  final String studyGroupId;
  final String lessonId;

  const _MyLessonPresence({required this.studyGroupId, required this.lessonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(genericaMyAttendanceProvider(studyGroupId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => TurmaMessage.error(
            message: 'Não foi possível carregar sua presença.',
            onRetry: () =>
                ref.invalidate(genericaMyAttendanceProvider(studyGroupId)),
          ),
          data: (marks) =>
              TurmaMyLessonPresence(status: marks[lessonId]?.displayName),
        );
  }
}

class GenericaMinhaFrequencia extends ConsumerWidget {
  final String studyGroupId;

  const GenericaMinhaFrequencia({super.key, required this.studyGroupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsAsync = ref.watch(publishedLessonsProvider(studyGroupId));
    final marksAsync = ref.watch(genericaMyAttendanceProvider(studyGroupId));
    final meta = CommunityDesign.metaStyle(context);

    if (lessonsAsync.isLoading || marksAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (lessonsAsync.hasError || marksAsync.hasError) {
      return TurmaMessage.error(
        message: 'Não foi possível carregar sua frequência.',
        onRetry: () {
          ref.invalidate(publishedLessonsProvider(studyGroupId));
          ref.invalidate(genericaMyAttendanceProvider(studyGroupId));
        },
      );
    }
    final lessons = lessonsAsync.value ?? const <StudyLesson>[];
    final marks = marksAsync.value ?? const <String, AttendanceStatus>{};
    if (lessons.isEmpty) {
      return const TurmaMessage(
        icon: AppIcons.study,
        message: 'Nenhuma aula publicada ainda.',
      );
    }
    final count = GenericaAttendanceCount.of(marks.values);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        GlassCard(
          child: Text(
            count.label,
            key: const ValueKey('generica-minha-frequencia-contagem'),
            style: CommunityDesign.titleStyle(
              context,
            ).copyWith(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
        for (final l in lessons)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(child: Text('Aula ${l.lessonNumber} · ${l.title}')),
                  Text(marks[l.id]?.displayName ?? '—', style: meta),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
