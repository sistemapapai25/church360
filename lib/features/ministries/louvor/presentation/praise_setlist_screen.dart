import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../events/domain/models/event.dart';
import '../../../events/presentation/providers/events_provider.dart';
import '../../shared/presentation/widgets/ministry_submodule_guard.dart';
import '../data/praise_repository.dart';
import 'louvores_tab.dart';
import 'praise_setlists_view.dart';
import 'providers/praise_providers.dart';
import 'widgets/setlist_item_sheet.dart';

/// Repertório (`/ministries/:id/louvores/repertorios/:setlistId`).
///
/// Quem monta ou publica e tem rascunho aberto cai no rascunho (canvas,
/// tela 6); o resto vê o publicado (tela 8). A RLS já não devolve rascunho
/// ao integrante comum.
class PraiseSetlistScreen extends StatelessWidget {
  final String ministryId;
  final String setlistId;

  const PraiseSetlistScreen({
    super.key,
    required this.ministryId,
    required this.setlistId,
  });

  @override
  Widget build(BuildContext context) {
    return MinistrySubmoduleGuard(
      ministryId: ministryId,
      submoduleLabel: 'Louvores',
      builder: (_) => _Setlist(ministryId: ministryId, setlistId: setlistId),
    );
  }
}

class _Setlist extends ConsumerWidget {
  final String ministryId;
  final String setlistId;

