import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/layout/readable_width.dart';
import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../data/ministry_routine_repository.dart';
import '../../domain/ministry_routine.dart';
import '../providers/ministry_routine_providers.dart';

/// `/ofertas/:id`: quem da Tesouraria recebeu as ofertas de um culto confere
/// e confirma (F5). Chega pelo aviso no sino; a Tesouraria não precisa ver o
/// ministério, por isso a tela não usa o workspace do ministério.
class OfferingConfirmScreen extends ConsumerStatefulWidget {
  final String deliveryId;

  const OfferingConfirmScreen({super.key, required this.deliveryId});

  @override
  ConsumerState<OfferingConfirmScreen> createState() =>
      _OfferingConfirmScreenState();
}

class _OfferingConfirmScreenState extends ConsumerState<OfferingConfirmScreen> {
  bool _busy = false;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(ministryRoutineRepositoryProvider)
          .confirmOffering(widget.deliveryId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recebimento confirmado.')),
        );
      }
    } on MinistryRoutineException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      ref.invalidate(offeringDeliveryProvider(widget.deliveryId));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(offeringDeliveryProvider(widget.deliveryId));
    final meta = CommunityDesign.metaStyle(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ofertas do culto')),
      body: ReadableWidth(child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e', textAlign: TextAlign.center)),
        data: (d) {
          if (d == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Esta entrega não foi encontrada ou não é sua.',
                  textAlign: TextAlign.center,
                  style: meta,
                ),
              ),
            );
          }
          final date = DateTime.tryParse(d['service_date'] as String? ?? '');
          final confirmedAt = DateTime.tryParse(
            d['received_confirmed_at'] as String? ?? '',
          )?.toLocal();
          final delivered = [
            for (final n in (d['delivered_by'] as List? ?? const [])) '$n',
          ];
          final isReceiver = d['is_receiver'] == true;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${d['ministry_name'] ?? 'Ministério'}'
                      '${date == null ? '' : ' · culto de ${DateFormat('dd/MM/yyyy').format(date)}'}',
                      style: CommunityDesign.titleStyle(
                        context,
                      ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Text('Envelopes: ${d['envelopes'] ?? '—'}'),
                    Text(
                      'Em espécie: ${formatReais((d['cash_amount'] as num?)?.toDouble())}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Entregue por: ${delivered.isEmpty ? '—' : delivered.join(' e ')}',
                      style: meta,
                    ),
                    Text(
                      'Recebido por: ${d['received_by_name'] ?? '—'}',
                      style: meta,
                    ),
                    if (d['notes'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('${d['notes']}', style: meta),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (confirmedAt != null)
                Row(
                  children: [
                    const Icon(AppIcons.verified, color: AppTheme.successColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recebimento confirmado em '
                        '${DateFormat("dd/MM 'às' HH:mm").format(confirmedAt)}.',
                      ),
                    ),
                  ],
                )
              else if (isReceiver) ...[
                Text(
                  'Confira os envelopes e o valor antes de confirmar. Depois '
                  'de confirmado, a equipe não muda mais a entrega.',
                  style: meta,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('offering-confirm'),
                  onPressed: _busy ? null : _confirm,
                  icon: const Icon(AppIcons.verified),
                  label: const Text('Confirmo que recebi'),
                ),
              ] else
                Text('Aguardando quem recebeu confirmar.', style: meta),
            ],
          );
        },
      )),
    );
  }
}
