import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../providers/permissions_providers.dart';
import '../../domain/models/permission.dart';
import '../../domain/models/user_effective_permission.dart';

class UserPermissionsScreen extends ConsumerStatefulWidget {
  final String userId;
  const UserPermissionsScreen({super.key, required this.userId});

  @override
  ConsumerState<UserPermissionsScreen> createState() => _UserPermissionsScreenState();
}

class _UserPermissionsScreenState extends ConsumerState<UserPermissionsScreen> {
  String _searchQuery = '';
  String? _selectedCategory;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final memberAsync = ref.watch(memberByIdProvider(widget.userId));
    final permissionsAsync = ref.watch(permissionsProvider);
    final effectiveAsync = ref.watch(userEffectivePermissionsProvider(widget.userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Permissões do Usuário',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          memberAsync.when(
            data: (member) => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    child: Text((member?.initials ?? '?')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member?.displayName ?? 'Usuário',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        if ((member?.email ?? '').isNotEmpty)
                          Text(
                            member!.email,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => const SizedBox.shrink(),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar permissão...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value.trim().toLowerCase());
                    },
                  ),
                ),
                const SizedBox(width: 12),
                DropdownMenu<String?>(
                  initialSelection: _selectedCategory,
                  label: const Text('Categoria'),
                  dropdownMenuEntries: const [
                    DropdownMenuEntry<String?>(value: null, label: 'Todas categorias'),
                    DropdownMenuEntry<String?>(value: 'dashboard', label: 'Dashboard'),
                    DropdownMenuEntry<String?>(value: 'ministries', label: 'Ministérios'),
                    DropdownMenuEntry<String?>(value: 'events', label: 'Eventos'),
                    DropdownMenuEntry<String?>(value: 'financial', label: 'Financeiro'),
                    DropdownMenuEntry<String?>(value: 'settings', label: 'Configurações'),
                    DropdownMenuEntry<String?>(value: 'members', label: 'Membros'),
                    DropdownMenuEntry<String?>(value: 'groups', label: 'Grupos'),
                    DropdownMenuEntry<String?>(value: 'news', label: 'Notícias'),
                    DropdownMenuEntry<String?>(value: 'banners', label: 'Banners'),
                    DropdownMenuEntry<String?>(value: 'church_info', label: 'Igreja'),
                    DropdownMenuEntry<String?>(value: 'agents', label: 'Agentes IA'),
                  ],
                  onSelected: (v) => setState(() => _selectedCategory = v),
                ),
              ],
            ),
          ),

          Expanded(
            child: effectiveAsync.when(
              data: (effective) {
                // Mapear permissões por código para facilitar acesso
                final effectiveMap = <String, List<UserEffectivePermission>>{};
                for (final e in effective) {
                  effectiveMap.putIfAbsent(e.permissionCode, () => []);
                  effectiveMap[e.permissionCode]!.add(e);
                }

                return permissionsAsync.when(
                  data: (perms) {
                    final filtered = perms.where((p) {
                      final matchesSearch = _searchQuery.isEmpty || p.name.toLowerCase().contains(_searchQuery) || p.code.toLowerCase().contains(_searchQuery);
                      final matchesCat = _selectedCategory == null || p.category == _selectedCategory;
                      return matchesSearch && matchesCat;
                    }).toList();

                    final byCategory = <String, List<Permission>>{};
                    for (final p in filtered) {
                      byCategory.putIfAbsent(p.category, () => []);
                      byCategory[p.category]!.add(p);
                    }

                    if (byCategory.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Nenhuma permissão encontrada',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final categories = byCategory.keys.toList()..sort();

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: categories.length,
                      itemBuilder: (context, i) {
                        final cat = categories[i];
                        final catPerms = byCategory[cat]!;
                        catPerms.sort((a, b) => a.name.compareTo(b.name));
                        
                        // Contar quantos estão habilitados
                        int grantedCount = 0;
                        for (final p in catPerms) {
                          final entries = effectiveMap[p.code] ?? [];
                          final custom = entries.where((e) => e.source == 'custom').firstOrNull;
                          final role = entries.where((e) => e.source == 'role').firstOrNull;
                          final isGranted = custom?.isGranted ?? role?.isGranted ?? false;
                          if (isGranted) grantedCount++;
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.security),
                                title: Text(cat),
                                subtitle: Text('$grantedCount/${catPerms.length} selecionadas'),
                              ),
                              const Divider(height: 1),
                              ...catPerms.map((p) {
                                final entries = effectiveMap[p.code] ?? [];
                                final custom = entries.where((e) => e.source == 'custom').firstOrNull;
                                final role = entries.where((e) => e.source == 'role').firstOrNull;
                                
                                final roleGranted = role?.isGranted ?? false;
                                final customGranted = custom?.isGranted; // pode ser null, true ou false
                                
                                // O valor final é o custom (se existir) ou o role
                                final isGranted = customGranted ?? roleGranted;
                                
                                // Indicadores visuais
                                final isOverridden = customGranted != null;
                                
                                return ListTile(
                                  leading: Icon(
                                    isGranted ? Icons.check_circle : Icons.cancel, 
                                    color: isGranted ? Colors.green : (isOverridden && !isGranted ? Colors.red : Colors.grey)
                                  ),
                                  title: Text(p.name),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.code, style: const TextStyle(fontSize: 12)),
                                      if (isOverridden)
                                        Text(
                                          isGranted ? 'Habilitado manualmente' : 'Desabilitado manualmente',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isGranted ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      else if (roleGranted)
                                        const Text(
                                          'Habilitado pelo cargo',
                                          style: TextStyle(fontSize: 11, color: Colors.blue),
                                        ),
                                    ],
                                  ),
                                  trailing: Switch(
                                    value: isGranted,
                                    onChanged: (v) async {
                                      if (_isSaving) return;
                                      setState(() => _isSaving = true);
                                      try {
                                        final repo = ref.read(permissionsRepositoryProvider);
                                        
                                        if (v) {
                                          // Quer habilitar
                                          if (roleGranted) {
                                            // Se o cargo já habilita, removemos qualquer bloqueio manual
                                            await repo.removeCustomPermission(
                                              userId: widget.userId,
                                              permissionId: p.id,
                                            );
                                          } else {
                                            // Se o cargo não habilita, forçamos true
                                            await repo.assignCustomPermission(
                                              userId: widget.userId,
                                              permissionId: p.id,
                                              isGranted: true,
                                            );
                                          }
                                        } else {
                                          // Quer desabilitar
                                          if (roleGranted) {
                                            // Se o cargo habilita, precisamos bloquear manualmente
                                            await repo.assignCustomPermission(
                                              userId: widget.userId,
                                              permissionId: p.id,
                                              isGranted: false,
                                            );
                                          } else {
                                            // Se o cargo já não habilita, removemos qualquer override (volta ao padrão false)
                                            await repo.removeCustomPermission(
                                              userId: widget.userId,
                                              permissionId: p.id,
                                            );
                                          }
                                        }
                                        ref.invalidate(userEffectivePermissionsProvider(widget.userId));
                                      } finally {
                                        if (mounted) setState(() => _isSaving = false);
                                      }
                                    },
                                  ),
                                  contentPadding: const EdgeInsets.only(left: 16, right: 16),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Erro ao carregar permissões: $e')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro ao carregar efetivas: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

