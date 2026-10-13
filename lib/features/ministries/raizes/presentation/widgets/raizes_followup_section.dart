import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../../core/utils/whatsapp_launcher.dart';
import '../../../../members/domain/models/member.dart';
import '../../../../members/presentation/providers/members_provider.dart';
import '../../../../permissions/providers/permissions_providers.dart';
import '../../domain/models/raizes_followup.dart';
import '../providers/raizes_dashboard_provider.dart';

/// Contatos e mudanças de etapa de uma pessoa (Raízes, 004900).
final raizesFollowupTimelineProvider = FutureProvider.autoDispose
    .family<List<RaizesTimelineEntry>, String>(
      (ref, userId) =>
          ref.watch(raizesRepositoryProvider).getFollowupTimeline(userId),
    );

String _errorText(Object e) {
  if (e is PostgrestException) {
    if (e.code == '42501') return 'Você não tem permissão para acompanhar visitantes.';
    if (e.code == '22023' || e.code == '23514') return e.message;
  }
  return 'Não deu para salvar. Tente de novo.';
}

/// Acompanhamento do Raízes na ficha da pessoa: etapa atual, Registrar
/// contato, Mudar etapa e a linha do tempo. Quem só vê (visitors.view) lê;
/// quem tem visitors.followup também registra.
class RaizesFollowupSection extends ConsumerWidget {
  final Member member;
  const RaizesFollowupSection({super.key, required this.member});

  void _refresh(WidgetRef ref) {
    ref.invalidate(raizesFollowupTimelineProvider(member.id));
    ref.invalidate(memberByIdProvider(member.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canFollow =
        ref
            .watch(currentUserHasPermissionProvider('visitors.followup'))
            .valueOrNull ??
        false;
    final timeline = ref.watch(raizesFollowupTimelineProvider(member.id));
    final stage = RaizesStage.fromValue(member.raizesStage);
    final meta = CommunityDesign.metaStyle(context);

    return Column(
      key: const ValueKey('raizes-followup'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Etapa: ${stage.label}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (canFollow)
              TextButton(
                key: const ValueKey('raizes-stage-change'),
                onPressed: () => _changeStage(context, ref, stage),
                child: const Text('Mudar etapa'),
              ),
          ],
        ),
        if (member.lastContactDate != null)
          Text(
            'Último contato: ${DateFormat('dd/MM/yyyy').format(member.lastContactDate!)}',
            style: meta,
          ),
        if (canFollow) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('raizes-contact-log'),
            onPressed: () => _logContact(context, ref, stage),
            icon: const Icon(Icons.add_comment_outlined),
            label: const Text('Registrar contato'),
          ),
        ],
        const SizedBox(height: 12),
        timeline.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Não deu para carregar o histórico.', style: meta),
          data: (entries) => entries.isEmpty
              ? Text('Nenhum contato ou mudança de etapa registrado.', style: meta)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final e in entries)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(
                          e.isContact ? Icons.forum_outlined : Icons.flag_outlined,
                        ),
                        title: Text(e.title),
                        subtitle: Text(
                          [
                            DateFormat(
                              e.isContact ? 'dd/MM/yyyy' : 'dd/MM/yyyy HH:mm',
                            ).format(e.when),
                            if (e.byName != null) e.byName!,
                            if ((e.detail ?? '').isNotEmpty) e.detail!,
                          ].join(' · '),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _changeStage(
    BuildContext context,
    WidgetRef ref,
    RaizesStage current,
  ) async {
    final noteCtrl = TextEditingController();
    final picked = await showModalBottomSheet<RaizesStage>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              Text('Mudar etapa', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Observação (opcional)',
                ),
              ),
              for (final s in RaizesStage.values)
                ListTile(
                  title: Text(s.label),
                  trailing: s == current ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(ctx, s),
                ),
            ],
          ),
        ),
      ),
    );
    final note = noteCtrl.text;
    noteCtrl.dispose();
    if (picked == null || picked == current) return;
    try {
      await ref
          .read(raizesRepositoryProvider)
          .setStage(member.id, picked, note: note);
      _refresh(ref);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(e))));
      }
    }
  }

  Future<void> _logContact(
    BuildContext context,
    WidgetRef ref,
    RaizesStage stage,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ContactSheet(member: member),
    );
    if (saved != true) return;
    _refresh(ref);
    if (!context.mounted || stage != RaizesStage.visitanteNovo) return;
    // D1: a etapa é à mão; o app só sugere.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Contato registrado.'),
        action: SnackBarAction(
          label: 'Marcar Contactado',
          onPressed: () async {
            try {
              await ref
                  .read(raizesRepositoryProvider)
                  .setStage(member.id, RaizesStage.contactado);
              _refresh(ref);
            } catch (_) {}
          },
        ),
      ),
    );
  }
}

class _ContactSheet extends ConsumerStatefulWidget {
  final Member member;
  const _ContactSheet({required this.member});

  @override
  ConsumerState<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends ConsumerState<_ContactSheet> {
  RaizesContactKind _kind = RaizesContactKind.whatsapp;
  DateTime _date = DateTime.now();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(raizesRepositoryProvider)
          .logContact(widget.member.id, _kind, notes: _notes.text, date: _date);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorText(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = widget.member.phone;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Registrar contato',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final k in RaizesContactKind.values)
                  ChoiceChip(
                    label: Text(k.label),
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
              ],
            ),
            if (_kind == RaizesContactKind.whatsapp &&
                (phone ?? '').trim().isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => launchWhatsAppMessage(
                    phone: phone,
                    message:
                        'Olá ${widget.member.firstName ?? ''}! Que bom que você esteve com a gente. '
                        'Podemos orar por você? Esperamos você no próximo culto!',
                  ),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('Abrir WhatsApp'),
                ),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text('Data: ${DateFormat('dd/MM/yyyy').format(_date)}'),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            TextField(
              controller: _notes,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Como foi? (opcional)',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('raizes-contact-save'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Salvando...' : 'Salvar contato'),
            ),
          ],
        ),
      ),
    );
  }
}
