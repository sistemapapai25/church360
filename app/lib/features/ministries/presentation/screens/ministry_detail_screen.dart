import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/ministries_provider.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../access_levels/presentation/providers/access_level_provider.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../domain/models/ministry.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/permission_widget.dart';

/// Tela de detalhes do ministério
class MinistryDetailScreen extends ConsumerWidget {
  final String ministryId;

  const MinistryDetailScreen({super.key, required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ministryAsync = ref.watch(ministryByIdProvider(ministryId));

    return ministryAsync.when(
      data: (ministry) {
        if (ministry == null) {
          return Scaffold(
            backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
            appBar: AppBar(
            backgroundColor: CommunityDesign.headerColor(context),
            elevation: 0,
            title: Text(
              'Ministério',
              style: CommunityDesign.titleStyle(context),
            ),
          ),
            body: const Center(child: Text('Ministério não encontrado')),
          );
        }

        final isAdminAsync = ref.watch(isAdminProvider);
        final membershipAsync = ref.watch(currentMemberMinistriesProvider);

        return isAdminAsync.when(
          data: (isAdmin) {
            if (isAdmin) {
              return _MinistryDetailContent(ministry: ministry);
            }

            return membershipAsync.when(
              data: (ministries) {
                final canView = ministries.any((m) => m.id == ministry.id);
                if (!canView) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Ministério')),
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.lock_outline, size: 48, color: Colors.red),
                          SizedBox(height: 12),
                          Text('Acesso restrito ao seu ministério'),
                        ],
                      ),
                    ),
                  );
                }
                return _MinistryDetailContent(ministry: ministry);
              },
              loading: () => Scaffold(
                appBar: AppBar(title: const Text('Ministério')),
                body: const Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Scaffold(
                appBar: AppBar(title: const Text('Ministério')),
                body: Center(child: Text('Erro: $error')),
              ),
            );
          },
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('Ministério')),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(title: const Text('Ministério')),
            body: Center(child: Text('Erro: $error')),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Ministério')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Ministério')),
        body: Center(child: Text('Erro: $error')),
      ),
    );
  }
}

/// Conteúdo da tela de detalhes
class _MinistryDetailContent extends ConsumerWidget {
  final Ministry ministry;