  const _Setlist({required this.ministryId, required this.setlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlistAsync = ref.watch(praiseSetlistProvider(setlistId));
    final accessAsync = ref.watch(praiseSetlistAccessProvider);

    final body = switch ((setlistAsync, accessAsync)) {
      (AsyncData(value: final s), AsyncData(value: final a)) =>
        s == null || s.current == null
            ? const PraiseMessage(
                title: 'Repertório não encontrado',
                message: 'Ele não existe mais ou você não tem acesso.',
              )
            : s.draft != null && (a.canManage || a.canPublish)
            ? _DraftEditor(
                key: ValueKey(s.draft!.id),
                ministryId: ministryId,
                setlist: s,
                canManage: a.canManage,
                canPublish: a.canPublish,
              )
            : _PublishedView(
                ministryId: ministryId,
                setlist: s,
                canManage: a.canManage,
                canPublish: a.canPublish,
              ),
      (AsyncError(:final error), _) ||
      (_, AsyncError(:final error)) => PraiseMessage(
        title: 'Não deu para abrir o repertório',
        message: praiseErrorText(error),
        onRetry: () {
          ref.invalidate(praiseSetlistProvider(setlistId));
          ref.invalidate(praiseSetlistAccessProvider);
        },
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        leading: IconButton(
          icon: const Icon(AppIcons.back),
          // maybePop respeita o aviso de rascunho não salvo.
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Repertório'),
      ),
      body: body,
    );
  }
}

String? _eventLine(PraiseSetlist s) {
  if (s.eventStart != null) {
    return DateFormat('EEE dd/MM · HH:mm', 'pt_BR').format(s.eventStart!);
  }
  return s.eventId == null ? null : 'evento sem acesso';
}

/// Linha de baixo do item: versão, tom original, capo, BPM, observação.
String _itemMeta(PraiseSetlistItem i, {bool withVersion = true}) => [
  if (withVersion) 'versão ${i.version.versionNumber}',
  if (withVersion && i.version.originalKey != null)
    'original ${i.version.originalKey}',
  if (i.capo > 0) 'capo ${i.capo}',
  if (i.bpm != null) '${i.bpm} BPM',
  if (i.notes != null) 'obs: ${i.notes}',
].join(' · ');

class _KeyBox extends StatelessWidget {
  final String text;

  const _KeyBox(this.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 40),
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

String _keyOf(PraiseSetlistItem i) =>
    i.selectedKey ?? i.version.originalKey ?? '—';

// ------------------------------------------------------------ rascunho (6)

class _DraftEditor extends ConsumerStatefulWidget {
  final String ministryId;
  final PraiseSetlist setlist;
  final bool canManage;
  final bool canPublish;

  const _DraftEditor({
    super.key,
    required this.ministryId,
    required this.setlist,
    required this.canManage,
    required this.canPublish,
  });

  @override
  ConsumerState<_DraftEditor> createState() => _DraftEditorState();
}

class _DraftEditorState extends ConsumerState<_DraftEditor> {
  late final _title = TextEditingController(text: _draft.title);
  late final List<PraiseSetlistItem> _items = [..._draft.items];
  bool _dirty = false;
  bool _busy = false;

  PraiseSetlistRevision get _draft => widget.setlist.draft!;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _changed(VoidCallback f) => setState(() {
    f();
    _dirty = true;
  });

  Future<void> _add() async {
    final item = await showSetlistItemSheet(context);
    if (item != null) _changed(() => _items.add(item));
  }

  Future<void> _edit(int index) async {
    final item = await showSetlistItemSheet(context, initial: _items[index]);
    if (item != null) _changed(() => _items[index] = item);
  }

  /// Grava título e lista. `false` = falhou (o aviso já foi mostrado).
  Future<bool> _save({bool quiet = false}) async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _snack('Dê um título ao repertório.');
      return false;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(praiseRepositoryProvider)
          .saveDraft(_draft.id, title, _items);
      setState(() => _dirty = false);
      if (!quiet) _snack('Rascunho salvo.');
      invalidatePraise(ref);
      return true;
    } catch (e) {
      _snack(praiseErrorText(e));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    if (_items.isEmpty) {
      _snack('Adicione ao menos uma música antes de publicar.');
      return;
    }
    final ok = await _confirm(
      'Publicar repertório?',
      widget.setlist.published == null
          ? 'A equipe do ministério passa a ver este repertório.'
          : 'Esta revisão substitui a publicada (rev. '
                '${widget.setlist.published!.number}) para toda a equipe.',
      'Publicar',
    );
    if (!ok) return;
    if (_dirty && !await _save(quiet: true)) return;
    setState(() => _busy = true);
    try {
      await ref.read(praiseRepositoryProvider).publishSetlist(_draft.id);
      invalidatePraise(ref);
      _snack('Repertório publicado.');
    } catch (e) {
      _snack(praiseErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Apaga o rascunho. Se nunca foi publicado, o repertório some junto.
  Future<void> _discard() async {
    final published = widget.setlist.published;
    final ok = await _confirm(
      'Descartar rascunho?',
      published == null
          ? 'Este repertório nunca foi publicado e será apagado.'
          : 'As mudanças da rev. ${_draft.number} se perdem. A rev. '
                '${published.number} publicada continua valendo.',
      'Descartar',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final gone = await ref
          .read(praiseRepositoryProvider)
          .discardDraft(_draft.id);
      if (mounted) setState(() => _dirty = false);
      invalidatePraise(ref);
      _snack(gone ? 'Repertório apagado.' : 'Rascunho descartado.');
      if (gone && mounted) Navigator.pop(context);
    } catch (e) {
      _snack(praiseErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Troca o evento na hora (é do repertório, não da revisão).
  Future<void> _changeEvent() async {
    final repo = ref.read(praiseRepositoryProvider);
    setState(() => _busy = true);
    final (events, setlists) = await (
      ref.read(upcomingEventsProvider.future).catchError((_) => <Event>[]),
      ref
          .read(praiseSetlistsProvider(widget.ministryId).future)
          .catchError((_) => <PraiseSetlist>[]),
    ).wait;
    if (!mounted) return;
    setState(() => _busy = false);
    final taken = {for (final s in setlists) s.eventId};
    final fmt = DateFormat('dd/MM HH:mm', 'pt_BR');
    final picked = await showDialog<(Event?,)>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Evento do repertório'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, (null,)),
            child: const Text('Sem evento'),
          ),
          for (final e in events)
            if (e.eventType != 'news' && !taken.contains(e.id))
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, (e,)),
                child: Text('${fmt.format(e.startDate)} · ${e.name}'),
              ),
        ],
      ),
    );
    if (picked == null || picked.$1?.id == widget.setlist.eventId) return;
    setState(() => _busy = true);
    try {
      await repo.setSetlistEvent(widget.setlist.id, picked.$1?.id);
      invalidatePraise(ref);
    } catch (e) {
      _snack(
        e is PostgrestException && e.code == '23505'
            ? 'Este ministério já tem repertório para este evento.'
            : praiseErrorText(e),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ==
      true;

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final meta = CommunityDesign.metaStyle(context);
    final event = _eventLine(widget.setlist);
    final editable = widget.canManage && !_busy;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirm(
          'Sair sem salvar?',
          'As mudanças deste rascunho se perdem.',
          'Sair',
        );
        if (leave && mounted) {
          setState(() => _dirty = false);
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Column(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              header: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _title,
                          enabled: widget.canManage,
                          style: CommunityDesign.titleStyle(
                            context,
                          ).copyWith(fontSize: 20, fontWeight: FontWeight.w800),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Título do repertório',
                          ),
                          onChanged: (_) => _changed(() {}),
                        ),
                      ),
                      SetlistStatusChip(
                        label: widget.setlist.published == null
                            ? 'Rascunho'
                            : 'Editando · rev. ${_draft.number}',
                        published: false,
                      ),
                    ],
                  ),
                  if (widget.canManage)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event == null
                                ? 'Sem evento'
                                : '$event · data do evento',
                            style: meta,
                          ),
                        ),
                        TextButton(
                          onPressed: editable ? _changeEvent : null,
                          child: const Text('Trocar evento'),
                        ),
                      ],
                    )
                  else if (event != null)
                    Text('$event · data do evento', style: meta),
                  if (widget.setlist.published != null)
                    Text(
                      'A rev. ${widget.setlist.published!.number} continua '
                      'valendo até esta ser publicada.',
                      style: meta,
                    ),
                  if (widget.canManage && _items.length > 1)
                    Text(
                      'Segure a alça e arraste para mudar a ordem.',
                      style: meta,
                    ),
                  const SizedBox(height: 8),
                ],
              ),
              footer: widget.canManage
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(AppIcons.add),
                            label: const Text('Adicionar da Biblioteca'),
                            onPressed: editable ? _add : null,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: editable ? _discard : null,
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                            ),
                            child: const Text('Descartar rascunho'),
                          ),
                        ],
                      ),
                    )
                  : null,
              itemCount: _items.length,
              onReorder: (from, to) => _changed(() {
                if (to > from) to--;
                _items.insert(to, _items.removeAt(from));
              }),
              itemBuilder: (context, i) {
                final it = _items[i];
                return Padding(
                  key: ObjectKey(it),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                    onTap: editable ? () => _edit(i) : null,
                    child: Row(
                      children: [
                        if (widget.canManage)
                          ReorderableDragStartListener(
                            index: i,
                            enabled: editable,
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(
                                AppIcons.dragHandle,
                                semanticLabel: 'Arrastar para reordenar',
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 12),
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${i + 1}',
                            style: meta.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                it.songTitle,
                                style: CommunityDesign.titleStyle(
                                  context,
                                ).copyWith(fontSize: 15),
                              ),
                              Text(_itemMeta(it), style: meta),
                            ],
                          ),
                        ),
                        _KeyBox(_keyOf(it)),
                        if (widget.canManage)
                          IconButton(
                            tooltip: 'Tirar do repertório',
                            icon: const Icon(AppIcons.close),
                            onPressed: editable
                                ? () => _changed(() => _items.removeAt(i))
                                : null,
                          )
                        else
                          const SizedBox(width: 12),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  if (widget.canManage)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _save(),
                        child: const Text('Salvar rascunho'),
                      ),
                    ),
                  if (widget.canManage && widget.canPublish)
                    const SizedBox(width: 10),
                  if (widget.canPublish)
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : _publish,
                        child: const Text('Publicar'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- publicado (8)

class _PublishedView extends ConsumerStatefulWidget {
  final String ministryId;
  final PraiseSetlist setlist;
  final bool canManage;
  final bool canPublish;

  const _PublishedView({
    required this.ministryId,
    required this.setlist,
    required this.canManage,
    required this.canPublish,
  });

  @override
  ConsumerState<_PublishedView> createState() => _PublishedViewState();
}

class _PublishedViewState extends ConsumerState<_PublishedView> {
  bool _busy = false;

  Future<void> _newRevision() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(praiseRepositoryProvider)
          .newSetlistRevision(widget.setlist.id);
      // A tela volta como rascunho quando o repertório recarrega.
      invalidatePraise(ref);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(praiseErrorText(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Excluir repertório?'),
            content: const Text(
              'Some para toda a equipe, com todas as revisões. '
              'Não dá para desfazer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        ) ==
        true;
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await ref.read(praiseRepositoryProvider).deleteSetlist(widget.setlist.id);
      invalidatePraise(ref);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(praiseErrorText(e))));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rev = widget.setlist.published!;
    final meta = CommunityDesign.metaStyle(context);
    final by = ref.watch(praisePublisherNameProvider(rev.id)).value;
    final line = [
      ?_eventLine(widget.setlist),
      if (rev.publishedAt != null)
        'publicado em ${DateFormat('dd/MM', 'pt_BR').format(rev.publishedAt!.toLocal())}'
            '${by == null ? '' : ' por $by'}',
    ].join(' · ');

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      rev.title,
                      style: CommunityDesign.titleStyle(
                        context,
                      ).copyWith(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  SetlistStatusChip(
                    label: 'Publicado · rev. ${rev.number}',
                    published: true,
                  ),
                ],
              ),
              if (line.isNotEmpty) Text(line, style: meta),
              const SizedBox(height: 12),
              for (final (i, it) in rev.items.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    onTap: () => context.push(
                      '/ministries/${widget.ministryId}/louvores/repertorios/'
                      '${widget.setlist.id}/itens/${it.id}',
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${i + 1}',
                            style: meta.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                it.songTitle,
                                style: CommunityDesign.titleStyle(
                                  context,
                                ).copyWith(fontSize: 15),
                              ),
                              if (_itemMeta(it, withVersion: false).isNotEmpty)
                                Text(
                                  _itemMeta(it, withVersion: false),
                                  style: meta,
                                ),
                            ],
                          ),
                        ),
                        _KeyBox(_keyOf(it)),
                        const Icon(AppIcons.forward, size: 18),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (widget.canManage || widget.canPublish)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.canManage) ...[
                    OutlinedButton(
                      onPressed: _busy ? null : _newRevision,
                      child: Text(
                        'Editar (abre a revisão ${rev.number + 1} em rascunho)',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quem já abriu continua vendo esta até a nova ser publicada.',
                      textAlign: TextAlign.center,
                      style: meta,
                    ),
                  ],
                  if (widget.canPublish)
                    TextButton(
                      onPressed: _busy ? null : _delete,
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: const Text('Excluir repertório'),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
