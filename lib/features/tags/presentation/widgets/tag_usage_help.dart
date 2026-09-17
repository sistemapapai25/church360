import 'package:flutter/material.dart';

import '../../../../core/design/community_design.dart';

/// Exemplos vivos da regra: o que o sistema não responde sozinho.
///
/// Nenhum deles é equipe formal de propósito — "time do café" foi descartado
/// justamente por poder virar ministério, que o sistema já conhece por vínculo
/// (`ministry_member`) e não deveria ser duplicado em tag.
///
/// "Batizado" entra por um motivo medido, não por opinião: em 17/09/2026,
/// `user_account.baptism_date` estava preenchida em 11 de 263 pessoas (4%),
/// então o filtro "Data de batismo" da lista de membros não responde na
/// prática. Se um dia o cadastro for preenchido, este exemplo sai — a régua
/// é "o sistema responde hoje?", não "o campo existe no schema".
/// O contraste: `marital_status` (69%) e `birthdate` (90%) estão preenchidos,
/// e por isso "casados" e "jovens" NÃO viram tag — viram filtro.
const List<String> kTagUsageExamples = <String>[
  'Precisa de visita',
  'Novo na cidade',
  'Interessado em batismo 2027',
  'Líder em formação',
  'Disponível para servir no próximo evento',
  'Batizado',
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
                      'Tag serve para o que o sistema não responde sozinho. '
                      'O que a lista de membros já filtra não precisa de tag.',
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
              title: 'O sistema já responde?',
              body: 'Idade, estado civil, cidade, data de membresia — e os '
                  'vínculos que o sistema conhece: ministério, cargo, grupo. '
                  'A lista de membros já filtra tudo isso sozinha. Repetir em '
                  'tag cria uma segunda verdade que ninguém atualiza: a pessoa '
                  'casa, faz aniversário, e a tag passa a mentir.',
            ),
            const SizedBox(height: 12),
            const _UsageBlock(
              icon: Icons.label_outline,
              title: 'O sistema não responde?',
              body: 'Aí é tag. Vale para situação e acompanhamento que mudam '
                  'com o tempo, e também para classificação estável que o '
                  'cadastro deveria dar mas está vazio na prática.',
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
            const SizedBox(height: 10),
            // Sem esta nota, "Batizado" parece contradizer o bloco de cima,
            // que manda nao duplicar campo do cadastro em tag.
            Text(
              '"Batizado" está aqui porque a data de batismo, hoje, está '
              'preenchida em menos de 5% das pessoas — o filtro do cadastro '
              'não acha esse grupo. Quando o cadastro estiver em dia, o '
              'filtro volta a ser o caminho e a tag sai.',
              style: CommunityDesign.contentStyle(context).copyWith(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
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
                'Se a lista de membros já filtra isso, não é tag.',
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
