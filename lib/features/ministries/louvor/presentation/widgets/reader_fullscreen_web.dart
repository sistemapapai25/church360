import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Tela cheia do leitor no navegador (a mesma do F11). Navegador que recusa
/// (iPhone, iframe) só fica sem a barra do app.
Future<void> setReaderFullscreen(bool on) async {
  try {
    if (on) {
      await web.document.documentElement?.requestFullscreen().toDart;
    } else if (web.document.fullscreenElement != null) {
      await web.document.exitFullscreen().toDart;
    }
  } catch (_) {}
}
