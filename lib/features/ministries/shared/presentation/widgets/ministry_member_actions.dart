import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../members/presentation/providers/members_provider.dart';
import '../../../../permissions/providers/permissions_providers.dart';
import '../../../domain/models/ministry.dart';
import '../../../presentation/providers/ministries_provider.dart';

/// Ações de equipe de um ministério: incluir membro, trocar a função de quem
/// já está e desvincular.
///
/// Vieram inteiras da ficha do ministério (`ministry_detail_screen.dart`),
/// onde eram privadas. Foram extraídas — sem reescrever a regra — porque a
/// aba Equipe do workspace precisa oferecer exatamente as mesmas ações: o
/// que muda entre as duas telas é a casca, não o que acontece no banco.

/// Abre o diálogo "Editar Função": troca o papel da pessoa no ministério,
/// sincroniza o cargo (RBAC) e grava as funções escolhidas.
Future<void> showMinistryEditRoleDialog({
  required BuildContext context,
  required WidgetRef ref,
  required MinistryMember member,
  required String ministryId,
}) async {
  final hasPermission = await ref.read(
    currentUserHasPermissionProvider('ministries.manage_members').future,
  );
  if (!hasPermission) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você não tem permissão para esta ação')),
      );
    }
    return;
  }
  if (!context.mounted) return;

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
                    if (selectedRoleId != null && availableFunctions.isEmpty) {
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
                                final Map<String, List<String>> assignedByUser =
                                    {};
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
                                      .getMemberFunctionsByMinistry(ministryId);
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
      bool userRoleSynced = true;
      try {
        final matchedRole = chosenRole;

        final ministry = await ref
            .read(ministriesRepositoryProvider)
            .getMinistryById(ministryId);
        final contextsRepo = ref.read(roleContextsRepositoryProvider);
        final contextsForMinistry = await contextsRepo.getContextsByMinistry(
          ministryId,
        );

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

        // Persistir funções atribuídas por usuário no metadata do contexto
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

        // Persistir em member_function (fonte para regras/geração de escala).
        // Esta é a etapa crítica — preserva a seleção de funções do membro
        // mesmo quando o vínculo com auth.users não puder ser sincronizado.
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

        // Sincronizar com user_roles (sistema de permissões).
        // user_roles.user_id referencia auth.users(id), então só funciona
        // para membros que possuem conta de acesso (auth_user_id).
        try {
          final authUserId = await _resolveAuthUserId(member.memberId);
          if (authUserId == null) {
            userRoleSynced = false;
            debugPrint(
              'Membro ${member.memberName} não possui conta de acesso '
              '(auth_user_id nulo) — sincronização com user_roles pulada.',
            );
          } else {
            for (final ctx in contextsForMinistry) {
              await ref
                  .read(userRolesRepositoryProvider)
                  .removeUserRoleByContext(
                    userId: authUserId,
                    contextId: ctx.id,
                  );
            }
            await ref
                .read(userRolesRepositoryProvider)
                .assignRoleToUser(
                  userId: authUserId,
                  roleId: matchedRole.id,
                  contextId: contextId,
                  notes: 'Atualizado via ministério',
                );
          }
        } catch (e) {
          userRoleSynced = false;
          debugPrint('Aviso: não foi possível sincronizar user_roles: $e');
        }
      } catch (e) {
        persistedOk = false;
        debugPrint('Falha ao sincronizar cargo com função: $e');
        rethrow;
      }
      ref.invalidate(ministryMembersProvider(ministryId));
      if (context.mounted && persistedOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userRoleSynced
                  ? 'Função atualizada com sucesso!'
                  : 'Função atualizada. Permissões não sincronizadas: membro sem conta de acesso.',
            ),
            backgroundColor: userRoleSynced ? Colors.green : Colors.orange,
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

/// Pergunta e, confirmado, desvincula a pessoa do ministério — removendo
/// também os cargos presos ao contexto deste ministério.
Future<void> confirmRemoveMinistryMember({
  required BuildContext context,
  required WidgetRef ref,
  required MinistryMember member,
  required String ministryId,
}) async {
  final hasPermission = await ref.read(
    currentUserHasPermissionProvider('ministries.manage_members').future,
  );
  if (!hasPermission) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você não tem permissão para esta ação')),
      );
    }
    return;
  }
  if (!context.mounted) return;

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

      // Remover cargos vinculados ao contexto deste ministério.
      // user_roles é indexada por auth.users.id, então traduzimos o
      // user_account.id do membro para o auth_user_id correspondente.
      try {
        final authUserId = await _resolveAuthUserId(member.memberId);
        if (authUserId != null) {
          final contexts = await ref
              .read(roleContextsRepositoryProvider)
              .getContextsByMinistry(ministryId);
          for (final ctx in contexts) {
            await ref
                .read(userRolesRepositoryProvider)
                .removeUserRoleByContext(userId: authUserId, contextId: ctx.id);
          }
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

/// Resolve o auth.users.id correspondente a um user_account.id.
/// Retorna null se o membro não possuir conta de acesso (auth_user_id).
/// user_roles.user_id referencia auth.users(id), então essa conversão
/// é necessária antes de gravar em user_roles para evitar FK violation.
Future<String?> _resolveAuthUserId(String userAccountId) async {
  try {
    final row = await Supabase.instance.client
        .from('user_account')
        .select('auth_user_id')
        .eq('id', userAccountId)
        .maybeSingle();
    final v = row?['auth_user_id'];
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  } catch (e) {
    debugPrint('Erro ao resolver auth_user_id de $userAccountId: $e');
    return null;
  }
}

/// Abre o diálogo de inclusão de membro no ministério.
Future<void> showAddMinistryMemberDialog({
  required BuildContext context,
  required String ministryId,
}) {
  return showDialog(
    context: context,
    builder: (context) => MinistryAddMemberDialog(ministryId: ministryId),
  );
}

/// Diálogo para adicionar membro ao ministério
class MinistryAddMemberDialog extends ConsumerStatefulWidget {
  final String ministryId;

  const MinistryAddMemberDialog({super.key, required this.ministryId});

  @override
  ConsumerState<MinistryAddMemberDialog> createState() =>
      _MinistryAddMemberDialogState();
}

class _MinistryAddMemberDialogState
    extends ConsumerState<MinistryAddMemberDialog> {
  String? _selectedMemberId;
  String? _selectedRoleId;
  List<String> _availableFunctions = [];
  final Set<String> _selectedFunctions = {};
  final Map<String, String> _functionCategory = {};
  final _newFunctionController = TextEditingController();
  final _notesController = TextEditingController();
  final _memberSearchController = TextEditingController();
  bool _isLoading = false;
  String _memberSearchQuery = '';
  // Fluxo simplificado: sempre atribui cargo de ministério automaticamente

  @override
  void dispose() {
    _newFunctionController.dispose();
    _notesController.dispose();
    _memberSearchController.dispose();
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
                    controller: _memberSearchController,
                    decoration: InputDecoration(
                      labelText: 'Buscar membro...',
                      prefixIcon: Icon(Icons.search),
                      suffixIcon: _memberSearchQuery.trim().isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _memberSearchController.clear();
                                  _memberSearchQuery = '';
                                });
                              },
                            )
                          : null,
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

          // Persistir funções atribuídas no metadata do contexto
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

          // Persistir member_function (fonte para regras/geração de escala)
          try {
            final repo = ref.read(ministriesRepositoryProvider);
            final currentMapByUser = await repo.getMemberFunctionsByMinistry(
              widget.ministryId,
            );
            final byFunc = <String, List<String>>{};
            currentMapByUser.forEach((uid, fnList) {
              for (final f in fnList) {
                byFunc.putIfAbsent(f, () => []);
                if (!byFunc[f]!.contains(uid)) byFunc[f]!.add(uid);
              }
            });
            for (final f in _availableFunctions) {
              final list = byFunc.putIfAbsent(f, () => []);
              final has = list.contains(_selectedMemberId);
              final sel = _selectedFunctions.contains(f);
              if (sel && !has) {
                list.add(_selectedMemberId!);
              } else if (!sel && has) {
                list.remove(_selectedMemberId);
              }
            }
            await repo.setMemberFunctionsByMinistry(widget.ministryId, byFunc);
          } catch (e) {
            debugPrint('Falha ao persistir member_function: $e');
          }

          // Sincronizar com user_roles — só funciona para membros com auth_user_id
          try {
            final authUserId = await _lookupAuthUserId(_selectedMemberId!);
            if (authUserId == null) {
              debugPrint(
                'Membro sem conta de acesso — sincronização com user_roles pulada.',
              );
            } else {
              await ref
                  .read(userRolesRepositoryProvider)
                  .assignRoleToUser(
                    userId: authUserId,
                    roleId: _selectedRoleId!,
                    contextId: contextId,
                    notes: 'Auto-atribuído via ministério',
                  );
            }
          } catch (e) {
            debugPrint('Aviso: não foi possível sincronizar user_roles: $e');
          }
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

  /// Resolve auth.users.id de um user_account.id — null se membro sem conta auth.
  Future<String?> _lookupAuthUserId(String userAccountId) async {
    try {
      final row = await Supabase.instance.client
          .from('user_account')
          .select('auth_user_id')
          .eq('id', userAccountId)
          .maybeSingle();
      final v = row?['auth_user_id'];
      if (v == null) return null;
      final s = v.toString();
      return s.isEmpty ? null : s;
    } catch (e) {
      debugPrint('Erro ao resolver auth_user_id de $userAccountId: $e');
      return null;
    }
  }
}
