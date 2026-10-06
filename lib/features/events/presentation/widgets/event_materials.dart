import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../courses/presentation/turma/lesson_media.dart';
import '../../../courses/presentation/turma/tabs/turma_aulas_tab.dart';
import '../../../courses/presentation/turma/tabs/turma_materiais_tab.dart';
import '../../../courses/presentation/turma/turma_access.dart';
import '../../../courses/presentation/turma/widgets/turma_sheet.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../../support_materials/domain/models/support_material.dart';
import '../../../support_materials/domain/models/support_material_link.dart';
import '../../../support_materials/presentation/providers/support_materials_provider.dart';
import '../../../study_groups/domain/models/study_group.dart';
import '../../../study_groups/presentation/providers/study_group_provider.dart';
import '../../domain/models/event.dart';
import '../providers/events_provider.dart';

/// Material de apoio do evento (`support_material_link`, `link_type =
/// event`). O material é visível à igreja toda (não há restrição por
/// material); a RLS do vínculo é a autoridade de quem vincula.

({MaterialLinkType linkType, String entityId}) _key(String eventId) =>
    (linkType: MaterialLinkType.event, entityId: eventId);

void _invalidate(WidgetRef ref, String eventId) {
  ref.invalidate(materialsByEntityProvider(_key(eventId)));
  ref.invalidate(materialsByEntitiesProvider);
}

/// Aulas ligadas a este encontro (a RLS de study_lessons decide quem lê).
final eventLessonsProvider = FutureProvider.family<List<StudyLesson>, String>(
  (ref, eventId) =>
      ref.watch(studyGroupRepositoryProvider).getLessonsByEvents([eventId]),
);

/// Quem vê o vídeo de referência do evento e das aulas do encontro: quem
/// gerencia o evento (elevado, `events.edit`, responsável), a liderança da
/// turma ou o professor de uma das aulas. Aluno não vê.
final canSeeReferenceVideoProvider = FutureProvider.family<bool, String>((
  ref,
  eventId,
) async {
  if (await ref.watch(currentUserIsElevatedProvider.future)) return true;
  if (await ref.watch(currentUserHasPermissionProvider('events.edit').future)) {
    return true;
  }
  if (await ref.watch(isEventResponsibleProvider(eventId).future)) return true;
  final lessons = await ref.watch(eventLessonsProvider(eventId).future);
  if (lessons.isEmpty) return false;
  final me = await ref.watch(currentMemberIdProvider.future);
  if (me != null && lessons.any((l) => l.teacherId == me)) return true;
  for (final groupId in {for (final l in lessons) l.studyGroupId}) {
    final access = await ref.watch(turmaAccessProvider(groupId).future);
    if (access.isLeadership) return true;
  }
  return false;
});

typedef _MediaLink = ({IconData icon, String title, String url});

/// Seção "Materiais" da tela do evento: só leitura. Mostra o PDF do evento,
/// o PDF das aulas publicadas do encontro e o material da biblioteca; o
/// vídeo de referência (do evento e das aulas) só para
/// [canSeeReferenceVideoProvider]. Some quando vazia; notícia não tem.
class EventMaterialsSection extends ConsumerWidget {
  final Event event;