  const _MinistryDetailContent({required this.ministry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorValue = int.tryParse(ministry.color) ?? 0xFF2196F3;
    final color = Color(colorValue);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(context, ref),
          const SizedBox(height: 24),

          // Header com informações do ministério
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: CommunityDesign.overlayDecoration(colorScheme),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: color.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: Icon(Icons.church, color: color, size: 44),
                ),
                const SizedBox(height: 16),
                Text(
                  ministry.name,
                  style: CommunityDesign.titleStyle(
                    context,
                  ).copyWith(fontSize: 24, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                if (ministry.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    ministry.description!,
                    style: CommunityDesign.metaStyle(
                      context,
                    ).copyWith(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CommunityDesign.badge(
                      context,
                      ministry.isActive ? 'Ativo' : 'Inativo',
                      ministry.isActive ? Colors.green : Colors.grey,
                      icon: ministry.isActive
                          ? Icons.check_circle
                          : Icons.cancel,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Seção de membros
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Membros do Ministério',
                  style: CommunityDesign.titleStyle(
                    context,
                  ).copyWith(fontSize: 20),
                ),
                CoordinatorOnlyWidget(
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddMemberDialog(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar'),
                    style: CommunityDesign.pillButtonStyle(
                      context,
                      colorScheme.primary,
                      compact: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Lista de membros
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _MembersList(ministryId: ministry.id),
          ),

          const SizedBox(height: 32),

          // Seção de escalas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Histórico de Escalas',
                  style: CommunityDesign.titleStyle(
                    context,
                  ).copyWith(fontSize: 20),
                ),
                Row(
                  children: [
                    CoordinatorOnlyWidget(
                      child: IconButton(
                        onPressed: () => context.push(
                          '/ministries/${ministry.id}/scale-history',
                        ),
                        icon: const Icon(Icons.history),
                        tooltip: 'Abrir Histórico',
                      ),
                    ),
                    const SizedBox(width: 8),
                    CoordinatorOnlyWidget(
                      child: ElevatedButton.icon(
                        onPressed: () => context.push(
                          '/ministries/${ministry.id}/auto-scheduler',
                        ),
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Gerar'),
                        style: CommunityDesign.pillButtonStyle(
                          context,
                          colorScheme.primary,
                          compact: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Lista de escalas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SchedulesList(ministryId: ministry.id),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 60, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 8),
          Text(
            'Detalhes do Ministério',
            style: CommunityDesign.titleStyle(
              context,
            ).copyWith(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          CoordinatorOnlyWidget(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      context.push('/ministries/${ministry.id}/edit'),
                  tooltip: 'Editar Ministério',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDelete(context, ref),
                  tooltip: 'Deletar Ministério',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
          'Tem certeza que deseja excluir o ministério "${ministry.name}"?\n\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repository = ref.read(ministriesRepositoryProvider);
        await repository.deleteMinistry(ministry.id);

        ref.invalidate(allMinistriesProvider);
        ref.invalidate(activeMinistriesProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ministério excluído com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir ministério: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showAddMemberDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _AddMemberDialog(ministryId: ministry.id),
    );
  }
}

/// Lista de membros do ministério
class _MembersList extends ConsumerWidget {
  final String ministryId;

  const _MembersList({required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(ministryMembersProvider(ministryId));

    return membersAsync.when(
      data: (members) {
        if (members.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: CommunityDesign.overlayDecoration(
              Theme.of(context).colorScheme,
            ),
            child: Column(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 48,
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Nenhum membro neste ministério',
                  style: CommunityDesign.titleStyle(
                    context,
                  ).copyWith(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: members.map((member) {
            return _MemberCard(member: member, ministryId: ministryId);
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text('Erro: $error'),
    );
  }
}

/// Card de membro do ministério
class _MemberCard extends ConsumerWidget {
  final MinistryMember member;
  final String ministryId;

  const _MemberCard({required this.member, required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final roleColor = _getRoleColor(member.role);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: CommunityDesign.overlayDecoration(colorScheme),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: roleColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: roleColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Icon(_getRoleIcon(member.role), color: roleColor, size: 24),
        ),
        title: Text(
          member.memberName,
          style: CommunityDesign.titleStyle(context).copyWith(fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              CommunityDesign.badge(
                context,
                member.cargoName == null || member.cargoName!.isEmpty
                    ? _getRoleLabel(member.role)
                    : member.cargoName!,
                roleColor,
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Editar Função'),
                ],
              ),
              onTap: () {
                Future.microtask(() {
                  if (!context.mounted) return;
                  _showEditRoleDialog(context, ref);
                });
              },
            ),
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Remover', style: TextStyle(color: Colors.red)),
                ],
              ),
              onTap: () {
                Future.microtask(() {
                  if (!context.mounted) return;
                  _confirmRemove(context, ref);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(MinistryRole role) {
    switch (role) {
      case MinistryRole.leader:
        return Colors.purple;
      case MinistryRole.coordinator:
        return Colors.blue;
      case MinistryRole.member:
        return Colors.green;
    }
  }

  IconData _getRoleIcon(MinistryRole role) {
    switch (role) {
      case MinistryRole.leader:
        return Icons.star;
      case MinistryRole.coordinator:
        return Icons.supervisor_account;
      case MinistryRole.member:
        return Icons.person;
    }
  }

  String _getRoleLabel(MinistryRole role) {
    return role.label;
  }

  Future<void> _showEditRoleDialog(BuildContext context, WidgetRef ref) async {
    String? selectedRoleId;
    final Set<String> selectedFunctions = {};
    List<String> availableFunctions = [];
    Map<String, String> functionCategory = {};
    // carrega restrições apenas para validação ao salvar

    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Editar Função'),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          content: SizedBox(
            width: 520,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Consumer(
                builder: (context, ref, _) {
                  final rolesAsync = ref.watch(allRolesProvider);
                  return rolesAsync.when(
                    data: (roles) {
                      final items = roles;
                      if (selectedRoleId == null) {
                        String? preferredId;
                        if (member.cargoName != null &&
                            member.cargoName!.isNotEmpty) {
                          final cn = member.cargoName!.toLowerCase();
                          for (final r in items) {
                            if (r.name.toLowerCase() == cn) {
                              preferredId = r.id;
                              break;
                            }
                          }
                        }
                        if (preferredId == null) {
                          for (final r in items) {
                            final name = r.name.toLowerCase();
                            if (member.role == MinistryRole.leader &&
                                (name.contains('líder') ||
                                    name.contains('leader'))) {
                              preferredId = r.id;
                              break;
                            }
                            if (member.role == MinistryRole.coordinator &&
                                (name.contains('coordenador') ||
                                    name.contains('coordinator'))) {
                              preferredId = r.id;
                              break;
                            }
                            if (member.role == MinistryRole.member &&
                                (name.contains('membro') ||
                                    name.contains('member'))) {
                              preferredId = r.id;
                              break;
                            }
                          }
                        }
                        selectedRoleId =
                            preferredId ??
                            (items.isNotEmpty ? items.first.id : null);
                      }
                      if (selectedRoleId != null &&
                          availableFunctions.isEmpty) {
                        Future.microtask(() async {
                          final contexts = await ref
                              .read(roleContextsRepositoryProvider)
                              .getContextsByMinistry(ministryId);
                          final Set<String> funcs = {};
                          final Map<String, String> catMap = {};
                          final Map<String, List<String>> assignedByUser = {};
                          for (final c in contexts) {
                            final meta = c.metadata ?? {};
                            for (final f in List<dynamic>.from(
                              meta['functions'] ?? const [],
                            )) {
                              funcs.add(f.toString());
                            }
                            final m = Map<String, dynamic>.from(
                              meta['function_category_by_function'] ?? {},
                            );
                            m.forEach((k, v) {
                              catMap[k] = v.toString();
                            });
                            final assigned = Map<String, dynamic>.from(
                              meta['assigned_functions'] ?? {},
                            );
                            assigned.forEach((uid, list) {
                              final arr = List<dynamic>.from(list ?? const []);
                              assignedByUser.putIfAbsent(
                                uid.toString(),
                                () => [],
                              );
                              for (final f in arr) {
                                if (!assignedByUser[uid.toString()]!.contains(
                                  f.toString(),
                                )) {
                                  assignedByUser[uid.toString()]!.add(
                                    f.toString(),
                                  );
                                }
                              }
                            });
                          }
                          try {
                            final mf = await ref
                                .read(ministriesRepositoryProvider)
                                .getMemberFunctionsByMinistry(ministryId);
                            final union = <String>{
                              ...assignedByUser[member.memberId] ?? const [],
                              ...mf[member.memberId] ?? const [],
                            };
                            setState(() {
                              availableFunctions = funcs.toList();
                              functionCategory = catMap;
                              selectedFunctions.addAll(union);
                            });
                          } catch (_) {
                            setState(() {
                              availableFunctions = funcs.toList();
                              functionCategory = catMap;
                              selectedFunctions.addAll(
                                assignedByUser[member.memberId] ?? const [],
                              );
                            });
                          }
                        });
                      }
                      return SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: selectedRoleId,
                              decoration: const InputDecoration(
                                labelText: 'Função (Cargo)',
                                border: OutlineInputBorder(),
                              ),
                              items: items
                                  .map(
                                    (r) => DropdownMenuItem(
                                      value: r.id,
                                      child: Text(r.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) async {
                                setState(() {
                                  selectedRoleId = value;
                                  availableFunctions = [];
                                  selectedFunctions.clear();
                                  functionCategory.clear();
                                });
                                if (value != null) {
                                  final contexts = await ref
                                      .read(roleContextsRepositoryProvider)
                                      .getContextsByMinistry(ministryId);
                                  final Set<String> funcs = {};
                                  final Map<String, String> catMap = {};
                                  final Map<String, List<String>>
                                  assignedByUser = {};
                                  for (final c in contexts) {
                                    final meta = c.metadata ?? {};
                                    for (final f in List<dynamic>.from(
                                      meta['functions'] ?? const [],
                                    )) {
                                      funcs.add(f.toString());
                                    }
                                    final m = Map<String, dynamic>.from(
                                      meta['function_category_by_function'] ??
                                          {},
                                    );
                                    m.forEach((k, v) {
                                      catMap[k] = v.toString();
                                    });
                                    final assigned = Map<String, dynamic>.from(
                                      meta['assigned_functions'] ?? {},
                                    );
                                    assigned.forEach((uid, list) {
                                      final arr = List<dynamic>.from(
                                        list ?? const [],
                                      );
                                      assignedByUser.putIfAbsent(
                                        uid.toString(),
                                        () => [],
                                      );
                                      for (final f in arr) {
                                        if (!assignedByUser[uid.toString()]!
                                            .contains(f.toString())) {
                                          assignedByUser[uid.toString()]!.add(
                                            f.toString(),
                                          );
                                        }
                                      }
                                    });
                                  }
                                  try {
                                    final mf = await ref
                                        .read(ministriesRepositoryProvider)
                                        .getMemberFunctionsByMinistry(
                                          ministryId,
                                        );
                                    final union = <String>{
                                      ...assignedByUser[member.memberId] ??
                                          const [],
                                      ...mf[member.memberId] ?? const [],
                                    };
                                    setState(() {
                                      availableFunctions = funcs.toList();
                                      functionCategory = catMap;
                                      selectedFunctions.addAll(union);
                                    });
                                  } catch (_) {
                                    setState(() {
                                      availableFunctions = funcs.toList();
                                      functionCategory = catMap;
                                      selectedFunctions.addAll(
                                        assignedByUser[member.memberId] ??
                                            const [],
                                      );
                                    });
                                  }
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Funções no ministério',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (availableFunctions.isEmpty)
                              Text(
                                'Nenhuma função cadastrada para este cargo neste ministério',
                                style: Theme.of(context).textTheme.bodySmall,
                              )
                            else
                              Column(
                                children: availableFunctions.map((f) {
                                  final checked = selectedFunctions.contains(f);
                                  final cat = functionCategory[f] ?? 'other';
                                  return CheckboxListTile(
                                    value: checked,
                                    title: Text(f),
                                    subtitle: Text(
                                      cat == 'instrument'
                                          ? 'Instrumento'
                                          : cat == 'voice_role'
                                          ? 'Back'
                                          : cat,
                                    ),
                                    onChanged: (sel) {
                                      setState(() {
                                        if (sel == true) {
                                          selectedFunctions.add(f);
                                        } else {
                                          selectedFunctions.remove(f);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 8),
                            const SizedBox.shrink(),
                          ],
                        ),
                      );
                    },
                    loading: () => const SizedBox(
                      height: 48,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Text('Erro ao carregar cargos: $e'),
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && selectedRoleId != null && context.mounted) {
      try {
        final repository = ref.read(ministriesRepositoryProvider);
        final rolesRepo = ref.read(rolesRepositoryProvider);
        final chosenRole = (await rolesRepo.getRoles()).firstWhere(
          (r) => r.id == selectedRoleId,
        );
        final chosenName = chosenRole.name.toLowerCase();
        final roleValue =
            chosenName.contains('líder') || chosenName.contains('leader')
            ? 'leader'
            : (chosenName.contains('coordenador') ||
                  chosenName.contains('coordinator'))
            ? 'coordinator'
            : 'member';
        await repository.updateMinistryMember(member.id, {'role': roleValue});

        // Sincronizar cargo (permissions) com a função escolhida
        bool persistedOk = true;
        try {
          final matchedRole = chosenRole;

          final ministry = await ref
              .read(ministriesRepositoryProvider)
              .getMinistryById(ministryId);
          final contextsRepo = ref.read(roleContextsRepositoryProvider);
          final contextsForMinistry = await contextsRepo.getContextsByMinistry(
            ministryId,
          );

          // Remove atribuições antigas do contexto deste ministério
          for (final ctx in contextsForMinistry) {
            await ref
                .read(userRolesRepositoryProvider)
                .removeUserRoleByContext(
                  userId: member.memberId,
                  contextId: ctx.id,
                );
          }

          // Seleciona ou cria contexto para o cargo escolhido
          final filtered = contextsForMinistry
              .where((c) => c.roleId == matchedRole.id)
              .toList();
          String contextId;
          if (filtered.isEmpty) {
            final created = await contextsRepo.createContext(
              roleId: matchedRole.id,
              contextName:
                  '${matchedRole.name} – ${ministry?.name ?? 'Ministério'}',
              metadata: {'ministry_id': ministryId},
            );
            contextId = created.id;
          } else {
            contextId = filtered.first.id;
          }

          await contextsRepo.getContextById(contextId);

          await ref
              .read(userRolesRepositoryProvider)
              .assignRoleToUser(
                userId: member.memberId,
                roleId: matchedRole.id,
                contextId: contextId,
                notes: 'Atualizado via ministério',
              );

          // Persistir funções atribuídas por usuário no metadata
          final updatedCtx = await contextsRepo.getContextById(contextId);
          final updatedMeta = Map<String, dynamic>.from(
            updatedCtx?.metadata ?? {},
          );
          final assigned = Map<String, dynamic>.from(
            updatedMeta['assigned_functions'] ?? {},
          );
          assigned[member.memberId] = selectedFunctions.toList();
          updatedMeta['assigned_functions'] = assigned;
          await contextsRepo.updateContext(
            contextId: contextId,
            metadata: updatedMeta,
          );

          // Persistir também em member_function (fonte para regras/geração de escala)
          try {
            final currentMapByUser = await repository
                .getMemberFunctionsByMinistry(ministryId);
            final byFunc = <String, List<String>>{};
            currentMapByUser.forEach((uid, fnList) {
              for (final f in fnList) {
                byFunc.putIfAbsent(f, () => []);
                if (!byFunc[f]!.contains(uid)) byFunc[f]!.add(uid);
              }
            });
            // Aplicar seleção atual deste membro
            for (final f in availableFunctions) {
              final list = byFunc.putIfAbsent(f, () => []);
              final has = list.contains(member.memberId);
              final sel = selectedFunctions.contains(f);
              if (sel && !has) {
                list.add(member.memberId);
              } else if (!sel && has) {
                list.remove(member.memberId);
              }
            }
            await repository.setMemberFunctionsByMinistry(ministryId, byFunc);
          } catch (e) {
            persistedOk = false;
            debugPrint('Falha ao persistir member_function: $e');
            rethrow;
          }
        } catch (e) {
          persistedOk = false;
          debugPrint('Falha ao sincronizar cargo com função: $e');
          rethrow;
        }
        ref.invalidate(ministryMembersProvider(ministryId));
        if (context.mounted && persistedOk) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Função atualizada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao atualizar função: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Remoção'),
        content: Text(
          'Tem certeza que deseja remover ${member.memberName} deste ministério?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repository = ref.read(ministriesRepositoryProvider);
        await repository.removeMinistryMember(member.id);

        // Remover cargos vinculados ao contexto deste ministério
        try {
          final contexts = await ref
              .read(roleContextsRepositoryProvider)
              .getContextsByMinistry(ministryId);
          for (final ctx in contexts) {
            await ref
                .read(userRolesRepositoryProvider)
                .removeUserRoleByContext(
                  userId: member.memberId,
                  contextId: ctx.id,
                );
          }
        } catch (e) {
          debugPrint('Falha ao remover cargos do contexto: $e');
        }

        ref.invalidate(ministryMembersProvider(ministryId));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Membro removido com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao remover membro: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

/// Diálogo para adicionar membro ao ministério
class _AddMemberDialog extends ConsumerStatefulWidget {
  final String ministryId;

  const _AddMemberDialog({required this.ministryId});

  @override
  ConsumerState<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends ConsumerState<_AddMemberDialog> {
  String? _selectedMemberId;
  String? _selectedRoleId;
  List<String> _availableFunctions = [];
  final Set<String> _selectedFunctions = {};
  final Map<String, String> _functionCategory = {};
  final _newFunctionController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;
  String _memberSearchQuery = '';
  // Fluxo simplificado: sempre atribui cargo de ministério automaticamente

  @override
  void dispose() {
    _newFunctionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(allMembersProvider);
    final allRolesAsync = ref.watch(allRolesProvider);

    return AlertDialog(
      title: const Text('Adicionar Membro'),
      content: SizedBox(
        width: double.maxFinite,
        child: membersAsync.when(
          data: (members) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Campo de busca de membro
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar membro...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() => _memberSearchQuery = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 240,
                    child: membersAsync.when(
                      data: (members) {
                        var filtered = members;
                        if (_memberSearchQuery.isNotEmpty) {
                          final q = _memberSearchQuery.toLowerCase();
                          filtered = filtered.where((m) {
                            return m.displayName.toLowerCase().contains(q) ||
                                ((m.nickname?.toLowerCase().contains(q)) ??
                                    false);
                          }).toList();
                        }

                        if (filtered.isEmpty) {
                          return Center(
                            child: Text(
                              _memberSearchQuery.isEmpty
                                  ? 'Nenhum membro encontrado'
                                  : 'Nenhum resultado para "$_memberSearchQuery"',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final m = filtered[index];
                            final isSelected = _selectedMemberId == m.id;
                            return ListTile(
                              leading: CircleAvatar(child: Text(m.initials)),
                              title: Text(m.displayName),
                              subtitle: Text(m.email),
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedMemberId = m.id;
                                });
                              },
                            );
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Center(child: Text('Erro: $error')),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Seletor de cargo (função)
                  allRolesAsync.when(
                    data: (roles) {
                      if (roles.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text('Nenhum cargo cadastrado'),
                              ),
                            ],
                          ),
                        );
                      }
                      _selectedRoleId ??= roles.first.id;
                      return DropdownButtonFormField<String>(
                        initialValue: _selectedRoleId,
                        decoration: const InputDecoration(
                          labelText: 'Função (Cargo)',
                          border: OutlineInputBorder(),
                        ),
                        items: roles
                            .map(
                              (r) => DropdownMenuItem(
                                value: r.id,
                                child: Text(r.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRoleId = value;
                          });
                          _loadFunctionsForSelectedRole();
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Erro ao carregar cargos: $e'),
                  ),
                  const SizedBox(height: 16),

                  if (_selectedRoleId != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Funções no ministério',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_availableFunctions.isEmpty)
                      Text(
                        'Nenhuma função cadastrada para este cargo neste ministério',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else
                      Column(
                        children: _availableFunctions.map((f) {
                          final checked = _selectedFunctions.contains(f);
                          final cat = _functionCategory[f] ?? 'other';
                          return CheckboxListTile(
                            value: checked,
                            title: Text(f),
                            subtitle: Text(
                              cat == 'instrument'
                                  ? 'Instrumento'
                                  : cat == 'voice_role'
                                  ? 'Voz'
                                  : 'Outra',
                            ),
                            onChanged: (sel) {
                              setState(() {
                                if (sel == true) {
                                  _selectedFunctions.add(f);
                                } else {
                                  _selectedFunctions.remove(f);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 420;
                        if (narrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _newFunctionController,
                                decoration: const InputDecoration(
                                  labelText: 'Nova função',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  onPressed: () {
                                    final name = _newFunctionController.text
                                        .trim();
                                    if (name.isEmpty) return;
                                    setState(() {
                                      if (!_availableFunctions.contains(name)) {
                                        _availableFunctions.add(name);
                                        _functionCategory.putIfAbsent(
                                          name,
                                          () => 'other',
                                        );
                                      }
                                      _selectedFunctions.add(name);
                                      _newFunctionController.clear();
                                    });
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Adicionar'),
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newFunctionController,
                                decoration: const InputDecoration(
                                  labelText: 'Nova função',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: () {
                                final name = _newFunctionController.text.trim();
                                if (name.isEmpty) return;
                                setState(() {
                                  if (!_availableFunctions.contains(name)) {
                                    _availableFunctions.add(name);
                                    _functionCategory.putIfAbsent(
                                      name,
                                      () => 'other',
                                    );
                                  }
                                  _selectedFunctions.add(name);
                                  _newFunctionController.clear();
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Adicionar'),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Atribuir cargo de ministério
                  // UI simplificada: sem seleção de contexto; será criado/selecionado automaticamente

                  // Notas
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notas (opcional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Erro: $error'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _addMember,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Adicionar'),
        ),
      ],
    );
  }

  Future<void> _addMember() async {
    if (_selectedMemberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um membro'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Verificar existência do usuário em user_account antes do insert
      final userExists = await ref
          .read(membersRepositoryProvider)
          .getMemberById(_selectedMemberId!);
      if (userExists == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Usuário não encontrado no cadastro. Verifique o registro em Usuários.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Evitar erro de duplicidade: checa se já está no ministério
      final alreadyMember = await ref
          .read(ministriesRepositoryProvider)
          .membershipExists(
            ministryId: widget.ministryId,
            personId: _selectedMemberId!,
          );
      if (alreadyMember) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Este membro já está neste ministério'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final repository = ref.read(ministriesRepositoryProvider);
      String roleValue = 'member';
      if (_selectedRoleId != null) {
        try {
          final rolesRepo = ref.read(rolesRepositoryProvider);
          final chosenRole = (await rolesRepo.getRoles()).firstWhere(
            (r) => r.id == _selectedRoleId,
          );
          final name = chosenRole.name.toLowerCase();
          roleValue = name.contains('líder') || name.contains('leader')
              ? 'leader'
              : (name.contains('coordenador') || name.contains('coordinator'))
              ? 'coordinator'
              : 'member';
        } catch (_) {}
      }

      await repository.addMinistryMember({
        'ministry_id': widget.ministryId,
        'user_id': _selectedMemberId,
        'role': roleValue,
        'joined_at': DateTime.now().toIso8601String().split('T')[0],
        if (_notesController.text.isNotEmpty)
          'notes': _notesController.text.trim(),
      });

      // Atribuição automática de cargo de ministério: cria contexto se não existir
      if (_selectedRoleId != null) {
        try {
          final rolesRepo = ref.read(rolesRepositoryProvider);
          final role = (await rolesRepo.getRoles()).firstWhere(
            (r) => r.id == _selectedRoleId,
          );
          final ministry = await ref
              .read(ministriesRepositoryProvider)
              .getMinistryById(widget.ministryId);

          final contexts = await ref
              .read(roleContextsRepositoryProvider)
              .getContextsByMinistry(widget.ministryId);
          final filtered = contexts
              .where((c) => c.roleId == _selectedRoleId)
              .toList();
          String contextId;
          if (filtered.isEmpty) {
            final created = await ref
                .read(roleContextsRepositoryProvider)
                .createContext(
                  roleId: _selectedRoleId!,
                  contextName:
                      '${role.name} – ${ministry?.name ?? 'Ministério'}',
                  metadata: {
                    'ministry_id': widget.ministryId,
                    if (_availableFunctions.isNotEmpty)
                      'functions': _availableFunctions,
                  },
                );
            contextId = created.id;
          } else {
            contextId = filtered.first.id;
            final meta = Map<String, dynamic>.from(
              filtered.first.metadata ?? {},
            );
            final List<dynamic> funcs = List<dynamic>.from(
              meta['functions'] ?? [],
            );
            for (final f in _availableFunctions) {
              if (!funcs.contains(f)) funcs.add(f);
            }
            meta['functions'] = funcs;
            await ref
                .read(roleContextsRepositoryProvider)
                .updateContext(contextId: contextId, metadata: meta);
          }

          await ref
              .read(userRolesRepositoryProvider)
              .assignRoleToUser(
                userId: _selectedMemberId!,
                roleId: _selectedRoleId!,
                contextId: contextId,
                notes: 'Auto-atribuído via ministério',
              );

          // Persistir funções atribuídas por usuário no metadata do contexto
          final updatedCtx = await ref
              .read(roleContextsRepositoryProvider)
              .getContextById(contextId);
          final updatedMeta = Map<String, dynamic>.from(
            updatedCtx?.metadata ?? {},
          );
          final assigned = Map<String, dynamic>.from(
            updatedMeta['assigned_functions'] ?? {},
          );
          assigned[_selectedMemberId!] = _selectedFunctions.toList();
          updatedMeta['assigned_functions'] = assigned;
          await ref
              .read(roleContextsRepositoryProvider)
              .updateContext(contextId: contextId, metadata: updatedMeta);
        } catch (e) {
          debugPrint('Falha ao atribuir cargo de ministério: $e');
        }
      }

      // Atualizar lista após atribuir cargo para refletir imediatamente o "Cargo" no card
      ref.invalidate(ministryMembersProvider(widget.ministryId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Membro adicionado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar membro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadFunctionsForSelectedRole() async {
    if (_selectedRoleId == null) return;
    try {
      final contexts = await ref
          .read(roleContextsRepositoryProvider)
          .getContextsByMinistry(widget.ministryId);
      final filtered = contexts
          .where((c) => c.roleId == _selectedRoleId)
          .toList();
      if (filtered.isNotEmpty) {
        final meta = filtered.first.metadata ?? {};
        final List<dynamic> funcs = List<dynamic>.from(meta['functions'] ?? []);
        final catMap = Map<String, dynamic>.from(
          meta['function_category_by_function'] ?? {},
        );
        setState(() {
          _availableFunctions = funcs.map((e) => e.toString()).toList();
          _functionCategory
            ..clear()
            ..addAll(catMap.map((k, v) => MapEntry(k, v.toString())));
          _selectedFunctions.clear();
        });
      } else {
        setState(() {
          _availableFunctions = [];
          _selectedFunctions.clear();
          _functionCategory.clear();
        });
      }
    } catch (_) {
      setState(() {
        _availableFunctions = [];
        _selectedFunctions.clear();
        _functionCategory.clear();
      });
    }
  }
}

/// Lista de escalas do ministério
class _SchedulesList extends ConsumerWidget {
  final String ministryId;

  const _SchedulesList({required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(ministrySchedulesProvider(ministryId));
    final colorScheme = Theme.of(context).colorScheme;

    return schedulesAsync.when(
      data: (schedules) {
        if (schedules.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: CommunityDesign.overlayDecoration(colorScheme),
            child: Column(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 48,
                  color: colorScheme.outline.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Nenhuma escala registrada',
                  style: CommunityDesign.titleStyle(
                    context,
                  ).copyWith(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Este ministério ainda não foi escalado para nenhum evento',
                  style: CommunityDesign.metaStyle(context),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Agrupar escalas por evento
        final Map<String, List<MinistrySchedule>> schedulesByEvent = {};
        for (final schedule in schedules) {
          if (!schedulesByEvent.containsKey(schedule.eventId)) {
            schedulesByEvent[schedule.eventId] = [];
          }
          schedulesByEvent[schedule.eventId]!.add(schedule);
        }

        return Column(
          children: schedulesByEvent.entries.map((entry) {
            final eventSchedules = entry.value;
            final eventName = eventSchedules.first.eventName;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: CommunityDesign.overlayDecoration(colorScheme),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  eventName,
                  style: CommunityDesign.titleStyle(
                    context,
                  ).copyWith(fontSize: 15),
                ),
                subtitle: Text(
                  '${eventSchedules.length} ${eventSchedules.length == 1 ? 'membro escalado' : 'membros escalados'}',
                  style: CommunityDesign.metaStyle(context),
                ),
                shape: const RoundedRectangleBorder(side: BorderSide.none),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: eventSchedules.map((schedule) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.person,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(
                      schedule.memberName,
                      style: CommunityDesign.titleStyle(
                        context,
                      ).copyWith(fontSize: 14),
                    ),
                    subtitle: schedule.notes != null
                        ? Text(
                            schedule.notes!,
                            style: CommunityDesign.metaStyle(context),
                          )
                        : null,
                  );
                }).toList(),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: CommunityDesign.overlayDecoration(colorScheme),
        child: Text(
          'Erro ao carregar escalas: $error',
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}
