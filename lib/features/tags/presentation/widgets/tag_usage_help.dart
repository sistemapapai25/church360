import 'package:flutter/material.dart';

import '../../../../core/design/community_design.dart';

/// Exemplos vivos da regra: situação, acompanhamento ou contexto passageiro.
///
/// Nenhum deles é equipe formal de propósito — "time do café" foi descartado
/// justamente por poder virar ministério, que o sistema já conhece por vínculo
/// (`ministry_member`) e não deveria ser duplicado em tag.
const List<String> kTagUsageExamples = <String>[
  'Precisa de visita',
  'Novo na cidade',
  'Interessado em batismo 2027',
  'Líder em formação',
  'Disponível para servir no próximo evento',
];

/// Faixa de ajuda no topo da tela de Tags (C0).
///
/// As tags foram desativadas por confusão entre "campo do cadastro" e "tag".
/// A regra mora aqui, na tela, e não num documento à parte: a dúvida aparece
/// na hora de criar a tag, é aí que a resposta precisa estar.
class TagUsageHelpBanner extends StatelessWidget {
  const TagUsageHelpBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.primaryContainer,
      child: InkWell(
        onTap: () => showTagUsageSheet(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: colorScheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tag marca situação, acompanhamento ou contexto '
                      'passageiro. O que é permanente é campo do cadastro.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ver a regra completa',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Abre a regra completa de uso das tags.
Future<void> showTagUsageSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _TagUsageSheet(),
  );
}

class _TagUsageSheet extends StatelessWidget {
  const _TagUsageSheet();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quando usar uma tag',
              style: CommunityDesign.titleStyle(context).copyWith(fontSize: 18),
            ),
            const SizedBox(height: 16),
            const _UsageBlock(
              icon: Icons.badge_outlined,
              title: 'Campo do cadastro ou vínculo do sistema',
              body: 'Informação estrutural e permanente — nascimento, estado '
                  'civil, batismo — e também o que o sistema já sabe por '
                  'vínculo: ministério, cargo, grupo. Tudo isso já filtra '
                  'sozinho, sem precisar de tag.',
            ),
            const SizedBox(height: 12),
            const _UsageBlock(
              icon: Icons.label_outline,
              title: 'Tag',
              body: 'Marcador manual para situação, acompanhamento ou contexto '
                  'transitório — o que muda com o tempo e o sistema não tem '
                  'como saber sozinho.',
            ),
            const SizedBox(height: 20),
            Text(
              'Exemplos de tag',
              style: CommunityDesign.titleStyle(context).copyWith(fontSize: 14),
            ),
            const SizedBox(height: 8),
            // Lista, e nao chips: um dos exemplos e uma frase inteira, que
            // num chip estouraria a largura em tela estreita em vez de quebrar.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: kTagUsageExamples
                  .map(
                    (example) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 7),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              example,
                              style: CommunityDesign.contentStyle(context)
                                  .copyWith(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(CommunityDesign.radius),
              ),
              child: Text(
                'Se dá para responder com um campo do cadastro ou com um '
                'vínculo que o sistema já conhece, não é tag.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _UsageBlock({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: CommunityDesign.titleStyle(context).copyWith(
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(body, style: CommunityDesign.contentStyle(context)),
            ],
          ),
        ),
      ],
    );
  }
}
