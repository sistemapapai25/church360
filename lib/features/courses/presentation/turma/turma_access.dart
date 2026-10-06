import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ministries/batismo/presentation/providers/baptism_providers.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../../study_groups/domain/models/study_group.dart';
import '../../../study_groups/presentation/providers/study_group_provider.dart';
import '../providers/courses_provider.dart';
import 'turma_origin.dart';

/// Quem eu sou nesta turma.
enum TurmaRole {
  /// Gestão: todas as aulas, Alunos, Presença.
  leadership,

  /// Área do aluno: aulas publicadas, Minha frequência, Materiais.
  student,

  /// Professor de uma aula (`study_lessons.teacher_id`), entrando pela
  /// Agenda: só aquela aula — conteúdo, a chamada dela e a anotação
  /// pessoal. Não vê a turma (PR 2c).
  teacher,

  /// Nada a ver aqui.
  none,
}

/// Papel na turma + o que ele pode fazer.
///
/// Espelha a RLS da etapa 4 (`20260925000600`) só para a tela decidir o que
/// mostrar. A autoridade continua sendo a policy.
class TurmaAccess {
  final TurmaRole role;

  /// Criar, editar, publicar e arquivar aula (`study_lessons` INSERT/UPDATE).
  final bool canWriteLessons;

  /// Líder ou co-líder ativo do grupo (só turma genérica). É a única porta
  /// de escrita em `study_attendance` (`study_lesson_led_by_me`): nem
  /// elevado nem `courses.*` marcam presença de turma genérica.
  final bool leadsGroup;

  /// `is_elevated_current_user()`. Na turma genérica lê a presença de
  /// todos (`study_attendance_select`), mas não escreve.
  final bool elevated;

  /// Aberta por uma porta que não grava (`TurmaMode.leitura`). A tela
  /// continua mostrando o que o papel enxerga; some tudo o que escreve.
  final bool readOnly;

  /// Também é aluno da turma (matrícula do Batismo ou participante ativo).
  /// Liderança que é aluno fica em liderança (decisão 24); na leitura a
  /// Presença da aula mostra só a marca dela.
  final bool enrolled;

  const TurmaAccess({
    required this.role,
    this.canWriteLessons = false,
    this.leadsGroup = false,
    this.elevated = false,
    this.readOnly = false,
    this.enrolled = false,
  });

  static const none = TurmaAccess(role: TurmaRole.none);
  static const student = TurmaAccess(role: TurmaRole.student);
  static const teacher = TurmaAccess(role: TurmaRole.teacher);

  /// O mesmo papel, sem nenhuma escrita.
  ///
  /// Derruba as duas portas de gravação da tela de uma vez:
  /// [canWriteLessons] (aula, e com ela o material da aula) e [leadsGroup]
  /// (presença da turma genérica). [elevated] fica de pé porque só abre
  /// leitura — a presença dos outros na turma genérica.
  TurmaAccess asReadOnly() => TurmaAccess(
    role: role,
    elevated: elevated,
    readOnly: true,
    enrolled: enrolled,
  );

  bool get isLeadership => role == TurmaRole.leadership;
  bool get isStudent => role == TurmaRole.student;
  bool get isTeacher => role == TurmaRole.teacher;
  bool get hasAccess => role != TurmaRole.none;
}

/// Participação do próprio usuário numa turma genérica, ou `null`.
///
/// `study_participants.user_id` é `auth.uid()`; o repositório já tenta as
/// duas chaves (`_candidateUserIds`).
final turmaMyParticipationProvider =
    FutureProvider.family<StudyParticipant?, String>((ref, studyGroupId) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) return null;
      final repository = ref.watch(studyGroupRepositoryProvider);
      return repository.getUserParticipation(studyGroupId, userId);
    });

/// Papel do usuário logado na turma.
///
/// Liderança que também é aluno fica em liderança (decisão 24).
final turmaAccessProvider = FutureProvider.family<TurmaAccess, String>((
  ref,
  studyGroupId,
) async {
  final origin = await ref.watch(turmaOriginProvider(studyGroupId).future);
  if (origin == null) return TurmaAccess.none;

  // Turma cancelada sai da vida do aluno: sem aulas, sem materiais, sem
  // atalho. Só a liderança continua enxergando (para consultar ou excluir).
  final turma = await ref.watch(turmaByIdProvider(studyGroupId).future);
  final cancelled = turma?.status == StudyGroupStatus.cancelled;
  final asStudent = cancelled ? TurmaAccess.none : TurmaAccess.student;

  final elevated = await ref.watch(currentUserIsElevatedProvider.future);
  Future<bool> can(String code) =>
      ref.watch(currentUserHasPermissionProvider(code).future);

  switch (origin) {
    case BatismoTurmaOrigin(:final ministryId):
      // study_group_leadership_allows, ramo Batismo:
      // ministries_user_can_see_all() OU (permissão E vínculo no ministério).
      final canSeeAll = await ref.watch(ministriesCanSeeAllProvider.future);
      final inMinistry = await ref.watch(
        ministryAccessProvider(ministryId).future,
      );
      final view = await can('baptism.view');
      // study_group_student_allows: matrícula ativa ou concluída.
      final enrollments = await ref.watch(myBaptismEnrollmentsProvider.future);
      final enrolled = enrollments.any((e) => e.studyGroupId == studyGroupId);
      final leadership = elevated || canSeeAll || (view && inMinistry);
      if (leadership) {
        final edit = await can('baptism.edit');
        final manageLessons = await can('courses.manage_lessons');
        return TurmaAccess(
          role: TurmaRole.leadership,
          canWriteLessons:
              elevated || canSeeAll || (edit && inMinistry) || manageLessons,
          enrolled: enrolled,
        );
      }
      return enrolled ? asStudent : TurmaAccess.none;

    case GenericaTurmaOrigin():
      final participation = await ref.watch(
        turmaMyParticipationProvider(studyGroupId).future,
      );
      final active = participation != null && participation.isActive;
      // is_active_study_group_leader: leader ou co_leader, ativo.
      final leader =
          active &&
          (participation.role == ParticipantRole.leader ||
              participation.role == ParticipantRole.coLeader);
      final courseView = await can('courses.view');
      if (elevated || leader || courseView) {
        final manageLessons = await can('courses.manage_lessons');
        return TurmaAccess(
          role: TurmaRole.leadership,
          canWriteLessons: elevated || leader || manageLessons,
          leadsGroup: leader,
          elevated: elevated,
          enrolled: active && participation.role == ParticipantRole.participant,
        );
      }
      return active ? asStudent : TurmaAccess.none;
  }
});
