import 'package:firebase_core/firebase_core.dart';

class FirebasePushConfig {
  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String? storageBucket;
  final String? iosBundleId;
  final String? iosClientId;
  final String? androidClientId;
  final String? authDomain;
  final String appName;

  const FirebasePushConfig({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    required this.appName,
    this.storageBucket,
    this.iosBundleId,
    this.iosClientId,
    this.androidClientId,
    this.authDomain,
  });

  static FirebasePushConfig fromEnvironment() {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const appName = String.fromEnvironment('FIREBASE_APP_NAME', defaultValue: 'church360_push');
    const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
    const iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');
    const iosClientId = String.fromEnvironment('FIREBASE_IOS_CLIENT_ID');
    const androidClientId = String.fromEnvironment('FIREBASE_ANDROID_CLIENT_ID');
    const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');

    return FirebasePushConfig(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      appName: appName,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      iosBundleId: iosBundleId.isEmpty ? null : iosBundleId,
      iosClientId: iosClientId.isEmpty ? null : iosClientId,
      androidClientId: androidClientId.isEmpty ? null : androidClientId,
      authDomain: authDomain.isEmpty ? null : authDomain,
    );
  }

  bool get isConfigured {
    return apiKey.trim().isNotEmpty &&
        appId.trim().isNotEmpty &&
        messagingSenderId.trim().isNotEmpty &&
        projectId.trim().isNotEmpty;
  }

  FirebaseOptions toOptions() {
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket,
      iosBundleId: iosBundleId,
      iosClientId: iosClientId,
      androidClientId: androidClientId,
      authDomain: authDomain,
    );
  }
}
