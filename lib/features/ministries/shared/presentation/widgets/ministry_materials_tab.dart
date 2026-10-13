import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../courses/presentation/turma/tabs/turma_materiais_tab.dart';
import '../../../../courses/presentation/turma/widgets/turma_sheet.dart';
import '../../../../permissions/presentation/widgets/permission_gate.dart';
import '../../../../support_materials/domain/models/support_material_link.dart';
import '../../../../support_materials/presentation/providers/support_materials_provider.dart';

/// Aba Materiais: o Material de Apoio vinculado ao ministério (manuais,
/// cartilhas, doutrina).
///
/// Quem é do ministério lê sem `support_materials.view`: a RLS libera o
/// material vinculado a um ministério do qual a pessoa faz parte
/// (`support_material_linked_to_me`). Por isso a leitura abre na janela da
/// turma, e não em `/support-materials/:id`, que exige a permissão.
class MinistryMaterialsTab extends ConsumerWidget {
  final String ministryId;

  const MinistryMaterialsTab({super.key, required this.ministryId});

  ({MaterialLinkType linkType, String entityId}) get _key =>
      (linkType: MaterialLinkType.ministry, entityId: ministryId);

  /// Cadastra no formulário de Material de Apoio já vinculado ao ministério.
  Future<void> _create(BuildContext context, WidgetRef ref) async {
    await context.push('/support-materials/new?ministry=$ministryId');
    ref.invalidate(materialsByEntityProvider(_key));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(materialsByEntityProvider(_key));
    final meta = CommunityDesign.metaStyle(context);

    if (async.hasError && !async.hasValue) {
      return TurmaMessage.error(
        message: 'Não foi possível carregar os materiais.',
        onRetry: () => ref.invalidate(materialsByEntityProvider(_key)),
      );
    }
    final materials = async.valueOrNull;
    if (materials == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => ref.refresh(materialsByEntityProvider(_key).future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${materials.length} '
                  '${materials.length == 1 ? 'material' : 'materiais'}',
                  style: meta,
                ),
              ),
              PermissionGate(
                permission: 'support_materials.create',
                showLoading: false,
                child: TextButton.icon(
                  key: const ValueKey('ministry-new-material'),
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  onPressed: () => _create(context, ref),
                  icon: const Icon(AppIcons.upload, size: 18),
                  label: const Text('Adicionar material'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (materials.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: TurmaMessage(
                icon: AppIcons.libraryBooks,
                message: 'Nenhum material deste ministério ainda.',
              ),
            ),
          for (final m in materials)
            TurmaMaterialCard(
              key: ValueKey('ministry-material-${m.id}'),
              material: m,
              onOpen: () => showTurmaSheet<void>(
                context: context,
                builder: (_) => TurmaMaterialReadSheet(material: m),
              ),
            ),
        ],
      ),
    );
  }
}
