import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access_levels/domain/models/access_level.dart';
import '../../../members/domain/models/member.dart';
import '../../../permissions/presentation/widgets/user_search_dialog.dart';
import '../../domain/models/tenant_unit.dart';
import '../providers/branches_provider.dart';

/// Diálogo para conceder cargo específico numa unidade que não é a atual
/// do chamador (CHU-301) — ex.: líder da matriz que também lidera algo
/// numa filial, sem precisar trocar de unidade primeiro.
class GrantUnitAccessDialog extends ConsumerStatefulWidget {
  const GrantUnitAccessDialog({super.key, required this.unit});

  final TenantUnit unit;

  @override
  ConsumerState<GrantUnitAccessDialog> createState() =>
      _GrantUnitAccessDialogState();
}

class _GrantUnitAccessDialogState
    extends ConsumerState<GrantUnitAccessDialog> {
  Member? _selectedUser;
  AccessLevelType _selectedLevel = AccessLevelType.leader;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Conceder Acesso em ${widget.unit.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: TextEditingController(
                text: _selectedUser == null
                    ? ''
                    : '${_selectedUser!.firstName} ${_selectedUser!.lastName}',
              ),
              decoration: InputDecoration(
                labelText: 'Usuário *',
                hintText: 'Clique para buscar um usuário',
                prefixIcon: const Icon(Icons.person_search),
                border: const OutlineInputBorder(),
                suffixIcon: _selectedUser != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _selectedUser = null),
                      )
                    : null,
              ),
              readOnly: true,
              onTap: _showUserSearchDialog,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AccessLevelType>(
              initialValue: _selectedLevel,
              decoration: const InputDecoration(
                labelText: 'Cargo *',
                prefixIcon: Icon(Icons.badge),
                border: OutlineInputBorder(),
              ),
              items: AccessLevelType.values
                  .map(
                    (level) => DropdownMenuItem(
                      value: level,
                      child: Text(level.displayName),
                    ),
                  )
                  .toList(),
              onChanged: (level) {
                if (level != null) setState(() => _selectedLevel = level);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isLoading || _selectedUser == null ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Conceder'),
        ),
      ],
    );
  }

  Future<void> _showUserSearchDialog() async {
    final selected = await showDialog<Member>(
      context: context,
      builder: (context) => const UserSearchDialog(),
    );

    if (selected != null && mounted) {
      setState(() => _selectedUser = selected);
    }
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(branchesRepositoryProvider);
      final authUserId = await repo.resolveAuthUserId(_selectedUser!.id);

      if (authUserId == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Este membro ainda não possui conta criada no Auth. Peça para ele se cadastrar.',
            ),
          ),
        );
        return;
      }

      await repo.concederAcessoEmUnidade(
        tenantId: widget.unit.tenantId,
        userId: authUserId,
        accessLevel: _selectedLevel,
      );

      if (mounted) {
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Acesso concedido em ${widget.unit.name} com sucesso!',
            ),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Erro ao conceder acesso: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
