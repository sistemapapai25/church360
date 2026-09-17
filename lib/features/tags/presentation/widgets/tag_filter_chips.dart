import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/community_design.dart';
import '../providers/tags_provider.dart';

/// Filtro de tags em chips, para o painel de filtros da lista de membros.
///
/// Não usa `ValueChipFilter` de propósito: aquele esconde o filtro com menos
/// de duas opções, o que faria a igreja com uma tag só nunca ver o controle —
/// e aqui a cor de cada tag é parte da informação.
///
/// Some sozinho quando não há tag alguma: sem `tags.view` a RLS devolve zero
/// linhas, e com o catálogo vazio não há o que filtrar.
class TagFilterChips extends ConsumerWidget {
  final String? selectedTagId;
  final ValueChanged<String?> onChanged;

  const TagFilterChips({
    super.key,
    required this.selectedTagId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(allTagsProvider);
    final tags = tagsAsync.value ?? const [];

    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    // O espaçamento fica aqui, e não no painel, porque só existe quando há
    // tag para mostrar — no painel viraria um buraco quando o filtro some.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.label_outline, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Tags',
              style: CommunityDesign.titleStyle(
                context,
              ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Todas'),
              selected: selectedTagId == null,
              onSelected: (_) => onChanged(null),
            ),
            ...tags.map((tag) {
              final isSelected = selectedTagId == tag.id;
              return ChoiceChip(
                avatar: CircleAvatar(backgroundColor: tag.colorValue, radius: 6),
                label: Text(tag.name),
                selected: isSelected,
                selectedColor: tag.colorValue.withValues(alpha: 0.18),
                // Tocar de novo na tag selecionada limpa o filtro.
                onSelected: (_) => onChanged(isSelected ? null : tag.id),
              );
            }),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
