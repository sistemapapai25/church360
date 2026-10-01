import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Onde a posição fica salva ao soltar o painel (como o círculo do
  /// suporte): ao reabrir, ele volta para lá.
  final String prefsKey;
  final Widget child;

  const FloatingTool({
    super.key,
    required this.area,
    required this.initial,
    required this.prefsKey,
    required this.child,
  });

  @override
  State<FloatingTool> createState() => _FloatingToolState();
}

class _FloatingToolState extends State<FloatingTool> {
  late Offset _pos = widget.initial;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final v = p.getStringList(widget.prefsKey);
      final x = double.tryParse(v?.first ?? ''),
          y = double.tryParse(v?.last ?? '');
      if (mounted && x != null && y != null) {
        setState(() => _pos = Offset(x, y));
      }
    });
  }

  Future<void> _save() async {
    final p = _clamped;
    (await SharedPreferences.getInstance()).setStringList(widget.prefsKey, [
      '${p.dx}',
      '${p.dy}',
    ]);
  }

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
      child: _DragScope(onDrag: _drag, onEnd: _save, child: widget.child),
    );
  }
}

/// Repassa o arrasto do cabeçalho do [_FloatingCard] para o [FloatingTool].
class _DragScope extends InheritedWidget {
  final ValueChanged<Offset> onDrag;
  final VoidCallback onEnd;

  const _DragScope({
    required this.onDrag,
    required this.onEnd,
    required super.child,
  });

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
                    onPanEnd: drag == null ? null : (_) => drag.onEnd(),
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

/// Um tocador por força de clique (fraco, médio, forte).
Future<void> _loadClicks(List<AudioPlayer> players) async {
  try {
    for (final (p, hz) in [
      (players[0], 1175.0),
      (players[1], 1400.0),
      (players[2], 1760.0),
    ]) {
      // `release` (o padrão) solta o som ao fim de cada clique e os
      // seguintes saem mudos.
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setSource(_source(_click(hz)));
    }
  } catch (_) {
    // Sem som o metrônomo segue piscando.
  }
}

void _playClick(AudioPlayer p) =>
    p.seek(Duration.zero).then((_) => p.resume()).catchError((_) {});

/// Compassos de um toque; o resto sai do "Personalizado".
const metronomePresets = ['2/4', '3/4', '4/4', '6/8', '9/8', '12/8'];

/// Denominadores que existem na notação: a figura que vale um tempo.
const meterUnits = [1, 2, 4, 8, 16, 32];

/// `"6/8"` → (6, 8). Numerador de 1 a 32 e unidade de [meterUnits]; o que
/// não servir vira 4/4.
(int, int) parseMeter(String? s) {
  final m = RegExp(r'^\s*(\d+)\s*/\s*(\d+)\s*$').firstMatch(s ?? '');
  final n = int.tryParse(m?[1] ?? ''), d = int.tryParse(m?[2] ?? '');
  if (n == null || d == null || n < 1 || n > 32 || !meterUnits.contains(d)) {
    return (4, 4);
  }
  return (n, d);
}

/// Força do clique: 2 = primeiro tempo, 1 = início de cada grupo de três
/// colcheias nos compostos (6/8, 9/8, 12/8...), 0 = o resto.
int beatAccent(int beat, int beats, int unit) {
  if (beat == 0) return 2;
  final compound = unit == 8 && beats > 3 && beats % 3 == 0;
  return compound && beat % 3 == 0 ? 1 : 0;
}

/// Metrônomo: bolinhas de cada tempo (o 1 acentuado), BPM grande, compasso e
/// Iniciar. Cada clique é uma figura do denominador (em 6/8, uma colcheia).
class MetronomePanel extends StatefulWidget {
  final int initialBpm;

  /// `{time: 6/8}` da cifra, se houver.
  final String? initialMeter;
  final VoidCallback onClose;

  const MetronomePanel({
    super.key,
    required this.initialBpm,
    this.initialMeter,
    required this.onClose,
  });

  @override
  State<MetronomePanel> createState() => _MetronomePanelState();
}

class _MetronomePanelState extends State<MetronomePanel> {
  static const _minBpm = 20, _maxBpm = 400;
  late int _bpm = widget.initialBpm.clamp(_minBpm, _maxBpm);
  late int _beats = parseMeter(widget.initialMeter).$1;
  late int _unit = parseMeter(widget.initialMeter).$2;
  late bool _custom = !metronomePresets.contains('$_beats/$_unit');

  /// Acentos escolhidos tocando nas bolinhas (7/8 = 2+2+3, 6/8 com o forte
  /// e o médio onde a música pede). Nulo = os de [beatAccent]. Trocar o
  /// compasso volta ao padrão.
  List<int>? _accents;

  int _accentOf(int beat) => _accents?[beat] ?? beatAccent(beat, _beats, _unit);

