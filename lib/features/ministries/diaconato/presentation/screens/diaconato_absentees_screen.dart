import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../worship/domain/models/worship_service.dart';
import '../../../../worship/presentation/providers/worship_provider.dart';
import '../../../shared/presentation/widgets/ministry_submodule_guard.dart';
import '../../domain/models/worship_attendance.dart';
import '../providers/diaconato_attendance_providers.dart';

/// Tela "Ausentes" do Diaconato (Lote MD.3).
///
/// Lista derivada: quem não foi marcado presente no checklist do culto.
/// Permite triar cada ausente em uma das ações (`none`/`call`/`communion`/
/// `call_and_communion`). Quando há visitantes não cadastrados na contagem,
/// mostra banner de captação para o Raízes.
class DiaconatoAbsenteesScreen extends ConsumerWidget {
  final String ministryId;
  final String worshipServiceId;

  const DiaconatoAbsenteesScreen({
    super.key,
    required this.ministryId,
    required this.worshipServiceId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MinistrySubmoduleGuard(
      ministryId: ministryId,
      requiredPermission: 'diaconato.manage_attendance',
      submoduleLabel: 'Ausentes do Diaconato',
      builder: (context) => _AbsenteesContent(
        ministryId: ministryId,
        worshipServiceId: worshipServiceId,
      ),
    );
  }
}

class _AbsenteesContent extends ConsumerStatefulWidget {
  final String ministryId;
  final String worshipServiceId;

  const _AbsenteesContent({
    required this.ministryId,
    required this.worshipServiceId,
  });

  @override
  ConsumerState<_AbsenteesContent> createState() => _AbsenteesContentState();
}

class _AbsenteesContentState extends ConsumerState<_AbsenteesContent> {
  late Future<_AbsenteesData> _loadFuture;

  WorshipAttendanceCount? _count;
  WorshipService? _service;
  List<DiaconatoEligiblePerson> _absentees = const [];

  /// userId → AbsenteeTriage atual no formulário.
  final Map<String, AbsenteeTriage> _triageByUser = <String, AbsenteeTriage>{};

  /// userIds que tiveram a triagem mexida nesta sessão (vão para o save).
  final Set<String> _dirtyUserIds = <String>{};

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<_AbsenteesData> _load() async {
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
    final service = results[1] as WorshipService?;
    final eligible = results[2] as List<DiaconatoEligiblePerson>;
    final personRows = await repo.getPersonRows(count.id);

    final presentUserIds = personRows
        .where((r) => r.present)
        .map((r) => r.userId)
        .toSet();
    final absentees = eligible
        .where((p) => !presentUserIds.contains(p.userId))
        .toList();

    // Seed da triagem a partir das linhas de ausentes já existentes.
    final triageSeeds = <String, AbsenteeTriage>{};
    final existingByUser = {for (final r in personRows) r.userId: r};
    for (final p in absentees) {
      final existing = existingByUser[p.userId];
      final action =
          (existing != null && !existing.present)
              ? existing.absentAction
              : DiaconatoAbsentAction.none;
      triageSeeds[p.userId] = AbsenteeTriage(
        action: action,
        personType: p.personType,
      );
    }

    _count = count;
    _service = service;
    _absentees = absentees;
    _triageByUser
      ..clear()
      ..addAll(triageSeeds);
    _dirtyUserIds.clear();

    return _AbsenteesData(
      count: count,
      hasAnyPresentMark: personRows.any((r) => r.present),
    );
  }

  void _setTriage(String userId, DiaconatoAbsentAction action) {
    final current = _triageByUser[userId];
    if (current == null || current.action == action) return;
    setState(() {
      _triageByUser[userId] = AbsenteeTriage(
        action: action,
        personType: current.personType,
      );
      _dirtyUserIds.add(userId);
    });
  }

