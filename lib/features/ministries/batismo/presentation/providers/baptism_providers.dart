import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../events/presentation/providers/events_provider.dart';
import '../../../../permissions/providers/permissions_providers.dart';
import '../../../presentation/providers/ministries_provider.dart';
import '../../data/baptism_repository.dart';
import '../../domain/baptism_attendance_roll.dart';
import '../../domain/baptism_checklist_progress.dart';
import '../../domain/models/baptism_attendance.dart';
import '../../domain/models/baptism_checklist.dart';
import '../../domain/models/baptism_enrollment.dart';
import '../../domain/models/baptism_meeting.dart';
import '../../domain/models/baptism_my_meeting.dart';
import '../../domain/models/baptism_public_info.dart';
import '../../domain/models/baptism_student.dart';
import '../../domain/models/baptism_turma.dart';

/// Matrículas do usuário logado em turmas de batismo (ativo ou concluído).
///
/// Não é family por ministério: o aluno não tem ministério nenhum, e a RPC
/// já recorta pelo tenant e pelo próprio cadastro.
final myBaptismEnrollmentsProvider =
    FutureProvider<List<BaptismEnrollment>>((ref) async {
  final repo = ref.watch(baptismRepositoryProvider);
  return repo.getMyEnrollments();
});

/// A chamada do aluno logado numa turma (RPC `my_baptism_attendance`).
final myBaptismAttendanceProvider =
    FutureProvider.family<List<BaptismMyMeeting>, String>((ref, turmaId) async {
  final repo = ref.watch(baptismRepositoryProvider);
  return repo.getMyAttendance(turmaId);
});

/// Turmas do ministério.
final baptismTurmasProvider =
    FutureProvider.family<List<BaptismTurma>, String>((ref, ministryId) async {
  final repo = ref.watch(baptismRepositoryProvider);
  return repo.getTurmas(ministryId);
});

/// Alunos de todas as turmas do ministério.
final baptismStudentsProvider =
    FutureProvider.family<List<BaptismStudent>, String>((ref, ministryId) async {
  final repo = ref.watch(baptismRepositoryProvider);
  return repo.getStudents(ministryId);
});

/// Catálogo de categorias da agenda (`event_type`), para o seletor da
/// turma.
///
/// É o mesmo catálogo do formulário de evento — e por isso já sai sem o
/// code `news`, que é marcador de sistema e não um tipo de evento de
/// alguma igreja. Fica aqui, e não no módulo de eventos, porque nenhum
/// provider existia: as outras telas chamam o repositório direto.
final baptismEventTypeCatalogProvider =
    FutureProvider<List<({String code, String label})>>((ref) async {
  final repo = ref.watch(eventsRepositoryProvider);
  final catalog = await repo.getEventTypesCatalog();
  return [
    for (final e in catalog)
      (code: e['code'] ?? '', label: e['label'] ?? e['code'] ?? ''),
  ];
});

/// Dados do formulário público de inscrição — o que o link abre.
///
/// Vive fora de qualquer sessão: quem chega aqui pode não estar logado, e
/// é a RPC `baptism_public_registration_info` que decide o que aparece.
final baptismPublicInfoProvider =
    FutureProvider.family<BaptismPublicInfo, String>((ref, ministryId) async {
  final repo = ref.watch(baptismRepositoryProvider);
  return repo.getPublicRegistrationInfo(ministryId);
});

/// Catálogo de etapas do checklist do ministério (ativas e desligadas).
final baptismChecklistItemsProvider =
    FutureProvider.family<List<BaptismChecklistItem>, String>(
        (ref, ministryId) async {
  final repo = ref.watch(baptismRepositoryProvider);
  return repo.getChecklistItems(ministryId);
});

/// Marcações de todos os alunos do ministério.
///
/// Depende dos alunos de propósito: é a lista deles que define quais
/// marcações buscar, e assim invalidar os alunos já refaz as marcações —
/// aluno recém-cadastrado nunca aparece sem a linha de progresso dele.
final baptismChecklistEntriesProvider =
    FutureProvider.family<List<BaptismChecklistEntry>, String>(
        (ref, ministryId) async {
  final students = await ref.watch(baptismStudentsProvider(ministryId).future);
  if (students.isEmpty) return const [];
  final repo = ref.watch(baptismRepositoryProvider);
  return repo.getChecklistEntries([for (final s in students) s.id]);
});

/// Progresso por aluno, já com catálogo e marcações casados.
final baptismChecklistProgressProvider =
    FutureProvider.family<List<BaptismStudentProgress>, String>(
        (ref, ministryId) async {
  final students = await ref.watch(baptismStudentsProvider(ministryId).future);
  final items = await ref.watch(baptismChecklistItemsProvider(ministryId).future);
  final entries =
      await ref.watch(baptismChecklistEntriesProvider(ministryId).future);

  return buildBaptismChecklistProgress(
    students: students,
    items: items,
    entries: entries,
  );
});

