import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../../../core/widgets/status_badge.dart';
import '../../../../permissions/providers/permissions_providers.dart';
import '../../../../study_groups/domain/models/study_group.dart';
import '../../../../support_materials/domain/models/support_material.dart';
import '../../../../support_materials/domain/models/support_material_link.dart';
import '../../../../support_materials/presentation/providers/support_materials_provider.dart';
import '../turma_access.dart';
import '../widgets/turma_sheet.dart';
import 'turma_aulas_tab.dart';

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
/// Visão agregada (passo 4 do modelo da Aula, ROADMAP-FORMACAO): uma seção
/// por aula, na ordem das aulas, com o PDF e o vídeo da aula e os
/// complementares dela. Aula sem nada disso não aparece.
///
/// **Regra (d):** a lista parte das aulas que a aba Aulas já mostra para a
/// pessoa ([turmaVisibleLessonsProvider]) e os complementares são pedidos
/// só para os ids dessas aulas. Nunca direto de `support_material_link`: a
/// RLS do link é só por tenant e mostraria ao aluno material de aula em
/// rascunho.
///
/// Material se vincula **pela aula** (decisão 3: nada de vínculo novo
/// `study_group` para conteúdo didático). Vínculo `study_group` antigo
/// aparece no fim, em "Material da turma", só quando existe, e quem pode
/// ([TurmaMaterialRights]) desvincula.
class TurmaMateriaisTab extends ConsumerWidget {
  final String studyGroupId;
  final TurmaAccess access;

  const TurmaMateriaisTab({
    super.key,
    required this.studyGroupId,
    required this.access,
  });

  ({MaterialLinkType linkType, String entityId}) get _groupKey =>
      (linkType: MaterialLinkType.studyGroup, entityId: studyGroupId);

  void _invalidate(WidgetRef ref) {
    invalidateTurmaLessons(ref, studyGroupId);
    ref.invalidate(materialsByEntityProvider(_groupKey));
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
      ref.invalidate(materialsByEntityProvider(_groupKey));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível desvincular: $error')),
      );
    }
  }

  void _openMaterial(BuildContext context, SupportMaterial material) {
    showTurmaSheet<void>(
      context: context,
      builder: (_) => TurmaMaterialReadSheet(material: material),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsAsync = ref.watch(
      turmaVisibleLessonsProvider(access, studyGroupId),
    );
    final lessons = lessonsAsync.valueOrNull;
    final byLessonAsync = lessons == null
        ? null
        : ref.watch(
            materialsByEntitiesProvider((
              linkType: MaterialLinkType.studyLesson,
              entityIds: materialEntityIdsKey(lessons.map((l) => l.id)),
            )),
          );
    final groupAsync = ref.watch(materialsByEntityProvider(_groupKey));
    final rights = access.isLeadership
        ? ref.watch(turmaMaterialRightsProvider).valueOrNull
        : null;

    if (lessonsAsync.hasError ||
        (byLessonAsync?.hasError ?? false) ||
        groupAsync.hasError) {
      return TurmaMessage.error(
        message: 'Não foi possível carregar os materiais.',
        onRetry: () => _invalidate(ref),
      );
    }
    final byLesson = byLessonAsync?.valueOrNull;
    final groupMaterials = groupAsync.valueOrNull;
    if (lessons == null || byLesson == null || groupMaterials == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final sections = [
      for (final lesson in lessons)
        if (_hasContent(lesson, byLesson[lesson.id]))
          (lesson: lesson, materials: byLesson[lesson.id] ?? const []),
    ];
    final meta = CommunityDesign.metaStyle(context);

    return RefreshIndicator(
      onRefresh: () async {
        _invalidate(ref);
        await ref.read(
          turmaVisibleLessonsProvider(access, studyGroupId).future,
        );
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text(
            '${sections.length} '
            '${sections.length == 1 ? 'aula com material' : 'aulas com material'}',
            style: meta,
          ),
          if (access.isLeadership) ...[
            const SizedBox(height: 6),
            Text(
              'Para incluir material, abra a aula na aba Aulas. Material de '
              'apoio é visível para toda a igreja, não só para esta turma; '
              'o vídeo e o PDF da aula abrem para quem tiver o link.',
              style: meta,
            ),
          ],
          const SizedBox(height: 12),
          if (sections.isEmpty && groupMaterials.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: TurmaMessage(
                icon: AppIcons.libraryBooks,
                message: access.isLeadership
                    ? 'Nenhuma aula desta turma tem material ainda.'
                    : 'Nenhum material disponível ainda.',
              ),
            ),
          for (final section in sections)
            _LessonMaterialsSection(
              key: ValueKey('materials-lesson-${section.lesson.id}'),
              lesson: section.lesson,
              materials: section.materials,
              showStatus: access.isLeadership,
              onOpenMaterial: (m) => _openMaterial(context, m),
            ),
          if (groupMaterials.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Material da turma',
              key: const ValueKey('materials-group-section'),
              style: meta.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final material in groupMaterials)
              _MaterialCard(
                key: ValueKey(material.id),
                material: material,
                onOpen: () => _openMaterial(context, material),
                onUnlink: rights != null && rights.canManage(material)
                    ? () => _unlink(context, ref, material)
                    : null,
              ),
          ],
        ],
      ),
    );
  }
}

