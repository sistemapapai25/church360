import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../../permissions/providers/permissions_providers.dart';
import '../../../../support_materials/domain/models/support_material.dart';
import '../../../../support_materials/domain/models/support_material_link.dart';
import '../../../../support_materials/presentation/providers/support_materials_provider.dart';
import '../turma_access.dart';
import '../widgets/turma_sheet.dart';

/// Quem pode vincular e desvincular materiais: o autor de cada material
/// (`created_by`, que é `user_account.id`), quem tem
/// `support_materials.edit` e quem é elevado. É o espelho do
/// `support_material_manageable()` da RLS (etapa 5 parte 1).
class TurmaMaterialRights {
  final String? memberId;
  final bool canEditAny;

  const TurmaMaterialRights({required this.memberId, required this.canEditAny});

  bool canManage(SupportMaterial material) =>
      canEditAny || (memberId != null && material.createdBy == memberId);
}

final turmaMaterialRightsProvider = FutureProvider<TurmaMaterialRights>((
  ref,
) async {
  final memberId = await ref.watch(currentMemberIdProvider.future);
  final elevated = await ref.watch(currentUserIsElevatedProvider.future);
  final edit = await ref.watch(
    currentUserHasPermissionProvider('support_materials.edit').future,
  );
  return TurmaMaterialRights(memberId: memberId, canEditAny: elevated || edit);
});

/// Aba Materiais da tela da turma — igual para Batismo e turma genérica.
///
/// Material **da turma** (`link_type = study_group`). Material de aula
/// (`study_lesson`) é outra coisa e não é convertido aqui.
///
/// Sem upload: enquanto o CHU-370 estiver aberto, material novo nasce no
/// módulo Material de Apoio. Aqui só se vincula o que já existe.
class TurmaMateriaisTab extends ConsumerWidget {
  final String studyGroupId;
  final TurmaAccess access;

  const TurmaMateriaisTab({
    super.key,
    required this.studyGroupId,
    required this.access,
  });

  ({MaterialLinkType linkType, String entityId}) get _key =>
      (linkType: MaterialLinkType.studyGroup, entityId: studyGroupId);

  void _invalidate(WidgetRef ref) {
    ref.invalidate(materialsByEntityProvider(_key));
  }

  Future<void> _link(
    BuildContext context,
    WidgetRef ref,
    List<SupportMaterial> linked,
    TurmaMaterialRights rights,
  ) async {
    final picked = await showTurmaSheet<SupportMaterial>(
      context: context,
      builder: (_) => _LinkMaterialSheet(
        linkedIds: {for (final m in linked) m.id},
        rights: rights,
      ),
    );
    if (picked == null) return;
    try {
      await ref.read(supportMaterialsRepositoryProvider).createLink({
        'material_id': picked.id,
        'link_type': MaterialLinkType.studyGroup.value,
        'linked_entity_id': studyGroupId,
      });
      _invalidate(ref);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível vincular: $error')),
      );
    }
  }

  Future<void> _unlink(
    BuildContext context,
    WidgetRef ref,
    SupportMaterial material,
  ) async {
    try {
      await ref
          .read(supportMaterialsRepositoryProvider)
          .deleteLinkFor(
            materialId: material.id,
            linkType: MaterialLinkType.studyGroup,
            entityId: studyGroupId,
          );
      _invalidate(ref);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível desvincular: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materialsAsync = ref.watch(materialsByEntityProvider(_key));
    final rights = access.isLeadership
        ? ref.watch(turmaMaterialRightsProvider).valueOrNull
        : null;

    return materialsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => TurmaMessage.error(
        message: 'Não foi possível carregar os materiais.',
        onRetry: () => _invalidate(ref),
      ),
      data: (materials) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${materials.length} '
                    '${materials.length == 1 ? 'material' : 'materiais'}',
                    style: CommunityDesign.metaStyle(context),
                  ),
                ),
                if (rights != null)
                  FilledButton.icon(
                    onPressed: () => _link(context, ref, materials, rights),
                    icon: const Icon(AppIcons.link, size: 18),
                    label: const Text('Vincular material'),
                  ),
              ],
            ),
            if (access.isLeadership) ...[
              const SizedBox(height: 6),
              Text(
                'Material de apoio é visível para toda a igreja, não só '
                'para esta turma.',
                style: CommunityDesign.metaStyle(context),
              ),
            ],
            const SizedBox(height: 12),
            if (materials.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: TurmaMessage(
                  icon: AppIcons.libraryBooks,
                  message: 'Nenhum material vinculado a esta turma.',
                ),
              )
            else
              for (final material in materials)
                _MaterialCard(
                  key: ValueKey(material.id),
                  material: material,
                  onOpen: () => showTurmaSheet<void>(
                    context: context,
                    builder: (_) => _MaterialReadSheet(material: material),
                  ),
                  onUnlink: rights != null && rights.canManage(material)
                      ? () => _unlink(context, ref, material)
                      : null,
                ),
          ],
        );
      },
    );
  }
}

