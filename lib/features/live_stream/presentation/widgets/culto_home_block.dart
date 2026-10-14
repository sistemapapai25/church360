import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';
import '../providers/live_stream_provider.dart';

/// Bloco "culto agora" no cabeçalho da Home (roadmap 14/10, fase A1).
/// Entra no lugar do slider de banners enquanto `current_culto()` diz que há
/// culto (chave do culto ao vivo ligada ou culto da Agenda aberto).
/// "Assistir" só com link (chave ligada); "Estou na igreja" só com a presença
/// pelo celular configurada, e abre a tela /presenca que já existe.
class CultoHomeBlock extends ConsumerWidget {
  const CultoHomeBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final culto = ref.watch(currentCultoProvider).valueOrNull;
    if (culto == null || !culto.isLive) return const SizedBox.shrink();

    final hasStream = (culto.streamUrl ?? '').isNotEmpty;
    final theme = Theme.of(context);
    final pillColor = hasStream ? Colors.red : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassCard(
        accentColor: pillColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: pillColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: pillColor),
                      const SizedBox(width: 6),
                      Text(
                        hasStream ? 'AO VIVO' : 'CULTO AGORA',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: pillColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (culto.startHhmm != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    'desde ${culto.startHhmm}',
                    style: CommunityDesign.metaStyle(context),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              culto.title ?? 'Culto ao vivo',
              style: CommunityDesign.titleStyle(
                context,
              ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            if (culto.message != null) ...[
              const SizedBox(height: 6),
              Text(culto.message!, style: CommunityDesign.metaStyle(context)),
            ],
            if (hasStream || culto.checkinEnabled) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (hasStream)
                    FilledButton.icon(
                      onPressed: () => context.push('/live-stream'),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Assistir'),
                    ),
                  if (culto.checkinEnabled)
                    FilledButton.tonalIcon(
                      onPressed: () => context.push('/presenca'),
                      icon: const Icon(AppIcons.church),
                      label: const Text('Estou na igreja'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
