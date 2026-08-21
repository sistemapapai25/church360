import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../members/presentation/providers/members_provider.dart';

/// Dialog de busca de usuários (membros cadastrados). Retorna o `Member`
/// selecionado via `Navigator.pop(context, member)`.
///
/// Extraído de `assign_role_screen.dart` pra ser reusado por outras telas
/// que precisam de um picker de usuário (ex: `branch_form_screen.dart`).
class UserSearchDialog extends ConsumerStatefulWidget {
  const UserSearchDialog({super.key});

  @override
  ConsumerState<UserSearchDialog> createState() => _UserSearchDialogState();
}

class _UserSearchDialogState extends ConsumerState<UserSearchDialog> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(searchMembersProvider(_searchQuery));

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Título
            Row(
              children: [
                const Icon(Icons.person_search),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Buscar Usuário',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Campo de busca
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Digite o nome do usuário...',
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
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              autofocus: true,
            ),
            const SizedBox(height: 16),

            // Lista de resultados
            Expanded(
              child: membersAsync.when(
                data: (members) {
                  if (members.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_off,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'Digite para buscar usuários'
                                : 'Nenhum usuário encontrado',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      return ListTile(
                        leading: Builder(builder: (context) {
                          final rawUrl = member.photoUrl;
                          String? resolvedUrl;
                          if (rawUrl != null && rawUrl.isNotEmpty) {
                            final parsed = Uri.tryParse(rawUrl);
                            if (parsed != null && parsed.hasScheme) {
                              resolvedUrl = rawUrl;
                            } else {
                              resolvedUrl = Supabase.instance.client.storage
                                  .from('member-photos')
                                  .getPublicUrl(rawUrl);
                            }
                          }

                          return CircleAvatar(
                            child: resolvedUrl != null
                                ? ClipOval(
                                    child: Image.network(
                                      resolvedUrl,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Text(member.initials);
                                      },
                                    ),
                                  )
                                : Text(member.initials),
                          );
                        }),
                        title: Text(member.displayName),
                        subtitle: Text(member.email),
                        onTap: () => Navigator.pop(context, member),
                      );
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
                        'Erro ao buscar usuários',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
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
