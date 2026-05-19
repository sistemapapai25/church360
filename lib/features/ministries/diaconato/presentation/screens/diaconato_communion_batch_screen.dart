import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../../core/utils/whatsapp_launcher.dart';
import '../../../../worship/domain/models/worship_service.dart';
import '../../../../worship/presentation/providers/worship_provider.dart';
import '../../../domain/models/ministry.dart';
import '../../../presentation/providers/ministries_provider.dart';
import '../../../shared/presentation/widgets/ministry_submodule_guard.dart';
import '../../domain/models/communion_delivery.dart';
import '../../domain/models/worship_attendance.dart';
import '../providers/diaconato_attendance_providers.dart';

/// Tela do lote de ceia do Diaconato (Lote MD.4.3/MD.4.4).
///
/// Carrega (ou cria) o lote para `(ministry, attendance_count)` derivada do
/// culto, sincroniza items a partir das triagens com `communion`/
/// `call_and_communion` em `worship_attendance_person` e permite atribuir
/// responsável + marcar status de entrega.
///
/// `rebuildBatchItemsFromTriage` é idempotente e **preserva progresso** —
/// items em estado terminal (`assigned`/`delivered`/`not_found`/`cancelled`)
/// nunca somem quando a triagem muda; só `pending` é destruído. Por isso a
/// mesma tela serve para "criar" e "abrir lote existente".
class DiaconatoCommunionBatchScreen extends ConsumerWidget {
  final String ministryId;
  final String worshipServiceId;

  const DiaconatoCommunionBatchScreen({
    super.key,
    required this.ministryId,
    required this.worshipServiceId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MinistrySubmoduleGuard(
      ministryId: ministryId,
      requiredPermission: 'diaconato.manage_communion',
      submoduleLabel: 'Lote de ceia',
      builder: (context) => _CommunionBatchContent(
        ministryId: ministryId,
        worshipServiceId: worshipServiceId,
      ),
    );
  }
}

class _CommunionBatchContent extends ConsumerStatefulWidget {
  final String ministryId;
  final String worshipServiceId;

  const _CommunionBatchContent({
    required this.ministryId,
    required this.worshipServiceId,
  });

