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
import '../../presentation/providers/ministries_provider.dart';
import '../../shared/presentation/widgets/ministry_submodule_guard.dart';
import '../data/praise_repository.dart';
import 'louvores_tab.dart';
import 'praise_setlists_view.dart';
import 'providers/praise_providers.dart';
import 'widgets/recipients_sheet.dart';
import 'widgets/setlist_item_sheet.dart';
import 'widgets/spontaneous_sheet.dart';

/// Repertório (`/ministries/:id/louvores/repertorios/:setlistId`).
///
/// Quem monta ou publica e tem rascunho aberto cai no rascunho (canvas,
/// tela 6); o resto vê o publicado (tela 8). A RLS já não devolve rascunho
/// ao integrante comum.
///
/// [received]: repertório que outro ministério mandou para [ministryId]
/// (`/ministries/:id/louvores/recebidos/:setlistId`, tela 12a). Só leitura.
class PraiseSetlistScreen extends StatelessWidget {
  final String ministryId;
  final String setlistId;
  final bool received;

  const PraiseSetlistScreen({
    super.key,
    required this.ministryId,
    required this.setlistId,
    this.received = false,
  });

  @override
  Widget build(BuildContext context) {
    return MinistrySubmoduleGuard(
      ministryId: ministryId,
      submoduleLabel: 'Louvores',
      builder: (_) => _Setlist(
        ministryId: ministryId,
        setlistId: setlistId,
        received: received,
      ),
    );
  }
}

class _Setlist extends ConsumerWidget {
  final String ministryId;
  final String setlistId;
  final bool received;