  const EventMaterialsSection({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (event.isNews) return const SizedBox.shrink();
    final materials =
        ref.watch(materialsByEntityProvider(_key(event.id))).valueOrNull ??
        const <SupportMaterial>[];

    final links = <_MediaLink>[];
    final pdf = blankToNull(event.pdfUrl);
    if (pdf != null) {
      links.add((icon: AppIcons.pdf, title: 'PDF do evento', url: pdf));
    }
    final showVideo =
        ref.watch(canSeeReferenceVideoProvider(event.id)).valueOrNull ?? false;
    final video = showVideo ? blankToNull(event.videoUrl) : null;
    if (video != null) {
      links.add((
        icon: AppIcons.videoLibrary,
        title: 'Vídeo de referência',
        url: video,
      ));
    }
    if (event.eventType == 'aula') {
      final lessons = [
        ...?ref.watch(eventLessonsProvider(event.id)).valueOrNull,
      ]..sort((a, b) => a.lessonNumber.compareTo(b.lessonNumber));
      for (final l in lessons) {
        if (l.status != LessonStatus.published) continue;
        final label = 'Aula ${l.lessonNumber} · ${l.title}';
        final lessonPdf = blankToNull(l.pdfUrl);
        if (lessonPdf != null) {
          links.add((
            icon: AppIcons.pdf,
            title: '$label — PDF',
            url: lessonPdf,
          ));
        }
        final lessonVideo = showVideo ? blankToNull(l.videoUrl) : null;
        if (lessonVideo != null) {
          links.add((
            icon: AppIcons.videoLibrary,
            title: '$label — vídeo de referência',
            url: lessonVideo,
          ));
        }
      }
    }

    if (links.isEmpty && materials.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('event-materials'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Materiais', style: CommunityDesign.titleStyle(context)),
        const SizedBox(height: 8),
        for (final l in links)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(l.icon),
            title: Text(l.title),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => openLessonLink(context, l.url),
          ),
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

/// Modalidade, PDF e vídeo de referência do próprio evento (colunas de
/// event, igual à aula). Cada ação grava na hora. PDF novo vira "Novo
/// material" em Atualizações; vídeo novo avisa só os professores das aulas
/// do encontro (20261006001100). A modalidade não controla nada por ora.
class EventMainMediaEditor extends ConsumerStatefulWidget {
  final String eventId;

  const EventMainMediaEditor({super.key, required this.eventId});

  @override
  ConsumerState<EventMainMediaEditor> createState() =>
      _EventMainMediaEditorState();
}

class _EventMainMediaEditorState extends ConsumerState<EventMainMediaEditor> {
  bool _busy = false;

  String _column(LessonMediaKind kind) =>
      kind == LessonMediaKind.pdf ? 'pdf_url' : 'video_url';

  Future<bool> _save(Map<String, dynamic> data) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(eventsRepositoryProvider)
          .updateEvent(widget.eventId, data);
      ref.invalidate(eventByIdProvider(widget.eventId));
      ref.invalidate(eventUpdatesProvider(widget.eventId));
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $error')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Apaga o arquivo antigo da pasta do evento (link externo fica).
  Future<void> _dropOld(LessonMediaKind kind, String? old) async {
    if (blankToNull(old) == null) return;
    try {
      await ref
          .read(lessonMediaServiceProvider)
          .removeIfLessonFile(
            kind: kind,
            lessonId: widget.eventId,
            url: old,
            folder: eventMediaFolder,
          );
    } catch (_) {}
  }

  Future<void> _upload(LessonMediaKind kind, String? old) async {
    final media = ref.read(lessonMediaServiceProvider);
    try {
      final file = await media.pick(kind);
      if (file == null || !mounted) return;
      if (file.size > lessonMediaMaxBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kind == LessonMediaKind.video
                  ? 'O vídeo passa de 50 MB. Use um link do YouTube ou do Drive.'
                  : 'O arquivo passa de 50 MB.',
            ),
          ),
        );
        return;
      }
      setState(() => _busy = true);
      final url = await media.upload(
        kind: kind,
        lessonId: widget.eventId,
        file: file,
        folder: eventMediaFolder,
      );
      if (await _save({_column(kind): url})) await _dropOld(kind, old);
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível enviar: $error')),
        );
      }
    }
  }

  Future<void> _pasteLink(LessonMediaKind kind, String? old) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          kind == LessonMediaKind.pdf ? 'Link do PDF' : 'Link do vídeo',
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'https://'),
            validator: (v) =>
                blankToNull(v) == null ? 'Informe o link' : lessonUrlError(v),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (url == null) return;
    if (await _save({_column(kind): url})) await _dropOld(kind, old);
  }

  Future<void> _remove(LessonMediaKind kind, String? old) async {
    if (await _save({_column(kind): null})) await _dropOld(kind, old);
  }

  Widget _mediaRow(LessonMediaKind kind, String? current, TextStyle meta) {
    final label = kind == LessonMediaKind.pdf ? 'PDF' : 'Vídeo de referência';
    final icon = kind == LessonMediaKind.pdf
        ? AppIcons.pdf
        : AppIcons.videoLibrary;
    final url = blankToNull(current);
    if (url == null) {
      return Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            key: ValueKey('event-upload-${kind.name}'),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: _busy ? null : () => _upload(kind, null),
            icon: const Icon(AppIcons.upload, size: 18),
            label: Text('Enviar ${kind.label} do aparelho'),
          ),
          TextButton.icon(
            key: ValueKey('event-link-${kind.name}'),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: _busy ? null : () => _pasteLink(kind, null),
            icon: const Icon(AppIcons.link, size: 18),
            label: const Text('Colar link'),
          ),
        ],
      );
    }
    return ListTile(
      key: ValueKey('event-media-${kind.name}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(kind == LessonMediaKind.pdf ? 'PDF do evento' : label),
      subtitle: Text(
        url,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: meta,
      ),
      onTap: () => openLessonLink(context, url),
      trailing: PopupMenuButton<String>(
        tooltip: 'Mais opções',
        enabled: !_busy,
        onSelected: (v) => switch (v) {
          'arquivo' => _upload(kind, url),
          'link' => _pasteLink(kind, url),
          _ => _remove(kind, url),
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'arquivo',
            child: Text('Trocar por arquivo'),
          ),
          const PopupMenuItem(value: 'link', child: Text('Trocar por link')),
          PopupMenuItem(value: 'remover', child: Text('Remover $label')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = ref.watch(eventByIdProvider(widget.eventId)).valueOrNull;
    if (event == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final meta = TextStyle(fontSize: 14, color: scheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Modalidade', style: meta),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          key: const ValueKey('event-modality'),
          segments: const [
            ButtonSegment(value: 'presencial', label: Text('Presencial')),
            ButtonSegment(value: 'online', label: Text('Online')),
          ],
          selected: {event.modality},
          onSelectionChanged: _busy
              ? null
              : (s) => _save({'modality': s.first}),
        ),
        const SizedBox(height: 8),
        _mediaRow(LessonMediaKind.pdf, event.pdfUrl, meta),
        _mediaRow(LessonMediaKind.video, event.videoUrl, meta),
        const SizedBox(height: 4),
        Text(
          'PDF novo aparece em Atualizações e avisa quem pode ver o evento. '
          'O vídeo é de referência: só professores e liderança veem, e o '
          'aviso vai só aos professores das aulas.',
          style: meta,
        ),
        const SizedBox(height: 16),
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
        Text(
          'Materiais',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        EventMainMediaEditor(eventId: eventId),
        Row(
          children: [
            Expanded(
              child: Text(
                'Da biblioteca',
                style: TextStyle(
                  fontSize: 16,
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
