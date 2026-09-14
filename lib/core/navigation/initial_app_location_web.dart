// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

/// Preserva o caminho e o callback de autenticação presentes na URL real.
///
/// `Uri.base` usa a tag HTML `<base href="/">` do Flutter Web e, por isso,
/// não representa links profundos como `/reset-password?code=...`.
String _initialLocation = '/';

void captureInitialAppLocation() {
  _initialLocation = _readCurrentLocation();
}

String initialAppLocation() => _initialLocation;

String _readCurrentLocation() {
  final location = html.window.location;
  final pathname = location.pathname ?? '';
  final path = pathname.isEmpty ? '/' : pathname;
  return '$path${location.search ?? ''}${location.hash}';
}
