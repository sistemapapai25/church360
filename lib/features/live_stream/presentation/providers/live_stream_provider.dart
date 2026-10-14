import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/live_stream_repository.dart';
import '../../domain/models/current_culto.dart';
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

/// "Tem culto agora?" para a Home. Sem Realtime (nunca foi ligado): consulta
/// ao abrir, a cada 60 s e quando o app volta para a frente. Erro de rede
/// mantém o último valor (a Home não pisca).
final currentCultoProvider = StreamProvider<CurrentCulto>((ref) {
  final repo = ref.watch(liveStreamRepositoryProvider);
  final controller = StreamController<CurrentCulto>();

  Future<void> load() async {
    try {
      final culto = await repo.currentCulto();
      if (!controller.isClosed) controller.add(culto);
    } catch (_) {}
  }

  final timer = Timer.periodic(const Duration(seconds: 60), (_) => load());
  final lifecycle = AppLifecycleListener(onResume: load);
  ref.onDispose(() {
    timer.cancel();
    lifecycle.dispose();
    controller.close();
  });
  load();
  return controller.stream;
});
