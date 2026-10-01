import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/praise_repository.dart';

final praiseRepositoryProvider = Provider<PraiseRepository>(
  (ref) => PraiseRepository(Supabase.instance.client),
);

/// `praise_can_view()` / `praise_can_manage()` do banco — a regra não é
/// reescrita em Dart.
final praiseAccessProvider = FutureProvider<({bool canView, bool canManage})>(
  (ref) => ref.watch(praiseRepositoryProvider).access(),
);

final praiseSongsProvider = FutureProvider<List<PraiseSong>>(
  (ref) => ref.watch(praiseRepositoryProvider).listSongs(),
);

final praiseSongProvider = FutureProvider.family<PraiseSong?, String>(
  (ref, songId) => ref.watch(praiseRepositoryProvider).getSong(songId),
);

final praiseVersionsProvider =
    FutureProvider.family<List<PraiseSongVersion>, String>(
      (ref, songId) => ref.watch(praiseRepositoryProvider).listVersions(songId),
    );

/// Realtime não é ligado por migration neste banco: depois de gravar,
/// invalidar na mão.
void invalidatePraise(WidgetRef ref, [String? songId]) {
  ref.invalidate(praiseSongsProvider);
  if (songId != null) {
    ref.invalidate(praiseSongProvider(songId));
    ref.invalidate(praiseVersionsProvider(songId));
  }
}
