import 'dart:js_interop';
import 'dart:ui_web' as ui;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

void registerIframeViewFactory({
  required String viewType,
  required String url,
  required VoidCallback onLoad,
  required VoidCallback onError,
}) {
  ui.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) {
      final iframe = web.HTMLIFrameElement();
      iframe.src = url;
      iframe.style.border = 'none';
      iframe.style.width = '100%';
      iframe.style.height = '100%';

      iframe.addEventListener(
        'load',
        ((web.Event _) {
          onLoad();
        }).toJS,
      );

      iframe.addEventListener(
        'error',
        ((web.Event _) {
          onError();
        }).toJS,
      );

      return iframe;
    },
  );
}

void openInNewTab(String url) {
  web.window.open(url, '_blank');
}
