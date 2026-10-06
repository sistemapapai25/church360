import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/models/event.dart';
import '../../domain/models/event_update.dart';
import '../providers/events_provider.dart';

/// Seção "Atualizações" da aba Informações: até 2 itens, sem cabeçalho de
/// dia, e "Ver todas as atualizações" para a tela empilhada. Quem pode
/// publicar vê "+ Aviso" e, sem itens, "Nenhum aviso ainda"; os demais não
/// veem a seção vazia (nem com erro). Notícia não tem feed.
class EventUpdatesSummary extends ConsumerWidget {
  final Event event;

  const EventUpdatesSummary({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (event.eventType == 'news') return const SizedBox.shrink();
    final updates = ref.watch(eventUpdatesProvider(event.id)).valueOrNull;
    final podePublicar =
        ref.watch(canPostEventUpdateProvider(event.id)).valueOrNull ?? false;
    if (updates == null || (updates.isEmpty && !podePublicar)) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Atualizações',
                style: CommunityDesign.titleStyle(context),
              ),
            ),
            if (podePublicar)
              TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: () => showNewEventNoticeSheet(context, event.id),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Aviso'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (updates.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Nenhum aviso ainda ·',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  onPressed: () => showNewEventNoticeSheet(context, event.id),
                  child: const Text('Publicar aviso'),
                ),
              ],
            ),
          ),
        for (final u in updates.take(2))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: EventUpdateCard(
              update: u,
              onDelete: podePublicar
                  ? () => confirmDeleteEventNotice(context, u)
                  : null,
            ),
          ),
        if (updates.length > 2)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              onPressed: () => context.push('/events/${event.id}/updates'),
              child: Text('Ver todas as atualizações (${updates.length})'),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Tela "Ver todas as atualizações", agrupada por HOJE/ONTEM/data.
class EventUpdatesScreen extends ConsumerWidget {
  final String eventId;

  const EventUpdatesScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventUpdatesProvider(eventId));
    final podePublicar =
        ref.watch(canPostEventUpdateProvider(eventId)).valueOrNull ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atualizações'),
        actions: [
          if (podePublicar)
            IconButton(
              tooltip: 'Novo aviso',
              icon: const Icon(Icons.add),
              onPressed: () => showNewEventNoticeSheet(context, eventId),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const _Vazio('Não foi possível carregar as atualizações.'),
        data: (updates) {
          if (updates.isEmpty) {
            return const _Vazio('Nenhuma atualização ainda.');
          }
          final children = <Widget>[];
          String? dia;
          for (final u in updates) {
            final h = eventUpdateDayHeader(u.createdAt);
            if (h != dia) {
              dia = h;
              children.add(
                Padding(
                  padding: EdgeInsets.only(
                    top: children.isEmpty ? 0 : 12,
                    bottom: 8,
                  ),
                  child: Semantics(
                    header: true,
                    child: Text(
                      h,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            }
            children.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: EventUpdateCard(
                  update: u,
                  onDelete: podePublicar
                      ? () => confirmDeleteEventNotice(context, u)
                      : null,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(eventUpdatesProvider(eventId).future),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: children,
            ),
          );
        },
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  final String texto;

  const _Vazio(this.texto);

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );
}

/// Cartão de um item do feed. Aviso = megafone azul + "Aviso"; mudança =
/// relógio âmbar (tom escuro no claro, para contraste) + "Mudança".
class EventUpdateCard extends StatelessWidget {
  final EventUpdate update;

  /// Menu ⋮ "Excluir aviso": só em aviso e só para quem pode.
  final VoidCallback? onDelete;

  const EventUpdateCard({super.key, required this.update, this.onDelete});

  static const _maxLinhas = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cor = update.isNotice
        ? CommunityDesign.accentForeground(context, AppTheme.primaryColor)
        : (dark ? AppTheme.warningColor : const Color(0xFFB45309));
    final rotulo = update.isNotice ? 'Aviso' : 'Mudança';
    final quando = eventUpdateTimeAgo(update.createdAt);

    final String titulo;
    final List<String> linhas;
    if (update.isNotice) {
      titulo = (update.title?.trim().isNotEmpty ?? false)
          ? update.title!.trim()
          : 'Aviso';
      linhas = [update.body ?? ''];
    } else if (update.changes.length == 1) {
      titulo = update.changeTitle;
      linhas = [update.changes.first.fromTo];
    } else {
      titulo = update.changeTitle;
      linhas = [
        for (final c in update.changes.take(_maxLinhas))
          '${c.fieldLabel}: ${c.fromTo}',
        if (update.changes.length > _maxLinhas)
          '+${update.changes.length - _maxLinhas} '
              '${update.changes.length - _maxLinhas == 1 ? 'alteração' : 'alterações'}',
      ];
    }

    final conteudo = Semantics(
      container: true,
      label: '$rotulo, $quando. $titulo. ${linhas.join('. ')}',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cor.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                update.isNotice ? Icons.campaign_outlined : Icons.schedule,
                size: 20,
                color: cor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        rotulo.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: cor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        quando,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  for (final l in linhas) ...[
                    const SizedBox(height: 4),
                    Text(l, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: conteudo),
          if (onDelete != null && update.isNotice)
            PopupMenuButton<String>(
              tooltip: 'Opções do aviso',
              icon: const Icon(Icons.more_vert),
              onSelected: (_) => onDelete!(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'excluir', child: Text('Excluir aviso')),
              ],
            ),
        ],
      ),
    );
  }
}

/// Confirma e exclui um aviso; o feed recarrega em seguida.
Future<void> confirmDeleteEventNotice(
  BuildContext context,
  EventUpdate update,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Excluir aviso?'),
      content: const Text(
        'Quem já viu este aviso não será avisado da exclusão.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await container.read(eventsRepositoryProvider).deleteEventNotice(update.id);
    container.invalidate(eventUpdatesProvider(update.eventId));
    messenger.showSnackBar(const SnackBar(content: Text('Aviso excluído.')));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Não foi possível excluir o aviso.')),
    );
  }
}

/// Bottom sheet "Novo aviso": título opcional, mensagem obrigatória.
Future<void> showNewEventNoticeSheet(BuildContext context, String eventId) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _NovoAvisoSheet(eventId: eventId),
  );
}

class _NovoAvisoSheet extends ConsumerStatefulWidget {
  final String eventId;

  const _NovoAvisoSheet({required this.eventId});

  @override
  ConsumerState<_NovoAvisoSheet> createState() => _NovoAvisoSheetState();
}

class _NovoAvisoSheetState extends ConsumerState<_NovoAvisoSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _mensagem = TextEditingController();
  bool _salvando = false;

  @override
  void dispose() {
    _titulo.dispose();
    _mensagem.dispose();
    super.dispose();
  }

  Future<void> _publicar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(eventsRepositoryProvider)
          .createEventNotice(
            eventId: widget.eventId,
            title: _titulo.text,
            body: _mensagem.text,
          );
      ref.invalidate(eventUpdatesProvider(widget.eventId));
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Aviso publicado.')));
    } catch (_) {
      if (mounted) setState(() => _salvando = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível publicar o aviso.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Novo aviso',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titulo,
                enabled: !_salvando,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Título (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mensagem,
                enabled: !_salvando,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Mensagem'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Escreva a mensagem do aviso.'
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                'Avisos não podem ser editados, só excluídos.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _salvando ? null : _publicar,
                child: _salvando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Publicar aviso'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
