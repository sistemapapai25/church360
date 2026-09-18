import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../events/presentation/providers/events_provider.dart';
import '../../../../permissions/providers/permissions_providers.dart';
import '../../../presentation/providers/ministries_provider.dart';
import '../../data/baptism_repository.dart';
import '../../domain/baptism_checklist_progress.dart';
import '../../domain/models/baptism_checklist.dart';
import '../../domain/models/baptism_public_info.dart';
import '../../domain/models/baptism_student.dart';
import '../../domain/models/baptism_turma.dart';

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
}