IconData _iconFor(SupportMaterialType type) => switch (type) {
  SupportMaterialType.pdf => AppIcons.pdf,
  SupportMaterialType.powerpoint => AppIcons.slideshow,
  SupportMaterialType.video => AppIcons.videoLibrary,
  SupportMaterialType.text => AppIcons.article,
  SupportMaterialType.audio => AppIcons.audioFile,
  SupportMaterialType.link => AppIcons.link,
  SupportMaterialType.other => AppIcons.insertDriveFile,
};

class _MaterialCard extends StatelessWidget {
  final SupportMaterial material;
  final VoidCallback onOpen;
  final VoidCallback? onUnlink;

  const _MaterialCard({
    super.key,
    required this.material,
    required this.onOpen,
    this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: onOpen,
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          children: [
            Icon(_iconFor(material.materialType), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.title,
                    style: CommunityDesign.titleStyle(
                      context,
                    ).copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      material.materialType.label,
                      if ((material.author ?? '').trim().isNotEmpty)
                        material.author!.trim(),
                    ].join(' · '),
                    style: CommunityDesign.metaStyle(context),
                  ),
                ],
              ),
            ),
            if (onUnlink != null)
              PopupMenuButton<String>(
                tooltip: 'Ações do material',
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'unlink', child: Text('Desvincular')),
                ],
                onSelected: (_) => onUnlink!(),
              ),
          ],
        ),
      ),
    );
  }
}

/// O material aberto: descrição, texto e o link para o arquivo.
///
/// A tela `/support-materials/:id` exige `support_materials.view`, que o
/// aluno não tem; por isso a leitura fica aqui.
class _MaterialReadSheet extends StatelessWidget {
  final SupportMaterial material;

  const _MaterialReadSheet({required this.material});

  String? get _url {
    for (final u in [
      material.fileUrl,
      material.videoUrl,
      material.externalLink,
    ]) {
      if (u != null && u.trim().isNotEmpty) return u.trim();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final meta = CommunityDesign.metaStyle(context);
    final url = _url;
    final description = (material.description ?? '').trim();
    final content = (material.content ?? '').trim();

    return TurmaSheetBody(
      title: material.title,
      children: [
        Text(material.materialType.label, style: meta),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(description),
        ],
        if (content.isNotEmpty) ...[const SizedBox(height: 12), Text(content)],
        if (url != null) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () async {
              final uri = Uri.tryParse(url);
              if (uri == null) return;
              final ok = await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Não foi possível abrir o material.'),
                  ),
                );
              }
            },
            icon: const Icon(AppIcons.forward, size: 18),
            label: const Text('Abrir'),
          ),
        ],
        if (url == null && content.isEmpty && description.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Este material não tem conteúdo para abrir.',
              style: meta,
            ),
          ),
      ],
    );
  }
}

/// Seletor de material para vincular à turma.
///
/// Só oferece o que a pessoa pode vincular ([TurmaMaterialRights]) e ainda
/// não está vinculado. Erro de RLS não é fluxo normal: se o seletor
/// mostrou, o banco aceita.
class _LinkMaterialSheet extends ConsumerStatefulWidget {
  final Set<String> linkedIds;
  final TurmaMaterialRights rights;

  const _LinkMaterialSheet({required this.linkedIds, required this.rights});

  @override
  ConsumerState<_LinkMaterialSheet> createState() => _LinkMaterialSheetState();
}

class _LinkMaterialSheetState extends ConsumerState<_LinkMaterialSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(allMaterialsProvider);
    final meta = CommunityDesign.metaStyle(context);

    return TurmaSheetBody(
      title: 'Vincular material',
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Procurar material',
            prefixIcon: Icon(AppIcons.search),
          ),
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
        const SizedBox(height: 12),
        allAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) =>
              Text('Não foi possível carregar os materiais.', style: meta),
          data: (all) {
            final options = [
              for (final m in all)
                if (!widget.linkedIds.contains(m.id) &&
                    widget.rights.canManage(m) &&
                    (_query.isEmpty || m.title.toLowerCase().contains(_query)))
                  m,
            ];
            if (options.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Nenhum material disponível. Você pode vincular materiais '
                  'que cadastrou no módulo Material de Apoio.',
                  style: meta,
                ),
              );
            }
            return Column(
              children: [
                for (final m in options)
                  ListTile(
                    key: ValueKey('link-${m.id}'),
                    leading: Icon(_iconFor(m.materialType)),
                    title: Text(m.title),
                    subtitle: Text(m.materialType.label),
                    onTap: () => Navigator.of(context).pop(m),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
