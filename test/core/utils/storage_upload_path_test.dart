import 'dart:io';

import 'package:church360_app/core/utils/storage_upload_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildStorageUploadPath', () {
    test('sem tenant mantém o formato legado na raiz', () {
      expect(
        buildStorageUploadPath(userId: 'u1', timestamp: 42, extension: 'pdf'),
        'u1_42.pdf',
      );
    });

    test('tenant vazio cai no formato legado', () {
      expect(
        buildStorageUploadPath(
          userId: 'u1',
          timestamp: 42,
          extension: 'pdf',
          tenantId: '  ',
        ),
        'u1_42.pdf',
      );
    });

    test('com tenant grava em <tenant>/<uid>/<arquivo>', () {
      final path = buildStorageUploadPath(
        userId: 'u1',
        timestamp: 42,
        extension: 'pdf',
        tenantId: 't1',
      );
      expect(path, 't1/u1/42.pdf');
      final segments = path.split('/');
      expect(segments[0], 't1');
      expect(segments[1], 'u1');
    });
  });

  // CHU-370: os buckets de Material de Apoio só aceitam escrita em
  // <tenant>/<auth uid>/. Um upload novo para eles sem o opt-in grava na raiz
  // e passa a falhar quando a migration entrar.
  test('todo upload para support-material-* usa tenantScopedPath', () {
    final offenders = <String>[];
    final bucketUse = RegExp(r"storageBucket:\s*'support-material-[a-z]+'");
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!bucketUse.hasMatch(lines[i])) continue;
        final window = lines
            .sublist(
              (i - 3).clamp(0, lines.length),
              (i + 4).clamp(0, lines.length),
            )
            .join('\n');
        if (!window.contains('tenantScopedPath: true')) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
