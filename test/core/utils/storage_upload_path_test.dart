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

    test('namespace entra depois do uid, sem mexer nos 2 primeiros segmentos',
        () {
      final path = buildStorageUploadPath(
        userId: 'u1',
        timestamp: 42,
        extension: 'jpg',
        tenantId: 't1',
        namespace: 'classifieds',
      );
      expect(path, 't1/u1/classifieds/42.jpg');
      final segments = path.split('/');
      expect(segments[0], 't1');
      expect(segments[1], 'u1');
    });

    test('namespace sem tenant é ignorado — no legado não há pasta', () {
      expect(
        buildStorageUploadPath(
          userId: 'u1',
          timestamp: 42,
          extension: 'jpg',
          namespace: 'classifieds',
        ),
        'u1_42.jpg',
      );
    });

    test('fileName substitui o timestamp e continua na pasta do usuário', () {
      expect(
        buildStorageUploadPath(
          userId: 'u1',
          timestamp: 42,
          extension: 'png',
          tenantId: 't1',
          namespace: 'support-chat-wallpapers',
          fileName: 'pastor',
        ),
        't1/u1/support-chat-wallpapers/pastor.png',
      );
    });
  });

  // CHU-370 (Material de Apoio), CHU-373 (Cursos) e CHU-374 (imagens): esses
  // buckets só aceitam escrita em <tenant>/<auth uid>/. Um upload novo para
  // eles sem o opt-in grava na raiz e a policy recusa.
  test('todo upload por widget para bucket fechado usa tenantScopedPath', () {
    final offenders = <String>[];
    final bucketUse = RegExp(
      r"storageBucket:\s*'(support-material-[a-z]+|course-images"
      r"|course-lesson-[a-z]+|banner-images|devotional-images|event-images"
      r"|member-photos|church-assets)'",
    );
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
