import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error_handler.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../providers/events_provider.dart';

/// Diálogo público para adicionar um inscrito a um evento.
class AddRegistrationDialog extends ConsumerStatefulWidget {
  final String eventId;

  const AddRegistrationDialog({super.key, required this.eventId});

  @override
  ConsumerState<AddRegistrationDialog> createState() =>
      _AddRegistrationDialogState();
}

class _AddRegistrationDialogState
    extends ConsumerState<AddRegistrationDialog> {
  String? _selectedMemberId;
  String _searchQuery = '';
  bool _submitting = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // REG-01: o provider antigo consultava `public.user_account` direto, e a
    // policy `user_account_select_tenant` só libera a leitura de terceiros
    // para conta elevada (`is_elevated_current_user`) — por isso a lista
    // vinha vazia para qualquer responsável comum. `memberDirectoryProvider`
    // usa a RPC `get_tenant_member_directory` (migration 20260807000001),
    // que é `SECURITY DEFINER` e foi criada para o mesmo bug na área Kids.
    final memberDirectoryAsync = ref.watch(memberDirectoryProvider);
    final registrationsAsync = ref.watch(
      eventRegistrationsProvider(widget.eventId),
    );
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Adicionar Inscrito'),
      content: SizedBox(
        width: double.maxFinite,
        child: memberDirectoryAsync.when(
          data: (directory) {
            return registrationsAsync.when(
              data: (registrations) {
                final registeredMemberIds = registrations
                    .map((r) => r.memberId)
                    .toSet();
                final availableMembers = directory
                    .where((m) => !registeredMemberIds.contains(m.id))
                    .toList();

                if (availableMembers.isEmpty) {
                  return _buildEmptyState(
                    context,
                    icon: Icons.how_to_reg,
                    heading: 'Todos já estão inscritos',
                    body:
                        'Não há mais ninguém no cadastro de membros para adicionar a este evento.',
                  );
                }

                if (_selectedMemberId != null &&
                    !availableMembers.any((m) => m.id == _selectedMemberId)) {
                  _selectedMemberId = null;
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Buscar membro...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.trim().isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 240,
                      child: Builder(
                        builder: (context) {
                          var filtered = availableMembers;
                          if (_searchQuery.isNotEmpty) {
                            final q = _searchQuery.toLowerCase();
                            filtered = filtered.where((m) {
                              return m.displayName.toLowerCase().contains(q) ||
                                  ((m.nickname?.toLowerCase().contains(q)) ??
                                      false);
                            }).toList();
                          }

                          if (filtered.isEmpty) {
                            return _buildEmptyState(
                              context,
                              icon: Icons.search_off,
                              heading: 'Nenhum resultado para "$_searchQuery"',
                              body:
                                  'Confira a grafia ou tente buscar pelo apelido.',
                            );
                          }

                          return ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final m = filtered[index];
                              final isSelected = _selectedMemberId == m.id;
                              final hasAvatar =
                                  m.avatarUrl != null && m.avatarUrl!.trim().isNotEmpty;
                              final hasNickname =
                                  m.nickname != null && m.nickname!.trim().isNotEmpty;
                              return ListTile(
                                leading: hasAvatar
                                    ? CircleAvatar(
                                        backgroundImage: NetworkImage(m.avatarUrl!),
                                      )
                                    : CircleAvatar(child: Text(m.initials)),
                                title: Text(m.displayName),
                                subtitle: hasNickname ? Text(m.nickname!) : null,
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check_circle,
                                        color: colorScheme.primary,
                                      )
                                    : null,
                                onTap: _submitting
                                    ? null
                                    : () {
                                        setState(() => _selectedMemberId = m.id);
                                      },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorState(context),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _buildErrorState(context),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colorScheme.primary),
          onPressed: (_selectedMemberId == null || _submitting)
              ? null
              : () => _addRegistration(context),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Adicionar'),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String heading,
    required String body,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            heading,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              color: colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Não foi possível carregar a lista de membros.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => ref.invalidate(memberDirectoryProvider),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Future<void> _addRegistration(BuildContext context) async {
    if (_selectedMemberId == null || _submitting) return;

    setState(() => _submitting = true);

    try {
      await ref
          .read(eventsRepositoryProvider)
          .addRegistration(widget.eventId, _selectedMemberId!);
      ref.invalidate(eventRegistrationsProvider(widget.eventId));
      ref.invalidate(eventByIdProvider(widget.eventId));

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inscrito adicionado.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppErrorHandler.showSnackBar(
          context,
          e,
          feature: 'events',
          fallbackMessage: 'Não foi possível adicionar o inscrito. Tente novamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
