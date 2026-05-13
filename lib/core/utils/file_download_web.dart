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

/// Lote 7.1: download de CSV no web. Prepende BOM UTF-8 para abrir
/// corretamente com Excel em PT-BR (caracteres acentuados).
void downloadCsv(String filename, String csv) {
  final withBom = '﻿$csv';
  final bytes = Uint8List.fromList(utf8.encode(withBom));
  final dataUrl =
      'data:text/csv;charset=utf-8;base64,${base64Encode(bytes)}';
  final a = web.HTMLAnchorElement()
    ..href = dataUrl
    ..download = filename
    ..target = '_blank'
    ..style.display = 'none';
  web.document.body?.append(a);
  a.click();
  a.remove();
}