bool _hasContent(StudyLesson lesson, List<SupportMaterial>? materials) =>
    (lesson.pdfUrl ?? '').trim().isNotEmpty ||
    (lesson.videoUrl ?? '').trim().isNotEmpty ||
    (materials ?? const []).isNotEmpty;

/// Uma aula na aba Materiais: título, status (só liderança, e só quando não
/// está publicada), vídeo e PDF principais e os complementares.
class _LessonMaterialsSection extends StatelessWidget {
  final StudyLesson lesson;
  final List<SupportMaterial> materials;
  final bool showStatus;
  final ValueChanged<SupportMaterial> onOpenMaterial;

  const _LessonMaterialsSection({
    super.key,
    required this.lesson,
    required this.materials,
    required this.showStatus,
    required this.onOpenMaterial,
  });

  @override
  Widget build(BuildContext context) {
    final meta = CommunityDesign.metaStyle(context);
    final videoUrl = (lesson.videoUrl ?? '').trim();
    final pdfUrl = (lesson.pdfUrl ?? '').trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Aula ${lesson.lessonNumber} · ${lesson.title}',
                  style: CommunityDesign.titleStyle(
                    context,
                  ).copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                if (showStatus && lesson.status != LessonStatus.published)
                  StatusBadge(
                    label: lesson.status.displayName,
                    tone: lessonStatusTone(lesson.status),
                  ),
              ],
            ),
            if (videoUrl.isNotEmpty || pdfUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (videoUrl.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => openLessonLink(context, videoUrl),
                      icon: const Icon(AppIcons.playArrow, size: 18),
                      label: const Text('Vídeo da aula'),
                    ),
                  if (pdfUrl.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => openLessonLink(context, pdfUrl),
                      icon: const Icon(AppIcons.pdf, size: 18),
                      label: const Text('PDF da aula'),
                    ),
                ],
              ),
            ],
            if (materials.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Complementares',
                style: meta.copyWith(fontWeight: FontWeight.w700),
              ),
              for (final m in materials)
                ListTile(
                  key: ValueKey('materials-lesson-${lesson.id}-${m.id}'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(turmaMaterialIcon(m.materialType)),
                  title: Text(m.title),
                  subtitle: Text(m.materialType.label),
                  onTap: () => onOpenMaterial(m),
                ),
            ] else
              const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

IconData turmaMaterialIcon(SupportMaterialType type) => switch (type) {
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
            Icon(turmaMaterialIcon(material.materialType), size: 22),
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
class TurmaMaterialReadSheet extends StatelessWidget {
  final SupportMaterial material;

  const TurmaMaterialReadSheet({super.key, required this.material});

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

/// Seletor de material para vincular à turma ou a uma aula dela.
///
/// Só oferece o que a pessoa pode vincular ([TurmaMaterialRights]) e ainda
/// não está vinculado. Erro de RLS não é fluxo normal: se o seletor
/// mostrou, o banco aceita.
class TurmaLinkMaterialSheet extends ConsumerStatefulWidget {
  final Set<String> linkedIds;
  final TurmaMaterialRights rights;
  final String emptyMessage;

  const TurmaLinkMaterialSheet({
    super.key,
    required this.linkedIds,
    required this.rights,
    this.emptyMessage =
        'Nenhum material disponível. Você pode vincular materiais '
        'que cadastrou no módulo Material de Apoio.',
  });

  @override
  ConsumerState<TurmaLinkMaterialSheet> createState() =>
      TurmaLinkMaterialSheetState();
}

class TurmaLinkMaterialSheetState
    extends ConsumerState<TurmaLinkMaterialSheet> {
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
                child: Text(widget.emptyMessage, style: meta),
              );
            }
            return Column(
              children: [
                for (final m in options)
                  ListTile(
                    key: ValueKey('link-${m.id}'),
                    leading: Icon(turmaMaterialIcon(m.materialType)),
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
