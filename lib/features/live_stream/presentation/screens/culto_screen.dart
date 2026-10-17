import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/media/inline_video.dart';
import '../../../worship/presentation/widgets/presence_reaction_panel.dart';
import '../../domain/models/current_culto.dart';

/// Modo culto em tela cheia (roadmap 14/10, A2), aberto por cima da Home
/// pelo "ampliar" do bloco do culto. Recebe o **mesmo** player e os mesmos
/// slides dos cards da Home (com GlobalKey): ampliar só muda o tamanho, não
/// abre outro vídeo. Tema escuro só aqui (não mexe no tema salvo). Mostra a
/// transmissão, os slides (A3), a mensagem da igreja, o painel "Chegou bem?"
/// e o ícone da Bíblia (D15 v1: abre por cima; o "voltar" devolve ao culto).
/// Celular = pilha; tela larga = lado a lado. [only] (`video` ou `slides`)
/// mostra só um dos dois: quem está na igreja amplia só os slides.
class CultoFullView extends StatelessWidget {
  final CurrentCulto culto;
  final String? only;
  final Widget? player;
  final Widget? slides;
  final VoidCallback onClose;

  const CultoFullView({
    super.key,
    required this.culto,
    required this.onClose,
    this.only,
    this.player,
    this.slides,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            key: const ValueKey('culto-reduzir'),
            tooltip: 'Reduzir',
            icon: const Icon(Icons.close_fullscreen),
            onPressed: onClose,
          ),
          title: Text(culto.title ?? 'Culto ao vivo'),
          actions: [
            IconButton(
              tooltip: 'Bíblia',
              icon: const Icon(AppIcons.bible),
              onPressed: () => context.push('/bible'),
            ),
          ],
        ),
        body: _CultoBody(
          culto: culto,
          only: only,
          player: player,
          slides: slides,
        ),
      ),
    );
  }
}

class _CultoBody extends StatelessWidget {
  final CurrentCulto culto;
  final String? only;
  final Widget? player;
  final Widget? slides;

  const _CultoBody({required this.culto, this.only, this.player, this.slides});

  @override
  Widget build(BuildContext context) {
    final meta = Theme.of(context).textTheme.bodyMedium;
    final player = this.player;
    final slides =
        this.slides ??
        Center(child: Text('Sem slides neste culto', style: meta));
    if (only == 'slides' && this.slides != null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: slides,
          ),
        ),
      );
    }
    if (only == 'video' && player != null) {
      return SafeArea(
        child: Center(
          child: Padding(padding: const EdgeInsets.all(8), child: player),
        ),
      );
    }
    final extras = <Widget>[
      if (culto.message != null) Text(culto.message!, style: meta),
      if (culto.message != null && culto.checkinEnabled)
        const SizedBox(height: 12),
      if (culto.checkinEnabled) const PresenceReactionPanel(compact: true),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 700) {
          return Row(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (player != null) player,
                    if (player != null && extras.isNotEmpty)
                      const SizedBox(height: 16),
                    ...extras,
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: slides,
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            if (player != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: player,
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: slides,
                ),
              ),
            ),
            if (extras.isNotEmpty)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: extras,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// YouTube toca dentro do app ([InlineVideo]); outro link abre no navegador,
/// como na tela Culto ao vivo.
class CultoPlayer extends StatelessWidget {
  final String url;

  const CultoPlayer({super.key, required this.url});

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(url.trim());
    final ok =
        uri != null && await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (YoutubePlayer.convertUrlToId(url) != null) {
      return InlineVideo(url: url, autoStart: true);
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: FilledButton.icon(
            onPressed: () => _open(context),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Assistir no navegador'),
          ),
        ),
      ),
    );
  }
}
