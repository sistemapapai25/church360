import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/notifications/data/push/firebase_push_config.dart';

void main() {
  group('FirebasePushConfig', () {
    test('isConfigured is false when required fields are missing', () {
      const config = FirebasePushConfig(
        apiKey: '',
        appId: '',
        messagingSenderId: '',
        projectId: '',
        appName: 'church360_push',
      );

      expect(config.isConfigured, isFalse);
    });

    test('isConfigured is true when required fields are provided', () {
      const config = FirebasePushConfig(
        apiKey: 'api-key',
        appId: 'app-id',
        messagingSenderId: 'sender-id',
        projectId: 'project-id',
        appName: 'church360_push',
      );

      expect(config.isConfigured, isTrue);
    });

    test('toOptions maps required and optional values', () {
      const config = FirebasePushConfig(
        apiKey: 'api-key',
        appId: 'app-id',
        messagingSenderId: 'sender-id',
        projectId: 'project-id',
        appName: 'church360_push',
        storageBucket: 'bucket',
        iosBundleId: 'ios.bundle',
      );

      final options = config.toOptions();
      expect(options.apiKey, 'api-key');
      expect(options.appId, 'app-id');
      expect(options.messagingSenderId, 'sender-id');
      expect(options.projectId, 'project-id');
      expect(options.storageBucket, 'bucket');
      expect(options.iosBundleId, 'ios.bundle');
    });
  });
}
