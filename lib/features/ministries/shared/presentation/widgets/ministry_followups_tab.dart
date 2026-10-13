import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/utils/whatsapp_launcher.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../diaconato/domain/models/worship_attendance.dart';
import '../../../diaconato/presentation/providers/diaconato_attendance_providers.dart';

/// Aba **Acompanhar**: ausentes do culto com pendência neste ministério.
///
/// Entram aqui os que o próprio ministério marcou para ligar/visitar e os
/// que outro ministério (o Diaconato) encaminhou para cá. A aba só aparece
/// quando há alguma pendência (ver [MinistryWorkspaceShell]); concluir tira
/// a pessoa da lista.
class MinistryFollowupsTab extends ConsumerWidget {
  final String ministryId;

  const MinistryFollowupsTab({super.key, required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(absenteeFollowupsProvider(ministryId));
    return RefreshIndicator(
      onRefresh: () =>
          ref.refresh(absenteeFollowupsProvider(ministryId).future),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [Text('Erro ao carregar: $e')],
        ),
        data: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Text(
              'Ausentes do culto que precisam de ligação, visita ou '
              'acompanhamento. Depois de falar com a pessoa, toque em '
              'Concluir.',
              style: CommunityDesign.metaStyle(context),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Nenhuma pendência.',
                  style: CommunityDesign.metaStyle(context),
                ),
              ),
            for (final f in items)
              _FollowupCard(ministryId: ministryId, followup: f),
          ],
        ),
      ),
    );
  }
}

class _FollowupCard extends ConsumerStatefulWidget {
  final String ministryId;
  final AbsenteeFollowup followup;

  const _FollowupCard({required this.ministryId, required this.followup});

  @override
  ConsumerState<_FollowupCard> createState() => _FollowupCardState();
}

class _FollowupCardState extends ConsumerState<_FollowupCard> {
  bool _busy = false;

  String get _what => switch (widget.followup.action) {
    DiaconatoAbsentAction.call ||
    DiaconatoAbsentAction.callAndCommunion => 'Ligar',
    DiaconatoAbsentAction.visit => 'Visitar',
    DiaconatoAbsentAction.forward =>
      'Encaminhado por ${widget.followup.fromMinistryName}',
    _ => widget.followup.action.label,
  };

  Future<void> _complete() async {
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Concluir ${widget.followup.fullName}?'),
        content: TextField(
          controller: notes,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Observação (opcional)',
            hintText: 'Ex.: está doente, pediu oração',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Concluir'),
          ),
        ],
      ),
    );
    final text = notes.text.trim();
    notes.dispose();
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(diaconatoAttendanceRepositoryProvider)
          .completeFollowup(
            widget.followup.personId,
            notes: text.isEmpty ? null : text,
          );
      ref.invalidate(absenteeFollowupsProvider(widget.ministryId));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao concluir: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.followup;
    final cs = Theme.of(context).colorScheme;
    final date = DateFormat("d 'de' MMM", 'pt_BR').format(f.serviceDate);
    final hasPhone = (f.phone ?? '').replaceAll(RegExp(r'\D'), '').length >= 10;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: cs.primary.withValues(alpha: 0.1),
                  backgroundImage: (f.photoUrl ?? '').trim().isNotEmpty
                      ? NetworkImage(f.photoUrl!)
                      : null,
                  child: (f.photoUrl ?? '').trim().isEmpty
                      ? Text(
                          f.fullName.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_what · faltou em ${f.eventName} ($date)',
                        style: CommunityDesign.metaStyle(
                          context,
                        ).copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if ((f.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(f.notes!.trim(), style: CommunityDesign.metaStyle(context)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (hasPhone) ...[
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri(
                        scheme: 'tel',
                        path: f.phone!.replaceAll(RegExp(r'[^0-9+]'), ''),
                      ),
                    ),
                    icon: const Icon(AppIcons.phone, size: 16),
                    label: const Text('Ligar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => launchWhatsAppMessage(phone: f.phone),
                    icon: const Icon(AppIcons.message, size: 16),
                    label: const Text('WhatsApp'),
                  ),
                ],
                FilledButton.icon(
                  onPressed: _busy ? null : _complete,
                  icon: const Icon(AppIcons.check, size: 16),
                  label: const Text('Concluir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
