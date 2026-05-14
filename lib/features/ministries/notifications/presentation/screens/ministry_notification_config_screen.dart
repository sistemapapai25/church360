import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/providers/ministries_provider.dart';
import '../../../../members/presentation/providers/members_provider.dart';
import '../../domain/models/ministry_notification_config.dart';
import '../providers/ministry_notification_config_provider.dart';

/// Lote 11.5 — Tela de configuração de notificações in-app por ministério.
///
/// Edita a row em `ministry_change_notification_config` (criada no 11.0).
/// Define quem é notificado quando há mudança na agenda + quais tipos de
/// mudança disparam notificação.
class MinistryNotificationConfigScreen extends ConsumerStatefulWidget {
  final String ministryId;
  final String ministryName;

  const MinistryNotificationConfigScreen({
    super.key,
    required this.ministryId,
    required this.ministryName,
  });

  @override
  ConsumerState<MinistryNotificationConfigScreen> createState() =>
      _MinistryNotificationConfigScreenState();
}

class _MinistryNotificationConfigScreenState
    extends ConsumerState<MinistryNotificationConfigScreen> {
  MinistryNotificationConfig? _config;
  bool _loading = true;
  bool _saving = false;

  // Cache de nomes pra mostrar chips legíveis sem fetch extra a cada rebuild.
  final Map<String, String> _ministryNamesCache = {};
  final Map<String, String> _userNamesCache = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(ministryNotificationConfigRepositoryProvider);
    final existing = await repo.getByMinistry(widget.ministryId);
    if (!mounted) return;
    setState(() {
      _config = existing ??
          MinistryNotificationConfig.defaultFor(widget.ministryId);
      _loading = false;
    });
  }

  Future<void> _save() async {
    final cfg = _config;
    if (cfg == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(ministryNotificationConfigRepositoryProvider);
      final saved = await repo.upsert(cfg);
      ref.invalidate(ministryNotificationConfigProvider(widget.ministryId));
      if (!mounted) return;
      setState(() {
        _config = saved;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuração salva')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    }
  }

  void _update(MinistryNotificationConfig Function(MinistryNotificationConfig) f) {
    setState(() {
      if (_config != null) _config = f(_config!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações de mudança'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context),
      bottomNavigationBar: _loading
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SafeArea(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Salvar'),
                ),
              ),
            ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final cfg = _config!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          'Ministério: ${widget.ministryName}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Quando algo muda na agenda deste ministério (evento adicionado/removido, escala editada, membro escalado), os destinatários abaixo recebem uma notificação dentro do app.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ativo'),
          subtitle: const Text('Desliga todas as notificações sem perder a configuração'),
          value: cfg.active,
          onChanged: (v) => _update((c) => c.copyWith(active: v)),
        ),

        const Divider(height: 32),

        Text('Quem recebe?', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        AbsorbPointer(
          absorbing: !cfg.active,
          child: Opacity(
            opacity: cfg.active ? 1.0 : 0.5,
            child: RadioGroup<NotificationConfigMode>(
              groupValue: cfg.mode,
              onChanged: (v) {
                if (v != null) _update((c) => c.copyWith(mode: v));
              },
              child: Column(
                children: [
                  for (final m in NotificationConfigMode.values)
                    RadioListTile<NotificationConfigMode>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(m.label),
                      value: m,
                    ),
                ],
              ),
            ),
          ),
        ),

        if (cfg.mode == NotificationConfigMode.custom) ...[
          const SizedBox(height: 8),
          _buildCustomMinistriesPicker(cfg),
          const SizedBox(height: 12),
          _buildCustomUsersPicker(cfg),
        ],

        const Divider(height: 32),

        Text('Quando notificar?', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Os toggles abaixo controlam quais tipos de mudança disparam notificação.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Evento adicionado à agenda'),
          value: cfg.notifyOnEventAdded,
          onChanged: cfg.active
              ? (v) => _update((c) => c.copyWith(notifyOnEventAdded: v))
              : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Evento removido da agenda'),
          value: cfg.notifyOnEventRemoved,
          onChanged: cfg.active
              ? (v) => _update((c) => c.copyWith(notifyOnEventRemoved: v))
              : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Evento editado'),
          subtitle: const Text('Nome, data/hora, local, tipo ou status'),
          value: cfg.notifyOnEventUpdated,
          onChanged: cfg.active
              ? (v) => _update((c) => c.copyWith(notifyOnEventUpdated: v))
              : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Membro escalado/desescalado'),
          value: cfg.notifyOnMemberAssigned,
          onChanged: cfg.active
              ? (v) => _update((c) => c.copyWith(notifyOnMemberAssigned: v))
              : null,
        ),

        const Divider(height: 32),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sempre incluir membro afetado'),
          subtitle: const Text(
              'Quando alguém é escalado/desescalado, ele recebe a notificação mesmo se não estiver na lista acima.'),
          value: cfg.alwaysIncludeAffectedMember,
          onChanged: cfg.active
              ? (v) =>
                  _update((c) => c.copyWith(alwaysIncludeAffectedMember: v))
              : null,
        ),
      ],
    );
  }

  Widget _buildCustomMinistriesPicker(MinistryNotificationConfig cfg) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Ministérios inteiros incluídos',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                TextButton.icon(
                  onPressed: cfg.active ? _pickMinistry : null,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (cfg.customMinistryIds.isEmpty)
              Text(
                'Nenhum ministério adicional selecionado.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in cfg.customMinistryIds)
                    InputChip(
                      label: Text(_ministryNamesCache[id] ?? id),
                      onDeleted: cfg.active
                          ? () => _update((c) => c.copyWith(
                                customMinistryIds: List<String>.from(
                                    c.customMinistryIds)
                                  ..remove(id),
                              ))
                          : null,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomUsersPicker(MinistryNotificationConfig cfg) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Pessoas individuais',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                TextButton.icon(
                  onPressed: cfg.active ? _pickUser : null,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (cfg.customUserIds.isEmpty)
              Text(
                'Nenhuma pessoa adicional selecionada.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in cfg.customUserIds)
                    InputChip(
                      label: Text(_userNamesCache[id] ?? id),
                      onDeleted: cfg.active
                          ? () => _update((c) => c.copyWith(
                                customUserIds: List<String>.from(
                                    c.customUserIds)
                                  ..remove(id),
                              ))
                          : null,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMinistry() async {
    final mins =
        await ref.read(activeMinistriesProvider.future);
    if (!mounted) return;
    final cfg = _config!;
    final available =
        mins.where((m) => !cfg.customMinistryIds.contains(m.id)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum ministério disponível pra adicionar')),
      );
      return;
    }
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Adicionar ministério'),
        children: [
          for (final m in available)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(m.id),
              child: Text(m.name),
            ),
        ],
      ),
    );
    if (picked == null) return;
    final pickedMinistry = available.firstWhere((m) => m.id == picked);
    _ministryNamesCache[picked] = pickedMinistry.name;
    _update((c) => c.copyWith(
          customMinistryIds: [...c.customMinistryIds, picked],
        ));
  }

  Future<void> _pickUser() async {
    final picked = await showDialog<(String id, String name)?>(
      context: context,
      builder: (context) => const _UserSearchDialog(),
    );
    if (picked == null) return;
    if (_config!.customUserIds.contains(picked.$1)) return;
    _userNamesCache[picked.$1] = picked.$2;
    _update((c) => c.copyWith(
          customUserIds: [...c.customUserIds, picked.$1],
        ));
  }
}

