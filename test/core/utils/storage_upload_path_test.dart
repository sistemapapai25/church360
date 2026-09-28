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
    // Regua deliberadamente larga. A versao anterior so olhava
    // `storageBucket:` numa janela de 3 linhas, e por isso deixou passar o
    // avatar do agente em developer_settings_screen.dart, que declara
    // `storageBucket: 'agent-avatars'` (bucket que nem existe em producao) e
    // alcanca `member-photos` pelo `fallbackBuckets`. Agora o bucket fechado
    // e procurado no bloco inteiro do widget, venha de onde vier.
    const fechados = <String>[
      'support-material-covers',
      'support-material-files',
      'support-material-videos',
      'course-images',
      'course-lesson-covers',
      'course-lesson-files',
      'course-lesson-videos',
      'banner-images',
      'devotional-images',
      'event-images',
      'member-photos',
      'church-assets',
    ];
    final aberturaWidget = RegExp(r'(Image|File|Video)UploadWidget\(');

    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!aberturaWidget.hasMatch(lines[i])) continue;
        // O bloco do widget: da abertura ate o proximo fechamento no mesmo
        // nivel de indentacao, com teto para nao varrer o arquivo inteiro.
        final indent = lines[i].length - lines[i].trimLeft().length;
        final fim = (i + 60).clamp(0, lines.length);
        var j = i + 1;
        while (j < fim) {
          final linha = lines[j];
          final corte = linha.trimLeft();
          final recuo = linha.length - corte.length;
          if (corte.startsWith(')') && recuo <= indent) break;
          j++;
        }
        final bloco = lines.sublist(i, j.clamp(i + 1, lines.length)).join('\n');
        final citaFechado = fechados.any((b) => bloco.contains("'$b'"));
        if (citaFechado && !bloco.contains('tenantScopedPath: true')) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'upload para bucket fechado sem tenantScopedPath: true — o path '
          'vai para a raiz e a policy de Storage recusa o envio',
    );
  });
}
