import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ministries/batismo/presentation/providers/baptism_providers.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../../study_groups/domain/models/study_group.dart';
import '../../../study_groups/presentation/providers/study_group_provider.dart';
import 'turma_origin.dart';

/// Quem eu sou nesta turma.
enum TurmaRole {
  /// Gestão: todas as aulas, Alunos, Presença.
  leadership,

  /// Área do aluno: aulas publicadas, Minha frequência, Materiais.
  student,

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

  const TurmaAccess({required this.role, this.canWriteLessons = false});

  static const none = TurmaAccess(role: TurmaRole.none);
  static const student = TurmaAccess(role: TurmaRole.student);

  bool get isLeadership => role == TurmaRole.leadership;
  bool get isStudent => role == TurmaRole.student;
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
final turmaAccessProvider =
    FutureProvider.family<TurmaAccess, String>((ref, studyGroupId) async {
  final origin = await ref.watch(turmaOriginProvider(studyGroupId).future);
  if (origin == null) return TurmaAccess.none;

  final elevated = await ref.watch(currentUserIsElevatedProvider.future);
  Future<bool> can(String code) =>
      ref.watch(currentUserHasPermissionProvider(code).future);

  switch (origin) {
    case BatismoTurmaOrigin(:final ministryId):
      // study_group_leadership_allows, ramo Batismo:
      // ministries_user_can_see_all() OU (permissão E vínculo no ministério).
      final canSeeAll = await ref.watch(ministriesCanSeeAllProvider.future);
      final inMinistry =
          await ref.watch(ministryAccessProvider(ministryId).future);
      final view = await can('baptism.view');
      final leadership = elevated || canSeeAll || (view && inMinistry);
      if (leadership) {
        final edit = await can('baptism.edit');
        final manageLessons = await can('courses.manage_lessons');
        return TurmaAccess(
          role: TurmaRole.leadership,
          canWriteLessons:
              elevated || canSeeAll || (edit && inMinistry) || manageLessons,
        );
      }
      // study_group_student_allows: matrícula ativa ou concluída.
      final enrollments = await ref.watch(myBaptismEnrollmentsProvider.future);
      final enrolled = enrollments.any((e) => e.studyGroupId == studyGroupId);
      return enrolled ? TurmaAccess.student : TurmaAccess.none;

    case GenericaTurmaOrigin():
      final participation =
          await ref.watch(turmaMyParticipationProvider(studyGroupId).future);
      final active = participation != null && participation.isActive;
      // is_active_study_group_leader: leader ou co_leader, ativo.
      final leader = active &&
          (participation.role == ParticipantRole.leader ||
              participation.role == ParticipantRole.coLeader);
      final courseView = await can('courses.view');
      if (elevated || leader || courseView) {
        final manageLessons = await can('courses.manage_lessons');
        return TurmaAccess(
          role: TurmaRole.leadership,
          canWriteLessons: elevated || leader || manageLessons,
        );
      }
      return active ? TurmaAccess.student : TurmaAccess.none;
  }
});
