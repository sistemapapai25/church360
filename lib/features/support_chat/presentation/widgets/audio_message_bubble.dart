import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Reduz os níveis do microfone (dBFS, de -160 a 0) gravados a cada 100 ms a [count] barras
/// de 0.15 a 1. Sem níveis (aparelho que não informa), barras médias iguais.
List<double> waveformBars(List<double> dbfs, {int count = 32}) {
  if (dbfs.isEmpty) return List.filled(count, 0.4);
  double norm(double db) => ((db.clamp(-50.0, 0.0) + 50) / 50 * 0.85 + 0.15);
  return List.generate(count, (i) {
    final start = (i * dbfs.length / count).floor();
    final end = math.max(start + 1, ((i + 1) * dbfs.length / count).floor());
    final slice = dbfs.sublist(start, math.min(end, dbfs.length));
    return norm(slice.reduce(math.max));
  });
}

/// Fala do agente (lida em voz pelo aparelho): a onda sai do tamanho das palavras,
/// sempre igual para o mesmo texto.
List<double> speechBars(String text, {int count = 32}) {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return List.filled(count, 0.4);
  return List.generate(count, (i) => 0.25 + math.min(words[i * words.length ~/ count].length, 10) / 10 * 0.75);
}

/// Duração estimada da fala: uns 150 palavras por minuto.
int speechDurationMs(String text) =>
    math.max(1000, text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length * 400);

String formatAudioDuration(int ms) {
  final s = (ms / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Bolha de áudio no visual do Support360: foto, play, ondas e duração dentro do card,
/// e "Transcrição" abrindo o texto embaixo.
class AudioMessageBubble extends StatelessWidget {
  const AudioMessageBubble({
    super.key,
    required this.isUser,
    required this.accent,
    required this.bars,
    required this.durationMs,
    required this.progress,
    required this.isPlaying,
    required this.avatar,
    this.onToggle,
    this.transcript,
    this.showTranscript = false,
    this.onToggleTranscript,
  });

  final bool isUser;
  final Color accent;
  final List<double> bars;
  final int durationMs;

  /// 0 a 1: parte já tocada.
  final double progress;
  final bool isPlaying;
  final Widget avatar;

  /// Nulo = sem arquivo para tocar (ex.: histórico depois de reabrir o app).
  final VoidCallback? onToggle;
  final String? transcript;
  final bool showTranscript;
  final VoidCallback? onToggleTranscript;

  @override
  Widget build(BuildContext context) {
    final fg = isUser ? Colors.white : const Color(0xFF0E1018);
    final hasTranscript = (transcript ?? '').trim().isNotEmpty;
    final played = (progress.clamp(0.0, 1.0) * bars.length).round();

    return Container(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: isUser ? accent : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isUser ? 12 : 0),
          topRight: Radius.circular(isUser ? 0 : 12),
          bottomLeft: const Radius.circular(12),
          bottomRight: const Radius.circular(12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isUser ? 0.12 : 0.07),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(width: 32, height: 32, child: ClipOval(child: avatar)),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: isPlaying ? 'Parar áudio' : 'Tocar áudio',
                child: InkWell(
                  onTap: onToggle,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isUser ? Colors.white : accent,
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 18,
                      color: (isUser ? accent : Colors.white).withValues(alpha: onToggle == null ? 0.4 : 1),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 26,
                  child: Row(
                    children: [
                      for (var i = 0; i < bars.length; i++)
                        Expanded(
                          child: Center(
                            child: Container(
                              width: 3,
                              // Antes de tocar, só pontinhos; a onda real aparece conforme o áudio passa.
                              height: i < played ? 26 * bars[i] : 3,
                              decoration: BoxDecoration(
                                color: fg.withValues(alpha: i < played ? 1 : 0.45),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatAudioDuration(durationMs),
                style: TextStyle(
                  fontSize: 11,
                  color: fg.withValues(alpha: 0.7),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (hasTranscript) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: onToggleTranscript,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.subject_rounded, size: 14, color: fg.withValues(alpha: 0.75)),
                    const SizedBox(width: 4),
                    Text(
                      showTranscript ? 'Ocultar transcrição' : 'Transcrição',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
              ),
            ),
            if (showTranscript)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SelectableText(
                  transcript!.trim(),
                  style: TextStyle(fontSize: 13, height: 1.45, fontStyle: FontStyle.italic, color: fg.withValues(alpha: 0.9)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
