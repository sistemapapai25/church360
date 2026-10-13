import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resposta das RPCs `worship_geo_status`/`worship_geo_checkin` (migration
/// 005000), mais os casos do próprio aparelho (permissão e GPS).
enum GeoCheckinStatus {
  semConta,
  semLocal,
  fechada,
  jaMarcado,
  aberta,
  presente,
  longe,
  semPermissao,
  semGps,
  erro;

  static GeoCheckinStatus fromServer(String? v) => switch (v) {
    'sem_conta' => semConta,
    'sem_local' => semLocal,
    'fechada' => fechada,
    'ja_marcado' => jaMarcado,
    'aberta' => aberta,
    'presente' => presente,
    'longe' => longe,
    _ => erro,
  };
}

class GeoCheckinResult {
  final GeoCheckinStatus status;
  final String? eventName;
  final int? distanceM;

  const GeoCheckinResult(this.status, {this.eventName, this.distanceM});

  factory GeoCheckinResult.fromJson(Object? json) {
    final m = json is Map ? json : const {};
    return GeoCheckinResult(
      GeoCheckinStatus.fromServer(m['status'] as String?),
      eventName: m['event_name'] as String?,
      distanceM: (m['distance_m'] as num?)?.toInt(),
    );
  }
}

/// Presença no culto pela localização.
///
/// O servidor decide tudo (há culto na janela? a pessoa está no raio?) e não
/// guarda a coordenada, só a distância. O app só pede a localização ao
/// aparelho quando o servidor diz que a janela está aberta.
class GeoCheckinService {
  final SupabaseClient _supabase;
  static bool _autoStarted = false;

  GeoCheckinService(this._supabase);

  Future<GeoCheckinResult> status() async =>
      GeoCheckinResult.fromJson(await _supabase.rpc('worship_geo_status'));

  /// [ask] = pode pedir a permissão (tela /presenca, aberta por um toque).
  /// Sem [ask], só confere se a permissão já foi dada: é a conferência
  /// silenciosa da abertura do app, que nunca mostra pedido nenhum.
  Future<GeoCheckinResult> checkIn({required bool ask}) async {
    final st = await status();
    if (st.status != GeoCheckinStatus.aberta) return st;

    if (!await Geolocator.isLocationServiceEnabled()) {
      return GeoCheckinResult(GeoCheckinStatus.semGps, eventName: st.eventName);
    }
    var perm = await Geolocator.checkPermission();
    if (ask &&
        (perm == LocationPermission.denied ||
            perm == LocationPermission.unableToDetermine)) {
      perm = await Geolocator.requestPermission();
    }
    if (perm != LocationPermission.whileInUse &&
        perm != LocationPermission.always) {
      return GeoCheckinResult(
        GeoCheckinStatus.semPermissao,
        eventName: st.eventName,
      );
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return GeoCheckinResult.fromJson(
      await _supabase.rpc(
        'worship_geo_checkin',
        params: {
          'p_lat': pos.latitude,
          'p_lng': pos.longitude,
          'p_accuracy': pos.accuracy,
        },
      ),
    );
  }

  /// Liga a conferência silenciosa: no login, na abertura e sempre que o app
  /// volta para a frente. Idempotente.
  void startAutoCheck() {
    if (_autoStarted) return;
    _autoStarted = true;

    Future<void> run() async {
      if (_supabase.auth.currentUser == null) return;
      try {
        await checkIn(ask: false);
      } catch (e) {
        debugPrint('Presença por localização falhou: $e');
      }
    }

    _supabase.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.signedIn) unawaited(run());
    });
    AppLifecycleListener(onResume: () => unawaited(run()));
    unawaited(run());
  }
}

final geoCheckinServiceProvider = Provider<GeoCheckinService>(
  (ref) => GeoCheckinService(Supabase.instance.client),
);
