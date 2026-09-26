import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ministries/batismo/domain/models/baptism_public_info.dart';
import '../../../ministries/batismo/presentation/providers/baptism_providers.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../domain/models/course.dart';
import '../../domain/models/course_turma.dart';
import '../providers/courses_provider.dart';
import '../turma/turma_access.dart';

/// Chamada principal da tela do curso (decisão 24 do ROADMAP-FORMACAO).
enum CourseCta {
  /// Não inscrito e há turma aceitando inscrição.
  enroll,

  /// Não inscrito e nenhuma turma aberta.
  closed,

  /// Aluno (ativo ou concluído) de pelo menos uma turma do curso.
  myTurma,

  /// Liderança/gestão sem matrícula: vê todas as turmas.
  manage,

  /// Nada a oferecer (curso sem inscrição pelo app e sem turma minha).
  none,
}

/// O que a tela do curso precisa saber de quem está olhando.
///
/// Espelha a RLS só para decidir o que mostrar; quem manda é a policy. A
/// lista de turmas vem sempre de `courseStudyGroupsProvider`, que já chega
/// recortada pelo banco.
class CourseHubState {
  /// Visão de gestão (gate 6): todas as turmas, editar, conteúdo.
  final bool management;

  /// Turmas em que o usuário é aluno, na ordem da lista do curso.
  final List<CourseTurma> myTurmas;

  /// Turmas do Batismo aceitando inscrição agora (vazio fora do Batismo).
  final List<BaptismPublicTurma> openTurmas;

  /// Curso com inscrição pelo app (hoje só o programa do Batismo, pela
  /// mesma RPC do link público — decisão 21).
  final bool acceptsEnrollment;

  /// Ministério do programa, para a inscrição. Nulo fora do Batismo.
  final String? ministryId;

  const CourseHubState({
    required this.management,
    this.myTurmas = const [],
    this.openTurmas = const [],
    this.acceptsEnrollment = false,
    this.ministryId,
  });

  bool get isStudent => myTurmas.isNotEmpty;

  /// Chamada principal. Aluno vem antes da gestão: "líder que também é
  /// aluno → Acessar minha turma + Gerenciar secundário" (decisão 24).
  CourseCta get primary {
    if (isStudent) return CourseCta.myTurma;
    if (management) return CourseCta.manage;
    if (!acceptsEnrollment) return CourseCta.none;
    return openTurmas.isEmpty ? CourseCta.closed : CourseCta.enroll;
  }

  /// "Gerenciar" como ação secundária, só para quem também é aluno.
  bool get showManageSecondary => isStudent && management;

  /// Ids que a seção Turmas mostra: gestão vê tudo que a RLS entrega;
  /// aluno, só as dele (decisão 24 e o "seção contextual" do app#163).
  bool showsTurma(CourseTurma turma) =>
      management || myTurmas.any((t) => t.id == turma.id);
}

/// Estado do hub para o usuário logado.
final courseHubProvider = FutureProvider.family<CourseHubState, String>((
  ref,
  courseId,
) async {
  final course = await ref.watch(courseByIdProvider(courseId).future);
  if (course == null) return const CourseHubState(management: false);

  final turmas = await ref.watch(courseStudyGroupsProvider(courseId).future);
  final elevated = await ref.watch(currentUserIsElevatedProvider.future);
  final courseView = await ref.watch(
    currentUserHasPermissionProvider('courses.view').future,
  );

  if (course.isBaptismProgram) {
    return _baptismHub(ref, course, turmas, elevated || courseView);
  }

  // Turma genérica: aluno = participante ativo que não lidera.
  final mine = <CourseTurma>[];
  var leads = false;
  for (final turma in turmas) {
    final access = await ref.watch(turmaAccessProvider(turma.id).future);
    if (access.isStudent) mine.add(turma);
    if (access.leadsGroup) leads = true;
  }
  return CourseHubState(
    management: elevated || courseView || leads,
    myTurmas: mine,
  );
});

Future<CourseHubState> _baptismHub(
  Ref ref,
  Course course,
  List<CourseTurma> turmas,
  bool elevatedOrCourseView,
) async {
  final ministryId = course.ministryId!;

  // Mesma régua de liderança de `turmaAccessProvider` (ramo Batismo).
  final canSeeAll = await ref.watch(ministriesCanSeeAllProvider.future);
  final inMinistry = await ref.watch(ministryAccessProvider(ministryId).future);
  final view = await ref.watch(
    currentUserHasPermissionProvider('baptism.view').future,
  );
  final management = elevatedOrCourseView || canSeeAll || (view && inMinistry);

  final enrollments = await ref.watch(myBaptismEnrollmentsProvider.future);
  final mineIds = {
    for (final e in enrollments)
      if (e.courseId == course.id && e.studyGroupId != null) e.studyGroupId!,
  };
  final mine = [
    for (final t in turmas)
      if (mineIds.contains(t.id)) t,
  ];

  // A RPC do link público é a única fonte de "turma aberta" que o aluno
  // pode ler. Falha aqui não derruba a tela: sem resposta, não oferecemos
  // inscrição em vez de prometer uma que talvez não exista.
  var open = const <BaptismPublicTurma>[];
  if (mine.isEmpty && !management) {
    try {
      final info = await ref.watch(
        baptismPublicInfoProvider(ministryId).future,
      );
      open = info.turmas;
    } catch (_) {
      return CourseHubState(management: management, ministryId: ministryId);
    }
  }

  return CourseHubState(
    management: management,
    myTurmas: mine,
    openTurmas: open,
    acceptsEnrollment: true,
    ministryId: ministryId,
  );
}
