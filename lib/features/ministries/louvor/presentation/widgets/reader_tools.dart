import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../praise/domain/chord.dart';
import '../../../../praise/domain/pitch.dart';

/// Fundo escuro fixo dos painéis (cara de aparelho, como no print 13), igual
/// nos dois temas.
const _panelBg = Color(0xFF16161A);
const _panelFg = Colors.white;
const _inTune = Color(0xFF4ADE80);

/// Painel flutuante do leitor, arrastável pelo cabeçalho como o círculo do
/// suporte. Tem que ser filho direto do `Stack` do leitor; [area] é o tamanho
/// desse `Stack`, para não deixar o painel sair da tela.
class FloatingTool extends StatefulWidget {
  final Size area;

  /// Distância inicial da borda direita e de baixo.
  final Offset initial;
  final Widget child;

  const FloatingTool({
    super.key,
    required this.area,
    required this.initial,
    required this.child,
  });

  @override
  State<FloatingTool> createState() => _FloatingToolState();
}

class _FloatingToolState extends State<FloatingTool> {
  late Offset _pos = widget.initial;

  /// Sempre sobra o cabeçalho visível para puxar o painel de volta.
  Offset get _clamped {
    final a = widget.area;
    return Offset(
      _pos.dx.clamp(0.0, math.max(0.0, a.width - _toolWidth)).toDouble(),
      _pos.dy.clamp(0.0, math.max(0.0, a.height - 56)).toDouble(),
    );
  }

  // Lê o estado na hora (não na build): o cabeçalho guarda este callback.
  void _drag(Offset d) => setState(() => _pos = _clamped - d);

  @override
  Widget build(BuildContext context) {
    final p = _clamped;
    return Positioned(
      right: p.dx,
      bottom: p.dy,
      child: _DragScope(onDrag: _drag, child: widget.child),
    );
  }
}

/// Repassa o arrasto do cabeçalho do [_FloatingCard] para o [FloatingTool].
class _DragScope extends InheritedWidget {
  final ValueChanged<Offset> onDrag;

  const _DragScope({required this.onDrag, required super.child});

  @override
  bool updateShouldNotify(_DragScope old) => false;
}

const _toolWidth = 288.0;