  /// fraco → médio → forte → fraco.
  void _cycleAccent(int beat) => setState(() {
    final a = _accents ??= [
      for (var b = 0; b < _beats; b++) beatAccent(b, _beats, _unit),
    ];
    a[beat] = (a[beat] + 1) % 3;
  });
  Timer? _timer;
  int _beat = -1;
  // Um tocador por força de clique: forte, médio, fraco.
  final _players = [AudioPlayer(), AudioPlayer(), AudioPlayer()];
  bool _loaded = false;

  @override
  void dispose() {
    _timer?.cancel();
    for (final p in _players) {
      p.dispose();
    }
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
      await _loadClicks(_players);
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
    _playClick(_players[_accentOf(_beat)]);
  }

  void _setBpm(int v) {
    setState(() => _bpm = v.clamp(_minBpm, _maxBpm));
    if (_timer != null) _restart();
  }

  void _setMeter(int beats, int unit) {
    setState(() {
      _beats = beats.clamp(1, 32);
      _unit = unit;
      _accents = null;
    });
    if (_timer != null) _restart();
  }

  /// Tocar no número abre o campo para digitar o BPM.
  Future<void> _typeBpm() async {
    final c = TextEditingController(text: '$_bpm');
    final v = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('BPM'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(helperText: '$_minBpm a $_maxBpm'),
          onSubmitted: (t) => Navigator.pop(context, int.tryParse(t)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(c.text)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    c.dispose();
    if (v != null) _setBpm(v);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final running = _timer != null;
    final dot = _beats > 8 ? 20.0 : 28.0;

    Widget meterChip(String label, bool selected, VoidCallback onTap) =>
        ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          shape: const StadiumBorder(),
          visualDensity: VisualDensity.compact,
          labelStyle: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w700,
          ),
          // `color` em vez de background/selectedColor: no Material 3 o chip
          // não selecionado saía branco no tema claro, com o texto branco.
          color: WidgetStatePropertyAll(selected ? accent : Colors.white10),
          side: BorderSide.none,
          onSelected: (_) => onTap(),
        );

    return _FloatingCard(
      title: 'Metrônomo',
      onClose: widget.onClose,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              for (var i = 0; i < _beats; i++)
                Semantics(
                  button: true,
                  label:
                      'Tempo ${i + 1}, ${const ['fraco', 'médio', 'forte'][_accentOf(i)]}',
                  child: GestureDetector(
                    onTap: () => _cycleAccent(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 80),
                      width: dot,
                      height: dot,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _beat ? accent : Colors.white10,
                        border: _accentOf(i) > 0 && i != _beat
                            ? Border.all(
                                width: _accentOf(i).toDouble(),
                                color: accent.withValues(
                                  alpha: _accentOf(i) == 2 ? 0.8 : 0.45,
                                ),
                              )
                            : null,
                      ),
                      child: ExcludeSemantics(
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: dot * 0.43,
                            fontWeight: FontWeight.w700,
                            color: i == _beat ? Colors.white : Colors.white60,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _accents == null
                ? 'Toque num tempo para mudar o acento'
                : 'Acento personalizado',
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _RoundButton(
                AppIcons.remove,
                'Mais devagar',
                () => _setBpm(_bpm - 1),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _typeBpm,
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
                      Text(
                        'BPM · $_beats/$_unit',
                        style: const TextStyle(
                          fontSize: 12,
                          letterSpacing: 2,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
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
              value: _bpm.clamp(30, 240).toDouble(),
              min: 30,
              max: 240,
              onChanged: (v) => _setBpm(v.round()),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in metronomePresets)
                meterChip(m, !_custom && m == '$_beats/$_unit', () {
                  final (n, d) = parseMeter(m);
                  _custom = false;
                  _setMeter(n, d);
                }),
              meterChip(
                'Personalizado',
                _custom,
                () => setState(() => _custom = true),
              ),
            ],
          ),
          if (_custom) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Menos tempos',
                  icon: const Icon(AppIcons.remove, size: 18),
                  onPressed: _beats > 1
                      ? () => _setMeter(_beats - 1, _unit)
                      : null,
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '$_beats',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Mais tempos',
                  icon: const Icon(AppIcons.add, size: 18),
                  onPressed: _beats < 32
                      ? () => _setMeter(_beats + 1, _unit)
                      : null,
                ),
                const Text(
                  ' / ',
                  style: TextStyle(fontSize: 18, color: Colors.white54),
                ),
                DropdownButton<int>(
                  value: _unit,
                  dropdownColor: _panelBg,
                  underline: const SizedBox.shrink(),
                  style: const TextStyle(
                    color: _panelFg,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  items: [
                    for (final u in meterUnits)
                      DropdownMenuItem(value: u, child: Text('$u')),
                  ],
                  onChanged: (u) => _setMeter(_beats, u ?? _unit),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
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
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Builder(
                            builder: (context) {
                              final style = d == 0
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
                                    );
                              if (near == null) {
                                return Text(d == 0 ? '–' : '', style: style);
                              }
                              // Nota grande e oitava pequena: A4, E2.
                              final midi =
                                  (near.octave + 1) * 12 + near.semitone;
                              return Text.rich(
                                TextSpan(
                                  text: Chord.noteName(near.semitone + d),
                                  children: [
                                    TextSpan(
                                      text: '${(midi + d) ~/ 12 - 1}',
                                      style: TextStyle(
                                        fontSize: style.fontSize! * 0.4,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                style: style,
                              );
                            },
                          ),
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

/// Player por seção (CifraClub §1.4, sem áudio da música): clique no BPM da
/// seção e a cifra rolando de [start] até [end] no tempo dela, com barra de
/// progresso e repetir. Cada linha conta 2 compassos. Mexer na tela para.
class SectionPlayerBar extends StatefulWidget {
  final String label;
  final int bpm;
  final String? meter;
  final int lines;
  final ScrollController scroll;

  /// Onde a seção começa e onde a próxima começa, no `offset` da rolagem.
  final double Function() start;
  final double Function() end;
  final VoidCallback onClose;

  const SectionPlayerBar({
    super.key,
    required this.label,
    required this.bpm,
    this.meter,
    required this.lines,
    required this.scroll,
    required this.start,
    required this.end,
    required this.onClose,
  });

  @override
  State<SectionPlayerBar> createState() => _SectionPlayerBarState();
}

class _SectionPlayerBarState extends State<SectionPlayerBar>
    with SingleTickerProviderStateMixin {
  late final _ticker = createTicker(_tick);
  final _players = [AudioPlayer(), AudioPlayer(), AudioPlayer()];
  bool _loaded = false;
  bool _loop = false;

  /// Posição em segundos dentro da seção; [_from] = onde estava ao dar play.
  double _pos = 0;
  double _from = 0;
  int _lastClick = -1;
  double? _jumped;

  (int, int) get _meter => parseMeter(widget.meter);
  double get _clickSeconds => 60 / widget.bpm.clamp(20, 400);
  int get _clicks => math.max(1, widget.lines) * 2 * _meter.$1;
  double get _total => _clicks * _clickSeconds;

  @override
  void initState() {
    super.initState();
    _play();
  }

  @override
  void dispose() {
    _ticker.dispose();
    for (final p in _players) {
      p.dispose();
    }
    super.dispose();
  }

  void _play() {
    // Não espera o som carregar: a rolagem começa já.
    if (!_loaded) {
      _loaded = true;
      _loadClicks(_players).ignore();
    }
    if (_pos >= _total) _pos = 0;
    _from = _pos;
    _lastClick = -1;
    _jumped = null;
    _ticker.start();
    setState(() {});
  }

  void _pause() {
    _ticker.stop();
    if (mounted) setState(() {});
  }

  void _seek(double seconds) {
    _pos = seconds.clamp(0, _total);
    _from = _pos;
    _lastClick = (_pos / _clickSeconds).floor();
    if (_ticker.isActive) {
      _ticker.stop();
      _ticker.start();
    }
    _scrollTo();
    setState(() {});
  }

  void _scrollTo() {
    final s = widget.scroll;
    if (!s.hasClients) return;
    final a = widget.start(), b = widget.end();
    final to = (a + (b - a) * (_pos / _total)).clamp(
      0.0,
      s.position.maxScrollExtent,
    );
    s.jumpTo(to);
    _jumped = to;
  }

  void _tick(Duration elapsed) {
    final s = widget.scroll;
    // Alguém rolou com o dedo ou o mouse: para e deixa a pessoa olhar.
    if (_jumped != null && s.hasClients && (s.offset - _jumped!).abs() > 2) {
      return _pause();
    }
    _pos = _from + elapsed.inMicroseconds / 1e6;
    if (_pos >= _total) {
      if (_loop) {
        _seek(0);
        return;
      }
      _pos = _total;
      _scrollTo();
      return _pause();
    }
    final click = (_pos / _clickSeconds).floor();
    if (click != _lastClick) {
      _lastClick = click;
      final beat = click % _meter.$1;
      _playClick(_players[beatAccent(beat, _meter.$1, _meter.$2)]);
    }
    _scrollTo();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final playing = _ticker.isActive;
    final accent = Theme.of(context).colorScheme.primary;
    return Material(
      elevation: 8,
      color: _panelBg,
      shape: const StadiumBorder(),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: _panelFg),
        child: IconTheme.merge(
          data: const IconThemeData(color: _panelFg),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: playing ? 'Pausar seção' : 'Tocar seção',
                  icon: Icon(playing ? AppIcons.pause : AppIcons.playArrow),
                  onPressed: playing ? _pause : _play,
                ),
                Flexible(
                  child: Text(
                    '${widget.label} · ${widget.bpm} bpm',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: accent,
                      thumbColor: accent,
                      inactiveTrackColor: Colors.white12,
                    ),
                    child: Slider(
                      value: _pos.clamp(0, _total),
                      max: _total,
                      onChanged: _seek,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: _loop ? 'Repetir ligado' : 'Repetir desligado',
                  isSelected: _loop,
                  color: _loop ? accent : Colors.white54,
                  icon: const Icon(AppIcons.repeat),
                  onPressed: () => setState(() => _loop = !_loop),
                ),
                IconButton(
                  tooltip: 'Fechar player',
                  icon: const Icon(AppIcons.close),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
