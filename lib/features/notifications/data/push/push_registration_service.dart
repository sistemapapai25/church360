import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../notification_repository.dart';
import 'firebase_push_config.dart';

class PushRegistrationResult {
  final bool success;
  final String message;

  const PushRegistrationResult({
    required this.success,
    required this.message,
  });
}

/// Registro do aparelho para push (FCM) e reação às mensagens recebidas.
///
/// O registro identifica a instalação (UUID guardado localmente), não o
/// hardware: `user_id + device_id` é a chave em `fcm_tokens`.
class PushRegistrationService {
  static const _deviceIdKey = 'push_device_id';

  final NotificationRepository _repository;
  final FirebasePushConfig Function() _configFactory;
  static bool _started = false;

  PushRegistrationService(
    this._repository, {
    FirebasePushConfig Function()? configFactory,
  }) : _configFactory = configFactory ?? FirebasePushConfig.fromEnvironment;

  /// Liga os listeners uma vez. A cada login (e já na abertura, se houver
  /// sessão) sincroniza o token; no Android pede a permissão sozinho. Na web o
  /// navegador exige um toque da pessoa, então lá só sincroniza se a permissão
  /// já foi dada (o toque no sino, [NotificationBadge], chama
  /// [registerCurrentDevice]).
  Future<void> start({
    required void Function() onForegroundMessage,
    required void Function(String route) onOpenRoute,
  }) async {
    final config = _configFactory();
    if (_started || !config.isConfigured) return;
    _started = true;
    await _ensureFirebaseInitialized(config);
    final messaging = FirebaseMessaging.instance;

    Future<void> syncOnLogin() async {
      try {
        final settings = await messaging.getNotificationSettings();
        if (_isGranted(settings.authorizationStatus)) {
          await _syncToken(config);
        } else if (!kIsWeb &&
            settings.authorizationStatus == AuthorizationStatus.notDetermined) {
          await registerCurrentDevice();
        }
      } catch (e) {
        debugPrint('Push sync falhou: $e');
      }
    }

    final auth = Supabase.instance.client.auth;
    auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) syncOnLogin();
    });
    if (auth.currentUser != null) unawaited(syncOnLogin());

    FirebaseMessaging.onMessage.listen((_) => onForegroundMessage());
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _openRoute(m, onOpenRoute));
    messaging.onTokenRefresh.listen((token) => _save(token));
    try {
      final initial = await messaging.getInitialMessage();
      if (initial != null) _openRoute(initial, onOpenRoute);
    } catch (_) {}
  }

  /// Pede a permissão (precisa vir de um toque na web) e registra o token.
  Future<PushRegistrationResult> registerCurrentDevice() async {
    final config = _configFactory();
    if (!config.isConfigured) {
      return const PushRegistrationResult(
        success: false,
        message: 'Push indisponivel: configure os dart-defines do Firebase.',
      );
    }

    await _ensureFirebaseInitialized(config);

    final permission = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (!_isGranted(permission.authorizationStatus)) {
      return const PushRegistrationResult(
        success: false,
        message: 'Permissao de notificacao negada no dispositivo.',
      );
    }

    try {
      if (!await _syncToken(config)) {
        return const PushRegistrationResult(
          success: false,
          message: 'Nao foi possivel obter o token push do dispositivo.',
        );
      }
    } catch (e) {
      return PushRegistrationResult(
        success: false,
        message: 'Falha ao registrar o push: $e',
      );
    }

    return const PushRegistrationResult(
      success: true,
      message: 'Push registrado com sucesso neste dispositivo.',
    );
  }

  /// Estado da permissão sem pedir nada (null quando o push não está configurado).
  Future<AuthorizationStatus?> permissionStatus() async {
    final config = _configFactory();
    if (!config.isConfigured) return null;
    await _ensureFirebaseInitialized(config);
    return (await FirebaseMessaging.instance.getNotificationSettings())
        .authorizationStatus;
  }

  /// Chamar ANTES do signOut (precisa da sessão para passar na RLS): este
  /// aparelho para de receber as notificações da conta que está saindo.
  static Future<void> deactivateThisDevice() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await client
          .from('fcm_tokens')
          .update({'is_active': false})
          .eq('user_id', userId)
          .eq('device_id', await _deviceId());
    } catch (e) {
      debugPrint('Falha ao desativar push no logout: $e');
    }
  }

  Future<bool> _syncToken(FirebasePushConfig config) async {
    final token = await FirebaseMessaging.instance.getToken(
      vapidKey: kIsWeb ? config.vapidKey : null,
    );
    if (token == null || token.trim().isEmpty) return false;
    await _save(token);
    return true;
  }

  Future<void> _save(String token) async {
    if (Supabase.instance.client.auth.currentUser == null) return;
    await _repository.saveFcmToken(
      token: token,
      deviceId: await _deviceId(),
      platform: _platformName(),
      deviceName: _deviceName(),
    );
  }

  static Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  static bool _isGranted(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  static void _openRoute(RemoteMessage m, void Function(String) onOpenRoute) {
    final route = m.data['route'];
    if (route is String && route.startsWith('/')) onOpenRoute(route);
  }

  // App padrão: FirebaseMessaging.instance usa sempre o [DEFAULT].
  Future<void> _ensureFirebaseInitialized(FirebasePushConfig config) async {
    if (Firebase.apps.isNotEmpty) return;
    await Firebase.initializeApp(options: config.toOptions());
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  String _deviceName() {
    if (kIsWeb) return 'web-browser';
    if (Platform.isAndroid) return 'android-device';
    if (Platform.isIOS) return 'ios-device';
    if (Platform.isWindows) return 'windows-device';
    if (Platform.isMacOS) return 'macos-device';
    if (Platform.isLinux) return 'linux-device';
    return 'unknown-device';
  }
}
