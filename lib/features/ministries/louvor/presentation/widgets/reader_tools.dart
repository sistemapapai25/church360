import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../praise/domain/chord.dart';
import '../../../../praise/domain/pitch.dart';

/// Cartão flutuante dos painéis do leitor (print 13 do CifraClub).
class _FloatingCard extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  final Widget child;

  const _FloatingCard({
    required this.title,
    required this.onClose,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 6,
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(CommunityDesign.radius),
      child: SizedBox(
        width: 280,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: CommunityDesign.titleStyle(context),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    icon: const Icon(AppIcons.close),
                    onPressed: onClose,
                  ),
                ],
              ),
              Padding(padding: const EdgeInsets.only(right: 12), child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// WAV curto (seno com decaimento) para o clique, gerado na hora: sem arquivo
/// de áudio no projeto.
Uint8List _click(double hz) {
  const rate = 22050;
  const n = rate ~/ 25; // 40 ms
  final data = ByteData(44 + n * 2);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + n * 2, Endian.little);
  ascii(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    final v = math.sin(2 * math.pi * hz * i / rate) * math.exp(-i / (n / 5));
    data.setInt16(44 + i * 2, (v * 26000).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

/// Metrônomo: bolinhas 1-2-3-4 (o 1 acentuado), BPM grande e Iniciar.
class MetronomePanel extends StatefulWidget {
  final int initialBpm;
  final VoidCallback onClose;

  const MetronomePanel({
    super.key,
    required this.initialBpm,
    required this.onClose,
  });

  @override
  State<MetronomePanel> createState() => _MetronomePanelState();
}

class _MetronomePanelState extends State<MetronomePanel> {
  static const _beats = 4;
  late int _bpm = widget.initialBpm.clamp(30, 240);
  Timer? _timer;
  int _beat = -1;
  final _accent = AudioPlayer();
  final _tick = AudioPlayer();
  bool _loaded = false;

  @override
  void dispose() {
    _timer?.cancel();
    _accent.dispose();
    _tick.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_timer != null) {
      _timer!.cancel();
      setState(() {
        _timer = null;
        _beat = -1;
      });
      return;
    }
    if (!_loaded) {
      _loaded = true;
      try {
        await _accent.setSource(BytesSource(_click(1760)));
        await _tick.setSource(BytesSource(_click(1175)));
      } catch (_) {
        // Sem som o metrônomo segue piscando.
      }
    }
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    _beat = -1;
    _onBeat();
    _timer = Timer.periodic(
      Duration(microseconds: 60000000 ~/ _bpm),
      (_) => _onBeat(),
    );
  }

  void _onBeat() {
    if (!mounted) return;
    setState(() => _beat = (_beat + 1) % _beats);
    final p = _beat == 0 ? _accent : _tick;
    p.seek(Duration.zero).then((_) => p.resume()).catchError((_) {});
  }

  void _setBpm(int v) {
    setState(() => _bpm = v.clamp(30, 240));
    if (_timer != null) _restart();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _FloatingCard(
      title: 'Metrônomo',
      onClose: widget.onClose,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _beats; i++)
                Container(
                  margin: const EdgeInsets.all(5),
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _beat
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: i == _beat ? scheme.onPrimary : null,
                    ),
                  ),
                ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Mais devagar',
                icon: const Icon(AppIcons.remove),
                onPressed: () => _setBpm(_bpm - 1),
              ),
              Text(
                '$_bpm',
                style: CommunityDesign.titleStyle(
                  context,
                ).copyWith(fontSize: 40),
              ),
              const SizedBox(width: 4),
              Text('BPM', style: CommunityDesign.metaStyle(context)),
              IconButton(
                tooltip: 'Mais rápido',
                icon: const Icon(AppIcons.add),
                onPressed: () => _setBpm(_bpm + 1),
              ),
            ],
          ),
          Slider(
            value: _bpm.toDouble(),
            min: 30,
            max: 240,
            onChanged: (v) => _setBpm(v.round()),
          ),
          FilledButton(
            onPressed: _toggle,
            child: Text(_timer == null ? 'Iniciar' : 'Parar'),
          ),
        ],
      ),
    );
  }
}

