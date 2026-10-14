import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/app_tabs.dart';
import '../providers/worship_provider.dart';
import '../../domain/models/worship_service.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../members/domain/models/member.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';

/// Tela de presença/check-in de um culto
class WorshipAttendanceScreen extends ConsumerStatefulWidget {
  final String worshipServiceId;

  const WorshipAttendanceScreen({
    super.key,
    required this.worshipServiceId,
  });

  @override
  ConsumerState<WorshipAttendanceScreen> createState() =>
      _WorshipAttendanceScreenState();
}

class _WorshipAttendanceScreenState
    extends ConsumerState<WorshipAttendanceScreen> {
  String _searchQuery = '';
  bool _showOnlyPresent = false;
  final _searchController = TextEditingController();

  /// 0 = Lista (check-in à mão), 1 = Pelo celular (quem chegou pelo GPS).
  int _tab = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(worshipAttendanceProvider(widget.worshipServiceId));
    ref.invalidate(worshipServiceByIdProvider(widget.worshipServiceId));
    ref.invalidate(allWorshipServicesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final serviceAsync = ref.watch(worshipServiceByIdProvider(widget.worshipServiceId));
    final attendanceAsync = ref.watch(worshipAttendanceProvider(widget.worshipServiceId));
    // Regra do check-in (Cultos A6): membros ativos + visitantes. Inativo fica
    // de fora porque não frequenta mais.
    final activeAsync = ref.watch(activeMembersProvider);
    final visitorsAsync = ref.watch(visitorsProvider);
    final AsyncValue<List<Member>> membersAsync = activeAsync.when(
      data: (active) => visitorsAsync.whenData((visitors) => [...active, ...visitors]),
      loading: () => const AsyncValue.loading(),
      error: AsyncValue.error,
    );

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: Text(
          'Check-in',
          style: CommunityDesign.titleStyle(context),
        ),
        actions: [
          IconButton(
            icon: Icon(_showOnlyPresent ? Icons.filter_alt : Icons.filter_alt_outlined),
            onPressed: () {
              setState(() {
                _showOnlyPresent = !_showOnlyPresent;
              });
            },
            tooltip: _showOnlyPresent ? 'Mostrar todos' : 'Mostrar apenas presentes',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header com informações do culto
          serviceAsync.when(
            data: (service) {
              if (service == null) {
                return const SizedBox.shrink();
              }

              final formattedDate = '${service.serviceDate.day.toString().padLeft(2, '0')}/${service.serviceDate.month.toString().padLeft(2, '0')}/${service.serviceDate.year}';

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.serviceType.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (service.theme != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        service.theme!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.groups, size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          '${service.totalAttendance} presente${service.totalAttendance != 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    // Reações da tela /presenca ("O que está achando do culto?").
                    if (_reactionSummary(attendanceAsync.valueOrNull) case final summary?) ...[
                      const SizedBox(height: 8),
                      Text(
                        'O que estão achando: $summary',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ],
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Lista (à mão) / Pelo celular (A4: quem chegou pelo GPS, para
          // validar ou recusar). O GPS dentro de prédio oscila e nunca
          // decide sozinho.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: AppTabs(
              tabs: [
                const AppTab(label: 'Lista'),
                AppTab(
                  label: 'Pelo celular',
                  count: switch (_geoCount(attendanceAsync.valueOrNull)) {
                    0 => null,
                    final n => '$n',
                  },
                ),
              ],
              selectedIndex: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),

          if (_tab == 1)
            Expanded(
              child: attendanceAsync.when(
                data: (attendances) => _PhoneCheckinsTab(
                  attendances: attendances.where((a) => a.isGeo).toList(),
                  worshipServiceId: widget.worshipServiceId,
                  onChanged: _refresh,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Erro: $error')),
              ),
            )
          else ...[
          // Barra de busca
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar membro ou visitante...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Lista de membros
          Expanded(
            child: membersAsync.when(
              data: (members) {
                return attendanceAsync.when(
                  data: (attendances) {
                    // IDs dos membros presentes
                    final presentMemberIds = attendances
                        .map((a) => a.memberId)
                        .toSet();

                    // Filtrar membros
                    var filteredMembers = members.where((member) {
                      final matchesSearch = _searchQuery.isEmpty ||
                          member.displayName.toLowerCase().contains(_searchQuery);

                      final matchesFilter = !_showOnlyPresent ||
                          presentMemberIds.contains(member.id);

                      return matchesSearch && matchesFilter;
                    }).toList();

                    // Ordenar: presentes primeiro
                    filteredMembers.sort((a, b) {
                      final aPresent = presentMemberIds.contains(a.id);
                      final bPresent = presentMemberIds.contains(b.id);
                      
                      if (aPresent && !bPresent) return -1;
                      if (!aPresent && bPresent) return 1;

                      return a.displayName.compareTo(b.displayName);
                    });

                    if (filteredMembers.isEmpty) {
                      return Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'Nenhum membro ou visitante encontrado'
                              : 'Nenhum resultado para "$_searchQuery"',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredMembers.length,
                      itemBuilder: (context, index) {
                        final member = filteredMembers[index];
                        final isPresent = presentMemberIds.contains(member.id);

                        return _MemberCheckInTile(
                          member: member,
                          isPresent: isPresent,
                          worshipServiceId: widget.worshipServiceId,
                          onToggle: _refresh,
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('Erro: $error')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Erro: $error')),
            ),
          ),
          ],
        ],
      ),
    );
  }
}

const _reactionEmojis = {'otimo': '🙌', 'gostando': '🙂', 'mais_ou_menos': '😐'};

/// "🙌 5 · 🙂 3 · 😐 1", ou nulo se ninguém reagiu.
String? _reactionSummary(List<WorshipAttendance>? attendances) {
  final counts = <String, int>{};
  for (final a in attendances ?? const <WorshipAttendance>[]) {
    if (_reactionEmojis.containsKey(a.reaction)) {
      counts[a.reaction!] = (counts[a.reaction!] ?? 0) + 1;
    }
  }
  if (counts.isEmpty) return null;
  return [
    for (final e in _reactionEmojis.entries)
      if (counts[e.key] != null) '${e.value} ${counts[e.key]}',
  ].join(' · ');
}

int _geoCount(List<WorshipAttendance>? attendances) =>
    attendances?.where((a) => a.isGeo).length ?? 0;

/// Aba "Pelo celular": quem marcou presença pelo próprio celular, com o
/// estado (detectada pelo GPS / confirmada pela pessoa / validada) e os
/// botões Confirmar e Recusar (RPC `worship_attendance_validate`).
class _PhoneCheckinsTab extends StatelessWidget {
  final List<WorshipAttendance> attendances;
  final String worshipServiceId;
  final VoidCallback onChanged;

  const _PhoneCheckinsTab({
    required this.attendances,
    required this.worshipServiceId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (attendances.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Ninguém marcou presença pelo celular neste culto.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: attendances.length,
      itemBuilder: (context, i) => _PhoneCheckinTile(
        attendance: attendances[i],
        worshipServiceId: worshipServiceId,
        onChanged: onChanged,
      ),
    );
  }
}

class _PhoneCheckinTile extends ConsumerStatefulWidget {
  final WorshipAttendance attendance;
  final String worshipServiceId;
  final VoidCallback onChanged;

  const _PhoneCheckinTile({
    required this.attendance,
    required this.worshipServiceId,
    required this.onChanged,
  });

  @override
  ConsumerState<_PhoneCheckinTile> createState() => _PhoneCheckinTileState();
}

class _PhoneCheckinTileState extends ConsumerState<_PhoneCheckinTile> {
  bool _busy = false;

  Future<void> _validate(bool ok) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(worshipRepositoryProvider)
          .validateCheckin(
            widget.worshipServiceId,
            widget.attendance.memberId,
            ok: ok,
          );
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.attendance;
    final (icon, color, state) = a.isValidated
        ? (Icons.verified, Colors.green, 'Validada')
        : a.isConfirmed
        ? (Icons.phone_android, Theme.of(context).colorScheme.primary, 'Confirmada pela pessoa')
        : (Icons.gps_not_fixed, Colors.grey, 'Detectada pelo GPS');
    final details = [
      DateFormat.Hm().format(a.checkedInAt.toLocal()),
      if (a.distanceM != null) '${a.distanceM} m',
      state,
      if (_reactionEmojis[a.reaction] case final emoji?) emoji,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(a.memberName ?? 'Sem nome'),
        subtitle: Text(details, style: const TextStyle(fontSize: 12)),
        trailing: _busy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : a.isValidated
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Confirmar',
                    icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                    onPressed: () => _validate(true),
                  ),
                  IconButton(
                    tooltip: 'Recusar',
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                    onPressed: () => _validate(false),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MemberCheckInTile extends ConsumerStatefulWidget {
  final Member member;
  final bool isPresent;
  final String worshipServiceId;
  final VoidCallback onToggle;

  const _MemberCheckInTile({
    required this.member,
    required this.isPresent,
    required this.worshipServiceId,
    required this.onToggle,
  });

  @override
  ConsumerState<_MemberCheckInTile> createState() => _MemberCheckInTileState();
}

class _MemberCheckInTileState extends ConsumerState<_MemberCheckInTile> {
  bool _isLoading = false;

  Future<void> _toggleAttendance() async {
    final hasPermission = await ref.read(
      currentUserHasPermissionProvider('worship.attendance').future,
    );
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Você não tem permissão para esta ação')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repo = ref.read(worshipRepositoryProvider);

      if (widget.isPresent) {
        await repo.checkOut(widget.worshipServiceId, widget.member.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.member.displayName} removido da presença'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        await repo.checkIn(widget.worshipServiceId, widget.member.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.member.displayName} marcado como presente!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      widget.onToggle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canToggleAttendance = ref
        .watch(currentUserHasPermissionProvider('worship.attendance'))
        .maybeWhen(data: (v) => v, orElse: () => false);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: widget.isPresent ? 2 : 0,
      color: widget.isPresent ? Colors.green.withValues(alpha: 0.05) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: widget.isPresent ? Colors.green : Colors.grey[300],
          child: widget.isPresent
              ? const Icon(Icons.check, color: Colors.white)
              : Text(
                  widget.member.initials,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
        title: Text(
          widget.member.displayName,
          style: TextStyle(
            fontWeight: widget.isPresent ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: widget.isPresent || widget.member.isVisitor
            ? Text(
                [
                  if (widget.member.isVisitor) 'Visitante',
                  if (widget.isPresent) 'Presente',
                ].join(' · '),
                style: TextStyle(
                  color: widget.isPresent ? Colors.green : Colors.orange[800],
                  fontSize: 12,
                ),
              )
            : null,
        trailing: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : DisabledByPermission(
                permission: 'worship.attendance',
                disabledTooltip: 'Você não tem permissão para esta ação',
                child: IconButton(
                  icon: Icon(
                    widget.isPresent ? Icons.check_circle : Icons.circle_outlined,
                    color: widget.isPresent ? Colors.green : Colors.grey,
                  ),
                  onPressed: _toggleAttendance,
                ),
              ),
        onTap: (_isLoading || !canToggleAttendance) ? null : _toggleAttendance,
      ),
    );
  }
}
