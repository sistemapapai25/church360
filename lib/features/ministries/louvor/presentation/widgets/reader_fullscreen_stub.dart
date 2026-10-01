import 'package:flutter/services.dart';

/// Tela cheia do leitor nos apps: some com as barras do sistema.
Future<void> setReaderFullscreen(bool on) =>
    SystemChrome.setEnabledSystemUIMode(
      on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
