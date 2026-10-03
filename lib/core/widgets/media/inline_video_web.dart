import 'dart:ui_web' as ui;

import 'package:web/web.dart' as web;

final _registered = <String>{};

/// Registra (uma vez por URL) o player e devolve o viewType para o
/// `HtmlElementView`. YouTube ([youtubeId]) vira o embed oficial direto, num
/// iframe só, com os controles e a tela cheia do próprio YouTube; arquivo
/// vira `<video controls>`.
String videoViewType(String url, {String? youtubeId}) {
  final type = 'inline-video-${url.hashCode}';
  if (_registered.add(type)) {
    ui.platformViewRegistry.registerViewFactory(type, (int _) {
      final web.HTMLElement el = youtubeId == null
          ? (web.HTMLVideoElement()
              ..src = url
              ..controls = true
              ..autoplay = true)
          : (web.HTMLIFrameElement()
              ..src =
                  'https://www.youtube.com/embed/$youtubeId'
                  '?autoplay=1&playsinline=1&rel=0'
              ..allow =
                  'autoplay; fullscreen; picture-in-picture; encrypted-media'
              ..allowFullscreen = true);
      return el
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'black';
    });
  }
  return type;
}
