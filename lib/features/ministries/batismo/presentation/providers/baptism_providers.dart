import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../permissions/providers/permissions_providers.dart';
import '../../../presentation/providers/ministries_provider.dart';
import '../../data/baptism_repository.dart';
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
}
