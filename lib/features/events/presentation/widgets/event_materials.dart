import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../courses/presentation/turma/tabs/turma_materiais_tab.dart';
import '../../../courses/presentation/turma/widgets/turma_sheet.dart';
import '../../../support_materials/domain/models/support_material.dart';
import '../../../support_materials/domain/models/support_material_link.dart';
import '../../../support_materials/presentation/providers/support_materials_provider.dart';
import '../../domain/models/event.dart';

/// Material de apoio do evento (`support_material_link`, `link_type =
/// event`). O material é visível à igreja toda (não há restrição por
/// material); a RLS do vínculo é a autoridade de quem vincula.

({MaterialLinkType linkType, String entityId}) _key(String eventId) =>
    (linkType: MaterialLinkType.event, entityId: eventId);

void _invalidate(WidgetRef ref, String eventId) {
  ref.invalidate(materialsByEntityProvider(_key(eventId)));
  ref.invalidate(materialsByEntitiesProvider);
}

/// Seção "Materiais" da tela do evento: só leitura, aberta como nos
/// complementares da aula. Some quando vazia; notícia não tem.
class EventMaterialsSection extends ConsumerWidget {
  final Event event;

  const EventMaterialsSection({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (event.isNews) return const SizedBox.shrink();
    final materials =
        ref.watch(materialsByEntityProvider(_key(event.id))).valueOrNull ??
        const <SupportMaterial>[];
    if (materials.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('event-materials'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Materiais', style: CommunityDesign.titleStyle(context)),
        const SizedBox(height: 8),
        for (final m in materials) ...[
          ListTile(
            key: ValueKey('event-material-${m.id}'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(turmaMaterialIcon(m.materialType)),
            title: Text(m.title),
            subtitle: Text(m.materialType.label),
          ),
          TurmaMaterialContent(material: m),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Aviso âmbar fixo do canvas (C9).
class EventMaterialsPublicNotice extends StatelessWidget {
  const EventMaterialsPublicNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cor = dark ? AppTheme.warningColor : const Color(0xFFB45309);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: cor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Materiais de apoio são visíveis para toda a igreja. Não use '
              'para conteúdo confidencial.',
              style: TextStyle(fontSize: 14, color: cor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Seção "Materiais" da edição do evento: vincular e desvincular material
/// que já está na biblioteca. Não cria material novo.
class EventMaterialsManager extends ConsumerWidget {
  final String eventId;

  const EventMaterialsManager({super.key, required this.eventId});

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _link(
    BuildContext context,
    WidgetRef ref,
    List<SupportMaterial> linked,
  ) async {
    final picked = await showTurmaSheet<SupportMaterial>(
      context: context,
      builder: (_) => TurmaLinkMaterialSheet(
        linkedIds: {for (final m in linked) m.id},
        // A RLS deixa vincular qualquer material visível.
        rights: const TurmaMaterialRights(memberId: null, canEditAny: true),
        notice: const EventMaterialsPublicNotice(),
        emptyMessage: 'Nenhum material disponível na biblioteca.',
      ),
    );
    if (picked == null || !context.mounted) return;
    final ok = await _confirm(
      context,
      title: 'Vincular material?',
      body: '"${picked.title}" vai aparecer na tela do evento.',
      action: 'Vincular',
    );
    if (!ok) return;
    try {
      await ref.read(supportMaterialsRepositoryProvider).createLink({
        'material_id': picked.id,
        'link_type': MaterialLinkType.event.value,
        'linked_entity_id': eventId,
      });
      _invalidate(ref, eventId);
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
    final ok = await _confirm(
      context,
      title: 'Desvincular material?',
      body:
          '"${material.title}" sai deste evento, mas continua na biblioteca '
          'de Material de Apoio.',
      action: 'Desvincular',
    );
    if (!ok) return;
    try {
      await ref
          .read(supportMaterialsRepositoryProvider)
          .deleteLinkFor(
            materialId: material.id,
            linkType: MaterialLinkType.event,
            entityId: eventId,
          );
      _invalidate(ref, eventId);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível desvincular: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final meta = TextStyle(fontSize: 14, color: scheme.onSurfaceVariant);
    final async = ref.watch(materialsByEntityProvider(_key(eventId)));
    final materials = async.valueOrNull ?? const <SupportMaterial>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Materiais',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            TextButton.icon(
              key: const ValueKey('event-link-material'),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              onPressed: async.hasValue
                  ? () => _link(context, ref, materials)
                  : null,
              icon: const Icon(Icons.link, size: 18),
              label: const Text('Vincular material'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const EventMaterialsPublicNotice(),
        const SizedBox(height: 8),
        if (async.isLoading && !async.hasValue)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (async.hasError)
          Text('Não foi possível carregar os materiais.', style: meta)
        else if (materials.isEmpty)
          Text('Nenhum material vinculado a este evento.', style: meta)
        else
          for (final m in materials)
            ListTile(
              key: ValueKey('event-material-${m.id}'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(turmaMaterialIcon(m.materialType)),
              title: Text(m.title),
              subtitle: Text(m.materialType.label),
              trailing: PopupMenuButton<String>(
                tooltip: 'Mais opções',
                onSelected: (_) => _unlink(context, ref, m),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'desvincular',
                    child: Text('Desvincular'),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 4),
        Text(
          'Para adicionar um material novo, fale com quem cuida da '
          'biblioteca.',
          style: meta,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
