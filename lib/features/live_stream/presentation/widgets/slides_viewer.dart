import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import 'slides_viewer_web_stub.dart'
    if (dart.library.js_interop) 'slides_viewer_web.dart';

/// Link que vai no iframe/WebView. Google Slides: tanto o link "Publicar na
/// web" (`/d/e/<id>/pub`) quanto o de edição (`/d/<id>/edit`) viram `/embed`,
/// o visualizador com as setas ← → e sem a barra do Google. Qualquer outro
/// link (PDF no Storage, por exemplo) fica como está: o navegador abre.
String slidesEmbedUrl(String raw) {
  final url = raw.trim();
  final m = RegExp(
    r'^(https://docs\.google\.com/presentation/d/(?:e/)?[A-Za-z0-9_-]+)(?:/[a-z]*)?',
  ).firstMatch(url);
  if (m == null) return url;
  return '${m.group(1)}/embed?start=false&loop=false';
}

bool _isGoogleSlides(String url) =>
    url.trim().startsWith('https://docs.google.com/presentation/');

/// O WebView do Android não abre PDF (baixa o arquivo); o visualizador do
/// Google abre e deixa rolar página a página. iOS abre PDF direto.
String slidesNativeUrl(String raw) {
  final url = slidesEmbedUrl(raw);
  if (_isGoogleSlides(url) || defaultTargetPlatform != TargetPlatform.android) {
    return url;
  }
  return 'https://docs.google.com/gview?embedded=true&url='
      '${Uri.encodeComponent(url)}';
}

/// Slides do culto (roadmap 14/10, A3, D2 v1: a pessoa passa sozinha).
/// Navegador = iframe (Google Slides com as próprias setas, ou o visualizador
/// de PDF do navegador). Android/iOS = WebView embutida (`flutter_inappwebview`,
/// que já vinha com o player do YouTube), para ver e passar dentro do app.
/// Outra plataforma = "Abrir slides" por fora.
class SlidesViewer extends StatelessWidget {
  final String url;

  const SlidesViewer({super.key, required this.url});

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(url.trim());
    final ok =
        uri != null && await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir os slides.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return HtmlElementView(viewType: slidesViewType(slidesEmbedUrl(url)));
    }
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return InAppWebView(
        key: ValueKey('slides-webview-$url'),
        initialUrlRequest: URLRequest(url: WebUri(slidesNativeUrl(url))),
        initialSettings: InAppWebViewSettings(
          mediaPlaybackRequiresUserGesture: false,
          transparentBackground: true,
        ),
      );
    }
    return Center(
      child: FilledButton.tonalIcon(
        onPressed: () => _open(context),
        icon: const Icon(Icons.slideshow_outlined),
        label: const Text('Abrir slides'),
      ),
    );
  }
}