class _UserSearchDialog extends ConsumerStatefulWidget {
  const _UserSearchDialog();

  @override
  ConsumerState<_UserSearchDialog> createState() => _UserSearchDialogState();
}

class _UserSearchDialogState extends ConsumerState<_UserSearchDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = _query.trim().length >= 3
        ? ref.watch(searchMembersProvider(_query.trim()))
        : null;
    return AlertDialog(
      title: const Text('Adicionar pessoa'),
      content: SizedBox(
        width: 400,
        height: 360,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Buscar (mín. 3 letras)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: results == null
                  ? const Center(
                      child: Text('Digite ao menos 3 letras pra buscar.'),
                    )
                  : results.when(
                      data: (members) {
                        if (members.isEmpty) {
                          return const Center(
                              child: Text('Ninguém encontrado.'));
                        }
                        return ListView.builder(
                          itemCount: members.length,
                          itemBuilder: (context, i) {
                            final m = members[i];
                            return ListTile(
                              dense: true,
                              title: Text(m.displayName),
                              subtitle: (m.email.isNotEmpty)
                                  ? Text(m.email)
                                  : null,
                              onTap: () => Navigator.of(context)
                                  .pop((m.id, m.displayName)),
                            );
                          },
                        );
                      },
                      loading: () => const Center(
                          child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Erro: $e')),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
