import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../courses/presentation/turma/tabs/turma_materiais_tab.dart';
import '../../../courses/presentation/turma/widgets/turma_sheet.dart';
import '../../domain/models/support_material.dart';
import '../../domain/models/support_material_link.dart';
import '../providers/support_materials_provider.dart';

/// Materiais vinculados a [entityId] pelo formulário do Material de Apoio
/// (vínculo Curso / Ministério). Abrem em sheet de leitura, como na turma:
/// a tela `/support-materials/:id` exige `support_materials.view`, que nem
/// todo mundo que vê o curso ou o ministério tem. A RLS de
/// `support_material` mostra material ativo a qualquer um da igreja.
List<SupportMaterial>? _linked(
  WidgetRef ref,
  MaterialLinkType linkType,
  String entityId,
) => ref
    .watch(materialsByEntityProvider((linkType: linkType, entityId: entityId)))
    .valueOrNull;

List<Widget> _tiles(BuildContext context, List<SupportMaterial> materials) => [
  for (final m in materials)
    ListTile(
      key: ValueKey('linked-material-${m.id}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(turmaMaterialIcon(m.materialType)),
      title: Text(m.title),
      subtitle: Text(m.materialType.label),
      onTap: () => showTurmaSheet<void>(
        context: context,
        builder: (_) => TurmaMaterialReadSheet(material: m),
      ),
    ),
];

/// Seção "Material de apoio" dentro de uma tela que rola (curso). Some
/// enquanto carrega, com erro ou sem material.
class LinkedMaterialsSection extends ConsumerWidget {
  final MaterialLinkType linkType;
  final String entityId;

  const LinkedMaterialsSection({
    super.key,
    required this.linkType,
    required this.entityId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materials = _linked(ref, linkType, entityId);
    if (materials == null || materials.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Material de apoio',
            style: CommunityDesign.titleStyle(
              context,
            ).copyWith(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._tiles(context, materials),
        ],
      ),
    );
  }
}

/// Botão da barra (ministério) que abre a lista em sheet. Some sem material.
class LinkedMaterialsAction extends ConsumerWidget {
  final MaterialLinkType linkType;
  final String entityId;

  const LinkedMaterialsAction({
    super.key,
    required this.linkType,
    required this.entityId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materials = _linked(ref, linkType, entityId);
    if (materials == null || materials.isEmpty) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(AppIcons.libraryBooks),
      tooltip: 'Material de apoio (${materials.length})',
      onPressed: () => showTurmaSheet<void>(
        context: context,
        builder: (sheetContext) => TurmaSheetBody(
          title: 'Material de apoio',
          children: _tiles(sheetContext, materials),
        ),
      ),
    );
  }
}
