import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../worship/presentation/widgets/presence_reaction_panel.dart';
import '../../domain/models/current_culto.dart';
import '../providers/live_stream_provider.dart';
import 'slides_viewer.dart';

/// Culto que a pessoa recolheu com "min" (id do culto ou link). O bloco vira
/// uma faixa fina até ela expandir de novo; outro culto volta expandido.
final cultoBlockMinimizedProvider = StateProvider<String?>((_) => null);

/// Cabeçalho da Home em modo culto (roadmap 14/10, A1 + esboço de 14/10):
/// no lugar do slider de banners, dois cards lado a lado do tamanho do
/// banner — "Culto ao vivo" (selo, nome, hora, botão **min**; tocar abre
/// `/culto`) e "Slides" (o slide atual com as setas do próprio visualizador;
/// tela cheia abre `/culto`). Abaixo, a mensagem da igreja e o painel
/// "Chegou bem?" (presença pelo celular, A4) quando a igreja tem pino.
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
    final height = width * 9 / 16;
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

    final cultoCard = GlassCard(
      key: const ValueKey('culto-card'),
      accentColor: pillColor,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      onTap: () => context.push('/culto'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [pill]),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    culto.title ?? 'Culto ao vivo',
                    maxLines: 2,
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
              ],
            ),
          ),
          Row(
            children: [
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
              const Spacer(),
              Icon(
                culto.hasStream ? Icons.play_circle_fill : Icons.open_in_full,
                size: culto.hasStream ? 32 : 20,
                color: pillColor,
              ),
            ],
          ),
        ],
      ),
    );

    final slidesCard = GlassCard(
      key: const ValueKey('slides-card'),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Slides',
                  style: CommunityDesign.titleStyle(
                    context,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Tela cheia',
                visualDensity: VisualDensity.compact,
                onPressed: () => context.push('/culto'),
                icon: const Icon(Icons.open_in_full, size: 18),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: culto.hasSlides
                    ? SlidesViewer(url: culto.slidesUrl!)
                    : Center(
                        child: Text(
                          'Sem slides neste culto',
                          textAlign: TextAlign.center,
                          style: CommunityDesign.metaStyle(context),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );

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
              SizedBox(
                height: height,
                child: Row(
                  children: [
                    Expanded(child: cultoCard),
                    const SizedBox(width: 12),
                    Expanded(child: slidesCard),
                  ],
                ),
              ),
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