  @override
  ConsumerState<_CommunionBatchContent> createState() =>
      _CommunionBatchContentState();
}

class _CommunionBatchContentState
    extends ConsumerState<_CommunionBatchContent> {
  late Future<_BatchData> _loadFuture;
  CommunionDeliveryBatch? _batch;
  WorshipService? _service;
  List<CommunionDeliveryItem> _items = const [];
  Map<String, DiaconatoEligiblePerson> _peopleById = const {};

  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<_BatchData> _load() async {
    final repo = ref.read(diaconatoAttendanceRepositoryProvider);
    final worshipRepo = ref.read(worshipRepositoryProvider);

    // 1) Garante a contagem (cria se não existe).
    final count = await repo.getOrCreateAttendanceCount(
      worshipServiceId: widget.worshipServiceId,
      ministryId: widget.ministryId,
    );

    // 2) Em paralelo: culto, lote, pessoas elegíveis.
    final results = await Future.wait([
      worshipRepo.getWorshipServiceById(widget.worshipServiceId),
      repo.getOrCreateCommunionBatch(
        ministryId: widget.ministryId,
        attendanceCountId: count.id,
      ),
      repo.getEligiblePeople(),
    ]);

    final service = results[0] as WorshipService?;
    final batch = results[1] as CommunionDeliveryBatch;
    final eligible = results[2] as List<DiaconatoEligiblePerson>;

    // 3) Sincroniza items com a triagem (idempotente, preserva progresso).
    final items = await repo.rebuildBatchItemsFromTriage(
      batchId: batch.id,
      attendanceCountId: count.id,
    );

    _batch = batch;
    _service = service;
    _items = items;
    _peopleById = {for (final p in eligible) p.userId: p};

    return _BatchData(batch: batch, items: items);
  }

  Future<void> _refresh() async {
    setState(() {
      _loadFuture = _load();
    });
    await _loadFuture;
  }

  Future<void> _sync() async {
    final batch = _batch;
    if (batch == null) return;
    setState(() => _syncing = true);
    try {
      final repo = ref.read(diaconatoAttendanceRepositoryProvider);
      final items = await repo.rebuildBatchItemsFromTriage(
        batchId: batch.id,
        attendanceCountId: batch.attendanceCountId,
      );
      if (!mounted) return;
      setState(() => _items = items);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sincronizado com a triagem. ${items.length} pessoa'
            '${items.length == 1 ? '' : 's'} no lote.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao sincronizar: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _assignItem(
    CommunionDeliveryItem item,
    MinistryMember? member,
  ) async {
    try {
      final repo = ref.read(diaconatoAttendanceRepositoryProvider);
      final updated = await repo.updateItemAssignment(
        itemId: item.id,
        assignedTo: member?.memberId,
      );
      if (!mounted) return;
      setState(() {
        _items = [
          for (final i in _items) if (i.id == item.id) updated else i,
        ];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atribuir: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _sendWhatsApp(CommunionDeliveryItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final person = _peopleById[item.userId];
    final phone = person?.phone;
    if (phone == null || phone.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Pessoa sem telefone cadastrado.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final greet = person == null ? 'Olá' : 'Olá ${person.firstName}';
    final message =
        '$greet! Sou da igreja. Tenho a ceia pra te entregar — quando posso passar?';

    final result = await launchWhatsAppMessage(phone: phone, message: message);
    if (!mounted) return;

    switch (result) {
      case WhatsAppLaunchResult.launched:
        try {
          final repo = ref.read(diaconatoAttendanceRepositoryProvider);
          final updated =
              await repo.markCommunionItemWhatsappReminderSent(item.id);
          if (!mounted) return;
          setState(() {
            _items = [
              for (final i in _items) if (i.id == item.id) updated else i,
            ];
          });
        } catch (_) {
          // Falha ao marcar é silenciosa — o WhatsApp já foi aberto.
        }
        messenger.showSnackBar(
          const SnackBar(
            content: Text('WhatsApp aberto. Lembrete marcado como enviado.'),
            backgroundColor: Colors.green,
          ),
        );
        break;
      case WhatsAppLaunchResult.invalidPhone:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Telefone inválido.'),
            backgroundColor: Colors.orange,
          ),
        );
        break;
      case WhatsAppLaunchResult.cannotLaunch:
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Não foi possível abrir o WhatsApp.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        break;
    }
  }

  Future<void> _changeStatus(
    CommunionDeliveryItem item,
    CommunionDeliveryStatus status,
  ) async {
    try {
      final repo = ref.read(diaconatoAttendanceRepositoryProvider);
      final updated = await repo.updateItemStatus(
        itemId: item.id,
        status: status,
      );
      if (!mounted) return;
      setState(() {
        _items = [
          for (final i in _items) if (i.id == item.id) updated else i,
        ];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _closeOrReopenBatch() async {
    final batch = _batch;
    if (batch == null) return;
    try {
      final repo = ref.read(diaconatoAttendanceRepositoryProvider);
      final updated = batch.status == CommunionBatchStatus.open
          ? await repo.closeBatch(batch.id)
          : await repo.reopenBatch(batch.id);
      if (!mounted) return;
      setState(() => _batch = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.status == CommunionBatchStatus.closed
                ? 'Lote fechado.'
                : 'Lote reaberto.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: const Text('Lote de ceia'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Sincronizar com triagem',
            onPressed: _syncing ? null : _sync,
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: FutureBuilder<_BatchData>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }
          return _buildBody(context);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final batch = _batch!;
    final stats = _computeStats(_items);
    final allTerminal = _items.isNotEmpty &&
        _items.every((i) => _isTerminal(i.status));

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _HeaderCard(
                service: _service,
                batch: batch,
                stats: stats,
              ),
              const SizedBox(height: 20),
              if (_items.isEmpty)
                _EmptyHint(
                  text:
                      'Nenhuma pessoa triada com "Levar ceia" ou "Ligar + ceia" nesta '
                      'contagem. Volte para "Ausentes" e ajuste a triagem.',
                )
              else
                ..._items.map((item) {
                  final person = _peopleById[item.userId];
                  return _ItemTile(
                    item: item,
                    person: person,
                    ministryId: widget.ministryId,
                    batchClosed: batch.status == CommunionBatchStatus.closed,
                    onAssign: (m) => _assignItem(item, m),
                    onStatus: (s) => _changeStatus(item, s),
                    onSendWhatsApp: () => _sendWhatsApp(item),
                  );
                }),
            ],
          ),
        ),
        _StickyFooter(
          batch: batch,
          stats: stats,
          allTerminal: allTerminal,
          onToggleClose: _closeOrReopenBatch,
        ),
      ],
    );
  }

  bool _isTerminal(CommunionDeliveryStatus s) =>
      s == CommunionDeliveryStatus.delivered ||
      s == CommunionDeliveryStatus.notFound ||
      s == CommunionDeliveryStatus.cancelled;

  _BatchStats _computeStats(List<CommunionDeliveryItem> items) {
    var pending = 0, assigned = 0, delivered = 0, other = 0;
    for (final i in items) {
      switch (i.status) {
        case CommunionDeliveryStatus.pending:
          pending++;
          break;
        case CommunionDeliveryStatus.assigned:
          assigned++;
          break;
        case CommunionDeliveryStatus.delivered:
          delivered++;
          break;
        case CommunionDeliveryStatus.notFound:
        case CommunionDeliveryStatus.cancelled:
          other++;
          break;
      }
    }
    return _BatchStats(
      total: items.length,
      pending: pending,
      assigned: assigned,
      delivered: delivered,
      other: other,
    );
  }
}

// =====================================================
// Helpers visuais
// =====================================================

class _BatchData {
  final CommunionDeliveryBatch batch;
  final List<CommunionDeliveryItem> items;
  const _BatchData({required this.batch, required this.items});
}

class _BatchStats {
  final int total;
  final int pending;
  final int assigned;
  final int delivered;
  final int other;

  const _BatchStats({
    required this.total,
    required this.pending,
    required this.assigned,
    required this.delivered,
    required this.other,
  });
}

class _HeaderCard extends StatelessWidget {
  final WorshipService? service;
  final CommunionDeliveryBatch batch;
  final _BatchStats stats;

  const _HeaderCard({
    required this.service,
    required this.batch,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = service;
    final dateLabel = s == null
        ? _capitalize(
            DateFormat("EEE, d 'de' MMM 'de' y", 'pt_BR')
                .format(batch.serviceDate),
          )
        : _capitalize(
            DateFormat("EEE, d 'de' MMM 'de' y", 'pt_BR').format(s.serviceDate),
          );
    final subtitle = s == null
        ? 'Lote ${batch.status.label.toLowerCase()}'
        : [
            s.serviceType.label,
            if ((s.serviceTime ?? '').trim().isNotEmpty) s.serviceTime!.trim(),
            'Lote ${batch.status.label.toLowerCase()}',
          ].join(' · ');

    final closed = batch.status == CommunionBatchStatus.closed;

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
                  color: (closed ? Colors.grey : cs.primary).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  closed
                      ? Icons.lock_outline
                      : Icons.takeout_dining_outlined,
                  color: closed ? Colors.grey : cs.primary,
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
                  label: 'Pendentes',
                  value: stats.pending,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatChip(
                  label: 'Atribuídos',
                  value: stats.assigned,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatChip(
                  label: 'Entregues',
                  value: stats.delivered,
                  color: Colors.green,
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

class _ItemTile extends ConsumerWidget {
  final CommunionDeliveryItem item;
  final DiaconatoEligiblePerson? person;
  final String ministryId;
  final bool batchClosed;
  final ValueChanged<MinistryMember?> onAssign;
  final ValueChanged<CommunionDeliveryStatus> onStatus;
  final VoidCallback onSendWhatsApp;

  const _ItemTile({
    required this.item,
    required this.person,
    required this.ministryId,
    required this.batchClosed,
    required this.onAssign,
    required this.onStatus,
    required this.onSendWhatsApp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final delivered = item.status == CommunionDeliveryStatus.delivered;
    final accent = delivered ? Colors.green : _statusColor(item.status, cs);

    final membersAsync = ref.watch(ministryMembersProvider(ministryId));
    final assigneeName = item.assignedTo == null
        ? null
        : membersAsync.maybeWhen(
            data: (members) {
              final m = members.firstWhere(
                (mm) => mm.memberId == item.assignedTo,
                orElse: () => MinistryMember(
                  id: '',
                  ministryId: ministryId,
                  memberId: item.assignedTo!,
                  memberName: 'Responsável',
                  role: MinistryRole.member,
                  joinedAt: DateTime.now(),
                  createdAt: DateTime.now(),
                ),
              );
              return m.memberName.isEmpty ? 'Responsável' : m.memberName;
            },
            orElse: () => 'Responsável',
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: delivered ? Colors.green.withValues(alpha: 0.05) : cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent, width: delivered ? 1.4 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: cs.primary.withValues(alpha: 0.1),
                backgroundImage: (person?.photoUrl ?? '').trim().isNotEmpty
                    ? NetworkImage(person!.photoUrl!)
                    : null,
                child: (person?.photoUrl ?? '').trim().isEmpty
                    ? Text(
                        person?.initial ?? '?',
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
                      person?.displayName ?? 'Pessoa removida',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _ReasonChip(reason: item.reason),
                        const SizedBox(width: 6),
                        _StatusBadge(status: item.status),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AssigneePicker(
                  ministryId: ministryId,
                  currentAssigneeName: assigneeName,
                  enabled: !batchClosed,
                  onChanged: onAssign,
                ),
              ),
              const SizedBox(width: 8),
              _StatusMenu(
                current: item.status,
                enabled: !batchClosed,
                onChanged: onStatus,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _WhatsAppItemRow(
            phone: person?.phone,
            sentAt: item.reminderWhatsappSentAt,
            enabled: !batchClosed,
            onPressed: onSendWhatsApp,
          ),
        ],
      ),
    );
  }

  Color _statusColor(CommunionDeliveryStatus s, ColorScheme cs) {
    switch (s) {
      case CommunionDeliveryStatus.pending:
        return Colors.orange.withValues(alpha: 0.5);
      case CommunionDeliveryStatus.assigned:
        return Colors.blue.withValues(alpha: 0.5);
      case CommunionDeliveryStatus.delivered:
        return Colors.green;
      case CommunionDeliveryStatus.notFound:
        return Colors.redAccent.withValues(alpha: 0.5);
      case CommunionDeliveryStatus.cancelled:
        return cs.onSurface.withValues(alpha: 0.2);
    }
  }
}

class _WhatsAppItemRow extends StatelessWidget {
  final String? phone;
  final DateTime? sentAt;
  final bool enabled;
  final VoidCallback onPressed;

  const _WhatsAppItemRow({
    required this.phone,
    required this.sentAt,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhone = (phone ?? '').trim().isNotEmpty;
    final wasSent = sentAt != null;
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: (enabled && hasPhone) ? onPressed : null,
          icon: const Icon(Icons.chat_bubble_outline, size: 14),
          label: Text(
            wasSent ? 'Reenviar WhatsApp' : 'Enviar WhatsApp',
            style: const TextStyle(fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF25D366),
            side: BorderSide(
              color: hasPhone
                  ? const Color(0xFF25D366).withValues(alpha: 0.6)
                  : Colors.grey.withValues(alpha: 0.3),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 8),
        if (!hasPhone)
          Expanded(
            child: Text(
              'Sem telefone',
              style: CommunityDesign.metaStyle(context).copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else if (wasSent)
          Expanded(
            child: Text(
              'Enviado em ${_formatSentAt(sentAt!)}',
              style: CommunityDesign.metaStyle(context).copyWith(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  String _formatSentAt(DateTime t) {
    return '${t.day.toString().padLeft(2, '0')}/'
        '${t.month.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }
}

class _ReasonChip extends StatelessWidget {
  final CommunionDeliveryReason reason;
  const _ReasonChip({required this.reason});

  @override
  Widget build(BuildContext context) {
    final color = reason == CommunionDeliveryReason.callAndCommunion
        ? Colors.deepPurple
        : Colors.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        reason.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final CommunionDeliveryStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _color(CommunionDeliveryStatus s) {
    switch (s) {
      case CommunionDeliveryStatus.pending:
        return Colors.orange;
      case CommunionDeliveryStatus.assigned:
        return Colors.blue;
      case CommunionDeliveryStatus.delivered:
        return Colors.green;
      case CommunionDeliveryStatus.notFound:
        return Colors.redAccent;
      case CommunionDeliveryStatus.cancelled:
        return Colors.grey;
    }
  }
}

class _AssigneePicker extends ConsumerWidget {
  final String ministryId;
  final String? currentAssigneeName;
  final bool enabled;
  final ValueChanged<MinistryMember?> onChanged;

  const _AssigneePicker({
    required this.ministryId,
    required this.currentAssigneeName,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(ministryMembersProvider(ministryId));
    final cs = Theme.of(context).colorScheme;

    return OutlinedButton.icon(
      onPressed: !enabled
          ? null
          : () async {
              final members = membersAsync.maybeWhen(
                data: (m) => m,
                orElse: () => <MinistryMember>[],
              );
              final picked = await _openAssigneeSheet(context, members);
              if (picked == null) return;
              onChanged(picked.value);
            },
      icon: Icon(
        currentAssigneeName == null
            ? Icons.person_add_alt
            : Icons.person_outlined,
        size: 16,
      ),
      label: Text(
        currentAssigneeName ?? 'Atribuir',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }

  Future<_PickedMember?> _openAssigneeSheet(
    BuildContext context,
    List<MinistryMember> members,
  ) async {
    return showModalBottomSheet<_PickedMember>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Atribuir responsável',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                  ),
                  child: members.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Nenhum membro neste ministério ainda.',
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: members.length + 1,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            if (i == 0) {
                              return ListTile(
                                leading: const Icon(Icons.clear),
                                title: const Text('Desatribuir'),
                                onTap: () => Navigator.of(ctx).pop(
                                  const _PickedMember(value: null),
                                ),
                              );
                            }
                            final m = members[i - 1];
                            return ListTile(
                              leading: const Icon(Icons.person_outline),
                              title: Text(m.memberName.isEmpty
                                  ? 'Membro do ministério'
                                  : m.memberName),
                              subtitle:
                                  m.role == MinistryRole.member
                                      ? null
                                      : Text(m.role.label),
                              onTap: () => Navigator.of(ctx)
                                  .pop(_PickedMember(value: m)),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PickedMember {
  final MinistryMember? value;
  const _PickedMember({required this.value});
}

class _StatusMenu extends StatelessWidget {
  final CommunionDeliveryStatus current;
  final bool enabled;
  final ValueChanged<CommunionDeliveryStatus> onChanged;

  const _StatusMenu({
    required this.current,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CommunionDeliveryStatus>(
      enabled: enabled,
      tooltip: 'Mudar status',
      icon: const Icon(Icons.more_vert),
      onSelected: onChanged,
      itemBuilder: (_) {
        return CommunionDeliveryStatus.values.map((s) {
          return PopupMenuItem<CommunionDeliveryStatus>(
            value: s,
            child: Row(
              children: [
                Icon(
                  s == current ? Icons.check : Icons.circle_outlined,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(s.label),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}

class _StickyFooter extends StatelessWidget {
  final CommunionDeliveryBatch batch;
  final _BatchStats stats;
  final bool allTerminal;
  final VoidCallback onToggleClose;

  const _StickyFooter({
    required this.batch,
    required this.stats,
    required this.allTerminal,
    required this.onToggleClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final closed = batch.status == CommunionBatchStatus.closed;
    final canClose = !closed && allTerminal;

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
                closed ? 'Lote fechado' : 'Entregues',
                style: CommunityDesign.metaStyle(context),
              ),
              Text(
                '${stats.delivered} de ${stats.total}',
                style: CommunityDesign.titleStyle(context).copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (closed)
            OutlinedButton.icon(
              onPressed: onToggleClose,
              icon: const Icon(Icons.lock_open, size: 16),
              label: const Text('Reabrir'),
            )
          else
            FilledButton.icon(
              onPressed: canClose ? onToggleClose : null,
              icon: const Icon(Icons.lock_outline, size: 16),
              label: const Text('Fechar lote'),
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
          Text('Erro ao carregar lote',
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
