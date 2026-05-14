import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../permissions/providers/permissions_providers.dart';
import '../../../presentation/providers/ministries_provider.dart';

/// Guard usado por telas de submódulos especializados de um ministério
/// (Raízes, Diaconato, ...). Bloqueia o acesso quando o usuário não tem
/// vínculo ativo no ministério E não tem permissão administrativa global.
///
/// Regra de acesso (qualquer um libera):
/// - `ministriesCanSeeAllProvider == true` (admin / ministries.view_all /
///   ministries.manage / ministries.create|edit|delete); OU
/// - vínculo ativo no ministério (`ministryAccessProvider`) E a permissão
///   específica do submódulo (ex.: `raizes.view`, `diaconato.view`).
class MinistrySubmoduleGuard extends ConsumerWidget {
  final String ministryId;
  final String requiredPermission;
  final String submoduleLabel;
  final WidgetBuilder builder;

  const MinistrySubmoduleGuard({
    super.key,
    required this.ministryId,
    required this.requiredPermission,
    required this.submoduleLabel,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSeeAllAsync = ref.watch(ministriesCanSeeAllProvider);
    final accessAsync = ref.watch(ministryAccessProvider(ministryId));
    final permissionAsync = ref.watch(
      currentUserHasPermissionProvider(requiredPermission),
    );

    final loading = canSeeAllAsync.isLoading ||
        accessAsync.isLoading ||
        permissionAsync.isLoading;
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final hasError = canSeeAllAsync.hasError ||
        accessAsync.hasError ||
        permissionAsync.hasError;
    if (hasError) {
      return _BlockedScreen(
        submoduleLabel: submoduleLabel,
        message:
            'Não foi possível verificar suas permissões. Tente novamente em instantes.',
      );
    }

    final canSeeAll = canSeeAllAsync.value ?? false;
    final hasAccess = accessAsync.value ?? false;
    final hasPermission = permissionAsync.value ?? false;

    final allowed = canSeeAll || (hasAccess && hasPermission);
    if (!allowed) {
      return _BlockedScreen(
        submoduleLabel: submoduleLabel,
        message:
            'Você não tem permissão para acessar o $submoduleLabel deste ministério.',
      );
    }

    return builder(context);
  }
}

class _BlockedScreen extends StatelessWidget {
  final String submoduleLabel;
  final String message;

  const _BlockedScreen({
    required this.submoduleLabel,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: Text(submoduleLabel),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 56),
              const SizedBox(height: 16),
              Text(
                'Acesso restrito',
                style: CommunityDesign.titleStyle(context),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: CommunityDesign.metaStyle(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
