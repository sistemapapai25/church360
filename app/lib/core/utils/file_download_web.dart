import 'dart:convert';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

void downloadFile(String filename, Uint8List bytes) {
  final dataUrl = 'data:application/pdf;base64,${base64Encode(bytes)}';
  final a = web.HTMLAnchorElement()
    ..href = dataUrl
    ..download = filename
    ..target = '_blank'
    ..style.display = 'none';
  web.document.body?.append(a);
  a.click();
  a.remove();
}
