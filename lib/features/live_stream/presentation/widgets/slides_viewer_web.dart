import 'dart:ui_web' as ui;

import 'package:web/web.dart' as web;

final _registered = <String>{};

/// Registra (uma vez por URL) o iframe dos slides e devolve o viewType para
/// o `HtmlElementView`. Mesmo desenho do player do `InlineVideo`.
String slidesViewType(String url) {
  final type = 'culto-slides-${url.hashCode}';
  if (_registered.add(type)) {
    ui.platformViewRegistry.registerViewFactory(type, (int _) {
      return web.HTMLIFrameElement()
        ..src = url
        ..allow = 'fullscreen'
        ..allowFullscreen = true
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'black';
    });
  }
  return type;
}