class _FloatingCard extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  final Widget child;
  final Color? border;

  const _FloatingCard({
    required this.title,
    required this.onClose,
    required this.child,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final drag = context.dependOnInheritedWidgetOfExactType<_DragScope>();
    return Material(
      elevation: 10,
      color: _panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CommunityDesign.radius),
        side: BorderSide(
          color: border ?? Colors.white12,
          width: border == null ? 1 : 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: _panelFg),
        child: IconTheme.merge(
          data: const IconThemeData(color: _panelFg),
          child: SizedBox(
            width: _toolWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MouseRegion(
                  cursor: drag == null
                      ? MouseCursor.defer
                      : SystemMouseCursors.move,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: drag == null
                        ? null
                        : (d) => drag.onDrag(d.delta),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 2, 2, 0),
                      child: Row(
                        children: [
                          if (drag != null)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(
                                AppIcons.dragHandle,
                                size: 18,
                                color: Colors.white38,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Fechar',
                            icon: const Icon(AppIcons.close, size: 20),
                            onPressed: onClose,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão redondo de − / + dos painéis.
class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _RoundButton(this.icon, this.tooltip, this.onPressed);

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      tooltip: tooltip,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        foregroundColor: _panelFg,
        side: const BorderSide(color: Colors.white24),
      ),
      onPressed: onPressed,
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

/// O audioplayers_web 4.x não implementa `BytesSource` (falha calado): no web
/// o WAV vai como data URI.
Source _source(Uint8List wav) => kIsWeb
    ? UrlSource('data:audio/wav;base64,${base64Encode(wav)}')
    : BytesSource(wav);

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
        for (final (p, hz) in [(_accent, 1760.0), (_tick, 1175.0)]) {
          // `release` (o padrão) solta o som ao fim de cada clique e os
          // seguintes saem mudos.
          await p.setReleaseMode(ReleaseMode.stop);
          await p.setSource(_source(_click(hz)));
        }
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
    final accent = Theme.of(context).colorScheme.primary;
    final running = _timer != null;
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
                AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _beat ? accent : Colors.white10,
                    border: i == 0 && i != _beat
                        ? Border.all(color: accent.withValues(alpha: 0.6))
                        : null,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: i == _beat ? Colors.white : Colors.white60,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _RoundButton(
                AppIcons.remove,
                'Mais devagar',
                () => _setBpm(_bpm - 1),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$_bpm',
                      style: const TextStyle(
                        fontSize: 64,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Text(
                      'BPM',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 2,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              _RoundButton(
                AppIcons.add,
                'Mais rápido',
                () => _setBpm(_bpm + 1),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accent,
              thumbColor: accent,
              inactiveTrackColor: Colors.white12,
            ),
            child: Slider(
              value: _bpm.toDouble(),
              min: 30,
              max: 240,
              onChanged: (v) => _setBpm(v.round()),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: running ? Colors.white12 : accent,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _toggle,
              child: Text(running ? 'Parar' : 'Iniciar'),
            ),
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
    const dim = TextStyle(color: Colors.white54, fontSize: 13);
    final hz = _hz;
    final near = hz == null ? null : nearestNote(hz);
    final inTune = near != null && near.cents.abs() < 5;
    final off = Theme.of(context).colorScheme.error;

    return _FloatingCard(
      title: 'Afinador',
      onClose: widget.onClose,
      border: inTune ? _inTune : null,
      child: !_listening
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                const Icon(AppIcons.microphone, size: 36),
                const SizedBox(height: 8),
                const Text(
                  'Precisamos acessar seu microfone para ouvir o instrumento.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: _start,
                    child: const Text('Habilitar meu microfone'),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: dim.copyWith(color: off),
                    ),
                  ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (var d = -2; d <= 2; d++)
                      Text(
                        near == null
                            ? (d == 0 ? '–' : '')
                            : Chord.noteName(near.semitone + d),
                        style: d == 0
                            ? TextStyle(
                                fontSize: 56,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                                color: inTune ? _inTune : Colors.white,
                              )
                            : TextStyle(
                                fontSize: d.abs() == 1 ? 20 : 16,
                                color: d.abs() == 1
                                    ? Colors.white38
                                    : Colors.white24,
                              ),
                      ),
                  ],
                ),
                Text(
                  hz == null
                      ? 'Toque uma corda'
                      : '${hz.toStringAsFixed(1)} Hz',
                  style: dim,
                ),
                const SizedBox(height: 12),
                // Régua de −50 a +50 cents: centro = afinado; esquerda =
                // baixo, direita = alto.
                LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    final x = near == null
                        ? w / 2
                        : w / 2 + near.cents.clamp(-50, 50) / 50 * (w / 2);
                    return SizedBox(
                      height: 40,
                      child: Stack(
                        children: [
                          for (var i = 0; i <= 10; i++)
                            Positioned(
                              left: w * i / 10 - 1,
                              top: i == 5 ? 4 : (i.isEven ? 12 : 16),
                              child: Container(
                                width: 2,
                                height: i == 5 ? 28 : (i.isEven ? 14 : 8),
                                color: i == 5 ? Colors.white70 : Colors.white24,
                              ),
                            ),
                          if (near != null)
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 120),
                              left: x - 2,
                              top: 0,
                              child: Container(
                                width: 4,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: inTune ? _inTune : off,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('♭', style: dim),
                    Expanded(
                      child: Text(
                        near == null
                            ? 'Lá = 440 Hz'
                            : inTune
                            ? 'Afinado'
                            : '${near.cents >= 0 ? '+' : ''}'
                                  '${near.cents.round()} cents',
                        textAlign: TextAlign.center,
                        style: dim.copyWith(
                          color: inTune ? _inTune : null,
                          fontWeight: inTune ? FontWeight.w700 : null,
                        ),
                      ),
                    ),
                    const Text('♯', style: dim),
                  ],
                ),
              ],
            ),
    );
  }
}
