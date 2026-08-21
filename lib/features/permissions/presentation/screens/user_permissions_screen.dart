import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../data/user_roles_repository.dart' show MemberWithoutAccountException;
import '../../providers/permissions_providers.dart';
import '../../domain/custom_permission_plan.dart';
import '../../domain/models/permission.dart';
import '../../domain/models/user_effective_permission.dart';
import '../permission_category_display.dart';

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
  final _searchController = TextEditingController();

  /// Categorias abertas manualmente (CHU-316). Guardado aqui e não no
  /// `ExpansionTile` porque a `ListView.builder` descarta os cards que saem da
  /// tela — e porque a busca abre tudo temporariamente sem apagar a escolha
  /// do usuário.
  final Set<String> _expandedCategories = {};

  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool get _isSearching => _searchQuery.isNotEmpty;

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim().toLowerCase());
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
  }

  UserPermissionState _stateFor(
    Permission permission,
    Map<String, List<UserEffectivePermission>> effectiveMap,
  ) {
    final entries = effectiveMap[permission.code] ?? const [];
    final custom = entries.where((e) => e.source == 'custom').firstOrNull;
    final role = entries.where((e) => e.source == 'role').firstOrNull;
    return UserPermissionState(
      permissionId: permission.id,
      roleGranted: role?.isGranted ?? false,
      customGranted: custom?.isGranted,
    );
  }

  /// Caminho único de gravação: um toque no switch e o "marcar todas" do card
  /// passam pelo mesmo plano, então o resultado em lote bate exatamente com o
  /// que marcar item a item produziria (CHU-317).
  Future<void> _applyPlan(CustomPermissionPlan plan, {String? successMessage}) async {
    if (_isSaving || plan.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSaving = true);
    try {
      await ref.read(permissionsRepositoryProvider).applyCustomPermissions(
            userId: widget.userId,
            plan: plan,
          );
      if (successMessage != null) {
        messenger.showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } on MemberWithoutAccountException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Este membro não possui conta de acesso. '
            'Crie uma conta para ele antes de editar permissões.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      // O plano pode ter aplicado os grants e falhado nos clears (ou o
      // contrário): invalidamos sempre, para a tela mostrar o que de fato
      // ficou gravado.
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erro ao alterar permissões: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      ref.invalidate(userEffectivePermissionsProvider(widget.userId));
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggleCategory({
    required String category,
    required List<UserPermissionState> states,
    required bool isGranted,
  }) async {
    if (_isSaving) return;

    final plan = CustomPermissionPlan.forTarget(
      permissions: states,
      isGranted: isGranted,
    );
    if (plan.isEmpty) return;

    final label = PermissionCategoryDisplay.label(category);
    // Aqui não existe botão SALVAR para desfazer — a gravação é imediata.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isGranted ? 'Habilitar categoria?' : 'Desabilitar categoria?'),
        content: Text(
          'Isso vai ${isGranted ? 'habilitar' : 'desabilitar'} '
          '${plan.affectedCount} ${plan.affectedCount == 1 ? 'permissão' : 'permissões'} '
          'de "$label" para este usuário. A alteração é salva imediatamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isGranted ? 'HABILITAR' : 'DESABILITAR'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _applyPlan(
      plan,
      successMessage: '$label: ${plan.affectedCount} '
          '${plan.affectedCount == 1 ? 'permissão atualizada' : 'permissões atualizadas'}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final memberAsync = ref.watch(memberByIdProvider(widget.userId));
    final permissionsAsync = ref.watch(permissionsProvider);
    final effectiveAsync = ref.watch(userEffectivePermissionsProvider(widget.userId));

    // Categorias vindas dos dados: a lista hardcoded tinha 13 itens e o tenant
    // tem 28, então 15 categorias não eram filtráveis (CHU-318).
    final categoryOptions = PermissionCategoryDisplay.optionsFrom(
      (permissionsAsync.valueOrNull ?? const <Permission>[]).map((p) => p.category),
    );
    final selectedCategory = categoryOptions.firstWhere(
      (option) => option.value == _selectedCategory,
      orElse: () => categoryOptions.first,
    );

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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                TextField(
                  key: const Key('busca-permissoes'),
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar permissão...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  onChanged: _onSearchChanged,
                ),
                const SizedBox(height: 12),
                DropdownMenu<PermissionCategoryOption>(
                  // As opções chegam junto com os dados; sem a key o
                  // DropdownMenu mantém a lista antiga do primeiro build.
                  key: ValueKey('categorias-${categoryOptions.length}'),
                  initialSelection: selectedCategory,
                  label: const Text('Categoria'),
                  expandedInsets: EdgeInsets.zero,
                  dropdownMenuEntries: categoryOptions
                      .map((option) => DropdownMenuEntry<PermissionCategoryOption>(
                            value: option,
                            label: option.label,
                          ))
                      .toList(),
                  onSelected: (option) => setState(() => _selectedCategory = option?.value),
                ),
              ],
            ),
          ),

          if (_isSaving) const LinearProgressIndicator(),

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
                      final matchesSearch = _searchQuery.isEmpty ||
                          p.name.toLowerCase().contains(_searchQuery) ||
                          p.code.toLowerCase().contains(_searchQuery) ||
                          (p.description?.toLowerCase().contains(_searchQuery) ?? false);
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

                    final categories = byCategory.keys.toList()
                      ..sort((a, b) => PermissionCategoryDisplay.label(a)
                          .compareTo(PermissionCategoryDisplay.label(b)));

                    return Column(
                      children: [
                        if (_isSearching || _selectedCategory != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _resultsLabel(filtered.length),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: categories.length,
                            itemBuilder: (context, i) {
                              final cat = categories[i];
                              final catPerms = byCategory[cat]!
                                ..sort((a, b) => a.name.compareTo(b.name));
                              return _buildCategoryCard(context, cat, catPerms, effectiveMap);
                            },
                          ),
                        ),
                      ],
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

  String _resultsLabel(int count) =>
      count == 1 ? '1 permissão encontrada' : '$count permissões encontradas';

  Widget _buildCategoryCard(
    BuildContext context,
    String category,
    List<Permission> permissions,
    Map<String, List<UserEffectivePermission>> effectiveMap,
  ) {
    final states = [
      for (final p in permissions) _stateFor(p, effectiveMap),
    ];
    final grantedCount = states.where((s) => s.isGranted).length;
    final allGranted = grantedCount == states.length;
    final noneGranted = grantedCount == 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        // A key muda quando a busca liga/desliga para o tile reavaliar o
        // `initiallyExpanded` — é o que abre as categorias com resultado e
        // devolve o estado anterior quando a busca é limpa.
        key: PageStorageKey('user-perm-$category-${_isSearching ? 'busca' : 'lista'}'),
        initiallyExpanded: _isSearching || _expandedCategories.contains(category),
        onExpansionChanged: (expanded) {
          // Durante a busca a expansão é automática; não sobrescreve a escolha
          // manual do usuário.
          if (_isSearching) return;
          setState(() {
            if (expanded) {
              _expandedCategories.add(category);
            } else {
              _expandedCategories.remove(category);
            }
          });
        },
        leading: Checkbox(
          tristate: true,
          value: allGranted ? true : (noneGranted ? false : null),
          onChanged: _isSaving
              ? null
              : (_) => _toggleCategory(
                    category: category,
                    states: states,
                    isGranted: !allGranted,
                  ),
        ),
        title: Text(
          PermissionCategoryDisplay.label(category),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '$grantedCount/${permissions.length} selecionadas',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        children: [
          const Divider(height: 1),
          ...List.generate(permissions.length, (index) {
            final p = permissions[index];
            final state = states[index];
            final isGranted = state.isGranted;
            final isOverridden = state.isOverridden;

            return ListTile(
              leading: Icon(
                isGranted ? Icons.check_circle : Icons.cancel,
                color: isGranted
                    ? Colors.green
                    : (isOverridden ? Colors.red : Colors.grey),
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
                  else if (state.roleGranted)
                    const Text(
                      'Habilitado pelo cargo',
                      style: TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                ],
              ),
              trailing: Switch(
                value: isGranted,
                onChanged: _isSaving
                    ? null
                    : (v) => _applyPlan(
                          CustomPermissionPlan.forTarget(
                            permissions: [state],
                            isGranted: v,
                          ),
                        ),
              ),
              contentPadding: const EdgeInsets.only(left: 16, right: 16),
            );
          }),
        ],
      ),
    );
  }
}
