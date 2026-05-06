import 'package:flutter/foundation.dart';

class ShareLinkUtils {
  static String buildShareUrl(String path) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final base = Uri.base;

    if (kIsWeb) {
      // Flutter web costuma usar hash (#/...). Preservar o host e trocar o fragment.
      if (base.fragment.startsWith('/')) {
        return base.replace(fragment: cleanPath).toString();
      }
      return base.replace(path: cleanPath, queryParameters: {}).toString();
    }

    // Mobile sem deep links: compartilhar o path.
    return cleanPath;
  }
}

