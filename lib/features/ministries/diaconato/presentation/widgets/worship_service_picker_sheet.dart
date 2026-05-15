import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../worship/domain/models/worship_service.dart';
import '../../../../worship/presentation/providers/worship_provider.dart';

/// Modal bottom sheet para escolher um culto antes de abrir o checklist.
///
/// Lista os cultos mais recentes (ordem desc por `service_date`). Limitado em
/// 30 itens para manter o sheet compacto — se precisar buscar mais antigos,
/// dá pra evoluir para um picker dedicado depois.
class WorshipServicePickerSheet extends ConsumerWidget {
  /// Callback chamado com o culto selecionado. O caller é responsável por
  /// fechar o sheet (este widget faz o pop antes de chamar).
  final void Function(WorshipService service) onSelected;

  const WorshipServicePickerSheet({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(allWorshipServicesProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Selecione o culto',
              style: CommunityDesign.titleStyle(context).copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Para iniciar o checklist de presença do diaconato.',
              style: CommunityDesign.metaStyle(context),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: servicesAsync.when(
                data: (services) {
                  if (services.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'Nenhum culto cadastrado.',
                          style: CommunityDesign.metaStyle(context),
                        ),
                      ),
                    );
                  }
                  final visible = services.take(30).toList();
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final s = visible[index];
                      return _ServiceTile(
                        service: s,
                        onTap: () {
                          Navigator.of(context).pop();
                          onSelected(s);
                        },
                      );
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'Erro ao carregar cultos: $e',
                      style: CommunityDesign.metaStyle(context),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final WorshipService service;
  final VoidCallback onTap;

  const _ServiceTile({required this.service, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateLabel = _formatDate(service.serviceDate);
    final time = (service.serviceTime ?? '').trim();
    final subtitleParts = <String>[
      service.serviceType.label,
      if (time.isNotEmpty) time,
      if ((service.theme ?? '').trim().isNotEmpty) service.theme!.trim(),
    ];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.event_outlined, color: cs.primary, size: 20),
      ),
      title: Text(
        dateLabel,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitleParts.join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      onTap: onTap,
    );
  }

  String _formatDate(DateTime date) {
    final formatter = DateFormat("EEE, d 'de' MMM 'de' y", 'pt_BR');
    return _capitalize(formatter.format(date));
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
