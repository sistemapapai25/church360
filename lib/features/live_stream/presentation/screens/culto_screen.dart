import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/media/inline_video.dart';
import '../../../worship/presentation/widgets/presence_reaction_panel.dart';
import '../../domain/models/current_culto.dart';
import '../providers/live_stream_provider.dart';
import '../widgets/slides_viewer.dart';

/// Modo culto em tela cheia (roadmap 14/10, A2): destino do toque nos cards
/// do topo da Home. Tema escuro só aqui (não mexe no tema salvo). Mostra a
/// transmissão (chave ligada), os slides do culto (A3), a mensagem da igreja,
/// o painel "Chegou bem?" e o ícone da Bíblia (D15 v1: abre por cima; o
/// "voltar" devolve ao culto). Celular = pilha; tela larga = lado a lado.
class CultoScreen extends ConsumerWidget {
  const CultoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final culto = ref.watch(currentCultoProvider).valueOrNull;
    final live = culto != null && culto.isLive;
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Text(live ? (culto.title ?? 'Culto ao vivo') : 'Culto'),
          actions: [
            IconButton(
              tooltip: 'Bíblia',
              icon: const Icon(AppIcons.bible),
              onPressed: () => context.push('/bible'),
            ),
          ],
        ),
        body: live
            ? _CultoBody(culto: culto)
            : const Center(
                child: Text(
                  'Nenhum culto agora',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
      ),
    );
  }
}

class _CultoBody extends StatelessWidget {
  final CurrentCulto culto;

  const _CultoBody({required this.culto});

  @override
  Widget build(BuildContext context) {
    final meta = Theme.of(context).textTheme.bodyMedium;
    final player = culto.hasStream ? _Player(url: culto.streamUrl!) : null;
    final slides = culto.hasSlides
        ? SlidesViewer(url: culto.slidesUrl!)
        : Center(child: Text('Sem slides neste culto', style: meta));
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
class _Player extends StatelessWidget {
  final String url;

  const _Player({required this.url});

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
      return InlineVideo(url: url);
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
