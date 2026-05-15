import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../worship/domain/models/worship_service.dart';
import '../../../../worship/presentation/providers/worship_provider.dart';
import '../../../shared/presentation/widgets/ministry_submodule_guard.dart';
import '../../domain/models/worship_attendance.dart';
import '../providers/diaconato_attendance_providers.dart';

/// Tela do checklist de presença do Diaconato (Lote MD.2).
///
/// Lista membros + visitantes cadastrados em duas seções, switch presente
/// para cada um, stepper para visitantes não cadastrados, total ao vivo,
/// salvar em `worship_attendance_count` + `worship_attendance_person`.
class DiaconatoChecklistScreen extends ConsumerWidget {
  final String ministryId;
  final String worshipServiceId;

  const DiaconatoChecklistScreen({
    super.key,
    required this.ministryId,
    required this.worshipServiceId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MinistrySubmoduleGuard(
      ministryId: ministryId,
      requiredPermission: 'diaconato.manage_attendance',
      submoduleLabel: 'Checklist do Diaconato',
      builder: (context) => _DiaconatoChecklistContent(
        ministryId: ministryId,
        worshipServiceId: worshipServiceId,
      ),
    );
  }
}

class _DiaconatoChecklistContent extends ConsumerStatefulWidget {
  final String ministryId;
  final String worshipServiceId;

  const _DiaconatoChecklistContent({
    required this.ministryId,
    required this.worshipServiceId,
  });