  const _Setlist({
    required this.ministryId,
    required this.setlistId,
    required this.received,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlistAsync = ref.watch(praiseSetlistProvider(setlistId));
    final accessAsync = ref.watch(praiseSetlistAccessProvider);

    final body = switch ((setlistAsync, accessAsync)) {
      (AsyncData(value: final s), AsyncData(value: final a)) =>
        s == null || (received ? s.published : s.current) == null
            ? const PraiseMessage(
                title: 'Repertório não encontrado',
                message: 'Ele não existe mais ou você não tem acesso.',
              )
            : received
            ? _PublishedView(
                ministryId: ministryId,
                setlist: s,
                canManage: false,
                canPublish: false,
                received: true,
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
        // §10.4 S2: o nome do repertório no título, não repetido no corpo.
        title: Text(
          switch (setlistAsync.valueOrNull) {
                final s? => (received ? s.published : s.current)?.title,
                null => null,
              } ??
              (received ? 'Repertório recebido' : 'Repertório'),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Destinatário só lê o repertório: não tem a biblioteca.
          if (!received)
            TextButton(
              onPressed: () => showSpontaneousSheet(
                context,
                ministryId: ministryId,
                ministerId: setlistAsync.valueOrNull?.current?.items
                    .map((i) => i.ministerId)
                    .nonNulls
                    .firstOrNull,
              ),
              child: const Text('Espontâneo'),
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        // §10.4 S3: em tela larga o conteúdo não estica de ponta a ponta.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: body,
        ),
      ),
    );
  }
}

String? _eventLine(PraiseSetlist s) {
  if (s.eventStart != null) {
    return DateFormat('EEE dd/MM · HH:mm', 'pt_BR').format(s.eventStart!);
  }
  return s.eventId == null ? null : 'evento sem acesso';
}

/// Linha de baixo do item: ministrante, versão, tom original, capo, BPM,
/// observação. [minister] = nome já resolvido (nulo = não mostra).
String _itemMeta(
  PraiseSetlistItem i, {
  bool withVersion = true,
  String? minister,
}) => [
  ?minister,
  if (withVersion) 'versão ${i.version.versionNumber}',
  if (withVersion && i.version.originalKey != null)
    'original ${i.version.originalKey}',
  if (i.capo > 0) 'capo ${i.capo}',
  if (i.bpm != null) '${i.bpm} BPM',
  if (i.notes != null) 'obs: ${i.notes}',
].join(' · ');

/// Nome de quem ministra cada item, pelos integrantes do ministério.
Map<String, String> _ministerNames(WidgetRef ref, String ministryId) => {
  for (final m
      in ref.watch(ministryMembersProvider(ministryId)).valueOrNull ?? const [])
    m.memberId: m.memberName,
};

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
        // Neutro: era o único lilás da tela (§10.4 S15).
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}

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
    final item = await showSetlistItemSheet(
      context,
      ministryId: widget.ministryId,
      songIds: [for (final i in _items) i.version.songId],
    );
    if (item != null) _changed(() => _items.add(item));
  }

  Future<void> _edit(int index) async {
    final item = await showSetlistItemSheet(
      context,
      ministryId: widget.ministryId,
      initial: _items[index],
      songIds: [for (final i in _items) i.version.songId],
    );
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
    final repo = ref.read(praiseRepositoryProvider);
    // A revisão N+1 já nasce com os destinatários da anterior.
    final current = await ref
        .read(praiseRecipientsProvider(_draft.id).future)
        .catchError((_) => <({String id, String name})>[]);
    if (!mounted) return;
    final picked = await showRecipientsSheet(
      context,
      ownerMinistryId: widget.ministryId,
      initial: {for (final r in current) r.id},
      title: 'Publicar repertório',
      subtitle: widget.setlist.published == null
          ? '${_title.text.trim()} · ${_items.length} músicas'
          : 'Esta revisão substitui a publicada (rev. '
                '${widget.setlist.published!.number}) para toda a equipe.',
      actionLabel: (n) => n == 0
          ? 'Publicar'
          : 'Publicar para $n ${n == 1 ? 'ministério' : 'ministérios'}',
    );
    if (picked == null) return;
    if (_dirty && !await _save(quiet: true)) return;
    setState(() => _busy = true);
    try {
      await repo.setRecipients(_draft.id, picked);
      await repo.publishSetlist(_draft.id);
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

  Future<void> _delete() async {
    setState(() => _busy = true);
    if (!await _deleteSetlist(context, ref, widget.setlist.id) && mounted) {
      setState(() => _busy = false);
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

  /// Só para ação que perde algo (descartar, sair sem salvar): botão vermelho.
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
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
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
    final names = _ministerNames(ref, widget.ministryId);

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
              footer: widget.canManage || widget.canPublish
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.canManage) ...[
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
                          // Quem só publica não monta nem descarta, mas
                          // exclui (a RPC aceita com rascunho aberto).
                          if (widget.canPublish)
                            TextButton(
                              onPressed: _busy ? null : _delete,
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                              ),
                              child: const Text('Excluir repertório'),
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
                              Text(
                                _itemMeta(
                                  it,
                                  // No rascunho o vazio aparece: é onde se
                                  // preenche o histórico do Espontâneo.
                                  minister: it.ministerId == null
                                      ? 'sem ministrante'
                                      : '🎤 ${names[it.ministerId] ?? 'fora do ministério'}',
                                ),
                                style: meta,
                              ),
                            ],
                          ),
                        ),
                        _KeyBox(praiseItemKey(it)),
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

/// Excluir repertório (só quem publica, igual à RPC): confirma, apaga e fecha
/// a tela. Serve ao publicado e ao rascunho aberto. Devolve se apagou.
Future<bool> _deleteSetlist(
  BuildContext context,
  WidgetRef ref,
  String setlistId,
) async {
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
  if (!ok) return false;
  try {
    await ref.read(praiseRepositoryProvider).deleteSetlist(setlistId);
    invalidatePraise(ref);
    if (context.mounted) Navigator.pop(context);
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(praiseErrorText(e))));
    }
    return false;
  }
}

// ----------------------------------------------------------- publicado (8)

class _PublishedView extends ConsumerStatefulWidget {
  final String ministryId;
  final PraiseSetlist setlist;
  final bool canManage;
  final bool canPublish;

  /// Visto pelo ministério destinatário (tela 12a): sem ações.
  final bool received;

