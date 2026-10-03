import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as yi;

import 'inline_video_web_stub.dart'
    if (dart.library.js_interop) 'inline_video_web.dart';
import 'video_play_overlay.dart';

/// Vídeo que toca dentro do app, no mesmo desenho do devocional: capa 16:9
/// com o botão de play; tocar troca a capa pelo player.
///
/// YouTube toca embutido em qualquer plataforma. Arquivo enviado (mp4 do
/// Storage) toca num `<video>` no navegador; no app nativo, sem player de
/// arquivo instalado, abre por fora.
class InlineVideo extends StatefulWidget {
  final String url;

  const InlineVideo({super.key, required this.url});

  @override
  State<InlineVideo> createState() => _InlineVideoState();
}

class _InlineVideoState extends State<InlineVideo> {
  bool _playing = false;
  YoutubePlayerController? _yt;
  yi.YoutubePlayerController? _ytWeb;

  String? get _youtubeId => YoutubePlayer.convertUrlToId(widget.url);

  @override
  void dispose() {
    _yt?.dispose();
    _ytWeb?.close();
    super.dispose();
  }

  Future<void> _play() async {
    final id = _youtubeId;
    if (id == null && !kIsWeb) {
      final uri = Uri.tryParse(widget.url);
      final ok =
          uri != null &&
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o vídeo.')),
        );
      }
      return;
    }
    if (id != null && kIsWeb) {
      _ytWeb = yi.YoutubePlayerController.fromVideoId(
        videoId: id,
        autoPlay: true,
        params: const yi.YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
        ),
      );
    } else if (id != null) {
      _yt = YoutubePlayerController(
        initialVideoId: id,
        flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
      );
    }
    setState(() => _playing = true);
  }

  Widget _player(String? id) {
    if (id == null) return HtmlElementView(viewType: videoViewType(widget.url));
    if (_ytWeb != null) return yi.YoutubePlayer(controller: _ytWeb!);
    return YoutubePlayer(controller: _yt!, showVideoProgressIndicator: true);
  }

  @override
  Widget build(BuildContext context) {
    final id = _youtubeId;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: _playing
            ? _player(id)
            : Material(
                color: Colors.black87,
                child: InkWell(
                  key: const ValueKey('inline-video-play'),
                  onTap: _play,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (id != null)
                        Image.network(
                          'https://img.youtube.com/vi/$id/hqdefault.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                      const VideoPlayOverlay(size: 56),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
