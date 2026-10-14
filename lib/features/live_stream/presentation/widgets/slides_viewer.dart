import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'slides_viewer_web_stub.dart'
    if (dart.library.js_interop) 'slides_viewer_web.dart';

/// Link que vai no iframe. Google Slides: tanto o link "Publicar na web"
/// (`/d/e/<id>/pub`) quanto o de edição (`/d/<id>/edit`) viram `/embed`, o
/// visualizador com as setas ← → e sem a barra do Google. Qualquer outro
/// link (PDF no Storage, por exemplo) fica como está: o navegador abre.
String slidesEmbedUrl(String raw) {
  final url = raw.trim();
  final m = RegExp(
    r'^(https://docs\.google\.com/presentation/d/(?:e/)?[A-Za-z0-9_-]+)(?:/[a-z]*)?',
  ).firstMatch(url);
  if (m == null) return url;
  return '${m.group(1)}/embed?start=false&loop=false';
}

/// Slides do culto (roadmap 14/10, A3, D2 v1: a pessoa passa sozinha).
/// No navegador é um iframe (Google Slides com as próprias setas, ou o
/// visualizador de PDF do navegador). No app nativo não há visualizador
/// embutido: "Abrir slides" abre no navegador do aparelho.
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
    return Center(
      child: FilledButton.tonalIcon(
        onPressed: () => _open(context),
        icon: const Icon(Icons.slideshow_outlined),
        label: const Text('Abrir slides'),
      ),
    );
  }
}
