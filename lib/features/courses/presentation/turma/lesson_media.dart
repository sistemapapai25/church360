import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/supabase_constants.dart';

/// Arquivo principal da aula da turma enviado pelo próprio formulário
/// (passo 3 do modelo híbrido, ROADMAP-FORMACAO).
///
/// Os arquivos vão para os buckets de Material de Apoio, numa pasta da aula:
/// `<tenant>/<auth uid>/study-lessons/<lessonId>/<timestamp>.<ext>`. A
/// migration `20260926000500` libera essa pasta para quem pode editar a
/// aula (mesma régua de `study_lessons_update`) e deixa essa mesma pessoa
/// ler e apagar ali — é o que permite apagar o arquivo antigo ao trocar.
enum LessonMediaKind {
  pdf('support-material-files', ['pdf'], 'PDF'),
  video('support-material-videos', ['mp4', 'mov', 'webm', 'm4v'], 'vídeo');

  final String bucket;
  final List<String> extensions;
  final String label;

  const LessonMediaKind(this.bucket, this.extensions, this.label);
}

/// Limite de envio do Supabase Storage no plano atual. Vídeo maior que isso
/// tem que ir por link (YouTube, Drive).
const int lessonMediaMaxBytes = 50 * 1024 * 1024;

const String _lessonFolder = 'study-lessons';

String buildLessonMediaPath({
  required String tenantId,
  required String userId,
  required String lessonId,
  required int timestamp,
  required String extension,
}) => '$tenantId/$userId/$_lessonFolder/$lessonId/$timestamp.$extension';

/// Caminho do objeto no bucket de [kind] quando [url] é um arquivo enviado
/// pela pasta da aula [lessonId]; `null` para qualquer outra coisa (link do
/// YouTube, arquivo de Material de Apoio, pasta de outra aula). Só o que
/// passa aqui é apagado pelo app.
String? lessonMediaObjectPath(
  String? url, {
  required LessonMediaKind kind,
  required String lessonId,
}) {
  final uri = Uri.tryParse((url ?? '').trim());
  if (uri == null) return null;
  final marker = ['storage', 'v1', 'object', 'public', kind.bucket];
  final segs = uri.pathSegments;
  for (var i = 0; i + marker.length <= segs.length; i++) {
    var match = true;
    for (var j = 0; j < marker.length; j++) {
      if (segs[i + j] != marker[j]) {
        match = false;
        break;
      }
    }
    if (!match) continue;
    final object = segs.sublist(i + marker.length);
    if (object.length == 5 &&
        object[2] == _lessonFolder &&
        object[3] == lessonId &&
        object.every((s) => s.isNotEmpty)) {
      return object.join('/');
    }
    return null;
  }
  return null;
}

String lessonMediaContentType(String extension) =>
    switch (extension.toLowerCase()) {
      'pdf' => 'application/pdf',
      'mp4' => 'video/mp4',
      'm4v' => 'video/x-m4v',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      _ => 'application/octet-stream',
    };

/// Arquivo escolhido e ainda não enviado (o envio só acontece ao salvar).
class PickedLessonFile {
  final String name;
  final int size;
  final Uint8List? bytes;
  final String? path;

  const PickedLessonFile({
    required this.name,
    required this.size,
    this.bytes,
    this.path,
  });

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }
}

/// Escolher, enviar e apagar arquivo da aula. Interface para os testes
/// trocarem o Storage por um falso.
abstract class LessonMediaService {
  Future<PickedLessonFile?> pick(LessonMediaKind kind);

  /// Envia para a pasta da aula e devolve a URL pública.
  Future<String> upload({
    required LessonMediaKind kind,
    required String lessonId,
    required PickedLessonFile file,
  });

  /// Apaga o arquivo antigo da aula. Só age em URL da pasta da própria aula
  /// ([lessonMediaObjectPath]); qualquer outra coisa é ignorada.
  Future<void> removeIfLessonFile({
    required LessonMediaKind kind,
    required String lessonId,
    required String? url,
  });
}

class SupabaseLessonMediaService implements LessonMediaService {
  final SupabaseClient? _client;

  /// Sem [client], usa o `Supabase.instance` só na hora de enviar/apagar
  /// (salvar aula sem arquivo nunca toca no Storage).
  SupabaseLessonMediaService([this._client]);

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  @override
  Future<PickedLessonFile?> pick(LessonMediaKind kind) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: kind.extensions,
      withData: kIsWeb,
    );
    final f = result?.files.firstOrNull;
    if (f == null) return null;
    return PickedLessonFile(
      name: f.name,
      size: f.size,
      bytes: f.bytes,
      path: kIsWeb ? null : f.path,
    );
  }

  @override
  Future<String> upload({
    required LessonMediaKind kind,
    required String lessonId,
    required PickedLessonFile file,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Usuário não autenticado');
    final path = buildLessonMediaPath(
      tenantId: SupabaseConstants.currentTenantId,
      userId: uid,
      lessonId: lessonId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      extension: file.extension,
    );
    final options = FileOptions(
      contentType: lessonMediaContentType(file.extension),
    );
    final bucket = _supabase.storage.from(kind.bucket);
    if (file.bytes != null) {
      await bucket.uploadBinary(path, file.bytes!, fileOptions: options);
    } else if (file.path != null) {
      await bucket.upload(path, File(file.path!), fileOptions: options);
    } else {
      throw Exception('Arquivo sem conteúdo');
    }
    return bucket.getPublicUrl(path);
  }

  @override
  Future<void> removeIfLessonFile({
    required LessonMediaKind kind,
    required String lessonId,
    required String? url,
  }) async {
    final path = lessonMediaObjectPath(url, kind: kind, lessonId: lessonId);
    if (path == null) return;
    await _supabase.storage.from(kind.bucket).remove([path]);
  }
}

final lessonMediaServiceProvider = Provider<LessonMediaService>(
  (ref) => SupabaseLessonMediaService(),
);