  Future<void> _save() async {
    final count = _count;
    if (count == null) return;
    if (_dirtyUserIds.isEmpty) return;

    setState(() => _saving = true);
    try {
      final payload = <String, AbsenteeTriage>{
        for (final id in _dirtyUserIds) id: _triageByUser[id]!,
      };

      final repo = ref.read(diaconatoAttendanceRepositoryProvider);
      await repo.saveAbsenteeTriage(
        attendanceCountId: count.id,
        triageByUser: payload,
      );

      if (!mounted) return;
      setState(() {
        _dirtyUserIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Triagem salva.'),
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
        title: const Text('Ausentes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: FutureBuilder<_AbsenteesData>(
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
          return _buildBody(context, snapshot.data!);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, _AbsenteesData data) {
    final triagedCount =
        _triageByUser.values.where((t) => t.action != DiaconatoAbsentAction.none).length;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _HeaderCard(
                service: _service,
                absent: _absentees.length,
                triaged: triagedCount,
                unregistered: data.count.totalUnregisteredVisitors,
              ),
              if (data.count.totalUnregisteredVisitors > 0) ...[
                const SizedBox(height: 16),
                _UnregisteredBanner(
                  count: data.count.totalUnregisteredVisitors,
                  onCapture: () => context.push('/ministries'),
                ),
              ],
              const SizedBox(height: 20),
              if (!data.hasAnyPresentMark) ...[
                _NoChecklistBanner(
                  onOpenChecklist: () {
                    context.pushReplacement(
                      '/ministries/${widget.ministryId}/diaconato/checklist/${widget.worshipServiceId}',
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
              if (_absentees.isEmpty)
                _EmptyHint(
                  text:
                      'Ninguém pendente — todos os elegíveis foram marcados presentes.',
                )
              else
                ..._absentees.map(
                  (p) => _AbsenteeTile(
                    person: p,
                    current: _triageByUser[p.userId]?.action ??
                        DiaconatoAbsentAction.none,
                    onChanged: (a) => _setTriage(p.userId, a),
                  ),
                ),
            ],
          ),
        ),
        _StickyFooter(
          triaged: triagedCount,
          total: _absentees.length,
          dirty: _dirtyUserIds.isNotEmpty,
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

class _AbsenteesData {
  final WorshipAttendanceCount count;
  final bool hasAnyPresentMark;

  const _AbsenteesData({
    required this.count,
    required this.hasAnyPresentMark,
  });
}

class _HeaderCard extends StatelessWidget {
  final WorshipService? service;
  final int absent;
  final int triaged;
  final int unregistered;

  const _HeaderCard({
    required this.service,
    required this.absent,
    required this.triaged,
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
                child: Icon(
                  Icons.call_missed_outgoing_outlined,
                  color: cs.primary,
                ),
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
                  label: 'Ausentes',
                  value: absent,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatChip(
                  label: 'Triados',
                  value: triaged,
                  color: Colors.green,
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

class _UnregisteredBanner extends StatelessWidget {
  final int count;
  final VoidCallback onCapture;

  const _UnregisteredBanner({required this.count, required this.onCapture});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.add_circle_outline, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count visitante${count == 1 ? '' : 's'} não cadastrado'
                  '${count == 1 ? '' : 's'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cadastre essas pessoas no Raízes para incluir em futuras triagens.',
                  style: CommunityDesign.metaStyle(context),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onCapture,
                  icon: const Icon(Icons.eco_outlined, size: 16),
                  label: const Text('Ir para Raízes'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoChecklistBanner extends StatelessWidget {
  final VoidCallback onOpenChecklist;

  const _NoChecklistBanner({required this.onOpenChecklist});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nenhum presente registrado neste culto.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'A lista abaixo trata todos os elegíveis como ausentes. '
                  'Faça o checklist primeiro para refinar a triagem.',
                  style: CommunityDesign.metaStyle(context),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: onOpenChecklist,
                  icon: const Icon(Icons.checklist_outlined, size: 16),
                  label: const Text('Abrir checklist'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AbsenteeTile extends StatelessWidget {
  final DiaconatoEligiblePerson person;
  final DiaconatoAbsentAction current;
  final ValueChanged<DiaconatoAbsentAction> onChanged;

  const _AbsenteeTile({
    required this.person,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final triaged = current != DiaconatoAbsentAction.none;
    final accent = triaged ? Colors.green : cs.onSurface.withValues(alpha: 0.12);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: triaged ? Colors.green.withValues(alpha: 0.05) : cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent, width: triaged ? 1.4 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      person.personType == DiaconatoPersonType.member
                          ? 'Membro'
                          : 'Visitante',
                      style: CommunityDesign.metaStyle(context)
                          .copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (triaged)
                Icon(Icons.check_circle, size: 18, color: Colors.green),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: DiaconatoAbsentAction.values.map((action) {
              return ChoiceChip(
                label: Text(action.label),
                selected: current == action,
                onSelected: (_) => onChanged(action),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _StickyFooter extends StatelessWidget {
  final int triaged;
  final int total;
  final bool dirty;
  final bool saving;
  final VoidCallback onSave;

  const _StickyFooter({
    required this.triaged,
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
              Text('Triados',
                  style: CommunityDesign.metaStyle(context)),
              Text(
                '$triaged de $total',
                style: CommunityDesign.titleStyle(context).copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: (saving || !dirty) ? null : onSave,
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
          Text('Erro ao carregar ausentes',
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
