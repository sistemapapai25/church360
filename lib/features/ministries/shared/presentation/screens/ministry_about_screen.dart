import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../domain/models/ministry.dart';
import '../../../presentation/providers/ministries_provider.dart';
import '../../../presentation/utils/ministry_visuals.dart';

/// As seções de "Sobre o ministério", na ordem da tela e do formulário
/// (Configurar ministério > Dados Básicos). A chave é a coluna em
/// `public.ministry`.
const ministryAboutSections = [
  (key: 'vision', label: 'Visão', icon: AppIcons.visibility),
  (key: 'guidelines', label: 'Diretrizes', icon: AppIcons.flag),
  (key: 'rules', label: 'Regras', icon: AppIcons.checklist),
  (key: 'doctrinal_base', label: 'Base doutrinária', icon: AppIcons.book),
];

String? ministryAboutText(Ministry m, String key) => switch (key) {
  'vision' => m.vision,
  'guidelines' => m.guidelines,
  'rules' => m.rules,
  'doctrinal_base' => m.doctrinalBase,
  _ => null,
};

/// Visão, diretrizes, regras e base doutrinária do ministério. Abre ao tocar
/// no ícone do ministério, como o logo da igreja abre "Quem somos".
class MinistryAboutScreen extends ConsumerWidget {
  final String ministryId;

  /// Leva à engrenagem quando não há nada escrito. `null` = quem abriu não
  /// pode editar (o botão não aparece).
  final VoidCallback? onEdit;

  const MinistryAboutScreen({super.key, required this.ministryId, this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ministry = ref.watch(ministryByIdProvider(ministryId)).valueOrNull;
    final sections = [
      if (ministry != null)
        for (final s in ministryAboutSections)
          if ((ministryAboutText(ministry, s.key) ?? '').trim().isNotEmpty)
            (s, ministryAboutText(ministry, s.key)!.trim()),
    ];

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ministry?.name ?? 'Ministério',
              style: CommunityDesign.titleStyle(context),
            ),
            Text(
              'Sobre o ministério',
              style: CommunityDesign.metaStyle(context),
            ),
          ],
        ),
      ),
      body: ministry == null
          ? const Center(child: CircularProgressIndicator())
          : sections.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      ministryIconData(ministry.icon),
                      size: 48,
                      color: ministryColor(ministry.color),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ainda não preenchido',
                      style: CommunityDesign.titleStyle(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A visão, as diretrizes, as regras e a base doutrinária '
                      'são escritas pelo líder em Configurar ministério.',
                      style: CommunityDesign.metaStyle(context),
                      textAlign: TextAlign.center,
                    ),
                    if (onEdit != null) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(AppIcons.edit),
                        label: const Text('Preencher'),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final (s, text) in sections) ...[
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                s.icon,
                                color: ministryColor(ministry.color),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                s.label,
                                style: CommunityDesign.titleStyle(context)
                                    .copyWith(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            text,
                            style: CommunityDesign.contentStyle(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }
}
