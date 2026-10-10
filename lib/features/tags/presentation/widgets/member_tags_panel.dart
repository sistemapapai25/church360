import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/community_design.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';
import '../../data/tags_repository.dart';
import '../../domain/models/tag.dart';
import '../providers/tags_provider.dart';

/// Painel de tags de um membro, para uso dentro do perfil.
///
/// Mostra as tags atuais como chips e, para quem tem `tags.edit`, abre um
/// bottom sheet de seleção. Atribuir tag exige `tags.edit` porque não existe
/// `tags.assign` no seed — é o mesmo predicado de `member_tag_insert_rbac`.
class MemberTagsPanel extends ConsumerWidget {
  final String memberId;

  const MemberTagsPanel({super.key, required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberTagsAsync = ref.watch(memberTagsProvider(memberId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        memberTagsAsync.when(
          data: (tags) {
            if (tags.isEmpty) {
              return Text(
                'Nenhuma tag atribuída.',
                style: CommunityDesign.metaStyle(context),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) => TagChip(tag: tag)).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => Text(
            'Não foi possível carregar as tags.',
            style: CommunityDesign.metaStyle(context),
          ),
        ),
        PermissionGate(
          permission: 'tags.edit',
          showLoading: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showMemberTagsSheet(context, memberId),
                icon: const Icon(Icons.label_outline, size: 18),
                label: const Text('Gerenciar tags'),
                style: CommunityDesign.pillButtonStyle(
                  context,
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Painel de tags de um ministério, para a tela de configuração dele.
/// Mesmo formato do [MemberTagsPanel], lendo `ministry_tag`.
class MinistryTagsPanel extends ConsumerWidget {
  final String ministryId;

  const MinistryTagsPanel({super.key, required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsByMinistryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tagsAsync.when(
          data: (byId) {
            final tags = byId[ministryId] ?? const <Tag>[];
            if (tags.isEmpty) {
              return Text(
                'Nenhuma tag atribuída.',
                style: CommunityDesign.metaStyle(context),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) => TagChip(tag: tag)).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => Text(
            'Não foi possível carregar as tags.',
            style: CommunityDesign.metaStyle(context),
          ),
        ),
        PermissionGate(
          permission: 'tags.edit',
          showLoading: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showMinistryTagsSheet(context, ministryId),
                icon: const Icon(Icons.label_outline, size: 18),
                label: const Text('Gerenciar tags'),
                style: CommunityDesign.pillButtonStyle(
                  context,
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Chip de leitura de uma tag, tingido pela cor dela.
///
/// O fundo usa alpha baixo de propósito: cor cheia com texto branco vira
/// contraste ruim no tema claro e mancha no escuro.
class TagChip extends StatelessWidget {
  final Tag tag;

  const TagChip({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tagColor = tag.colorValue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tagColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: tagColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            tag.name,
            style: CommunityDesign.contentStyle(context).copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Abre o seletor de tags do membro.
Future<void> showMemberTagsSheet(BuildContext context, String memberId) {
  return _showTagPickerSheet(
    context,
    _TagPickerSheet(
      title: 'Tags do membro',
      hint:
          'Marque o que vale para esta pessoa agora. Tag é marcador manual '
          'e temporário — o que é dado do cadastro fica no cadastro.',
      watchAssigned: (ref) => ref
          .watch(memberTagsProvider(memberId))
          .whenData((tags) => tags.map((t) => t.id).toSet()),
      save: (repo, tagId, assign) => assign
          ? repo.addTagToMember(memberId, tagId)
          : repo.removeTagFromMember(memberId, tagId),
      invalidate: (ref) {
        ref.invalidate(memberTagsProvider(memberId));
        ref.invalidate(tagsByMemberProvider);
      },
    ),
  );
}

/// Abre o seletor de tags do ministério (`ministry_tag`, mesmas regras de
/// `member_tag`: marcar exige `tags.edit`).
Future<void> showMinistryTagsSheet(BuildContext context, String ministryId) {
  return _showTagPickerSheet(
    context,
    _TagPickerSheet(
      title: 'Tags do ministério',
      hint: 'Marque as tags que classificam este ministério.',
      watchAssigned: (ref) => ref
          .watch(tagsByMinistryProvider)
          .whenData((byId) => {...?byId[ministryId]?.map((t) => t.id)}),
      save: (repo, tagId, assign) => assign
          ? repo.addTagToMinistry(ministryId, tagId)
          : repo.removeTagFromMinistry(ministryId, tagId),
      invalidate: (ref) => ref.invalidate(tagsByMinistryProvider),
    ),
  );
}

Future<void> _showTagPickerSheet(BuildContext context, Widget sheet) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => sheet,
  );
}

class _TagPickerSheet extends ConsumerStatefulWidget {
  final String title;
  final String hint;
  final AsyncValue<Set<String>> Function(WidgetRef ref) watchAssigned;
  final Future<void> Function(TagsRepository repo, String tagId, bool assign)
  save;
  final void Function(WidgetRef ref) invalidate;

  const _TagPickerSheet({
    required this.title,
    required this.hint,
    required this.watchAssigned,
    required this.save,
    required this.invalidate,
  });

  @override
  ConsumerState<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<_TagPickerSheet> {
  /// Tags em gravação, por id — evita toque duplo na mesma linha.
  final Set<String> _saving = <String>{};

  @override
  Widget build(BuildContext context) {
    final allTagsAsync = ref.watch(allTagsProvider);
    final assignedAsync = widget.watchAssigned(ref);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                widget.title,
                style: CommunityDesign.titleStyle(
                  context,
                ).copyWith(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                widget.hint,
                style: CommunityDesign.metaStyle(context),
              ),
            ),
            Flexible(
              child: allTagsAsync.when(
                data: (allTags) {
                  if (allTags.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Text(
                        'Nenhuma tag cadastrada ainda. Crie as tags da igreja '
                        'no menu Tags.',
                        style: CommunityDesign.metaStyle(context),
                      ),
                    );
                  }

                  // Sem isso, o sheet aberto antes das tags atribuídas
                  // chegarem mostraria todas desmarcadas por um instante.
                  if (!assignedAsync.hasValue) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final assignedIds = assignedAsync.value!;

                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: allTags.length,
                    itemBuilder: (context, index) {
                      final tag = allTags[index];
                      return _buildTagRow(
                        context,
                        tag,
                        isAssigned: assignedIds.contains(tag.id),
                        isSaving: _saving.contains(tag.id),
                      );
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Text(
                    'Não foi possível carregar as tags: $error',
                    style: CommunityDesign.metaStyle(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagRow(
    BuildContext context,
    Tag tag, {
    required bool isAssigned,
    required bool isSaving,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: isSaving ? null : () => _toggleTag(tag, isAssigned: isAssigned),
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: tag.colorValue.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(color: tag.colorValue.withValues(alpha: 0.5)),
        ),
        child: Icon(Icons.label, size: 15, color: tag.colorValue),
      ),
      title: Text(
        tag.name,
        style: CommunityDesign.contentStyle(
          context,
        ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: tag.category == null || tag.category!.trim().isEmpty
          ? null
          : Text(tag.category!, style: CommunityDesign.metaStyle(context)),
      trailing: SizedBox(
        width: 24,
        height: 24,
        child: isSaving
            ? const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                child: isAssigned
                    ? Icon(
                        Icons.check_circle,
                        key: const ValueKey('on'),
                        color: colorScheme.primary,
                      )
                    : Icon(
                        Icons.circle_outlined,
                        key: const ValueKey('off'),
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
              ),
      ),
    );
  }

  Future<void> _toggleTag(Tag tag, {required bool isAssigned}) async {
    setState(() => _saving.add(tag.id));

    final repository = ref.read(tagsRepositoryProvider);
    try {
      await widget.save(repository, tag.id, !isAssigned);

      widget.invalidate(ref);
      // A lista de tags carrega a contagem de membros junto.
      ref.invalidate(allTagsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAssigned
                  ? 'Tag "${tag.name}" removida.'
                  : 'Tag "${tag.name}" atribuída.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage(error, isAssigned: isAssigned)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving.remove(tag.id));
      }
    }
  }

  /// A RLS de `member_tag`/`ministry_tag` responde 42501 a quem não tem `tags.edit`; sem esta
  /// tradução o usuário via o texto cru do PostgREST.
  String _errorMessage(Object error, {required bool isAssigned}) {
    final acao = isAssigned ? 'remover' : 'atribuir';
    if (error is PostgrestException && error.code == '42501') {
      return 'Você não tem permissão para $acao tags.';
    }
    return 'Erro ao $acao tag: $error';
  }
}
