import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../data/pptx_deck.dart';

import 'slides_viewer_web_stub.dart'
    if (dart.library.js_interop) 'slides_viewer_web.dart';

/// Link que vai no iframe/WebView. Google Slides: tanto o link "Publicar na
/// web" (`/d/e/<id>/pub`) quanto o de edição (`/d/<id>/edit`) viram `/embed`,
/// o visualizador com as setas ← → e sem a barra do Google. PowerPoint
/// (.pptx/.ppt enviado ao Storage público) passa pelo visualizador do Office,
/// que mostra um slide por vez com as setas ← → (como o PreacherLab), sem
/// virar PDF. Qualquer outro link (PDF, por exemplo) fica como está.
String slidesEmbedUrl(String raw) {
  final url = raw.trim();
  if (isPowerPoint(url)) {
    return 'https://view.officeapps.live.com/op/embed.aspx?src='
        '${Uri.encodeComponent(url)}';
  }
  final m = RegExp(
    r'^(https://docs\.google\.com/presentation/d/(?:e/)?[A-Za-z0-9_-]+)(?:/[a-z]*)?',
  ).firstMatch(url);
  if (m == null) return url;
  return '${m.group(1)}/embed?start=false&loop=false';
}

bool isPowerPoint(String url) => RegExp(
  r'\.pptx?$',
  caseSensitive: false,
).hasMatch(Uri.tryParse(url.trim())?.path ?? '');

bool _isGoogleSlides(String url) =>
    url.trim().startsWith('https://docs.google.com/presentation/');

/// O WebView do Android não abre PDF (baixa o arquivo); o visualizador do
/// Google abre e deixa rolar página a página. iOS abre PDF direto.
String slidesNativeUrl(String raw) {
  final url = slidesEmbedUrl(raw);
  if (_isGoogleSlides(url) ||
      url.startsWith('https://view.officeapps.live.com/') ||
      defaultTargetPlatform != TargetPlatform.android) {
    return url;
  }
  return 'https://docs.google.com/gview?embedded=true&url='
      '${Uri.encodeComponent(url)}';
}

/// Slides do culto (roadmap 14/10, A3, D2 v1: a pessoa passa sozinha).
/// PowerPoint abre no leitor próprio ([_PptxViewer], sem a barra da
/// Microsoft); o que ele não desenha cai no visualizador do Office.
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
  Widget build(BuildContext context) => isPowerPoint(url)
      ? _PptxViewer(url: url, fallback: _embedded)
      : _embedded(context);

  Widget _embedded(BuildContext context) {
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

/// Leitor próprio do PPTX: um slide por vez, arrastar ou setas, "n / total".
class _PptxViewer extends StatefulWidget {
  final String url;
  final WidgetBuilder fallback;

  const _PptxViewer({required this.url, required this.fallback});

  @override
  State<_PptxViewer> createState() => _PptxViewerState();
}

class _PptxViewerState extends State<_PptxViewer> {
  late Future<PptxDeck?> _deck = _load();
  final _pages = PageController();
  int _page = 0;

  Future<PptxDeck?> _load() async {
    final res = await http.get(Uri.parse(widget.url.trim()));
    if (res.statusCode != 200) return null;
    return PptxDeck.tryParse(res.bodyBytes);
  }

  @override
  void didUpdateWidget(_PptxViewer old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _deck = _load();
      _page = 0;
      if (_pages.hasClients) _pages.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int delta, int total) {
    final to = (_page + delta).clamp(0, total - 1);
    _pages.animateToPage(
      to,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PptxDeck?>(
      future: _deck,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final deck = snap.data;
        if (deck == null) return widget.fallback(context);
        final total = deck.slides.length;
        return ColoredBox(
          color: Colors.black,
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: total,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => Center(
                    child: _SlideView(deck: deck, slide: deck.slides[i]),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Slide anterior',
                    color: Colors.white,
                    onPressed: _page > 0 ? () => _go(-1, total) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    '${_page + 1} / $total',
                    style: const TextStyle(color: Colors.white),
                  ),
                  IconButton(
                    tooltip: 'Próximo slide',
                    color: Colors.white,
                    onPressed: _page < total - 1 ? () => _go(1, total) : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SlideView extends StatelessWidget {
  final PptxDeck deck;
  final PptxSlide slide;

  const _SlideView({required this.deck, required this.slide});

  @override
  Widget build(BuildContext context) {
    final bg = int.tryParse(slide.background ?? '', radix: 16);
    return AspectRatio(
      aspectRatio: deck.width / deck.height,
      child: LayoutBuilder(
        builder: (context, box) {
          final k = box.maxWidth / deck.width;
          return ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: bg == null ? Colors.black : Color(0xFF000000 | bg),
                  ),
                ),
                for (final p in slide.pictures)
                  Positioned(
                    left: p.x * k,
                    top: p.y * k,
                    width: p.w * k,
                    height: p.h * k,
                    child: Image.memory(
                      p.bytes,
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