/// Afinador pelo microfone: a nota mais perto no meio das vizinhas, o
/// ponteiro em cents e a frequência. Lá = 440 Hz.
class TunerPanel extends StatefulWidget {
  final VoidCallback onClose;

  const TunerPanel({super.key, required this.onClose});

  @override
  State<TunerPanel> createState() => _TunerPanelState();
}

class _TunerPanelState extends State<TunerPanel> {
  static const _rate = 44100;
  static const _window = 4096;
  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  final _buffer = Float32List(_window);
  int _filled = 0;
  DateTime _last = DateTime(0);
  String? _error;
  bool _listening = false;
  double? _hz;

  @override
  void dispose() {
    _sub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      if (!await _recorder.hasPermission()) {
        setState(() => _error = 'Sem permissão para usar o microfone.');
        return;
      }
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _rate,
          numChannels: 1,
        ),
      );
      _sub = stream.listen(_onAudio);
      setState(() => _listening = true);
    } catch (e) {
      setState(() => _error = 'Não deu para abrir o microfone.');
    }
  }

  void _onAudio(Uint8List bytes) {
    final pcm = ByteData.sublistView(bytes);
    final count = bytes.length ~/ 2;
    // Janela deslizante: as amostras novas entram no fim.
    if (count >= _window) {
      for (var i = 0; i < _window; i++) {
        _buffer[i] =
            pcm.getInt16((count - _window + i) * 2, Endian.little) / 32768;
      }
    } else {
      _buffer.setRange(0, _window - count, _buffer, count);
      for (var i = 0; i < count; i++) {
        _buffer[_window - count + i] =
            pcm.getInt16(i * 2, Endian.little) / 32768;
      }
    }
    _filled = math.min(_window, _filled + count);
    final now = DateTime.now();
    if (_filled < _window || now.difference(_last).inMilliseconds < 120) {
      return;
    }
    _last = now;
    final hz = detectPitch(_buffer, _rate);
    if (mounted && hz != null) setState(() => _hz = hz);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final meta = CommunityDesign.metaStyle(context);
    final hz = _hz;
    final near = hz == null ? null : nearestNote(hz);
    final inTune = near != null && near.cents.abs() < 5;

    return _FloatingCard(
      title: 'Afinador',
      onClose: widget.onClose,
      child: !_listening
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'O afinador ouve o instrumento pelo microfone do aparelho.',
                  textAlign: TextAlign.center,
                  style: meta,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(AppIcons.microphone),
                  label: const Text('Habilitar meu microfone'),
                  onPressed: _start,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: meta.copyWith(color: scheme.error),
                    ),
                  ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var d = -2; d <= 2; d++)
                      Text(
                        near == null
                            ? (d == 0 ? '–' : '')
                            : Chord.noteName(near.semitone + d),
                        style: d == 0
                            ? CommunityDesign.titleStyle(context).copyWith(
                                fontSize: 36,
                                color: inTune ? scheme.primary : null,
                              )
                            : meta.copyWith(fontSize: 16),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Ponteiro: centro = afinado; esquerda = baixo, direita = alto.
                LayoutBuilder(
                  builder: (context, c) {
                    final x = near == null
                        ? c.maxWidth / 2
                        : c.maxWidth / 2 + near.cents / 50 * (c.maxWidth / 2);
                    return SizedBox(
                      height: 24,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Center(
                              child: Container(
                                height: 4,
                                color: scheme.surfaceContainerHighest,
                              ),
                            ),
                          ),
                          Positioned(
                            left: c.maxWidth / 2 - 1,
                            top: 0,
                            bottom: 0,
                            child: Container(width: 2, color: scheme.outline),
                          ),
                          if (near != null)
                            Positioned(
                              left: x.clamp(0, c.maxWidth) - 6,
                              top: 6,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: inTune ? scheme.primary : scheme.error,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  near == null
                      ? 'Toque uma corda'
                      : '${hz!.toStringAsFixed(1)} Hz · '
                            '${near.cents >= 0 ? '+' : ''}${near.cents.round()} cents',
                  style: meta,
                ),
                Text('Lá = 440 Hz', style: meta.copyWith(fontSize: 11)),
              ],
            ),
    );
  }
}
