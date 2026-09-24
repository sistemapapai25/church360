import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../permissions/providers/permissions_providers.dart';
import '../../../presentation/providers/ministries_provider.dart';

/// Guard das telas de um ministério — do workspace base e dos submódulos
/// especializados (Batismo, Raízes, Diaconato, ...).
///
/// A régua tem dois degraus, e é deliberado que sejam dois:
///
/// 1. **Escopo do ministério** — *esta pessoa pode entrar aqui?* Libera quem
///    tem visão global (`ministriesCanSeeAllProvider`: `ministries.view_all`,
///    `ministries.manage`, `create`, `edit` ou `delete`) **ou** vínculo ativo
///    no ministério. É o `ministryAccessProvider`.
/// 2. **Capacidade interna** — *o que ela pode abrir aqui dentro?* É a
///    [requiredPermission] do submódulo (`baptism.view`, `raizes.view`, ...).
///
/// Passar [requiredPermission] como `null` fica só no primeiro degrau: é o
/// caso do workspace base, que qualquer pessoa vinculada abre. Cada aba lá
/// dentro continua com o gate dela — o Financeiro é o exemplo, que exige
/// vínculo **e** `ministry_finance.view` por conta própria.
///
/// Vínculo dá escopo local, papel pastoral dá escopo global, permissão dá
/// capacidade interna. Entrar no workspace não autoriza nada do que existe
/// dentro dele.
class MinistrySubmoduleGuard extends ConsumerWidget {
  final String ministryId;

  /// Permissão do submódulo. `null` = workspace base: basta o escopo.
  final String? requiredPermission;

  final String submoduleLabel;
  final WidgetBuilder builder;

  const MinistrySubmoduleGuard({
    super.key,
    required this.ministryId,
    this.requiredPermission,
    required this.submoduleLabel,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSeeAllAsync = ref.watch(ministriesCanSeeAllProvider);
    final accessAsync = ref.watch(ministryAccessProvider(ministryId));
    // Sem submódulo não há segunda pergunta a fazer: o workspace base abre
    // no escopo. `AsyncValue.data(true)` mantém o resto do build igual.
    final permissionAsync = requiredPermission == null
        ? const AsyncValue<bool>.data(true)
        : ref.watch(currentUserHasPermissionProvider(requiredPermission!));

    final loading =
        canSeeAllAsync.isLoading ||
        accessAsync.isLoading ||
        permissionAsync.isLoading;
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final hasError =
        canSeeAllAsync.hasError ||
        accessAsync.hasError ||
        permissionAsync.hasError;
    if (hasError) {
      return _BlockedScreen(
        ministryId: ministryId,
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
      // Quem já está no workspace base não tem para onde ser mandado: a
      // saída abaixo aponta justamente para ele. Sem isto, o botão viraria
      // um vai-e-volta entre duas telas bloqueadas.
      final isBaseWorkspace = requiredPermission == null;
      return _BlockedScreen(
        ministryId: ministryId,
        submoduleLabel: submoduleLabel,
        showWorkspaceExit: !isBaseWorkspace,
        message: isBaseWorkspace
            ? 'Este ministério é aberto para quem faz parte dele. Peça a '
                  'alguém da liderança para incluir você na equipe.'
            : 'Você não tem permissão para acessar o $submoduleLabel deste ministério.',
      );
    }

    return builder(context);
  }
}

class _BlockedScreen extends StatelessWidget {
  final String ministryId;
  final String submoduleLabel;
  final String message;

  /// Mostra a saída para o workspace base do ministério. Falso quando o
  /// próprio workspace base é quem está bloqueando.
  final bool showWorkspaceExit;

  const _BlockedScreen({
    required this.ministryId,
    required this.submoduleLabel,
    required this.message,
    this.showWorkspaceExit = true,
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
              const SizedBox(height: 20),
              // Desde que o card do ministério passou a abrir o módulo
              // direto, esta tela virou o fim da linha para quem está
              // vinculado mas ainda não tem a permissão do submódulo. Sem
              // esta saída, essas pessoas perderiam o acesso que tinham
              // antes — hoje ela leva ao workspace base, que abre no
              // vínculo (a ficha antiga não existe mais).
              if (showWorkspaceExit)
                TextButton.icon(
                  onPressed: () =>
                      context.pushReplacement('/ministries/$ministryId'),
                  icon: const Icon(Icons.badge_outlined, size: 18),
                  label: const Text('Abrir ministério'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
