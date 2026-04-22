import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

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

class PushRegistrationService {
  final NotificationRepository _repository;
  final FirebaseMessaging _messaging;
  final FirebasePushConfig Function() _configFactory;

  PushRegistrationService(
    this._repository, {
    FirebaseMessaging? messaging,
    FirebasePushConfig Function()? configFactory,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _configFactory = configFactory ?? FirebasePushConfig.fromEnvironment;

  Future<PushRegistrationResult> registerCurrentDevice() async {
    final config = _configFactory();
    if (!config.isConfigured) {
      return const PushRegistrationResult(
        success: false,
        message: 'Push indisponivel: configure os dart-defines do Firebase.',
      );
    }

    await _ensureFirebaseInitialized(config);

    final permission = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    final granted = permission.authorizationStatus == AuthorizationStatus.authorized ||
        permission.authorizationStatus == AuthorizationStatus.provisional;
    if (!granted) {
      return const PushRegistrationResult(
        success: false,
        message: 'Permissao de notificacao negada no dispositivo.',
      );
    }

    final token = await _messaging.getToken();
    if (token == null || token.trim().isEmpty) {
      return const PushRegistrationResult(
        success: false,
        message: 'Nao foi possivel obter o token push do dispositivo.',
      );
    }

    await _repository.saveFcmToken(
      token: token,
      platform: _platformName(),
      deviceName: _deviceName(),
    );

    return const PushRegistrationResult(
      success: true,
      message: 'Push registrado com sucesso neste dispositivo.',
    );
  }

  Future<void> _ensureFirebaseInitialized(FirebasePushConfig config) async {
    if (Firebase.apps.any((app) => app.name == config.appName)) {
      return;
    }

    await Firebase.initializeApp(
      name: config.appName,
      options: config.toOptions(),
    );
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
