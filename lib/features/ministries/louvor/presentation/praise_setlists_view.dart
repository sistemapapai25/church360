import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../events/domain/models/event.dart';
import '../../../events/presentation/providers/events_provider.dart';
import '../data/praise_repository.dart';
import 'louvores_tab.dart';
import 'providers/praise_providers.dart';

/// Lado "Repertórios" da aba Louvores (canvas, tela 5): próximos (com
/// evento), sem evento e anteriores.
class PraiseSetlistsView extends ConsumerWidget {
  final String ministryId;

  const PraiseSetlistsView({super.key, required this.ministryId});

  /// `event.start_date` é hora de parede de SP rotulada como UTC: compara
  /// campo a campo com o "hoje" do aparelho, sem converter fuso.
  static bool isUpcoming(DateTime eventStart, DateTime now) =>
      !eventStart.isBefore(DateTime.utc(now.year, now.month, now.day));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref
        .watch(praiseSetlistAccessProvider)
        .maybeWhen(data: (a) => a.canManage, orElse: () => false);
    final listAsync = ref.watch(praiseSetlistsProvider(ministryId));

    return listAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => PraiseMessage(
        title: 'Não deu para carregar os repertórios',
        message: praiseErrorText(e),
        onRetry: () => ref.invalidate(praiseSetlistsProvider(ministryId)),
      ),
      data: (all) {
        final now = DateTime.now();
        final upcoming =
            all
                .where(
                  (s) => s.eventStart != null && isUpcoming(s.eventStart!, now),
                )
                .toList()
              ..sort((a, b) => a.eventStart!.compareTo(b.eventStart!));
        final noEvent = all.where((s) => s.eventId == null).toList();
        final past =
            all
                .where((s) => s.eventId != null && !upcoming.contains(s))
                .toList()
              ..sort(
                (a, b) => (b.eventStart ?? DateTime(0)).compareTo(
                  a.eventStart ?? DateTime(0),
                ),
              );

        return RefreshIndicator(
          onRefresh: () =>
              ref.refresh(praiseSetlistsProvider(ministryId).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              if (canManage)
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    icon: const Icon(AppIcons.add),
                    label: const Text('Novo repertório'),
                    onPressed: () => _create(context, ref, all),
                  ),
                ),
              if (all.isEmpty)
                PraiseMessage(
                  title: 'Nenhum repertório ainda',
                  message: canManage
                      ? 'Monte o primeiro em "Novo repertório".'
                      : 'Quando a liderança publicar um repertório, ele aparece aqui.',
                ),
              ..._section(context, 'Próximos', upcoming),
              ..._section(context, 'Sem evento', noEvent),
              ..._section(context, 'Anteriores', past),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _section(
    BuildContext context,
    String label,
    List<PraiseSetlist> items,
  ) {
    if (items.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(
          label.toUpperCase(),
          style: CommunityDesign.metaStyle(
            context,
          ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ),
      for (final s in items) _SetlistCard(ministryId: ministryId, setlist: s),
    ];
  }

  Future<void> _create(
    BuildContext context,
    WidgetRef ref,
    List<PraiseSetlist> existing,
  ) async {
    final taken = {for (final s in existing) s.eventId};
    final events = await ref
        .read(upcomingEventsProvider.future)
        .catchError((_) => <Event>[]);
    if (!context.mounted) return;
    final id = await showDialog<String>(
      context: context,
      builder: (_) => _NewSetlistDialog(
        ministryId: ministryId,
        events: [
          for (final e in events)
            if (e.eventType != 'news' && !taken.contains(e.id)) e,
        ],
      ),
    );
    if (id == null) return;
    invalidatePraise(ref);
    if (context.mounted) {
      context.push('/ministries/$ministryId/louvores/repertorios/$id');
    }
  }
}

/// Situação do card: Publicado / Rascunho / "Editando · rev. N".
({String label, bool published}) setlistStatus(PraiseSetlist s) {
  if (s.draft != null && s.published != null) {
    return (label: 'Editando · rev. ${s.draft!.number}', published: false);
  }
  if (s.draft != null) return (label: 'Rascunho', published: false);
  return (label: 'Publicado', published: true);
}

class _SetlistCard extends StatelessWidget {
  final String ministryId;
  final PraiseSetlist setlist;

  const _SetlistCard({required this.ministryId, required this.setlist});

  @override
  Widget build(BuildContext context) {
    final rev = setlist.current;
    if (rev == null) return const SizedBox.shrink();
    final status = setlistStatus(setlist);
    final count =
        '${rev.itemCount} ${rev.itemCount == 1 ? 'música' : 'músicas'}';
    final when = setlist.eventStart != null
        ? DateFormat('EEE dd/MM · HH:mm', 'pt_BR').format(setlist.eventStart!)
        : (setlist.eventId != null ? 'evento sem acesso' : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        onTap: () => context.push(
          '/ministries/$ministryId/louvores/repertorios/${setlist.id}',
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rev.title,
                    style: CommunityDesign.titleStyle(
                      context,
                    ).copyWith(fontSize: 15),
                  ),
                  Text(
                    [?when, count].join(' · '),
                    style: CommunityDesign.metaStyle(context),
                  ),
                ],
              ),
            ),
            SetlistStatusChip(label: status.label, published: status.published),
          ],
        ),
      ),
    );
  }
}

/// Pílula verde (publicado) ou âmbar (rascunho).
class SetlistStatusChip extends StatelessWidget {
  final String label;
  final bool published;

  const SetlistStatusChip({
    super.key,
    required this.label,
    required this.published,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final MaterialColor hue = published ? Colors.green : Colors.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: dark ? 0.22 : 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: dark ? hue.shade200 : hue.shade900,
        ),
      ),
    );
  }
}

/// Título + evento opcional. Devolve o id do repertório criado.
class _NewSetlistDialog extends ConsumerStatefulWidget {
  final String ministryId;
  final List<Event> events;

  const _NewSetlistDialog({required this.ministryId, required this.events});

  @override
  ConsumerState<_NewSetlistDialog> createState() => _NewSetlistDialogState();
}

class _NewSetlistDialogState extends ConsumerState<_NewSetlistDialog> {
  final _title = TextEditingController();
  Event? _event;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Dê um título ao repertório.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await ref
          .read(praiseRepositoryProvider)
          .createSetlist(
            ministryId: widget.ministryId,
            title: title,
            eventId: _event?.id,
          );
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = praiseErrorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM HH:mm', 'pt_BR');
    return AlertDialog(
      title: const Text('Novo repertório'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<Event?>(
            initialValue: _event,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Evento (opcional)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sem evento')),
              for (final e in widget.events)
                DropdownMenuItem(
                  value: e,
                  child: Text(
                    '${fmt.format(e.startDate)} · ${e.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (e) => setState(() {
              _event = e;
              if (e != null && _title.text.trim().isEmpty) _title.text = e.name;
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Título', errorText: _error),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Criar'),
        ),
      ],
    );
  }
}
