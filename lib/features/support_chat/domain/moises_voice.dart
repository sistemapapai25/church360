import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Voz do Moisés: a mesma em todo aparelho (Antonio, gerada pela edge
/// moises-voz). Sem internet ou com a voz fora do ar, lê com a voz do aparelho.
/// Troca direta do FlutterTts: mesmos métodos que as telas usam.
class MoisesVoice {
  MoisesVoice() {
    _player.onPlayerComplete.listen((_) => _onDone?.call());
    _player.onPositionChanged.listen((p) async {
      final d = await _player.getDuration();
      if (_onProgress != null && d != null && d.inMilliseconds > 0 && _text.isNotEmpty) {
        final end = (_text.length * p.inMilliseconds / d.inMilliseconds).round().clamp(0, _text.length);
        _onProgress!(_text, 0, end, '');
      }
    });
  }

  /// Uma resposta já ouvida não gasta a cota de novo enquanto o app está aberto.
  static final _cache = <String, Uint8List>{};

  final _player = AudioPlayer();
  final _device = FlutterTts();
  VoidCallback? _onDone, _onCancel;
  void Function(String text, int start, int end, String word)? _onProgress;
  String _text = '';
  int _turn = 0;

  Future<void> setLanguage(String lang) => _device.setLanguage(lang);

  void setCompletionHandler(VoidCallback f) {
    _onDone = f;
    _device.setCompletionHandler(f);
  }

  void setCancelHandler(VoidCallback f) {
    _onCancel = f;
    _device.setCancelHandler(f);
  }

  void setErrorHandler(void Function(dynamic) f) => _device.setErrorHandler(f);

  void setProgressHandler(void Function(String, int, int, String) f) {
    _onProgress = f;
    _device.setProgressHandler(f);
  }

  Future<void> speak(String text) async {
    final turn = ++_turn;
    _text = text;
    try {
      final bytes = _cache[text] ??= await _fetch(text);
      if (turn != _turn) return; // parou ou trocou de mensagem enquanto baixava
      await _player.play(kIsWeb
          ? UrlSource(Uri.dataFromBytes(bytes, mimeType: 'audio/mpeg').toString())
          : BytesSource(bytes));
    } catch (e) {
      debugPrint('moises-voz: $e; usando a voz do aparelho');
      if (turn == _turn) await _device.speak(text);
    }
  }

  Future<void> stop() async {
    _turn++;
    final wasPlaying = _player.state == PlayerState.playing;
    await _player.stop();
    await _device.stop();
    if (wasPlaying) _onCancel?.call();
  }

  void dispose() {
    _turn++;
    _device.stop();
    _player.dispose();
  }

  static Future<Uint8List> _fetch(String text) async {
    final r = await Supabase.instance.client.functions.invoke('moises-voz', body: {'text': text});
    final data = r.data;
    if (data is Uint8List && data.isNotEmpty) return data;
    throw StateError('resposta sem áudio');
  }
}
