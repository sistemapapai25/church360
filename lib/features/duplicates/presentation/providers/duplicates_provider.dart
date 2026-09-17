import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/duplicates_repository.dart';
import '../../domain/models/dismissed_pair.dart';
import '../../domain/models/duplicate_group.dart';

/// Grupos candidatos. autoDispose porque a lista muda a cada dispensa ou
/// fusao e nao ha Realtime nesta tabela: quem grava invalida na mao.
final duplicateGroupsProvider =
    FutureProvider.autoDispose<List<DuplicateGroup>>((ref) async {
  return ref.watch(duplicatesRepositoryProvider).findDuplicates();
});

/// Pares ja marcados como pessoas diferentes.
final dismissedPairsProvider =
    FutureProvider.autoDispose<List<DismissedPair>>((ref) async {
  return ref.watch(duplicatesRepositoryProvider).listDismissed();
});
