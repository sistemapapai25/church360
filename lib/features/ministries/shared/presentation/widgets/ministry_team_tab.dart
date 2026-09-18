import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/models/ministry.dart';
import '../../../presentation/providers/ministries_provider.dart';

/// Aba Equipe do workspace: quem toca o ministério, em leitura.
///
/// Deliberadamente enxuta. Cadastrar membro, montar escala e editar a ficha
/// continuam na tela de detalhe do ministério — aquele arquivo tem 2087
/// linhas e as peças (`_MembersList`, `_MemberCard`, `_SchedulesList`) são
/// privadas; extraí-las seria refatorar uma tela central em produção no meio
/// da entrega do Batismo. O link do rodapé leva para lá.
class MinistryTeamTab extends ConsumerWidget {
  final String ministryId;

  const MinistryTeamTab({super.key, required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(ministryMembersProvider(ministryId));

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _TeamError(
        message: '$error',
        onRetry: () => ref.invalidate(ministryMembersProvider(ministryId)),
      ),
      data: (members) {
        final leaders =
            members.where((m) => m.role != MinistryRole.member).toList()
              ..sort((a, b) => a.role.index.compareTo(b.role.index));
        final rest =
            members.where((m) => m.role == MinistryRole.member).toList()
              ..sort((a, b) => a.memberName.compareTo(b.memberName));

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(ministryMembersProvider(ministryId));
            await ref.read(ministryMembersProvider(ministryId).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              if (members.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Nenhum membro vinculado a este ministério ainda.',
                    textAlign: TextAlign.center,
                    style: CommunityDesign.metaStyle(context),
                  ),
                ),
              if (leaders.isNotEmpty) ...[
                _SectionLabel('Liderança (${leaders.length})'),
                for (final m in leaders) _TeamMemberTile(member: m),
                const SizedBox(height: 20),
              ],
              if (rest.isNotEmpty) ...[
                _SectionLabel('Membros (${rest.length})'),
                for (final m in rest) _TeamMemberTile(member: m),
              ],
              const SizedBox(height: 24),
              _OpenMinistrySheetLink(ministryId: ministryId),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted =
        dark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: muted,
        ),
      ),
    );
  }
}

class _TeamMemberTile extends StatelessWidget {
  final MinistryMember member;

  const _TeamMemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = dark ? AppTheme.darkBorder : AppTheme.border;
    final accent = dark ? AppTheme.darkRing : AppTheme.primary;

    final name = member.memberName.trim();
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();

    // `cargoName` é o cargo da pessoa na igreja; `role` é o papel dela
    // dentro deste ministério. Quando os dois existem, os dois aparecem.
    final cargo = member.cargoName;
    final subtitle = (cargo == null || cargo.isEmpty)
        ? member.role.label
        : '${member.role.label} · $cargo';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CommunityDesign.cardSurfaceColor(colorScheme),
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Sem nome' : name,
                  style: CommunityDesign.titleStyle(context).copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: CommunityDesign.metaStyle(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenMinistrySheetLink extends StatelessWidget {
  final String ministryId;

  const _OpenMinistrySheetLink({required this.ministryId});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppTheme.darkRing : AppTheme.primary;

    return InkWell(
      onTap: () => context.push('/ministries/$ministryId'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.badge_outlined, size: 20, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Abrir ficha completa do ministério',
                    style: CommunityDesign.titleStyle(context).copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Cadastrar membro, escala, notificações e edição.',
                    style: CommunityDesign.metaStyle(context),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: accent),
          ],
        ),
      ),
    );
  }
}

class _TeamError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _TeamError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar a equipe.',
              textAlign: TextAlign.center,
              style: CommunityDesign.titleStyle(context).copyWith(fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: CommunityDesign.metaStyle(context),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Tentar de novo')),
          ],
        ),
      ),
    );
  }
}
