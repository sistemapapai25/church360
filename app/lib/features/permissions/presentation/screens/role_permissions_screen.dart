import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/permissions_providers.dart';
import '../../domain/models/permission.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';

/// Tela de Permissões do Cargo
/// Gerenciar quais permissões um cargo possui
class RolePermissionsScreen extends ConsumerStatefulWidget {
  final String roleId;
  final int? initialLevel;

  const RolePermissionsScreen({super.key, required this.roleId, this.initialLevel});

  @override
  ConsumerState<RolePermissionsScreen> createState() => _RolePermissionsScreenState();
}

class _RolePermissionsScreenState extends ConsumerState<RolePermissionsScreen> {
  final Map<String, bool> _selectedPermissions = {};
  bool _isLoading = false;
  bool _hasChanges = false;
  String _searchQuery = '';
  int? _baseLevelParam;

  @override
  Widget build(BuildContext context) {
    // Nível base inicial vindo da rota
    _baseLevelParam ??= widget.initialLevel;
    final roleAsync = ref.watch(roleByIdProvider(widget.roleId));
    final allPermissionsAsync = ref.watch(allPermissionsProvider);
    final rolePermissionsAsync = ref.watch(rolePermissionsProvider(widget.roleId));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Permissões do Cargo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isLoading ? null : _savePermissions,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('SALVAR'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Header com nome do cargo
          roleAsync.when(
            data: (role) => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.badge,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          role?.name ?? 'Cargo',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (role?.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      role!.description!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) => Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Text(
                'Erro ao carregar cargo',
                style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
              ),
            ),
          ),

          // Barra de busca
          Padding(
            padding: const EdgeInsets.all(16),
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
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Lista de permissões
          Expanded(
            child: allPermissionsAsync.when(
              data: (allPermissions) {
                return rolePermissionsAsync.when(
                  data: (rolePermissions) {
                    // Inicializar seleções se ainda não foi feito
                    if (_selectedPermissions.isEmpty) {
                      // Pré-seleção recomendada por nível (se fornecido)
                      final recommendedCodes = _recommendedPermissionCodesForLevel(_baseLevelParam);
                      for (final perm in allPermissions) {
                        final isGranted = rolePermissions.any((rp) => rp.id == perm.id);
                        final isRecommended = recommendedCodes.contains(perm.code);
                        _selectedPermissions[perm.id] = isGranted || isRecommended;
                      }
                    }

                    // Agrupar por categoria
                    final permissionsByCategory = <String, List<Permission>>{};
                    for (final perm in allPermissions) {
                      final matchesSearch = _searchQuery.isEmpty ||
                          perm.name.toLowerCase().contains(_searchQuery) ||
                          perm.code.toLowerCase().contains(_searchQuery) ||
                          (perm.description?.toLowerCase().contains(_searchQuery) ?? false);
                      
                      if (matchesSearch) {
                        permissionsByCategory.putIfAbsent(perm.category, () => []);
                        permissionsByCategory[perm.category]!.add(perm);
                      }
                    }

                    if (permissionsByCategory.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
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

                    final categories = permissionsByCategory.keys.toList()..sort();

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: categories.length + 3,
                      itemBuilder: (context, index) {
                        if (index < categories.length) {
                          final category = categories[index];
                          final permissions = permissionsByCategory[category]!;
                          permissions.sort((a, b) => a.name.compareTo(b.name));
                          return _buildCategoryCard(context, category, permissions);
                        }
                        if (index == categories.length) {
                          return _buildCategoriesCatalogCard(context);
                        }
                        if (index == categories.length + 1) {
                          return _buildFunctionCategoriesCard(context);
                        }
                        return _buildScheduleRulesCard(context);
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Text('Erro ao carregar permissões do cargo: $error'),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Erro ao carregar permissões: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Mapeamento recomendado de permissões por nível
  Set<String> _recommendedPermissionCodesForLevel(int? level) {
    if (level == null) return const {};
    switch (level) {
      case 0: // Visitor - público, participação básica
        return const {
          'church_info.view',
          'events.view',
          'groups.view',
          'banners.view',
          'news.view',
          'study_groups.view',
        };
      case 1: // Member - sem Dashboard, participação
        return const {
          'church_info.view',
          'events.view',
          'groups.view',
          'banners.view',
          'news.view',
          'study_groups.view',
        };
      case 2: // Voluntary - com Dashboard, sem ver pessoas; ministério só leitura
        return const {
          'dashboard.access',
          'ministries.view',
          'events.view',
          'groups.view',
          'church_info.view',
          'news.view',
        };
      case 3: // leader
        return const {
          'dashboard.access',
          'ministries.view',
          'events.view',
          'members.view',
          'financial.view',
          'financial.view_reports',
          'groups.view',
        };
      case 4: // coordinator
        return const {
          'dashboard.access',
          'ministries.view',
          'ministries.manage_members',
          'ministries.manage_schedule',
          'events.view',
          'events.create',
          'events.edit',
          'groups.manage_all',
          'members.view',
          'members.edit',
          'news.view',
          'news.create',
          'news.edit',
          'banners.view',
          'banners.create',
          'banners.edit',
          'courses.view',
          'courses.create',
          'courses.edit',
        };
      case 5: // admin/owner
        return const {
          'dashboard.access',
          'ministries.view',
          'ministries.manage_members',
          'ministries.manage_schedule',
          'events.view',
          'events.create',
          'events.edit',
          'events.delete',
          'financial.view',
          'financial.view_reports',
          'financial.edit',
          'financial.delete',
          'settings.manage_users',
          'settings.manage_permissions',
          'settings.manage_roles',
          'settings.manage_access_levels',
        };
      default:
        return const {};
    }
  }

  Widget _buildCategoryCard(BuildContext context, String category, List<Permission> permissions) {
    final allSelected = permissions.every((p) => _selectedPermissions[p.id] == true);
    final someSelected = permissions.any((p) => _selectedPermissions[p.id] == true);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          // Header da categoria com checkbox "selecionar todos"
          CheckboxListTile(
            value: allSelected,
            tristate: true,
            onChanged: (value) {
              setState(() {
                final newValue = value ?? false;
                for (final perm in permissions) {
                  _selectedPermissions[perm.id] = newValue;
                }
                _hasChanges = true;
              });
            },
            title: Text(
              _formatCategoryName(category),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${permissions.where((p) => _selectedPermissions[p.id] == true).length}/${permissions.length} selecionadas',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            secondary: Icon(
              _getCategoryIcon(category),
              color: someSelected 
                  ? Theme.of(context).colorScheme.primary 
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const Divider(height: 1),
          // Lista de permissões da categoria
          ...permissions.map((permission) {
            return CheckboxListTile(
              value: _selectedPermissions[permission.id] ?? false,
              onChanged: (value) {
                setState(() {
                  _selectedPermissions[permission.id] = value ?? false;
                  _hasChanges = true;
                });
              },
              title: Text(permission.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    permission.code,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  if (permission.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      permission.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
              contentPadding: const EdgeInsets.only(left: 56, right: 16),
            );
          }),
        ],
      ),
    );
  }

  String _formatCategoryName(String category) {
    final labels = {
      'church_info': 'Igreja',
      'courses': 'Cursos',
      'ministries': 'Ministérios',
      'events': 'Eventos',
      'financial': 'Financeiro',
      'members': 'Membros',
      'groups': 'Grupos',
      'visitors': 'Visitantes',
      'worship': 'Cultos',
      'reports': 'Relatórios',
      'devotionals': 'Devocionais',
      'prayer_requests': 'Pedidos de Oração',
      'testimonies': 'Testemunhos',
      'study_groups': 'Grupos de Estudo',
      'courses_lessons': 'Aulas do Curso',
      'support_materials': 'Materiais de Apoio',
      'banners': 'Banners',
      'news': 'Notícias',
      'church_schedule': 'Agenda da Igreja',
      'dashboard': 'Dashboard',
      'tags': 'Tags',
      'analytics': 'Analytics',
      'reading_plans': 'Planos de Leitura',
    };
    final label = labels[category];
    if (label != null) return label;
    final words = category.split('_');
    return words.map((w) => w.isEmpty ? '' : (w[0].toUpperCase() + w.substring(1))).join(' ');
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'members': return Icons.people;
      case 'groups': return Icons.group;
      case 'events': return Icons.event;
      case 'financial': return Icons.attach_money;
      case 'visitors': return Icons.person_add;
      case 'ministries': return Icons.church;
      case 'worship': return Icons.church_outlined;
      case 'reports': return Icons.assessment;
      case 'devotionals': return Icons.menu_book;
      case 'prayer_requests': return Icons.volunteer_activism;
      case 'testimonies': return Icons.record_voice_over;
      case 'study_groups': return Icons.school;
      case 'courses': return Icons.class_;
      case 'courses_lessons': return Icons.library_books;
      case 'support_materials': return Icons.folder;
      case 'banners': return Icons.image;
      case 'news': return Icons.article;
      case 'church_info': return Icons.info;
      case 'church_schedule': return Icons.event_note;
      case 'reading_plans': return Icons.menu_book_outlined;
      case 'analytics': return Icons.insights;
      case 'settings': return Icons.settings;
      case 'dashboard': return Icons.dashboard;
      case 'tags': return Icons.label;
      default: return Icons.security;
    }
  }

  Widget _buildCategoriesCatalogCard(BuildContext context) {
    final ministriesAsync = ref.watch(activeMinistriesProvider);
    List<Map<String, dynamic>> cats = [];
    bool loading = false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> loadInitial() async {
              setLocalState(() {
                loading = true;
                cats.clear();
              });
              try {
                final ministries = await ref.read(activeMinistriesProvider.future);
                for (final m in ministries) {
                  final contexts = await ref.read(roleContextsRepositoryProvider).getContextsByMinistry(m.id);
                  final filtered = contexts.where((c) => c.roleId == widget.roleId).toList();
                  if (filtered.isEmpty) continue;
                  final meta = Map<String, dynamic>.from(filtered.first.metadata ?? {});
                  final List<dynamic> available = List<dynamic>.from(meta['available_categories'] ?? const []);
                  final restrictions = Map<String, dynamic>.from(meta['category_restrictions'] ?? {});
                  for (final v in available.map((e) => e.toString())) {
                    final idx = cats.indexWhere((c) => c['name'] == v);
                    final exclusive = (restrictions[v]?['exclusive'] as bool?) ?? false;
                    if (idx == -1) {
                      cats.add({
                        'name': v,
                        'exclusive': exclusive,
                        'ministries': <String>{m.id},
                      });
                    } else {
                      (cats[idx]['ministries'] as Set<String>).add(m.id);
                      cats[idx]['exclusive'] = exclusive || (cats[idx]['exclusive'] as bool);
                    }
                  }
                }
              } catch (_) {}
              setLocalState(() {
                loading = false;
              });
            }

            if (!loading && cats.isEmpty) {
              Future.microtask(loadInitial);
            }

            Future<void> save() async {
              try {
                final ministries = await ref.read(activeMinistriesProvider.future);
                for (final cat in cats) {
                  final name = (cat['name'] as String).trim();
                  final exclusive = cat['exclusive'] == true;
                  final selected = (cat['ministries'] as Set<String>);
                  for (final m in ministries) {
                    if (!selected.contains(m.id)) continue;
                    final contexts = await ref.read(roleContextsRepositoryProvider).getContextsByMinistry(m.id);
                    final filtered = contexts.where((c) => c.roleId == widget.roleId).toList();
                    String ctxId;
                    Map<String, dynamic> meta;
                    if (filtered.isEmpty) {
                      final created = await ref.read(roleContextsRepositoryProvider).createContext(
                        roleId: widget.roleId,
                        contextName: 'Contexto • ${m.name}',
                        metadata: {'ministry_id': m.id},
                      );
                      ctxId = created.id;
                      meta = {'ministry_id': m.id};
                    } else {
                      ctxId = filtered.first.id;
                      meta = Map<String, dynamic>.from(filtered.first.metadata ?? {});
                    }
                    final List<dynamic> avail = List<dynamic>.from(meta['available_categories'] ?? const []);
                    if (!avail.contains(name)) avail.add(name);
                    meta['available_categories'] = avail;
                    final restr = Map<String, dynamic>.from(meta['category_restrictions'] ?? {});
                    restr[name] = {'exclusive': exclusive};
                    meta['category_restrictions'] = restr;
                    await ref.read(roleContextsRepositoryProvider).updateContext(
                      contextId: ctxId,
                      metadata: meta,
                    );
                  }
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Categorias atualizadas')), 
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao salvar categorias: $e')),
                  );
                }
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Categorias',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ministriesAsync.when(
                  data: (ministries) {
                    return Column(
                      children: [
                        if (loading) const LinearProgressIndicator(),
                        ...cats.map((cat) {
                          final name = cat['name'] as String;
                          final exclusive = cat['exclusive'] == true;
                          final selected = (cat['ministries'] as Set<String>);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(name)),
                                    const SizedBox(width: 8),
                                    Switch(
                                      value: exclusive,
                                      onChanged: (v) => setLocalState(() => cat['exclusive'] = v),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => setLocalState(() => cats.remove(cat)),
                                    ),
                                  ],
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: ministries.map((m) {
                                    final selectedFlag = selected.contains(m.id);
                                    return FilterChip(
                                      label: Text(m.name),
                                      selected: selectedFlag,
                                      onSelected: (v) {
                                        setLocalState(() {
                                          if (v) {
                                            selected.add(m.id);
                                          } else {
                                            selected.remove(m.id);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          );
                        }),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Nova categoria',
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (value) {
                                  final name = value.trim();
                                  if (name.isEmpty) return;
                                  setLocalState(() {
                                    cats.add({'name': name, 'exclusive': false, 'ministries': <String>{}});
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: save,
                              icon: const Icon(Icons.save),
                              label: const Text('Salvar Categorias'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Erro ao carregar ministérios: $e'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFunctionCategoriesCard(BuildContext context) {
    final ministriesAsync = ref.watch(activeMinistriesProvider);
    String? selectedMinistryId;
    List<String> functions = [];
    Map<String, String> functionCategory = {};
    bool loading = false;
    List<String> availableCategories = [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> loadForMinistry(String ministryId) async {
              setLocalState(() {
                loading = true;
                functions = [];
                functionCategory.clear();
                availableCategories = [];
              });
              try {
                final contexts = await ref.read(roleContextsRepositoryProvider).getContextsByMinistry(ministryId);
                final filtered = contexts.where((c) => c.roleId == widget.roleId).toList();
                if (filtered.isNotEmpty) {
                  final meta = filtered.first.metadata ?? {};
                  final List<dynamic> funcs = List<dynamic>.from(meta['functions'] ?? []);
                  final catMap = Map<String, dynamic>.from(meta['function_category_by_function'] ?? {});
                  final List<dynamic> cats = List<dynamic>.from(meta['available_categories'] ?? const []);
                  setLocalState(() {
                    functions = funcs.map((e) => e.toString()).toList();
                    functionCategory = catMap.map((k, v) => MapEntry(k, v.toString()));
                    availableCategories = cats.map((e) => e.toString()).toList();
                    loading = false;
                  });
                }
              } catch (_) {
                setLocalState(() {
                  loading = false;
                });
              }
            }

            Future<void> saveForMinistry() async {
              if (selectedMinistryId == null) return;
              try {
                final contexts = await ref.read(roleContextsRepositoryProvider).getContextsByMinistry(selectedMinistryId!);
                final filtered = contexts.where((c) => c.roleId == widget.roleId).toList();
                if (filtered.isEmpty) return;
                final ctx = filtered.first;
                final meta = Map<String, dynamic>.from(ctx.metadata ?? {});
                meta['functions'] = functions;
                meta['function_category_by_function'] = functionCategory;
                meta['available_categories'] = availableCategories;
                await ref.read(roleContextsRepositoryProvider).updateContext(
                  contextId: ctx.id,
                  metadata: meta,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Funções salvas')), 
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao salvar funções: $e')),
                  );
                }
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Funções e Categorias',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ministriesAsync.when(
                  data: (ministries) {
                    final entries = ministries.map((m) => DropdownMenuEntry<String>(value: m.id, label: m.name)).toList();
                    selectedMinistryId ??= ministries.isNotEmpty ? ministries.first.id : null;
                    if (functions.isEmpty && selectedMinistryId != null && !loading) {
                      Future.microtask(() => loadForMinistry(selectedMinistryId!));
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: DropdownMenu<String>(
                            initialSelection: selectedMinistryId,
                            label: const Text('Ministério'),
                            dropdownMenuEntries: entries,
                            onSelected: (value) {
                              setLocalState(() {
                                selectedMinistryId = value;
                              });
                              if (value != null) loadForMinistry(value);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: loading || selectedMinistryId == null ? null : saveForMinistry,
                          icon: const Icon(Icons.save),
                          label: const Text('Salvar Funções'),
                        ),
                      ],
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Erro ao carregar ministérios: $e'),
                ),
                const SizedBox(height: 12),
                if (loading)
                  const LinearProgressIndicator()
                else ...[
                  if (availableCategories.isEmpty)
                    Text(
                      'Nenhuma categoria configurada para este ministério. Crie categorias no card "Categorias".',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 8),
                  if (functions.isEmpty)
                    Text(
                      'Nenhuma função cadastrada para este cargo neste ministério',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    Column(
                      children: functions.map((f) {
                        final currentCat = functionCategory[f];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(child: Text(f)),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 220,
                                child: DropdownButtonFormField<String>(
                                  initialValue: currentCat,
                                  decoration: const InputDecoration(
                                    labelText: 'Categoria',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: availableCategories
                                      .map((c) => DropdownMenuItem(value: c, child: Text(_formatCategoryName(c))))
                                      .toList(),
                                  onChanged: availableCategories.isEmpty
                                      ? null
                                      : (v) {
                                          setLocalState(() {
                                            if (v != null) functionCategory[f] = v;
                                          });
                                        },
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Nova função',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (value) {
                            final name = value.trim();
                            if (name.isEmpty) return;
                            setLocalState(() {
                              if (!functions.contains(name)) {
                                functions.add(name);
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar'),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _savePermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(permissionsRepositoryProvider);

      // Preparar lista de IDs das permissões selecionadas (is_granted = true)
      final permissionIds = _selectedPermissions.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key)
          .toList();

      await repository.setRolePermissions(
        roleId: widget.roleId,
        permissionIds: permissionIds,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissões salvas com sucesso!')),
        );
        setState(() {
          _hasChanges = false;
        });
      }

      // Invalidar cache
      ref.invalidate(rolePermissionsProvider(widget.roleId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar permissões: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  Widget _buildScheduleRulesCard(BuildContext context) {
    final ministriesAsync = ref.watch(activeMinistriesProvider);
    String? selectedMinistryId;
    Map<String, dynamic> eventRequirements = {};

    return Card(
      margin: const EdgeInsets.only(top: 16, bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> loadForMinistry(String ministryId) async {
              try {
                final contexts = await ref.read(roleContextsRepositoryProvider).getContextsByMinistry(ministryId);
                final filtered = contexts.where((c) => c.roleId == widget.roleId).toList();
                if (filtered.isNotEmpty) {
                  final meta = filtered.first.metadata ?? {};
                  final req = Map<String, dynamic>.from(meta['event_function_requirements'] ?? {});
                  setLocalState(() {
                    eventRequirements = req;
                  });
                } else {
                  setLocalState(() {
                    eventRequirements = {};
                  });
                }
              } catch (_) {}
            }

            Future<void> saveForMinistry() async {
              if (selectedMinistryId == null) return;
              try {
                final contexts = await ref.read(roleContextsRepositoryProvider).getContextsByMinistry(selectedMinistryId!);
                final filtered = contexts.where((c) => c.roleId == widget.roleId).toList();
                if (filtered.isEmpty) return;
                final ctx = filtered.first;
                final meta = Map<String, dynamic>.from(ctx.metadata ?? {});
                meta['event_function_requirements'] = eventRequirements;
                await ref.read(roleContextsRepositoryProvider).updateContext(
                  contextId: ctx.id,
                  metadata: meta,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Regras de escala salvas')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao salvar regras: $e')),
                  );
                }
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Regras de Escala (por evento)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Defina requisitos de funções por tipo de evento',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                ministriesAsync.when(
                  data: (ministries) {
                    return DropdownButtonFormField<String>(
                      initialValue: selectedMinistryId,
                      decoration: const InputDecoration(
                        labelText: 'Ministério',
                        border: OutlineInputBorder(),
                      ),
                      items: ministries.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
                      onChanged: (v) {
                        setLocalState(() {
                          selectedMinistryId = v;
                        });
                        if (v != null) {
                          loadForMinistry(v);
                        }
                      },
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Erro ao carregar ministérios: $e'),
                ),
                const SizedBox(height: 12),
                if (selectedMinistryId != null) ...[
                  const SizedBox(height: 8),
                  _EventRequirementsEditor(
                    requirements: eventRequirements,
                    onChanged: (req) => setLocalState(() => eventRequirements = req),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Salvar Regras'),
                      onPressed: saveForMinistry,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

}

class _EventRequirementsEditor extends StatefulWidget {
  final Map<String, dynamic> requirements;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const _EventRequirementsEditor({required this.requirements, required this.onChanged});

  @override
  State<_EventRequirementsEditor> createState() => _EventRequirementsEditorState();
}

class _EventRequirementsEditorState extends State<_EventRequirementsEditor> {
  final TextEditingController _eventTypeController = TextEditingController();
  final TextEditingController _funcNameController = TextEditingController();
  final TextEditingController _funcCountController = TextEditingController(text: '1');

  @override
  void dispose() {
    _eventTypeController.dispose();
    _funcNameController.dispose();
    _funcCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.requirements.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Requisitos por Tipo de Evento',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          Text('Nenhum requisito definido', style: Theme.of(context).textTheme.bodySmall)
        else
          Column(
            children: entries.map((e) {
              final type = e.key;
              final Map<String, dynamic> req = Map<String, dynamic>.from(e.value as Map? ?? {});
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Tipo: $type', style: Theme.of(context).textTheme.bodyMedium)),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                widget.requirements.remove(type);
                              });
                              widget.onChanged(widget.requirements);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: req.entries.map((f) {
                          final fname = f.key;
                          final fcount = int.tryParse(f.value.toString()) ?? 1;
                          return Row(
                            children: [
                              Expanded(child: Text(fname)),
                              SizedBox(
                                width: 80,
                                child: TextFormField(
                                  initialValue: '$fcount',
                                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Qtde'),
                                  onChanged: (v) {
                                    final n = int.tryParse(v) ?? fcount;
                                    setState(() {
                                      req[fname] = n;
                                      widget.requirements[type] = req;
                                    });
                                    widget.onChanged(widget.requirements);
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    req.remove(fname);
                                    widget.requirements[type] = req;
                                  });
                                  widget.onChanged(widget.requirements);
                                },
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _eventTypeController,
                decoration: const InputDecoration(labelText: 'Tipo de evento', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _funcNameController,
                decoration: const InputDecoration(labelText: 'Função', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _funcCountController,
                decoration: const InputDecoration(labelText: 'Qtde', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Adicionar'),
              onPressed: () {
                final type = _eventTypeController.text.trim();
                final fname = _funcNameController.text.trim();
                final count = int.tryParse(_funcCountController.text.trim()) ?? 1;
                if (type.isEmpty || fname.isEmpty) return;
                setState(() {
                  final Map<String, dynamic> req = Map<String, dynamic>.from(widget.requirements[type] as Map? ?? {});
                  req[fname] = count;
                  widget.requirements[type] = req;
                });
                widget.onChanged(widget.requirements);
                _funcNameController.clear();
              },
            ),
          ],
        ),
      ],
    );
  }
}
