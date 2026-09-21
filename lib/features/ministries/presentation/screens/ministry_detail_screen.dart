import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/ministries_provider.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../domain/models/ministry.dart';
import '../../../../core/design/community_design.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';
import '../../notifications/presentation/screens/ministry_notification_config_screen.dart';
import '../../shared/presentation/widgets/ministry_member_actions.dart';
import '../../../../core/design/app_icons.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';

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

        final canManageAllAsync = ref.watch(
          currentUserHasPermissionProvider('ministries.edit'),
        );
        final membershipAsync = ref.watch(currentMemberMinistriesProvider);

        return canManageAllAsync.when(
          data: (canManageAll) {
            if (canManageAll) {
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
                          Icon(AppIcons.lock, size: 48, color: Colors.red),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              padding: const EdgeInsets.all(20),
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
                    child: Icon(AppIcons.church, color: color, size: 44),
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
                      StatusBadge(
                        label: ministry.isActive ? 'Ativo' : 'Inativo',
                        tone: ministry.isActive
                            ? AppStatusTone.active
                            : AppStatusTone.dropped,
                        icon: ministry.isActive
                            ? AppIcons.checkCircle
                            : AppIcons.cancel,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Atalho para o submódulo especializado do ministério (Raízes, Diaconato).
          // Aparece apenas para tipos com tela própria (Lote 4A do roadmap Ministérios).
          if (ministry.specializedRoute() != null) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SpecializedModuleCta(ministry: ministry, color: color),
            ),
          ],

          // Lote 11.5 — atalho pra config de notificações in-app de mudanças
          // na agenda. Só aparece pra quem tem permissão de editar o ministério.
          const SizedBox(height: 20),
          PermissionBuilder(
            permission: 'ministries.edit',
            builder: (context, hasPermission) {
              if (!hasPermission) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GlassCard(
                  child: ListTile(
                    leading: const Icon(AppIcons.notificationsActive),
                    title: const Text('Notificações de mudança'),
                    subtitle: const Text(
                      'Quem é avisado quando algo muda na agenda do ministério',
                    ),
                    trailing: const Icon(AppIcons.forward),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MinistryNotificationConfigScreen(
                            ministryId: ministry.id,
                            ministryName: ministry.name,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
            loadingWidget: const SizedBox.shrink(),
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
                PermissionBuilder(
                  permission: 'ministries.manage_members',
                  builder: (context, hasPermission) {
                    if (!hasPermission) return const SizedBox.shrink();
                    return ElevatedButton.icon(
                      onPressed: () => _showAddMemberDialog(context, ref),
                      icon: const Icon(AppIcons.add, size: 18),
                      label: const Text('Adicionar'),
                      style: CommunityDesign.pillButtonStyle(
                        context,
                        colorScheme.primary,
                        compact: true,
                      ),
                    );
                  },
                  loadingWidget: const SizedBox.shrink(),
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
                    PermissionBuilder(
                      permission: 'ministries.manage_schedule',
                      builder: (context, hasPermission) {
                        if (!hasPermission) return const SizedBox.shrink();
                        return IconButton(
                          onPressed: () => context.push(
                            '/ministries/${ministry.id}/scale-history',
                          ),
                          icon: const Icon(AppIcons.history),
                          tooltip: 'Abrir Histórico',
                        );
                      },
                      loadingWidget: const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 8),
                    PermissionBuilder(
                      permission: 'ministries.manage_schedule',
                      builder: (context, hasPermission) {
                        if (!hasPermission) return const SizedBox.shrink();
                        return ElevatedButton.icon(
                          onPressed: () => context.push(
                            '/ministries/${ministry.id}/auto-scheduler',
                          ),
                          icon: const Icon(AppIcons.autoSchedule, size: 18),
                          label: const Text('Gerar'),
                          style: CommunityDesign.pillButtonStyle(
                            context,
                            colorScheme.primary,
                            compact: true,
                          ),
                        );
                      },
                      loadingWidget: const SizedBox.shrink(),
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
      decoration: CommunityDesign.overlayDecoration(
        Theme.of(context).colorScheme,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(AppIcons.back),
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
          Row(
            children: [
              PermissionBuilder(
                permission: 'ministries.edit',
                builder: (context, hasPermission) {
                  if (!hasPermission) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(AppIcons.edit),
                    onPressed: () =>
                        context.push('/ministries/${ministry.id}/edit'),
                    tooltip: 'Editar Ministério',
                  );
                },
                loadingWidget: const SizedBox.shrink(),
              ),
              PermissionBuilder(
                permission: 'ministries.delete',
                builder: (context, hasPermission) {
                  if (!hasPermission) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(AppIcons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(context, ref),
                    tooltip: 'Deletar Ministério',
                  );
                },
                loadingWidget: const SizedBox.shrink(),
              ),
            ],
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
      builder: (context) => MinistryAddMemberDialog(ministryId: ministry.id),
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
          return SizedBox(
            width: double.infinity,
            child: GlassCard(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(
                    AppIcons.groupsFilled,
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
    final roleColor = _getRoleColor(member.role);
    final memberAsync = ref.watch(memberByIdProvider(member.memberId));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
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
            child: memberAsync.when(
              data: (m) {
                final rawUrl = m?.photoUrl;
                String? resolvedUrl;
                if (rawUrl != null && rawUrl.trim().isNotEmpty) {
                  final parsed = Uri.tryParse(rawUrl.trim());
                  if (parsed != null && parsed.hasScheme) {
                    resolvedUrl = rawUrl.trim();
                  } else {
                    resolvedUrl = Supabase.instance.client.storage
                        .from('member-photos')
                        .getPublicUrl(rawUrl.trim());
                  }
                }

                if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
                  return ClipOval(
                    child: Image.network(
                      resolvedUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          _getRoleIcon(member.role),
                          color: roleColor,
                          size: 24,
                        );
                      },
                    ),
                  );
                }

                return Icon(
                  _getRoleIcon(member.role),
                  color: roleColor,
                  size: 24,
                );
              },
              loading: () =>
                  Icon(_getRoleIcon(member.role), color: roleColor, size: 24),
              error: (error, stackTrace) =>
                  Icon(_getRoleIcon(member.role), color: roleColor, size: 24),
            ),
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
          trailing: PermissionBuilder(
            permission: 'ministries.manage_members',
            builder: (context, hasPermission) {
              if (!hasPermission) return const SizedBox.shrink();
              return PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Row(
                      children: [
                        Icon(AppIcons.edit),
                        SizedBox(width: 8),
                        Text('Editar Função'),
                      ],
                    ),
                    onTap: () {
                      Future.microtask(() {
                        if (!context.mounted) return;
                        showMinistryEditRoleDialog(
                          context: context,
                          ref: ref,
                          member: member,
                          ministryId: ministryId,
                        );
                      });
                    },
                  ),
                  PopupMenuItem(
                    child: const Row(
                      children: [
                        Icon(AppIcons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Remover', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                    onTap: () {
                      Future.microtask(() {
                        if (!context.mounted) return;
                        confirmRemoveMinistryMember(
                          context: context,
                          ref: ref,
                          member: member,
                          ministryId: ministryId,
                        );
                      });
                    },
                  ),
                ],
              );
            },
            loadingWidget: const SizedBox.shrink(),
          ),
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
        return AppIcons.security;
      case MinistryRole.coordinator:
        return AppIcons.supervisor;
      case MinistryRole.member:
        return AppIcons.personFilled;
    }
  }

  String _getRoleLabel(MinistryRole role) {
    return role.label;
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
          return SizedBox(
            width: double.infinity,
            child: GlassCard(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(
                    AppIcons.calendarFilled,
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

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
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
                      AppIcons.eventFilled,
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          AppIcons.personFilled,
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
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => GlassCard(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Erro ao carregar escalas: $error',
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}

/// CTA que abre o submódulo especializado do ministério (Raízes, Diaconato, ...).
/// Renderizado apenas quando `ministry.specializedRoute()` é não-nulo.
class _SpecializedModuleCta extends StatelessWidget {
  final Ministry ministry;
  final Color color;

  const _SpecializedModuleCta({required this.ministry, required this.color});

  @override
  Widget build(BuildContext context) {
    final route = ministry.specializedRoute();
    if (route == null) return const SizedBox.shrink();

    final (label, description, icon) = _copyFor(ministry.ministryType);

    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(16),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        accentColor: color,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: CommunityDesign.titleStyle(
                      context,
                    ).copyWith(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(description, style: CommunityDesign.metaStyle(context)),
                ],
              ),
            ),
            Icon(AppIcons.forward, color: color),
          ],
        ),
      ),
    );
  }

  (String, String, IconData) _copyFor(MinistryType type) {
    switch (type) {
      case MinistryType.raizes:
        return (
          'Abrir módulo Raízes',
          'Dashboard de visitantes, novas decisões e demandas de contato.',
          AppIcons.volunteer,
        );
      case MinistryType.diaconato:
        return (
          'Abrir módulo Diaconato',
          'Checklist de presença, ausentes e entregas de ceia.',
          AppIcons.volunteer,
        );
      case MinistryType.batismo:
        return (
          'Abrir módulo Batismo',
          'Equipe, alunos, turmas, presença e o caixa do ministério.',
          AppIcons.water,
        );
      case MinistryType.generic:
      case MinistryType.kids:
      case MinistryType.louvor:
      case MinistryType.midia:
        return (
          'Abrir módulo',
          'Tela especializada deste ministério.',
          AppIcons.dashboard,
        );
    }
  }
}
