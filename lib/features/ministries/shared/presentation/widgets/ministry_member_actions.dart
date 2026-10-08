import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../members/presentation/providers/members_provider.dart';
import '../../../../members/presentation/widgets/send_access_invite.dart';
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
  bool functionsRequested = false;

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
                      // Sem correspondência, nada marcado: cair no 1º cargo
                      // da lista dava um cargo RBAC que ninguém escolheu.
                      selectedRoleId = preferredId;
                    }
                    // A lista é do ministério, não do cargo: carrega uma vez,
                    // mesmo sem cargo escolhido.
                    if (!functionsRequested) {
                      functionsRequested = true;
                      _loadMinistryFunctions(
                        ref,
                        ministryId,
                        member.memberId,
                      ).then((r) {
                        if (!context.mounted) return;
                        setState(() {
                          for (final f in r.functions) {
                            if (!availableFunctions.contains(f)) {
                              availableFunctions.add(f);
                            }
                          }
                          functionCategory = r.categories;
                          selectedFunctions.addAll(r.mine);
                        });
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
                            onChanged: (value) =>
                                setState(() => selectedRoleId = value),
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
                              'Nenhuma função cadastrada neste ministério. '
                              'Crie abaixo.',
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          else
                            Column(
                              children: availableFunctions.map((f) {
                                final checked = selectedFunctions.contains(f);
                                final cat = functionCategory[f];
                                return CheckboxListTile(
                                  value: checked,
                                  title: Text(f),
                                  subtitle: cat == null
                                      ? null
                                      : Text(
                                          cat == 'instrument'
                                              ? 'Instrumento'
                                              : cat == 'voice_role'
                                              ? 'Back'
                                              : cat == 'other'
                                              ? 'Outra'
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
                          _NewFunctionField(
                            onAdd: (name) => setState(() {
                              if (!availableFunctions.contains(name)) {
                                availableFunctions.add(name);
                              }
                              selectedFunctions.add(name);
                            }),
                          ),
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

  if (confirmed != true || !context.mounted) return;

  // Funções primeiro e com ou sem cargo: são do ministério, não do cargo.
  try {
    await _saveMemberFunctions(
      ref: ref,
      ministryId: ministryId,
      memberId: member.memberId,
      available: availableFunctions,
      selected: selectedFunctions,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar funções: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return;
  }
  if (selectedRoleId == null) {
    ref.invalidate(ministryMembersProvider(ministryId));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Funções atualizadas com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    }
    return;
  }

  if (context.mounted) {
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
            // Sem login o cargo não vale no RBAC: oferece o convite. Depois
            // que o acesso sai a ficha já tem login, e salvar o cargo de
            // novo grava em user_roles.
            action: userRoleSynced
                ? null
                : SnackBarAction(
                    label: 'Enviar acesso',
                    textColor: Colors.white,
                    onPressed: () => sendAccessInvite(
                      context,
                      userAccountId: member.memberId,
                      memberName: member.memberName,
                    ),
                  ),
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

/// Funções do ministério: a união da lista de todos os cargos (role_context)
/// e do que já está em member_function. Não depende do cargo escolhido —
/// a lista é do ministério. [memberId] traz o que a pessoa já tem.
Future<
  ({List<String> functions, Map<String, String> categories, Set<String> mine})
>
_loadMinistryFunctions(
  WidgetRef ref,
  String ministryId,
  String? memberId,
) async {
  final contexts = await ref
      .read(roleContextsRepositoryProvider)
      .getContextsByMinistry(ministryId);
  final funcs = <String>{};
  final categories = <String, String>{};
  final mine = <String>{};
  for (final c in contexts) {
    final meta = c.metadata ?? {};
    for (final f in List<dynamic>.from(meta['functions'] ?? const [])) {
      funcs.add(f.toString());
    }
    Map<String, dynamic>.from(
      meta['function_category_by_function'] ?? {},
    ).forEach((k, v) => categories[k] = v.toString());
    final assigned = Map<String, dynamic>.from(
      meta['assigned_functions'] ?? {},
    );
    for (final f in List<dynamic>.from(assigned[memberId] ?? const [])) {
      mine.add(f.toString());
    }
  }
  try {
    final byUser = await ref
        .read(ministriesRepositoryProvider)
        .getMemberFunctionsByMinistry(ministryId);
    for (final list in byUser.values) {
      funcs.addAll(list);
    }
    mine.addAll(byUser[memberId] ?? const []);
  } catch (_) {}
  return (functions: funcs.toList(), categories: categories, mine: mine);
}

/// Grava as funções da pessoa no ministério:
/// - nome novo entra na lista de todos os cargos do ministério;
/// - assigned_functions fica igual em todos os cargos que já tinham a pessoa
///   (a leitura junta todos, então um cargo velho fazia a função desmarcada
///   voltar);
/// - member_function, que o gerador de escala usa, é regravada.
Future<void> _saveMemberFunctions({
  required WidgetRef ref,
  required String ministryId,
  required String memberId,
  required List<String> available,
  required Set<String> selected,
}) async {
  final contextsRepo = ref.read(roleContextsRepositoryProvider);
  for (final c in await contextsRepo.getContextsByMinistry(ministryId)) {
    final meta = Map<String, dynamic>.from(c.metadata ?? {});
    final funcs = List<dynamic>.from(
      meta['functions'] ?? const [],
    ).map((e) => e.toString()).toList();
    final added = available.where((f) => !funcs.contains(f)).toList();
    final assigned = Map<String, dynamic>.from(
      meta['assigned_functions'] ?? {},
    );
    final hasMember = assigned.containsKey(memberId);
    if (added.isEmpty && !hasMember) continue;
    meta['functions'] = [...funcs, ...added];
    if (hasMember) {
      assigned[memberId] = selected.toList();
      meta['assigned_functions'] = assigned;
    }
    await contextsRepo.updateContext(contextId: c.id, metadata: meta);
  }

  final repository = ref.read(ministriesRepositoryProvider);
  final byFunc = <String, List<String>>{};
  (await repository.getMemberFunctionsByMinistry(ministryId)).forEach((
    uid,
    fnList,
  ) {
    for (final f in fnList) {
      final list = byFunc.putIfAbsent(f, () => []);
      if (!list.contains(uid)) list.add(uid);
    }
  });
  for (final f in available) {
    final list = byFunc.putIfAbsent(f, () => []);
    list.remove(memberId);
    if (selected.contains(f)) list.add(memberId);
  }
  await repository.setMemberFunctionsByMinistry(ministryId, byFunc);
}

/// Campo "Nova função" + botão: devolve o nome digitado para quem chamou
/// incluir na lista (já marcado).
class _NewFunctionField extends StatefulWidget {
  final ValueChanged<String> onAdd;

  const _NewFunctionField({required this.onAdd});

  @override
  State<_NewFunctionField> createState() => _NewFunctionFieldState();
}

class _NewFunctionFieldState extends State<_NewFunctionField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    widget.onAdd(name);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Nova função',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _add(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Adicionar função',
          onPressed: _add,
          icon: const Icon(Icons.add),
        ),
      ],
    );
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
  final List<String> _availableFunctions = [];
  final Set<String> _selectedFunctions = {};
  final Map<String, String> _functionCategory = {};
  final _notesController = TextEditingController();
  final _memberSearchController = TextEditingController();
  bool _isLoading = false;
  String _memberSearchQuery = '';
  // Fluxo simplificado: sempre atribui cargo de ministério automaticamente

  @override
  void initState() {
    super.initState();
    _loadMinistryFunctions(ref, widget.ministryId, null).then((r) {
      if (!mounted) return;
      setState(() {
        for (final f in r.functions) {
          if (!_availableFunctions.contains(f)) _availableFunctions.add(f);
        }
        _functionCategory.addAll(r.categories);
      });
    });
  }

  @override
  void dispose() {
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
                      // Sem pré-seleção: o cargo é RBAC da igreja inteira e
                      // vai para user_roles. Vir com o 1º cargo marcado dava
                      // esse cargo a todo membro incluído sem ninguém escolher.
                      return DropdownButtonFormField<String>(
                        initialValue: _selectedRoleId,
                        decoration: const InputDecoration(
                          labelText: 'Função (Cargo)',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Sem cargo'),
                          ),
                          ...roles.map(
                            (r) => DropdownMenuItem(
                              value: r.id,
                              child: Text(r.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedRoleId = value;
                          });
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Erro ao carregar cargos: $e'),
                  ),
                  const SizedBox(height: 16),

                  // Funções são do ministério, não do cargo: aparecem sempre.
                  ...[
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
                        'Nenhuma função cadastrada neste ministério. '
                        'Crie abaixo.',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else
                      Column(
                        children: _availableFunctions.map((f) {
                          final checked = _selectedFunctions.contains(f);
                          final cat = _functionCategory[f];
                          return CheckboxListTile(
                            value: checked,
                            title: Text(f),
                            subtitle: cat == null
                                ? null
                                : Text(
                                    cat == 'instrument'
                                        ? 'Instrumento'
                                        : cat == 'voice_role'
                                        ? 'Voz'
                                        : cat == 'other'
                                        ? 'Outra'
                                        : cat,
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
                    _NewFunctionField(
                      onAdd: (name) => setState(() {
                        if (!_availableFunctions.contains(name)) {
                          _availableFunctions.add(name);
                        }
                        _selectedFunctions.add(name);
                      }),
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
      String? avisoCargo;
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
            avisoCargo = 'o cargo não foi atribuído';
          }
        } catch (e) {
          debugPrint('Falha ao atribuir cargo de ministério: $e');
          avisoCargo = 'o cargo não foi atribuído';
        }
      }

      // Funções com ou sem cargo: são do ministério, não do cargo.
      try {
        await _saveMemberFunctions(
          ref: ref,
          ministryId: widget.ministryId,
          memberId: _selectedMemberId!,
          available: _availableFunctions,
          selected: _selectedFunctions,
        );
      } catch (e) {
        debugPrint('Falha ao persistir funções: $e');
        avisoCargo = 'as funções não foram salvas';
      }

      // Atualizar lista após atribuir cargo para refletir imediatamente o "Cargo" no card
      ref.invalidate(ministryMembersProvider(widget.ministryId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              avisoCargo == null
                  ? 'Membro adicionado com sucesso!'
                  : 'Membro adicionado, mas $avisoCargo. Tente pela edição do membro.',
            ),
            backgroundColor: avisoCargo == null ? Colors.green : Colors.orange,
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
