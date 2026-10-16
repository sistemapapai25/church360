import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../worship/presentation/widgets/presence_reaction_panel.dart';
import '../../domain/models/current_culto.dart';
import '../providers/live_stream_provider.dart';
import '../screens/culto_screen.dart';
import 'slides_viewer.dart';

/// Culto que a pessoa recolheu com "min" (id do culto ou link). O bloco vira
/// uma faixa fina até ela expandir de novo; outro culto volta expandido.
final cultoBlockMinimizedProvider = StateProvider<String?>((_) => null);

/// Cabeçalho da Home em modo culto (roadmap 14/10, A1 + esboço de 14/10):
/// no lugar do slider de banners, uma linha com selo, nome, hora, "ampliar
/// os dois" e **min**; embaixo, lado a lado, a transmissão já tocando e os
/// slides (PPTX/PDF/Google Slides) com as setas do próprio visualizador.
/// Cada card amplia sozinho (`/culto?so=video|slides`). Abaixo, a mensagem
/// da igreja e o painel "Chegou bem?" (presença pelo celular, A4).
class CultoHomeBlock extends ConsumerWidget {
  const CultoHomeBlock({super.key});

  static String _key(CurrentCulto c) => c.eventId ?? c.streamUrl ?? 'culto';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final culto = ref.watch(currentCultoProvider).valueOrNull;
    if (culto == null || !culto.isLive) return const SizedBox.shrink();

    final key = _key(culto);
    final minimized = ref.watch(cultoBlockMinimizedProvider) == key;
    // Mesma largura de referência do banner (clamp 480) e proporção 16:9.
    final width = (MediaQuery.sizeOf(context).width - 32).clamp(0.0, 480.0);
    final theme = Theme.of(context);
    final pillColor = culto.hasStream ? Colors.red : theme.colorScheme.primary;
    final pill = _Pill(
      text: culto.hasStream ? 'AO VIVO' : 'CULTO AGORA',
      color: pillColor,
    );

    if (minimized) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: SizedBox(
            width: width,
            child: GlassCard(
              key: const ValueKey('culto-strip'),
              accentColor: pillColor,
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              onTap: () =>
                  ref.read(cultoBlockMinimizedProvider.notifier).state = null,
              child: Row(
                children: [
                  pill,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      culto.title ?? 'Culto ao vivo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CommunityDesign.titleStyle(
                        context,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (culto.startHhmm != null)
                    Text(
                      'desde ${culto.startHhmm}',
                      style: CommunityDesign.metaStyle(context),
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.open_in_full, size: 18),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Abre /culto: os dois juntos (sem [so]) ou só um em tela cheia.
    void open([String? so]) =>
        context.push(so == null ? '/culto' : '/culto?so=$so');

    final header = Row(
      children: [
        pill,
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            culto.startHhmm == null
                ? (culto.title ?? 'Culto ao vivo')
                : '${culto.title ?? 'Culto ao vivo'} · ${culto.startHhmm}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CommunityDesign.titleStyle(
              context,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (culto.hasStream && culto.hasSlides)
          IconButton(
            key: const ValueKey('culto-max'),
            tooltip: 'Ampliar os dois',
            visualDensity: VisualDensity.compact,
            onPressed: open,
            icon: const Icon(Icons.fullscreen, size: 22),
          ),
        TextButton.icon(
          key: const ValueKey('culto-min'),
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 36),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            visualDensity: VisualDensity.compact,
          ),
          onPressed: () =>
              ref.read(cultoBlockMinimizedProvider.notifier).state = key,
          icon: const Icon(Icons.close_fullscreen, size: 16),
          label: const Text('min'),
        ),
      ],
    );

    // Transmissão e slides tocam aqui mesmo, cada um no seu card 16:9;
    // o botão do canto amplia só aquele card.
    Widget tile(String label, String so, Widget child) => GlassCard(
      key: ValueKey('$so-card'),
      padding: const EdgeInsets.fromLTRB(8, 2, 2, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: CommunityDesign.metaStyle(context)),
              ),
              IconButton(
                key: ValueKey('$so-expand'),
                tooltip: 'Ampliar',
                visualDensity: VisualDensity.compact,
                onPressed: () => open(so),
                icon: const Icon(Icons.open_in_full, size: 16),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );

    final tiles = [
      if (culto.hasStream)
        tile('Transmissão', 'video', CultoPlayer(url: culto.streamUrl!)),
      if (culto.hasSlides)
        tile('Slides', 'slides', SlidesViewer(url: culto.slidesUrl!)),
    ];

    final showPanel = culto.checkinEnabled;
    final showMessage = culto.message != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              if (tiles.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: tiles.first),
                    if (tiles.length > 1) ...[
                      const SizedBox(width: 12),
                      Expanded(child: tiles.last),
                    ],
                  ],
                ),
              ],
              if (showMessage || showPanel) ...[
                const SizedBox(height: 12),
                GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showMessage)
                        Text(
                          culto.message!,
                          style: CommunityDesign.metaStyle(context),
                        ),
                      if (showMessage && showPanel) const SizedBox(height: 10),
                      // Presença pelo celular (A4): "Chegou bem? / O que está
                      // achando?" com os 3 botões; responder marca a presença.
                      if (showPanel) const PresenceReactionPanel(compact: true),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;

  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
