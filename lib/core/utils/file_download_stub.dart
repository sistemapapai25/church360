import 'dart:typed_data';

void downloadFile(String filename, Uint8List bytes) {
  // Stub implementation for non-web platforms.
  // This should ideally not be reached if guarded by kIsWeb,
  // or logic for mobile download/share should be handled by caller or another utility.
  throw UnimplementedError('Web download is not supported on this platform.');
}