/// O mesmo progresso reduzido a "feitas/total" por aluno.
///
/// É o que a aba Alunos mostra no card. Fica num provider próprio para que
/// aquela tela não precise conhecer o checklist inteiro.
final baptismChecklistTallyProvider =
    FutureProvider.family<Map<String, ({int done, int total})>, String>(
        (ref, ministryId) async {
  final progress =
      await ref.watch(baptismChecklistProgressProvider(ministryId).future);
  return baptismChecklistTallyByStudent(progress);
});

/// Encontros de todas as turmas do ministério.
///
/// Depende das turmas de propósito: `baptism_meeting` não duplica
/// `ministry_id` (a cadeia é encontro → turma → ministério), então é a
/// lista de turmas que define quais encontros buscar. Assim, criar uma
/// turma e invalidar as turmas já refaz os encontros.
final baptismMeetingsProvider =
    FutureProvider.family<List<BaptismMeeting>, String>((ref, ministryId) async {
  final turmas = await ref.watch(baptismTurmasProvider(ministryId).future);
  if (turmas.isEmpty) return const [];
  final repo = ref.watch(baptismRepositoryProvider);
  return repo.getMeetings([for (final t in turmas) t.id]);
});

/// Marcações de presença de todos os encontros do ministério.
final baptismAttendanceProvider =
    FutureProvider.family<List<BaptismAttendance>, String>(
        (ref, ministryId) async {
  final meetings = await ref.watch(baptismMeetingsProvider(ministryId).future);
  if (meetings.isEmpty) return const [];
  final repo = ref.watch(baptismRepositoryProvider);
  return repo.getAttendance([for (final m in meetings) m.id]);
});

/// A chamada de cada encontro, já com alunos e marcações casados.
///
/// É o que a aba Presença consome. Espelha o
/// `baptismChecklistProgressProvider`: a composição mora numa camada pura
/// (`buildBaptismMeetingRolls`) e a tela só desenha.
final baptismMeetingRollsProvider =
    FutureProvider.family<List<BaptismMeetingRoll>, String>(
        (ref, ministryId) async {
  final meetings = await ref.watch(baptismMeetingsProvider(ministryId).future);
  final students = await ref.watch(baptismStudentsProvider(ministryId).future);
  final attendance =
      await ref.watch(baptismAttendanceProvider(ministryId).future);

  return buildBaptismMeetingRolls(
    meetings: meetings,
    students: students,
    attendance: attendance,
  );
});

// ---------------------------------------------------------------------
// Turma travada (tela da turma em Cursos)
// ---------------------------------------------------------------------

/// Uma turma dentro de um ministério. Chave das famílias "por turma", usadas
/// quando as abas Alunos e Presença abrem presas a uma turma só
/// (`lockedTurmaId`).
typedef BaptismTurmaKey = ({String ministryId, String turmaId});

/// A turma travada, se ela é mesmo deste ministério; `null` quando não é.
///
/// É a segunda trava do modo travado (a primeira é o acesso da tela da
/// turma): turma que não aparece em [baptismTurmasProvider] deste
/// ministério não abre nada — nunca cai para "todas as turmas" nem para a
/// primeira da lista.
final baptismLockedTurmaProvider =
    FutureProvider.family<BaptismTurma?, BaptismTurmaKey>((ref, key) async {
  final turmas = await ref.watch(baptismTurmasProvider(key.ministryId).future);
  for (final t in turmas) {
    if (t.id == key.turmaId) return t;
  }
  return null;
});

/// Alunos só da turma, recortados no banco (`turma_id`).
final baptismTurmaStudentsProvider =
    FutureProvider.family<List<BaptismStudent>, BaptismTurmaKey>(
        (ref, key) async {
  final turma = await ref.watch(baptismLockedTurmaProvider(key).future);
  if (turma == null) return const [];
  final repo = ref.watch(baptismRepositoryProvider);
  return repo.getStudents(key.ministryId, turmaId: turma.id);
});

/// Encontros só da turma.
final baptismTurmaMeetingsProvider =
    FutureProvider.family<List<BaptismMeeting>, BaptismTurmaKey>(
        (ref, key) async {
  final turma = await ref.watch(baptismLockedTurmaProvider(key).future);
  if (turma == null) return const [];
  final repo = ref.watch(baptismRepositoryProvider);
  return repo.getMeetings([turma.id]);
});

