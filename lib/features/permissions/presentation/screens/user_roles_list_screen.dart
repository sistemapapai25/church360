import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/permissions_providers.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../members/domain/models/member.dart';

/// Tela de Usuários e Cargos
/// Exibe todos os usuários e seus cargos atribuídos
class UserRolesListScreen extends ConsumerStatefulWidget {
  const UserRolesListScreen({super.key});

  @override
  ConsumerState<UserRolesListScreen> createState() => _UserRolesListScreenState();
}

class _UserRolesListScreenState extends ConsumerState<UserRolesListScreen> {
  String _searchQuery = '';
  bool _showExpired = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(allMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Usuários e Cargos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(_showExpired ? Icons.visibility : Icons.visibility_off),
            tooltip: _showExpired ? 'Ocultar expirados' : 'Mostrar expirados',
            onPressed: () {
              setState(() {
                _showExpired = !_showExpired;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de busca
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar usuários ou cargos...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Lista de atribuições
          Expanded(
            child: membersAsync.when(
              data: (members) {
                final filteredMembers = members.where((m) {
                  final name = m.displayName.toLowerCase();
                  final email = m.email.toLowerCase();
                  final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery) || email.contains(_searchQuery);
                  return matchesSearch;
                }).toList()
                  ..sort((a, b) => a.displayName.compareTo(b.displayName));

                if (filteredMembers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhum usuário encontrado',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Todos os usuários cadastrados são listados aqui',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredMembers.length,
                  itemBuilder: (context, index) {
                    final member = filteredMembers[index];
                    return _buildUserCard(context, member);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Erro ao carregar usuários',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => ref.refresh(allMembersProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/permissions/assign-role'),
        icon: const Icon(Icons.person_add),
        label: const Text('Atribuir Cargo'),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, Member member) {
    final rolesAsync = ref.watch(userRoleContextsProvider(member.id));
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            member.initials,
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
        ),
        title: Text(
          member.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: rolesAsync.when(
          data: (items) {
            final seenKeys = <String>{};
            for (final it in items) {
              final roleId = (it['role_id'] as String?)?.trim();
              final roleName = (it['role_name'] as String? ?? '').trim().toLowerCase();
              final key = (roleId != null && roleId.isNotEmpty) ? roleId : 'name:$roleName';
              seenKeys.add(key);
            }
            return Text('${seenKeys.length} cargo(s) atribuído(s)');
          },
          loading: () => const Text('Carregando cargos...'),
          error: (e, _) => const Text('Erro ao carregar cargos'),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => _AssignRoleToUserDialog(userId: member.id),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Atribuir cargo'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    context.push('/permissions/users/${member.id}/permissions');
                  },
                  icon: const Icon(Icons.tune),
                  label: const Text('Editar permissões'),
                ),
              ],
            ),
          ),
          rolesAsync.when(
            data: (items) {
              final uniqueByRole = <String, Map<String, dynamic>>{};
              for (final it in items) {
                final roleId = (it['role_id'] as String?)?.trim();
                final roleNameKey = (it['role_name'] as String? ?? '').trim().toLowerCase();
                final key = (roleId != null && roleId.isNotEmpty) ? roleId : 'name:$roleNameKey';
                uniqueByRole.putIfAbsent(key, () => it);
              }

              final filtered = uniqueByRole.values.where((it) {
                final roleName = (it['role_name'] as String? ?? '').toLowerCase();
                return _searchQuery.isEmpty || roleName.contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Sem cargos atribuídos',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }
              return Column(
                children: filtered.map((it) {
                  final roleName = it['role_name'] as String? ?? 'Cargo';
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    leading: Icon(
                      Icons.badge,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(roleName),
                  );
                }).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Erro ao carregar cargos: $e'),
            ),
          ),
        ],
      ),
    );
  }


}


class _AssignRoleToUserDialog extends ConsumerStatefulWidget {
  final String userId;
  const _AssignRoleToUserDialog({required this.userId});

  @override
  ConsumerState<_AssignRoleToUserDialog> createState() => _AssignRoleToUserDialogState();
}

class _AssignRoleToUserDialogState extends ConsumerState<_AssignRoleToUserDialog> {
  String? _selectedRoleId;
  DateTime? _expiresAt;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(allRolesProvider);

    return AlertDialog(
      title: const Text('Atribuir Cargo ao Usuário'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            rolesAsync.when(
              data: (roles) {
                if (roles.isEmpty) return const Text('Nenhum cargo cadastrado');
                _selectedRoleId ??= roles.first.id;
                return DropdownButtonFormField<String>(
                  initialValue: _selectedRoleId,
                  decoration: const InputDecoration(
                    labelText: 'Cargo',
                    border: OutlineInputBorder(),
                  ),
                  items: roles.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
                  onChanged: (v) => setState(() {
                    _selectedRoleId = v;
                  }),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Erro ao carregar cargos: $e'),
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _expiresAt ?? now.add(const Duration(days: 30)),
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 365 * 5)),
                      );
                      if (picked != null) setState(() => _expiresAt = picked);
                    },
                    icon: const Icon(Icons.event),
                    label: Text(_expiresAt == null ? 'Definir expiração (opcional)' : 'Expira em: ${DateFormat('dd/MM/yyyy').format(_expiresAt!)}'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _isLoading ? null : _assignRole,
          icon: const Icon(Icons.save),
          label: const Text('Atribuir'),
        ),
      ],
    );
  }

  // Contextos ocultos: atribuição global sem contexto

  Future<void> _assignRole() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_selectedRoleId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Selecione o cargo')),
      );
      return;
    }

    final nav = Navigator.of(context);
    setState(() => _isLoading = true);
    try {
      await ref.read(userRolesRepositoryProvider).assignRoleToUser(
        userId: widget.userId,
        roleId: _selectedRoleId!,
        contextId: null,
        expiresAt: _expiresAt,
        notes: 'Atribuído via Usuários e Cargos',
      );

      ref.invalidate(userRolesByUserProvider(widget.userId));
      ref.invalidate(userRolesProvider);

      if (mounted) nav.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Erro ao atribuir cargo: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
