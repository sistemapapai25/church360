import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart'
    show YoutubePlayer;

import 'inline_video_web_stub.dart'
    if (dart.library.js_interop) 'inline_video_web.dart';
import 'video_play_overlay.dart';

/// Embed oficial do YouTube: os controles são os do próprio YouTube
/// (pausar, voltar, legendas, velocidade, tela cheia).
String youtubeEmbedUrl(String id) =>
    'https://www.youtube.com/embed/$id?autoplay=1&playsinline=1&rel=0';

/// Página mínima com o embed, para a WebView do app instalado. Vai com a
/// origem do app ([_embedBase]): sem origem/referer o YouTube recusa o
/// embed ("erro de configuração do player").
String youtubeEmbedHtml(String id) =>
    '<!doctype html><html><head>'
    '<meta name="viewport" content="width=device-width,initial-scale=1">'
    '<style>html,body{margin:0;height:100%;background:#000}'
    'iframe{border:0;width:100%;height:100%}</style></head><body>'
    '<iframe src="${youtubeEmbedUrl(id)}" '
    'allow="autoplay; fullscreen; picture-in-picture; encrypted-media" '
    'allowfullscreen></iframe></body></html>';

const _embedBase = 'https://papai.church360.com.br/';

/// O único player de vídeo do app (aula, devocional, culto). Capa 16:9 com
/// o botão de play; tocar troca a capa pelo player.
///
/// YouTube é sempre o embed oficial direto, com os controles do YouTube: no
/// navegador num iframe só; no app instalado numa WebView com a mesma
/// página. Os players antigos (`youtube_player_iframe`, com iframe
/// intermediário por `postMessage`, e `youtube_player_flutter`, com
/// controles próprios sem legenda) deixavam o toque sem resposta. Arquivo
/// enviado (mp4 do Storage) toca num `<video>` no navegador; no app
/// instalado abre por fora.
class InlineVideo extends StatefulWidget {
  final String url;

  /// Já abre no player, sem a capa (culto ao vivo, devocional depois do
  /// play). Só vale para YouTube; arquivo continua esperando o toque.
  final bool autoStart;

  const InlineVideo({super.key, required this.url, this.autoStart = false});

  @override
  State<InlineVideo> createState() => _InlineVideoState();
}

class _InlineVideoState extends State<InlineVideo> {
  late bool _playing = widget.autoStart && _youtubeId != null;

  String? get _youtubeId => YoutubePlayer.convertUrlToId(widget.url);

  Future<void> _play() async {
    if (_youtubeId == null && !kIsWeb) {
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
    setState(() => _playing = true);
  }

  Widget _player(String? id) {
    if (kIsWeb) {
      return HtmlElementView(
        viewType: videoViewType(widget.url, youtubeId: id),
      );
    }
    return InAppWebView(
      key: ValueKey('yt-webview-$id'),
      initialData: InAppWebViewInitialData(
        data: youtubeEmbedHtml(id!),
        baseUrl: WebUri(_embedBase),
      ),
      initialSettings: InAppWebViewSettings(
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        transparentBackground: true,
      ),
    );
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