/// Marcações de presença só dos encontros da turma.
final baptismTurmaAttendanceProvider =
    FutureProvider.family<List<BaptismAttendance>, BaptismTurmaKey>(
        (ref, key) async {
  final meetings = await ref.watch(baptismTurmaMeetingsProvider(key).future);
  if (meetings.isEmpty) return const [];
  final repo = ref.watch(baptismRepositoryProvider);
  return repo.getAttendance([for (final m in meetings) m.id]);
});

/// A chamada de cada encontro da turma.
final baptismTurmaMeetingRollsProvider =
    FutureProvider.family<List<BaptismMeetingRoll>, BaptismTurmaKey>(
        (ref, key) async {
  final meetings = await ref.watch(baptismTurmaMeetingsProvider(key).future);
  final students = await ref.watch(baptismTurmaStudentsProvider(key).future);
  final attendance =
      await ref.watch(baptismTurmaAttendanceProvider(key).future);

  return buildBaptismMeetingRolls(
    meetings: meetings,
    students: students,
    attendance: attendance,
  );
});

/// "Feitas/total" do checklist, só dos alunos da turma.
final baptismTurmaChecklistTallyProvider =
    FutureProvider.family<Map<String, ({int done, int total})>, BaptismTurmaKey>(
        (ref, key) async {
  final students = await ref.watch(baptismTurmaStudentsProvider(key).future);
  if (students.isEmpty) return const {};
  final items =
      await ref.watch(baptismChecklistItemsProvider(key.ministryId).future);
  final repo = ref.watch(baptismRepositoryProvider);
  final entries =
      await repo.getChecklistEntries([for (final s in students) s.id]);
  return baptismChecklistTallyByStudent(
    buildBaptismChecklistProgress(
      students: students,
      items: items,
      entries: entries,
    ),
  );
});

/// As três ações de escrita do módulo, com o código RBAC de cada uma.
enum BaptismWriteAction {
  create('baptism.create'),
  edit('baptism.edit'),
  delete('baptism.delete');

  final String permission;

  const BaptismWriteAction(this.permission);
}

/// Se o usuário atual pode executar uma ação de escrita neste ministério.
///
/// Espelha a policy do banco: `ministries_user_can_see_all()` OU
/// (`check_user_permission` da ação E vínculo no ministério). O
/// vínculo não é checado de novo aqui porque quem chegou nesta tela já
/// passou pelo `MinistrySubmoduleGuard`, que exige visão global OU vínculo.
///
/// Sem o ramo da visão global, os dois owners e os dois admins — que não
/// têm cargo RBAC — perderiam os botões numa tela que a policy deixaria
/// escrever. É a mesma armadilha do `PermissionOrLevelRoute`.
final baptismCanWriteProvider =
    FutureProvider.family<bool, ({String ministryId, BaptismWriteAction action})>(
        (ref, args) async {
  final canSeeAll = await ref.watch(ministriesCanSeeAllProvider.future);
  if (canSeeAll) return true;
  return ref.watch(
    currentUserHasPermissionProvider(args.action.permission).future,
  );
});

/// Invalida as duas listas do módulo depois de uma gravação.
///
/// Realtime nunca é habilitado por migration neste banco: `onPostgresChanges`
/// pode nunca disparar, então toda gravação invalida na mão.
void invalidateBaptismData(WidgetRef ref, String ministryId) {
  ref.invalidate(baptismStudentsProvider(ministryId));
  ref.invalidate(baptismTurmasProvider(ministryId));
  // O checklist entra aqui, e não numa função própria, porque `invalidate`
  // não sobe para quem depende: invalidar só o catálogo deixaria o
  // progresso e a contagem da aba Alunos com o número velho na tela.
  ref.invalidate(baptismChecklistItemsProvider(ministryId));
  ref.invalidate(baptismChecklistEntriesProvider(ministryId));
  ref.invalidate(baptismChecklistProgressProvider(ministryId));
  ref.invalidate(baptismChecklistTallyProvider(ministryId));
  // A presença entra aqui pela mesma razão: invalidar só os encontros
  // deixaria a chamada com o estado anterior na tela, porque `invalidate`
  // não sobe para quem depende.
  ref.invalidate(baptismMeetingsProvider(ministryId));
  ref.invalidate(baptismAttendanceProvider(ministryId));
  ref.invalidate(baptismMeetingRollsProvider(ministryId));
  // As famílias da turma travada, inteiras: a chave delas leva a turma, que
  // quem grava não precisa conhecer, e uma gravação no ministério pode ter
  // mexido em qualquer turma dele.
  ref.invalidate(baptismLockedTurmaProvider);
  ref.invalidate(baptismTurmaStudentsProvider);
  ref.invalidate(baptismTurmaMeetingsProvider);
  ref.invalidate(baptismTurmaAttendanceProvider);
  ref.invalidate(baptismTurmaMeetingRollsProvider);
  ref.invalidate(baptismTurmaChecklistTallyProvider);
}
