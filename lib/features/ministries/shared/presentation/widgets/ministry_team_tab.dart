import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_filter_bar.dart';
import '../../../../permissions/providers/permissions_providers.dart';
import '../../../domain/models/ministry.dart';
import '../../../presentation/providers/ministries_provider.dart';
import 'ministry_member_actions.dart';

/// Aba Equipe do workspace: quem toca o ministério — e o que dá para fazer
/// com essa lista.
///
/// Ela deixou de ser só leitura: incluir membro, alterar a função e remover
/// são as mesmas ações da ficha do ministério, agora chamadas daqui pelas
/// funções de `ministry_member_actions.dart`. Não há mais link para a
/// ficha: descrição, notificações e edição subiram para o cabeçalho do
/// workspace, então não sobrou nada lá que esta aba precise alcançar.
class MinistryTeamTab extends ConsumerStatefulWidget {
  final String ministryId;

  const MinistryTeamTab({super.key, required this.ministryId});

  @override
  ConsumerState<MinistryTeamTab> createState() => _MinistryTeamTabState();
}

class _MinistryTeamTabState extends ConsumerState<MinistryTeamTab> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<MinistryMember> _apply(List<MinistryMember> members) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return members;
    return members.where((m) {
      if (m.memberName.toLowerCase().contains(query)) return true;
      final cargo = m.cargoName?.toLowerCase() ?? '';
      if (cargo.contains(query)) return true;
      return m.role.label.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _addMember() async {
    await showAddMinistryMemberDialog(
      context: context,
      ministryId: widget.ministryId,
    );
    // O diálogo grava e fecha sem devolver resultado; invalidar aqui é o que
    // faz a pessoa recém-incluída aparecer na lista sem sair da aba.
    if (mounted) ref.invalidate(ministryMembersProvider(widget.ministryId));
  }

  Future<void> _editRole(MinistryMember member) async {
    await showMinistryEditRoleDialog(
      context: context,
      ref: ref,
      member: member,
      ministryId: widget.ministryId,
    );
  }

  Future<void> _remove(MinistryMember member) async {
    await confirmRemoveMinistryMember(
      context: context,
      ref: ref,
      member: member,
      ministryId: widget.ministryId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(ministryMembersProvider(widget.ministryId));

    // `maybeWhen` com `orElse: false` em vez de PermissionGate: enquanto a
    // permissão carrega o botão simplesmente não aparece — mesmo
    // comportamento da aba Alunos, sem esqueleto piscando na barra.
    final canManage = ref
        .watch(currentUserHasPermissionProvider('ministries.manage_members'))
        .maybeWhen(data: (v) => v, orElse: () => false);

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _TeamError(
        message: '$error',
        onRetry: () =>
            ref.invalidate(ministryMembersProvider(widget.ministryId)),
      ),
      data: (members) {
        final visible = _apply(members);
        final leaders =
            visible.where((m) => m.role != MinistryRole.member).toList()
              ..sort((a, b) => a.role.index.compareTo(b.role.index));
        final rest =
            visible.where((m) => m.role == MinistryRole.member).toList()
              ..sort((a, b) => a.memberName.compareTo(b.memberName));

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(ministryMembersProvider(widget.ministryId));
            await ref.read(ministryMembersProvider(widget.ministryId).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              AppFilterBar(
                searchController: _search,
                searchHint: 'Buscar por nome ou função...',
                onSearchChanged: (v) => setState(() => _query = v),
                primaryAction: canManage
                    ? AppFilterAction(
                        label: 'Incluir membro',
                        icon: Icons.person_add_alt,
                        onPressed: _addMember,
                      )
                    : null,
              ),
              const SizedBox(height: 14),
              if (members.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Nenhum membro vinculado a este ministério ainda.',
                    textAlign: TextAlign.center,
                    style: CommunityDesign.metaStyle(context),
                  ),
                )
              else if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Ninguém na equipe bate com essa busca.',
                    textAlign: TextAlign.center,
                    style: CommunityDesign.metaStyle(context),
                  ),
                ),
              if (leaders.isNotEmpty) ...[
                _SectionLabel('Liderança (${leaders.length})'),
                for (final m in leaders)
                  _TeamMemberTile(
                    member: m,
                    onEditRole: canManage ? () => _editRole(m) : null,
                    onRemove: canManage ? () => _remove(m) : null,
                  ),
                const SizedBox(height: 20),
              ],
              if (rest.isNotEmpty) ...[
                _SectionLabel('Membros (${rest.length})'),
                for (final m in rest)
                  _TeamMemberTile(
                    member: m,
                    onEditRole: canManage ? () => _editRole(m) : null,
                    onRemove: canManage ? () => _remove(m) : null,
                  ),
              ],
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
    final muted = dark
        ? AppTheme.darkMutedForeground
        : AppTheme.mutedForeground;

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
  final VoidCallback? onEditRole;
  final VoidCallback? onRemove;

  const _TeamMemberTile({required this.member, this.onEditRole, this.onRemove});

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

    final hasActions = onEditRole != null || onRemove != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.fromLTRB(12, 12, hasActions ? 4 : 12, 12),
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
                  style: CommunityDesign.titleStyle(
                    context,
                  ).copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: CommunityDesign.metaStyle(context)),
              ],
            ),
          ),
          if (hasActions)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              tooltip: 'Ações do membro',
              onSelected: (value) {
                if (value == 'role') onEditRole?.call();
                if (value == 'remove') onRemove?.call();
              },
              itemBuilder: (context) => [
                if (onEditRole != null)
                  const PopupMenuItem(
                    value: 'role',
                    child: Row(
                      children: [
                        Icon(Icons.badge_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Alterar função'),
                      ],
                    ),
                  ),
                if (onRemove != null)
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_remove_outlined,
                          size: 18,
                          color: Colors.red,
                        ),
                        SizedBox(width: 10),
                        Text('Remover', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
              ],
            ),
        ],
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
