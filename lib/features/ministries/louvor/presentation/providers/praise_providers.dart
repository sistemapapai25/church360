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

final praiseUsageProvider = FutureProvider<Map<String, int>>(
  (ref) => ref.watch(praiseRepositoryProvider).songUsage(),
);

final praiseSongProvider = FutureProvider.family<PraiseSong?, String>(
  (ref, songId) => ref.watch(praiseRepositoryProvider).getSong(songId),
);

final praiseVersionsProvider =
    FutureProvider.family<List<PraiseSongVersion>, String>(
      (ref, songId) => ref.watch(praiseRepositoryProvider).listVersions(songId),
    );

/// `praise_can_manage_setlist()` / `praise_can_publish_setlist()`.
final praiseSetlistAccessProvider =
    FutureProvider<({bool canManage, bool canPublish})>(
      (ref) => ref.watch(praiseRepositoryProvider).setlistAccess(),
    );

final praiseSetlistsProvider =
    FutureProvider.family<List<PraiseSetlist>, String>(
      (ref, ministryId) =>
          ref.watch(praiseRepositoryProvider).listSetlists(ministryId),
    );

final praiseSetlistProvider = FutureProvider.family<PraiseSetlist?, String>(
  (ref, setlistId) => ref.watch(praiseRepositoryProvider).getSetlist(setlistId),
);

/// Revisão publicada é imutável: não precisa entrar no [invalidatePraise].
final praisePublisherNameProvider = FutureProvider.family<String?, String>(
  (ref, revisionId) =>
      ref.watch(praiseRepositoryProvider).publisherName(revisionId),
);

/// Revisão anterior (arquivada) para o "o que mudou". Imutável.
final praiseRevisionProvider =
    FutureProvider.family<PraiseSetlistRevision?, (String, int)>(
      (ref, key) =>
          ref.watch(praiseRepositoryProvider).getRevision(key.$1, key.$2),
    );

final praiseRecipientsProvider =
    FutureProvider.family<List<({String id, String name})>, String>(
      (ref, revisionId) =>
          ref.watch(praiseRepositoryProvider).listRecipients(revisionId),
    );

/// Repertórios recebidos pelo ministério (Fase D).
final praiseReceivedProvider =
    FutureProvider.family<List<PraiseSetlist>, String>(
      (ref, ministryId) =>
          ref.watch(praiseRepositoryProvider).receivedSetlists(ministryId),
    );

/// Realtime não é ligado por migration neste banco: depois de gravar,
/// invalidar na mão.
void invalidatePraise(WidgetRef ref, [String? songId]) {
  ref.invalidate(praiseSongsProvider);
  ref.invalidate(praiseSetlistsProvider);
  ref.invalidate(praiseSetlistProvider);
  ref.invalidate(praiseRecipientsProvider);
  ref.invalidate(praiseReceivedProvider);
  if (songId != null) {
    ref.invalidate(praiseSongProvider(songId));
    ref.invalidate(praiseVersionsProvider(songId));
  }
}
