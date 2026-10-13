import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../permissions/providers/permissions_providers.dart';
import '../../../presentation/providers/ministries_provider.dart';

/// Linha de um seletor de responsável para quem está no ministério mas não
/// abre a tela para onde o aviso leva (Diaconato 6). Não dá para escolher;
/// quem gerencia permissões ganha o atalho "Dar permissão", que abre a tela
/// de permissões da pessoa por cima e, na volta, recarrega o seletor.
class AssigneeWithoutPermissionTile extends ConsumerWidget {
  final String ministryId;
  final String permission;
  final String memberId;
  final String name;

  const AssigneeWithoutPermissionTile({
    super.key,
    required this.ministryId,
    required this.permission,
    required this.memberId,
    required this.name,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canGrant =
        ref
            .watch(currentUserHasPermissionProvider('settings.manage_permissions'))
            .valueOrNull ??
        false;

    return ListTile(
      enabled: false,
      leading: const Icon(AppIcons.lock),
      title: Text(name),
      subtitle: const Text('Sem permissão para abrir a tela do aviso'),
      trailing: canGrant
          ? TextButton(
              onPressed: () async {
                await context.push('/permissions/users/$memberId/permissions');
                ref.invalidate(
                  ministryMemberIdsWithPermissionProvider((
                    ministryId: ministryId,
                    permission: permission,
                  )),
                );
              },
              child: const Text('Dar permissão'),
            )
          : null,
    );
  }
}
