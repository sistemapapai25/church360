import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;

/// Foto pela webcam do computador. No navegador de desktop o `image_picker`
/// ignora a câmera e abre o seletor de arquivos; aqui a prévia é um
/// `<video>` ligado ao `getUserMedia` e a foto sai de um `<canvas>`.
///
/// Lança se o navegador negar ou não tiver câmera; `null` é cancelar.
Future<XFile?> tirarFotoWebcam(BuildContext context) async {
  final stream = await web.window.navigator.mediaDevices
      .getUserMedia(web.MediaStreamConstraints(video: true.toJS))
      .toDart;
  final video = web.HTMLVideoElement()
    ..autoplay = true
    ..muted = true
    ..srcObject = stream
    ..setAttribute('playsinline', 'true');
  video.style
    ..width = '100%'
    ..height = '100%'
    ..objectFit = 'cover'
    // Prévia espelhada, como um espelho; a foto sai sem espelhar.
    ..transform = 'scaleX(-1)';
  final viewType = 'webcam-${DateTime.now().microsecondsSinceEpoch}';
  ui.platformViewRegistry.registerViewFactory(viewType, (int _) => video);

  try {
    if (!context.mounted) return null;
    return await showDialog<XFile>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tirar foto'),
        content: SizedBox(
          width: 480,
          height: 360,
          child: HtmlElementView(viewType: viewType),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final foto = await _capturar(video);
              if (dialogContext.mounted) Navigator.pop(dialogContext, foto);
            },
            icon: const Icon(Icons.camera_alt),
            label: const Text('Capturar'),
          ),
        ],
      ),
    );
  } finally {
    // Sem isto a luz da câmera fica acesa depois de fechar.
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
  }
}

Future<XFile?> _capturar(web.HTMLVideoElement video) async {
  final w = video.videoWidth;
  final h = video.videoHeight;
  if (w == 0 || h == 0) return null;
  final canvas = web.HTMLCanvasElement()
    ..width = w
    ..height = h;
  canvas.context2D.drawImage(video, 0, 0);
  final pronto = Completer<web.Blob?>();
  canvas.toBlob(
    ((web.Blob? blob) => pronto.complete(blob)).toJS,
    'image/jpeg',
    0.85.toJS,
  );
  final blob = await pronto.future;
  if (blob == null) return null;
  final bytes = (await blob.arrayBuffer().toDart).toDart.asUint8List();
  return XFile.fromData(bytes, name: 'webcam.jpg', mimeType: 'image/jpeg');
}
