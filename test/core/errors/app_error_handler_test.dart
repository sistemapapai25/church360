import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/core/errors/app_error_handler.dart';

void main() {
  group('AppErrorHandler', () {
    test('maps unique violation to a friendly message', () {
      final err = PostgrestException(
        message: 'duplicate key value violates unique constraint',
        code: '23505',
        details: 'Key (x)=(y) already exists.',
        hint: null,
      );

      final info = AppErrorHandler.map(err, feature: 'test.unique');
      expect(info.userMessage.toLowerCase(), isNot(contains('duplicate')));
      expect(info.userMessage.toLowerCase(), contains('ja existe'));
      expect(info.code, '23505');
    });

    test('maps schema cache miss to update message', () {
      final err = PostgrestException(
        message: "Could not find the 'modules' column in the schema cache",
        code: 'PGRST204',
        details: null,
        hint: null,
      );

      final info = AppErrorHandler.map(err, feature: 'test.schema');
      expect(info.userMessage.toLowerCase(), contains('atualizacao'));
      expect(info.userMessage.toLowerCase(), isNot(contains('schema cache')));
    });

    test('maps timeout to a friendly message', () {
      final info = AppErrorHandler.map(
        TimeoutException('timeout'),
        feature: 'test.timeout',
      );
      expect(info.userMessage.toLowerCase(), contains('tempo'));
    });
  });
}

