import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/members_provider.dart';
import 'member_profile_screen.dart';
import '../../../../core/design/community_design.dart';

/// Tela de Perfil do Usuário (Meu Perfil)
///
/// Esta tela agora padroniza a visualização utilizando o [MemberProfileScreen]
/// quando o membro é encontrado. Caso contrário, exibe a tela de onboarding.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberAsync = ref.watch(currentMemberProvider);
    final currentUser = ref.watch(currentUserProvider);
    final resolvedEmailAsync = ref.watch(resolvedUserEmailProvider);

    return memberAsync.when(
      data: (member) {
        if (member == null) {
          // Se não encontrou o membro, exibe tela de "Perfil não encontrado" (Onboarding)
          final email = resolvedEmailAsync.maybeWhen(
            data: (v) => v,
            orElse: () => currentUser?.email,
          );
          return _buildProfileNotFound(context, email);
        }

        // Se encontrou, reutiliza a tela padrão de perfil de membro
        return MemberProfileScreen(memberId: member.id, title: 'Meu Perfil');
      },
      loading: () => Scaffold(
        backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
        appBar: AppBar(
          title: const Text('Meu Perfil'),
          backgroundColor: CommunityDesign.headerColor(context),
          elevation: 0,
          scrolledUnderElevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          titleTextStyle: CommunityDesign.titleStyle(
            context,
          ).copyWith(fontSize: 20, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(
            color: CommunityDesign.titleStyle(context).color,
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Erro ao carregar perfil',
                style: CommunityDesign.titleStyle(
                  context,
                ).copyWith(fontSize: 22),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: CommunityDesign.metaStyle(context),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tela quando o perfil não é encontrado
  Widget _buildProfileNotFound(BuildContext context, String? userEmail) {
    return Scaffold(
      backgroundColor: CommunityDesign.backgroundColor,
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: CommunityDesign.titleStyle(
          context,
        ).copyWith(fontSize: 20, fontWeight: FontWeight.bold),
        iconTheme: IconThemeData(
          color: CommunityDesign.titleStyle(context).color,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: CommunityDesign.overlayPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 24),
              Text(
                'Perfil não encontrado',
                style: CommunityDesign.titleStyle(
                  context,
                ).copyWith(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Não encontramos um perfil de membro vinculado à sua conta.',
                style: CommunityDesign.contentStyle(context),
                textAlign: TextAlign.center,
              ),
              if (userEmail != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.email, size: 16, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          userEmail,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              // Botão para criar perfil
              ElevatedButton.icon(
                onPressed: () {
                  context.push('/members/new', extra: {'userEmail': userEmail});
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Criar Meu Perfil'),
                style: CommunityDesign.pillButtonStyle(
                  context,
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text('ou', style: CommunityDesign.metaStyle(context)),
              const SizedBox(height: 16),
              Container(
                decoration: CommunityDesign.overlayDecoration(
                  Theme.of(context).colorScheme,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Como resolver?',
                          style: CommunityDesign.titleStyle(
                            context,
                          ).copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInstructionStep(
                      context,
                      '1',
                      'Entre em contato com a administração da igreja',
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionStep(
                      context,
                      '2',
                      'Informe seu email de login: ${userEmail ?? "não disponível"}',
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionStep(
                      context,
                      '3',
                      'Solicite a criação do seu perfil de membro',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Voltar'),
                style: CommunityDesign.pillButtonStyle(
                  context,
                  Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Passo de instrução
  Widget _buildInstructionStep(
    BuildContext context,
    String number,
    String text,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: CommunityDesign.contentStyle(context)),
        ),
      ],
    );
  }
}