  @override
  ConsumerState<_DiaconatoChecklistContent> createState() =>
      _DiaconatoChecklistContentState();
}

class _DiaconatoChecklistContentState
    extends ConsumerState<_DiaconatoChecklistContent> {
  late Future<_ChecklistData> _loadFuture;

  WorshipAttendanceCount? _count;
  WorshipService? _service;
  List<DiaconatoEligiblePerson> _eligible = const [];

  final Set<String> _presentMemberIds = <String>{};
  final Set<String> _presentVisitorIds = <String>{};
  int _unregisteredVisitors = 0;
  bool _saving = false;
  bool _dirty = false;

  final _unregisteredController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  @override
  void dispose() {
    _unregisteredController.dispose();
    super.dispose();
  }

  Future<_ChecklistData> _load() async {
    final repo = ref.read(diaconatoAttendanceRepositoryProvider);
    final worshipRepo = ref.read(worshipRepositoryProvider);

    final results = await Future.wait([
      repo.getOrCreateAttendanceCount(
        worshipServiceId: widget.worshipServiceId,
        ministryId: widget.ministryId,
      ),
      worshipRepo.getWorshipServiceById(widget.worshipServiceId),
      repo.getEligiblePeople(),
    ]);

    final count = results[0] as WorshipAttendanceCount;
    final personRows = await repo.getPersonRows(count.id);

    final data = _ChecklistData(
      count: count,
      service: results[1] as WorshipService?,
      eligible: results[2] as List<DiaconatoEligiblePerson>,
      personRows: personRows,
    );

    // Hidrata o estado local na primeira carga.
    _count = data.count;
    _service = data.service;
    _eligible = data.eligible;
    _unregisteredVisitors = data.count.totalUnregisteredVisitors;
    _unregisteredController.text = _unregisteredVisitors.toString();

    for (final row in data.personRows) {
      if (!row.present) continue;
      if (row.personType == DiaconatoPersonType.member) {
        _presentMemberIds.add(row.userId);
      } else {
        _presentVisitorIds.add(row.userId);
      }
    }
    _dirty = false;

    return data;
  }

  void _toggleMember(String userId, bool present) {
    setState(() {
      if (present) {
        _presentMemberIds.add(userId);
      } else {
        _presentMemberIds.remove(userId);
      }
      _dirty = true;
    });
  }

  void _toggleVisitor(String userId, bool present) {
    setState(() {
      if (present) {
        _presentVisitorIds.add(userId);
      } else {
        _presentVisitorIds.remove(userId);
      }
      _dirty = true;
    });
  }

  void _onUnregisteredChanged(String text) {
    final parsed = int.tryParse(text.trim()) ?? 0;
    final clamped = parsed < 0 ? 0 : parsed;
    if (clamped != _unregisteredVisitors) {
      setState(() {
        _unregisteredVisitors = clamped;
        _dirty = true;
      });
    }
  }

  void _bumpUnregistered(int delta) {
    final next = (_unregisteredVisitors + delta).clamp(0, 9999);
    if (next != _unregisteredVisitors) {
      setState(() {
        _unregisteredVisitors = next;
        _unregisteredController.text = next.toString();
        _dirty = true;
      });
    }
  }

  Future<void> _save() async {
    final count = _count;
    if (count == null) return;

    setState(() => _saving = true);
    try {
      final presentByUser = <String, DiaconatoPersonType>{};
      for (final id in _presentMemberIds) {
        presentByUser[id] = DiaconatoPersonType.member;
      }
      for (final id in _presentVisitorIds) {
        presentByUser[id] = DiaconatoPersonType.visitor;
      }

      final repo = ref.read(diaconatoAttendanceRepositoryProvider);
      final updated = await repo.saveChecklist(
        attendanceCountId: count.id,
        presentByUser: presentByUser,
        totalUnregisteredVisitors: _unregisteredVisitors,
      );

      if (!mounted) return;
      setState(() {
        _count = updated;
        _dirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Checklist salvo. Total: ${updated.totalPeople} pessoa'
            '${updated.totalPeople == 1 ? '' : 's'}.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: const Text('Checklist de presença'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: FutureBuilder<_ChecklistData>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(
              message: snapshot.error.toString(),
              onRetry: () {
                setState(() {
                  _loadFuture = _load();
                });
              },
            );
          }
          return _buildForm(context);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final members = _eligible
        .where((p) => p.personType == DiaconatoPersonType.member)
        .toList();
    final visitors = _eligible
        .where((p) => p.personType == DiaconatoPersonType.visitor)
        .toList();

    final totalMarked =
        _presentMemberIds.length + _presentVisitorIds.length + _unregisteredVisitors;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _HeaderCard(
                service: _service,
                presentMembers: _presentMemberIds.length,
                presentVisitors: _presentVisitorIds.length,
                unregistered: _unregisteredVisitors,
              ),
              const SizedBox(height: 20),
              _SectionHeader(
                title: 'Membros',
                badge: '${_presentMemberIds.length}/${members.length}',
                icon: Icons.groups_outlined,
              ),
              const SizedBox(height: 8),
              if (members.isEmpty)
                _EmptyHint(text: 'Nenhum membro ativo cadastrado.')
              else
                ...members.map(
                  (p) => _PersonTile(
                    person: p,
                    present: _presentMemberIds.contains(p.userId),
                    onChanged: (v) => _toggleMember(p.userId, v),
                  ),
                ),
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'Visitantes cadastrados',
                badge: '${_presentVisitorIds.length}/${visitors.length}',
                icon: Icons.person_add_alt_outlined,
              ),
              const SizedBox(height: 8),
              if (visitors.isEmpty)
                _EmptyHint(
                  text:
                      'Nenhum visitante/novo convertido cadastrado em user_account.',
                )
              else
                ...visitors.map(
                  (p) => _PersonTile(
                    person: p,
                    present: _presentVisitorIds.contains(p.userId),
                    onChanged: (v) => _toggleVisitor(p.userId, v),
                  ),
                ),
              const SizedBox(height: 24),
              _UnregisteredCard(
                controller: _unregisteredController,
                count: _unregisteredVisitors,
                onChanged: _onUnregisteredChanged,
                onBump: _bumpUnregistered,
              ),
            ],
          ),
        ),
        _StickyFooter(
          total: totalMarked,
          dirty: _dirty,
          saving: _saving,
          onSave: _save,
        ),
      ],
    );
  }
}

// =====================================================
// Componentes internos
// =====================================================

