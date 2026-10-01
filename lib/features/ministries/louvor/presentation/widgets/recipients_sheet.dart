import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../../core/widgets/app_filter_bar.dart';
import '../../../presentation/providers/ministries_provider.dart';

/// Ministérios que recebem o repertório (canvas, tela 10a). O dono
/// ([ownerMinistryId]) não aparece: o repertório já é dele. Devolve os ids
/// marcados, ou nulo se cancelou.
Future<Set<String>?> showRecipientsSheet(
  BuildContext context, {
  required String ownerMinistryId,
  required Set<String> initial,
  required String title,
  String? subtitle,
  required String Function(int count) actionLabel,
}) => showModalBottomSheet<Set<String>>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _RecipientsSheet(
    ownerMinistryId: ownerMinistryId,
    initial: initial,
    title: title,
    subtitle: subtitle,
    actionLabel: actionLabel,
  ),
);

class _RecipientsSheet extends ConsumerStatefulWidget {
  final String ownerMinistryId;
  final Set<String> initial;
  final String title;
  final String? subtitle;
  final String Function(int count) actionLabel;

  const _RecipientsSheet({
    required this.ownerMinistryId,
    required this.initial,
    required this.title,
    this.subtitle,
    required this.actionLabel,
  });

  @override
  ConsumerState<_RecipientsSheet> createState() => _RecipientsSheetState();
}

class _RecipientsSheetState extends ConsumerState<_RecipientsSheet> {
  late final Set<String> _picked = {...widget.initial};
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = CommunityDesign.metaStyle(context);
    final ownerName = ref
        .watch(ministryByIdProvider(widget.ownerMinistryId))
        .valueOrNull
        ?.name;
    final ministries = ref.watch(activeMinistriesProvider);
    final q = _searchQuery.trim().toLowerCase();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: CommunityDesign.titleStyle(
                  context,
                ).copyWith(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              if (widget.subtitle != null) Text(widget.subtitle!, style: meta),
              const SizedBox(height: 12),
              Text(
                'ENVIAR TAMBÉM PARA',
                style: meta.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Todos os integrantes dos ministérios marcados vão poder ver o '
                'repertório e abrir as músicas. Ninguém de lá edita.',
                style: meta,
              ),
              const SizedBox(height: 8),
              AppFilterBar(
                searchController: _searchController,
                searchHint: 'Buscar ministério',
                onSearchChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: ministries.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Não deu para listar: $e'),
                  data: (all) {
                    final list = [
                      for (final m in all)
                        if (m.id != widget.ownerMinistryId &&
                            m.name.toLowerCase().contains(q))
                          m,
                    ];
                    return ListView(
                      shrinkWrap: true,
                      children: [
                        for (final m in list)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _picked.contains(m.id),
                            title: Text(m.name),
                            subtitle: m.memberCount == null
                                ? null
                                : Text('${m.memberCount} integrantes'),
                            onChanged: (v) => setState(
                              () => v == true
                                  ? _picked.add(m.id)
                                  : _picked.remove(m.id),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${ownerName ?? 'O ministério de origem'} não aparece na lista: '
                'o repertório já é dele. Dá para tirar ou incluir ministérios '
                'depois, sem publicar de novo.',
                style: meta,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, _picked),
                      child: Text(widget.actionLabel(_picked.length)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
