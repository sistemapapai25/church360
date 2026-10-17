import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/errors/app_error_handler.dart';

/// K6: consultas de antecedentes de um membro, da mais recente para a mais
/// antiga. A RLS só devolve linhas para quem tem
/// `members.background_check.view`, e nunca a da própria pessoa.
final memberBackgroundChecksProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, memberId) async {
      final rows = await Supabase.instance.client
          .from('member_background_check')
          .select('id, status, checked_at, valid_until, source, notes')
          .eq('user_id', memberId)
          .order('checked_at', ascending: false)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    });

/// K6: quem serve em ministério que exige ficha limpa e não está apto
/// (RPC `background_check_pending`; sem a permissão volta vazio).
final backgroundCheckPendingProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final rows = await Supabase.instance.client.rpc(
        'background_check_pending',
      );
      return List<Map<String, dynamic>>.from(rows as List);
    });

const backgroundCheckStatusLabels = {
  'apto': 'Apto',
  'inapto': 'Não apto',
  'pendente': 'Pendente',
};

/// Seção "Ficha limpa (antecedentes)" da ficha do membro. Quem mostra a
/// seção decide pela permissão; aqui só a lista e o "Lançar resultado".
class MemberBackgroundCheckPanel extends ConsumerWidget {
  final String memberId;

  const MemberBackgroundCheckPanel({super.key, required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checksAsync = ref.watch(memberBackgroundChecksProvider(memberId));
    final fmt = DateFormat('dd/MM/yyyy');
    final today = DateUtils.dateOnly(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        checksAsync.when(
          data: (rows) {
            if (rows.isEmpty) {
              return Text(
                'Nenhuma consulta lançada.',
                style: CommunityDesign.metaStyle(context),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, r) in rows.indexed)
                  _row(context, r, fmt, today, current: i == 0),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            AppErrorHandler.userMessage(e, feature: 'members.background_check'),
            style: CommunityDesign.metaStyle(context),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => _launch(context, ref),
          icon: const Icon(Icons.add_task, size: 18),
          label: const Text('Lançar resultado'),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    Map<String, dynamic> r,
    DateFormat fmt,
    DateTime today, {
    required bool current,
  }) {
    final status = r['status'] as String? ?? '';
    final checked = DateTime.tryParse(r['checked_at'] as String? ?? '');
    final valid = DateTime.tryParse(r['valid_until'] as String? ?? '');
    final expired = valid != null && valid.isBefore(today);
    final ok = status == 'apto' && !expired;
    final color = !current
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : (ok ? Colors.green : Colors.red);
    final label = backgroundCheckStatusLabels[status] ?? status;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: !current,
      leading: Icon(
        ok ? Icons.verified_user : Icons.gpp_maybe_outlined,
        color: color,
      ),
      title: Text(
        current && expired ? '$label (vencida)' : label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          if (checked != null) 'Consulta em ${fmt.format(checked)}',
          if (valid != null) 'vale até ${fmt.format(valid)}',
          if ((r['notes'] as String?)?.isNotEmpty == true) r['notes'] as String,
        ].join(' · '),
      ),
    );
  }

  Future<void> _launch(BuildContext context, WidgetRef ref) async {
    var status = 'apto';
    var date = DateUtils.dateOnly(DateTime.now());
    final notes = TextEditingController();
    final fmt = DateFormat('dd/MM/yyyy');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Lançar ficha limpa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Situação'),
                items: [
                  for (final e in backgroundCheckStatusLabels.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => status = v ?? status),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Data da consulta'),
                subtitle: Text(fmt.format(date)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => date = picked);
                },
              ),
              TextField(
                controller: notes,
                decoration: const InputDecoration(
                  labelText: 'Observação (opcional)',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'A consulta vale 6 meses a partir da data.',
                style: CommunityDesign.metaStyle(ctx),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await Supabase.instance.client.rpc(
        'background_check_save',
        params: {
          'p_user': memberId,
          'p_status': status,
          'p_checked_at': DateFormat('yyyy-MM-dd').format(date),
          'p_notes': notes.text.trim(),
        },
      );
      ref.invalidate(memberBackgroundChecksProvider(memberId));
      ref.invalidate(backgroundCheckPendingProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Resultado lançado.')));
      }
    } catch (e) {
      if (context.mounted) {
        AppErrorHandler.showSnackBar(
          context,
          e,
          feature: 'members.background_check',
        );
      }
    }
  }
}