  const _PublishedView({
    required this.ministryId,
    required this.setlist,
    required this.canManage,
    required this.canPublish,
    this.received = false,
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

  /// "Alterar" destinatários da publicada, sem republicar (tela 10b).
  Future<void> _changeRecipients(List<({String id, String name})> now) async {
    final rev = widget.setlist.published!;
    final picked = await showRecipientsSheet(
      context,
      ownerMinistryId: widget.ministryId,
      initial: {for (final r in now) r.id},
      title: 'Destinatários',
      subtitle: '${rev.title} · rev. ${rev.number}',
      actionLabel: (_) => 'Salvar',
    );
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(praiseRepositoryProvider).setRecipients(rev.id, picked);
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
    setState(() => _busy = true);
    if (!await _deleteSetlist(context, ref, widget.setlist.id) && mounted) {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rev = widget.setlist.published!;
    final meta = CommunityDesign.metaStyle(context);
    // Recebido: os integrantes são de outro ministério, então sem nome.
    final names = widget.received
        ? const <String, String>{}
        : _ministerNames(ref, widget.ministryId);
    final by = ref.watch(praisePublisherNameProvider(rev.id)).value;
    final published = rev.publishedAt == null
        ? null
        : 'publicad${widget.received ? 'a' : 'o'} em '
              '${DateFormat('dd/MM', 'pt_BR').format(rev.publishedAt!.toLocal())}'
              '${by == null ? '' : ' por $by'}';
    final line = widget.received
        ? [
            'Recebido de ${widget.setlist.ministryName ?? 'outro ministério'}',
            ?_eventLine(widget.setlist),
          ].join(' · ')
        : [?_eventLine(widget.setlist), ?published].join(' · ');
    final base = widget.received
        ? '/ministries/${widget.ministryId}/louvores/recebidos/'
        : '/ministries/${widget.ministryId}/louvores/repertorios/';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              Row(
                children: [
                  if (widget.received)
                    const Chip(
                      shape: StadiumBorder(),
                      avatar: Icon(AppIcons.lock, size: 14),
                      label: Text('Só leitura'),
                    )
                  else
                    SetlistStatusChip(
                      label: 'Publicado · rev. ${rev.number}',
                      published: true,
                    ),
                ],
              ),
              if (line.isNotEmpty) Text(line, style: meta),
              if (widget.received)
                Text(
                  ['Rev. ${rev.number}', ?published].join(' · '),
                  style: meta,
                ),
              if (widget.received && rev.number > 1)
                _Changes(setlistId: widget.setlist.id, revision: rev)
              else if (!widget.received)
                _RecipientsLine(
                  revisionId: rev.id,
                  onChange: widget.canPublish && !_busy
                      ? _changeRecipients
                      : null,
                ),
              const SizedBox(height: 12),
              for (final (i, it) in rev.items.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    onTap: () => context.push(
                      '$base${widget.setlist.id}/itens/${it.id}',
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
                              if (_itemMeta(
                                    it,
                                    withVersion: false,
                                    minister: _minister(names, it),
                                  )
                                  case final line when line.isNotEmpty)
                                Text(line, style: meta),
                            ],
                          ),
                        ),
                        _KeyBox(praiseItemKey(it)),
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
                      child: const Text('Editar repertório'),
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

String? _minister(Map<String, String> names, PraiseSetlistItem it) =>
    switch (names[it.ministerId]) {
      final n? => '🎤 $n',
      null => null,
    };

/// "Destinatários: Mídia · Diaconato" + Alterar (tela 10b). Sem
/// destinatário e sem quem altere, some.
class _RecipientsLine extends ConsumerWidget {
  final String revisionId;
  final ValueChanged<List<({String id, String name})>>? onChange;

  const _RecipientsLine({required this.revisionId, this.onChange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(praiseRecipientsProvider(revisionId)).valueOrNull;
    if (list == null || (list.isEmpty && onChange == null)) {
      return const SizedBox.shrink();
    }
    final meta = CommunityDesign.metaStyle(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(
          children: [
            const Icon(AppIcons.share, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Destinatários', style: meta),
                  Text(
                    list.isEmpty
                        ? 'Só este ministério vê'
                        : list.map((r) => r.name).join(' · '),
                    style: CommunityDesign.titleStyle(
                      context,
                    ).copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
            if (onChange != null)
              OutlinedButton(
                onPressed: () => onChange!(list),
                child: Text(list.isEmpty ? 'Escolher' : 'Alterar'),
              ),
          ],
        ),
      ),
    );
  }
}

/// "O que mudou desde a rev. N−1" (tela 12a), contra a arquivada anterior.
class _Changes extends ConsumerWidget {
  final String setlistId;
  final PraiseSetlistRevision revision;

  const _Changes({required this.setlistId, required this.revision});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final before = ref
        .watch(praiseRevisionProvider((setlistId, revision.number - 1)))
        .valueOrNull;
    if (before == null) return const SizedBox.shrink();
    final changes = setlistChanges(before, revision);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'O que mudou desde a rev. ${before.number}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            if (changes.isEmpty)
              Text(
                'Só a ordem ou os detalhes das músicas.',
                style: CommunityDesign.metaStyle(context),
              ),
            for (final c in changes)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: Text(
                        c.sign,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Expanded(child: Text(c.text)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
