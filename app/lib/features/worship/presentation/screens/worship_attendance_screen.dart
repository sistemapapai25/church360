import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/worship_provider.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../members/domain/models/member.dart';

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

  @override
  Widget build(BuildContext context) {
    final serviceAsync = ref.watch(worshipServiceByIdProvider(widget.worshipServiceId));
    final attendanceAsync = ref.watch(worshipAttendanceProvider(widget.worshipServiceId));
    final membersAsync = ref.watch(activeMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-in'),
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
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[300]!),
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
                        const Icon(Icons.people, size: 20, color: Colors.blue),
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
                  ],
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Barra de busca
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar membro...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
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
                          member.firstName.toLowerCase().contains(_searchQuery) ||
                          member.lastName.toLowerCase().contains(_searchQuery);

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
                      
                      return a.firstName.compareTo(b.firstName);
                    });

                    if (filteredMembers.isEmpty) {
                      return Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'Nenhum membro encontrado'
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
                          onToggle: () {
                            ref.invalidate(worshipAttendanceProvider(widget.worshipServiceId));
                            ref.invalidate(worshipServiceByIdProvider(widget.worshipServiceId));
                          },
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
      ),
    );
  }
}

/// Tile de membro para check-in
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
              content: Text('${widget.member.firstName} removido da presença'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        await repo.checkIn(widget.worshipServiceId, widget.member.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.member.firstName} marcado como presente!'),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: widget.isPresent ? 2 : 0,
      color: widget.isPresent ? Colors.green.withOpacity(0.05) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: widget.isPresent ? Colors.green : Colors.grey[300],
          child: widget.isPresent
              ? const Icon(Icons.check, color: Colors.white)
              : Text(
                  widget.member.firstName[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
        title: Text(
          '${widget.member.firstName} ${widget.member.lastName}',
          style: TextStyle(
            fontWeight: widget.isPresent ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: widget.isPresent
            ? const Text(
                'Presente',
                style: TextStyle(color: Colors.green, fontSize: 12),
              )
            : null,
        trailing: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                icon: Icon(
                  widget.isPresent ? Icons.check_circle : Icons.circle_outlined,
                  color: widget.isPresent ? Colors.green : Colors.grey,
                ),
                onPressed: _toggleAttendance,
              ),
        onTap: _isLoading ? null : _toggleAttendance,
      ),
    );
  }
}

