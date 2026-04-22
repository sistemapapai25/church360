import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/live_stream_repository.dart';
import '../../domain/models/live_stream.dart';

final liveStreamRepositoryProvider = Provider<LiveStreamRepository>((ref) {
  return LiveStreamRepository(Supabase.instance.client);
});

final liveStreamConfigProvider = FutureProvider<LiveStreamConfig?>((ref) async {
  final repo = ref.watch(liveStreamRepositoryProvider);
  return repo.getLiveStreamConfig();
});

final activeLiveStreamProvider = FutureProvider<LiveStreamConfig?>((ref) async {
  final repo = ref.watch(liveStreamRepositoryProvider);
  return repo.getActiveLiveStream();
});
