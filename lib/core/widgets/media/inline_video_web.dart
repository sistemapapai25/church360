import 'dart:ui_web' as ui;

import 'package:web/web.dart' as web;

final _registered = <String>{};

/// Registra (uma vez por URL) um `<video controls>` e devolve o viewType
/// para o `HtmlElementView`.
String videoViewType(String url) {
  final type = 'inline-video-${url.hashCode}';
  if (_registered.add(type)) {
    ui.platformViewRegistry.registerViewFactory(type, (int _) {
      return web.HTMLVideoElement()
        ..src = url
        ..controls = true
        ..autoplay = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'black';
    });
  }
  return type;
}