class _ChecklistData {
  final WorshipAttendanceCount count;
  final WorshipService? service;
  final List<DiaconatoEligiblePerson> eligible;
  final List<WorshipAttendancePerson> personRows;

  const _ChecklistData({
    required this.count,
    required this.service,
    required this.eligible,
    required this.personRows,
  });
}

class _HeaderCard extends StatelessWidget {
  final WorshipService? service;
  final int presentMembers;
  final int presentVisitors;
  final int unregistered;

  const _HeaderCard({
    required this.service,
    required this.presentMembers,
    required this.presentVisitors,
    required this.unregistered,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = service;

    final dateLabel = s == null
        ? '—'
        : _capitalize(
            DateFormat("EEE, d 'de' MMM 'de' y", 'pt_BR').format(s.serviceDate),
          );

    final subtitle = s == null
        ? 'Carregando culto...'
        : [
            s.serviceType.label,
            if ((s.serviceTime ?? '').trim().isNotEmpty) s.serviceTime!.trim(),
            if ((s.theme ?? '').trim().isNotEmpty) s.theme!.trim(),
          ].join(' · ');

    return Container(
      decoration: CommunityDesign.overlayDecoration(cs),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.event_outlined, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateLabel,
                      style: CommunityDesign.titleStyle(context).copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: CommunityDesign.metaStyle(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: 'Membros',
                  value: presentMembers,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatChip(
                  label: 'Visitantes',
                  value: presentVisitors,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatChip(
                  label: 'Não cad.',
                  value: unregistered,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: CommunityDesign.metaStyle(context).copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String badge;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.badge,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: CommunityDesign.titleStyle(context).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: cs.primary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _PersonTile extends StatelessWidget {
  final DiaconatoEligiblePerson person;
  final bool present;
  final ValueChanged<bool> onChanged;

  const _PersonTile({
    required this.person,
    required this.present,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = present ? Colors.green : cs.onSurface.withValues(alpha: 0.12);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: present
            ? Colors.green.withValues(alpha: 0.06)
            : cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent, width: present ? 1.4 : 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(!present),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: cs.primary.withValues(alpha: 0.1),
                  backgroundImage: (person.photoUrl ?? '').trim().isNotEmpty
                      ? NetworkImage(person.photoUrl!)
                      : null,
                  child: (person.photoUrl ?? '').trim().isEmpty
                      ? Text(
                          person.initial,
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    person.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Switch.adaptive(
                  value: present,
                  onChanged: onChanged,
                  activeThumbColor: Colors.green,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnregisteredCard extends StatelessWidget {
  final TextEditingController controller;
  final int count;
  final ValueChanged<String> onChanged;
  final void Function(int delta) onBump;

  const _UnregisteredCard({
    required this.controller,
    required this.count,
    required this.onChanged,
    required this.onBump,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: CommunityDesign.overlayDecoration(cs),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.add_circle_outline, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Text(
                'Visitantes não cadastrados',
                style: CommunityDesign.titleStyle(context).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Pessoas presentes que ainda não estão em user_account.',
            style: CommunityDesign.metaStyle(context),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: count > 0 ? () => onBump(-1) : null,
                icon: const Icon(Icons.remove),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () => onBump(1),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StickyFooter extends StatelessWidget {
  final int total;
  final bool dirty;
  final bool saving;
  final VoidCallback onSave;

  const _StickyFooter({
    required this.total,
    required this.dirty,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total no culto',
                style: CommunityDesign.metaStyle(context),
              ),
              Text(
                '$total ${total == 1 ? 'pessoa' : 'pessoas'}',
                style: CommunityDesign.titleStyle(context).copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(dirty ? Icons.save_outlined : Icons.check),
            label: Text(saving
                ? 'Salvando...'
                : dirty
                    ? 'Salvar'
                    : 'Salvo'),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: CommunityDesign.metaStyle(context),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Erro ao carregar checklist',
              style: CommunityDesign.titleStyle(context)),
          const SizedBox(height: 8),
          Text(
            message,
            style: CommunityDesign.metaStyle(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}
