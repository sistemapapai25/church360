import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/ministry_routine_repository.dart';
import '../../domain/ministry_routine.dart';

final ministryRoutineRepositoryProvider = Provider<MinistryRoutineRepository>(
  (ref) => MinistryRoutineRepository(Supabase.instance.client),
);

final ministryRoutineCapsProvider =
    FutureProvider.family<MinistryRoutineCaps, String>(
      (ref, ministryId) =>
          ref.watch(ministryRoutineRepositoryProvider).caps(ministryId),
    );

final ministryRoutineItemsProvider =
    FutureProvider.family<List<RoutineItem>, String>(
      (ref, ministryId) =>
          ref.watch(ministryRoutineRepositoryProvider).getItems(ministryId),
    );

final ministryRoutineRunsProvider =
    FutureProvider.family<List<RoutineRun>, String>(
      (ref, ministryId) =>
          ref.watch(ministryRoutineRepositoryProvider).getRuns(ministryId),
    );

final ministryRoutineRunProvider = FutureProvider.family<RoutineRun, String>(
  (ref, runId) => ref.watch(ministryRoutineRepositoryProvider).getRun(runId),
);

/// Sem realtime: toda gravação invalida na mão.
void invalidateMinistryRoutine(
  WidgetRef ref,
  String ministryId, {
  String? runId,
}) {
  ref.invalidate(ministryRoutineItemsProvider(ministryId));
  ref.invalidate(ministryRoutineRunsProvider(ministryId));
  if (runId != null) ref.invalidate(ministryRoutineRunProvider(runId));
}
