import 'package:flutter/material.dart';

/// Overlay padrão para thumbnails de vídeo (evento, aula, devocional...):
/// botão de play circular + badge de duração opcional, sobre a imagem.
class VideoPlayOverlay extends StatelessWidget {
  final String? duration;
  final double size;

  const VideoPlayOverlay({
    super.key,
    this.duration,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (duration != null && duration!.isNotEmpty)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                duration!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.5),
            ),
            child: Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: size * 0.42,
            ),
          ),
        ),
      ],
    );
  }
}
