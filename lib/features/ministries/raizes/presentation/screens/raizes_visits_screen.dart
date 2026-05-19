import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../../core/utils/whatsapp_launcher.dart';
import '../../../../permissions/presentation/widgets/permission_gate.dart';
import '../../../presentation/providers/ministries_provider.dart';
import '../../../shared/presentation/widgets/ministry_submodule_guard.dart';
import '../../data/raizes_repository.dart';
import '../../domain/models/raizes_visit.dart';
import '../providers/raizes_dashboard_provider.dart';
import '../providers/raizes_visits_provider.dart';

/// Agenda de visitas do Raízes (Lote 4B).
class RaizesVisitsScreen extends ConsumerWidget {
  final String ministryId;

  const RaizesVisitsScreen({super.key, required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MinistrySubmoduleGuard(
      ministryId: ministryId,
      requiredPermission: 'raizes.view',
      submoduleLabel: 'Raízes — Agenda de visitas',
      builder: (context) => _VisitsContent(ministryId: ministryId),
    );
  }
}

class _VisitsContent extends ConsumerStatefulWidget {
  final String ministryId;
  const _VisitsContent({required this.ministryId});

  @override
  ConsumerState<_VisitsContent> createState() => _VisitsContentState();
}

class _VisitsContentState extends ConsumerState<_VisitsContent> {
  RaizesVisitsFilter _filter = RaizesVisitsFilter.todayAndOverdue;

  @override
  Widget build(BuildContext context) {
    final ministryAsync = ref.watch(ministryByIdProvider(widget.ministryId));
    final args = RaizesVisitsArgs(
      ministryId: widget.ministryId,
      filter: _filter,
    );
    final visitsAsync = ref.watch(raizesVisitsProvider(args));

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: ministryAsync.maybeWhen(
          data: (m) => Text('Visitas — ${m?.name ?? "Raízes"}'),
          orElse: () => const Text('Agenda de visitas'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
            onPressed: () => ref.invalidate(raizesVisitsProvider(args)),
          ),
        ],
      ),
      floatingActionButton: PermissionGate(
        permission: 'raizes.manage_visits',
        showLoading: false,
        child: FloatingActionButton.extended(
          onPressed: () => _openCreateDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Nova visita'),
        ),
      ),
      body: Column(
        children: [
          _FilterBar(
            value: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(raizesVisitsProvider(args));
                await ref.read(raizesVisitsProvider(args).future);
              },
              child: visitsAsync.when(
                data: (visits) => visits.isEmpty
                    ? _EmptyState(filter: _filter)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                        itemCount: visits.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _VisitCard(
                          visit: visits[i],
                          onChangeStatus: (status) =>
                              _changeStatus(visits[i], status),
                          onSendWhatsApp: () => _sendWhatsApp(visits[i]),
                        ),
                      ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorBox(
                  message: '$e',
                  onRetry: () => ref.invalidate(raizesVisitsProvider(args)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateVisitDialog(ministryId: widget.ministryId),
    );
    if (created == true && mounted) {
      // Invalida lista atual e KPIs do dashboard.
      ref.invalidate(raizesVisitsProvider(
        RaizesVisitsArgs(ministryId: widget.ministryId, filter: _filter),
      ));
      ref.invalidate(raizesDashboardStatsProvider(widget.ministryId));
    }
  }

  Future<void> _sendWhatsApp(RaizesVisit visit) async {
    final messenger = ScaffoldMessenger.of(context);
    final phone = visit.visitorPhone;
    if (phone == null || phone.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Visitante sem telefone cadastrado.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final firstName = (visit.visitorName ?? '').trim().split(' ').first;
    final dd = visit.scheduledDate.day.toString().padLeft(2, '0');
    final mm = visit.scheduledDate.month.toString().padLeft(2, '0');
    final timePart = visit.scheduledTime != null
        ? ' às ${visit.scheduledTime!.split(':').take(2).join(':')}'
        : (visit.period != null ? ' (${visit.period!.label.toLowerCase()})' : '');
    final greet = firstName.isEmpty ? 'Olá' : 'Olá $firstName';
    final message =
        '$greet! Sou da igreja e gostaria de te visitar no dia $dd/$mm$timePart. '
        'Combina pra você?';

    final result = await launchWhatsAppMessage(phone: phone, message: message);
    if (!mounted) return;

    switch (result) {
      case WhatsAppLaunchResult.launched:
        try {
          final repo = ref.read(raizesRepositoryProvider);
          await repo.markVisitWhatsappReminderSent(visit.id);
          if (!mounted) return;
          ref.invalidate(raizesVisitsProvider(
            RaizesVisitsArgs(ministryId: widget.ministryId, filter: _filter),
          ));
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
    RaizesVisit visit,
    RaizesVisitStatus newStatus,
  ) async {
    final repo = ref.read(raizesRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.updateVisitStatus(
        visitId: visit.id,
        status: newStatus,
      );
      ref.invalidate(raizesVisitsProvider(
        RaizesVisitsArgs(ministryId: widget.ministryId, filter: _filter),
      ));
      ref.invalidate(raizesDashboardStatsProvider(widget.ministryId));
      messenger.showSnackBar(
        SnackBar(content: Text('Status atualizado: ${newStatus.label}')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Falha ao atualizar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _FilterBar extends StatelessWidget {
  final RaizesVisitsFilter value;
  final ValueChanged<RaizesVisitsFilter> onChanged;

  const _FilterBar({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _chip(context, RaizesVisitsFilter.todayAndOverdue, 'Hoje + atrasadas'),
          const SizedBox(width: 8),
          _chip(context, RaizesVisitsFilter.upcoming, 'Próximas'),
          const SizedBox(width: 8),
          _chip(context, RaizesVisitsFilter.all, 'Todas'),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    RaizesVisitsFilter f,
    String label,
  ) {
    final selected = value == f;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onChanged(f),
    );
  }
}

class _VisitCard extends StatelessWidget {
  final RaizesVisit visit;
  final ValueChanged<RaizesVisitStatus> onChangeStatus;
  final VoidCallback onSendWhatsApp;

  const _VisitCard({
    required this.visit,
    required this.onChangeStatus,
    required this.onSendWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final overdue = visit.isOverdue;
    final today = visit.isToday;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: overdue
              ? Colors.red.withValues(alpha: 0.4)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  visit.visitorName ?? 'Visitante',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusBadge(status: visit.status),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _meta(
                context,
                Icons.calendar_today,
                _formatDate(visit.scheduledDate) +
                    (today ? ' (hoje)' : overdue ? ' (atrasada)' : ''),
                color: overdue ? Colors.red : null,
              ),
              if (visit.scheduledTime != null)
                _meta(context, Icons.access_time,
                    _formatTime(visit.scheduledTime!)),
              if (visit.period != null && visit.scheduledTime == null)
                _meta(context, Icons.schedule, visit.period!.label),
              _meta(
                context,
                Icons.person,
                visit.assignedToName ?? 'Sem responsável',
                color: visit.assignedTo == null ? Colors.orange : null,
              ),
            ],
          ),
          if (visit.notes != null && visit.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              visit.notes!.trim(),
              style: CommunityDesign.metaStyle(context),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          _WhatsAppRow(
            phone: visit.visitorPhone,
            sentAt: visit.reminderWhatsappSentAt,
            onPressed: onSendWhatsApp,
          ),
          const SizedBox(height: 8),
          PermissionGate(
            permission: 'raizes.manage_visits',
            showLoading: false,
            child: _StatusActions(
              current: visit.status,
              onChange: onChangeStatus,
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(
    BuildContext context,
    IconData icon,
    String text, {
    Color? color,
  }) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: c)),
      ],
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  String _formatTime(String raw) {
    // raw vem como HH:mm:ss
    final parts = raw.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return raw;
  }
}

class _WhatsAppRow extends StatelessWidget {
  final String? phone;
  final DateTime? sentAt;
  final VoidCallback onPressed;

  const _WhatsAppRow({
    required this.phone,
    required this.sentAt,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhone = (phone ?? '').trim().isNotEmpty;
    final wasSent = sentAt != null;

    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: hasPhone ? onPressed : null,
          icon: const Icon(Icons.chat_bubble_outline, size: 16),
          label: Text(wasSent ? 'Reenviar WhatsApp' : 'Enviar WhatsApp'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF25D366),
            side: BorderSide(
              color: hasPhone
                  ? const Color(0xFF25D366).withValues(alpha: 0.6)
                  : Colors.grey.withValues(alpha: 0.3),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
        ),
        const SizedBox(width: 8),
        if (!hasPhone)
          Text(
            'Sem telefone',
            style: CommunityDesign.metaStyle(context).copyWith(
              fontStyle: FontStyle.italic,
            ),
          )
        else if (wasSent)
          Text(
            'Enviado em ${_formatSentAt(sentAt!)}',
            style: CommunityDesign.metaStyle(context),
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

class _StatusBadge extends StatelessWidget {
  final RaizesVisitStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _colorFor(RaizesVisitStatus s) {
    switch (s) {
      case RaizesVisitStatus.pending:
        return Colors.amber.shade800;
      case RaizesVisitStatus.confirmed:
        return Colors.blue.shade700;
      case RaizesVisitStatus.completed:
        return Colors.green.shade700;
      case RaizesVisitStatus.reschedule:
        return Colors.deepOrange;
      case RaizesVisitStatus.cancelled:
        return Colors.grey;
    }
  }
}

class _StatusActions extends StatelessWidget {
  final RaizesVisitStatus current;
  final ValueChanged<RaizesVisitStatus> onChange;

  const _StatusActions({required this.current, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final next = _nextActions(current);
    if (next.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: next
          .map(
            (s) => OutlinedButton(
              onPressed: () => onChange(s),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: Text(s.label, style: const TextStyle(fontSize: 12)),
            ),
          )
          .toList(),
    );
  }

  List<RaizesVisitStatus> _nextActions(RaizesVisitStatus s) {
    switch (s) {
      case RaizesVisitStatus.pending:
        return const [
          RaizesVisitStatus.confirmed,
          RaizesVisitStatus.completed,
          RaizesVisitStatus.reschedule,
          RaizesVisitStatus.cancelled,
        ];
      case RaizesVisitStatus.confirmed:
        return const [
          RaizesVisitStatus.completed,
          RaizesVisitStatus.reschedule,
          RaizesVisitStatus.cancelled,
        ];
      case RaizesVisitStatus.reschedule:
        return const [
          RaizesVisitStatus.pending,
          RaizesVisitStatus.cancelled,
        ];
      case RaizesVisitStatus.completed:
      case RaizesVisitStatus.cancelled:
        return const [];
    }
  }
}

class _EmptyState extends StatelessWidget {
  final RaizesVisitsFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final msg = switch (filter) {
      RaizesVisitsFilter.todayAndOverdue =>
        'Nenhuma visita pra hoje nem em atraso.',
      RaizesVisitsFilter.upcoming => 'Nenhuma visita futura ainda.',
      RaizesVisitsFilter.all => 'Nenhuma visita cadastrada.',
    };
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(Icons.event_available,
            size: 56, color: Theme.of(context).disabledColor),
        const SizedBox(height: 12),
        Center(
          child: Text(msg,
              style: TextStyle(color: Theme.of(context).disabledColor)),
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 32),
        const SizedBox(height: 8),
        Text(message),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Tentar de novo'),
          ),
        ),
      ],
    );
  }
}

// =====================================================
// Dialog de criação
// =====================================================

class _CreateVisitDialog extends ConsumerStatefulWidget {
  final String ministryId;
  const _CreateVisitDialog({required this.ministryId});

  @override
  ConsumerState<_CreateVisitDialog> createState() =>
      _CreateVisitDialogState();
}

class _CreateVisitDialogState extends ConsumerState<_CreateVisitDialog> {
  String? _visitorId;
  String? _assignedTo;
  DateTime _date = DateTime.now();
  TimeOfDay? _time;
  RaizesVisitPeriod? _period;
  final _notes = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visitorsAsync = ref.watch(raizesEligibleVisitorsProvider);
    final assigneesAsync =
        ref.watch(raizesEligibleAssigneesProvider(widget.ministryId));

    return AlertDialog(
      title: const Text('Nova visita'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _visitorField(visitorsAsync),
              const SizedBox(height: 12),
              _assigneeField(assigneesAsync),
              const SizedBox(height: 12),
              _dateField(context),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _timeField(context)),
                  const SizedBox(width: 12),
                  Expanded(child: _periodField()),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(
                  labelText: 'Observações',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: (_saving || _visitorId == null) ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Criar'),
        ),
      ],
    );
  }

  Widget _visitorField(AsyncValue<List<Map<String, String>>> async) {
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Falha ao carregar visitantes: $e',
          style: const TextStyle(color: Colors.red)),
      data: (list) {
        return DropdownButtonFormField<String>(
          initialValue: _visitorId,
          decoration: const InputDecoration(
            labelText: 'Visitante *',
            border: OutlineInputBorder(),
          ),
          items: list
              .map((v) => DropdownMenuItem(
                    value: v['id'],
                    child: Text(v['name'] ?? ''),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _visitorId = v),
        );
      },
    );
  }

  Widget _assigneeField(AsyncValue<List<Map<String, String>>> async) {
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Falha ao carregar responsáveis: $e',
          style: const TextStyle(color: Colors.red)),
      data: (list) {
        return DropdownButtonFormField<String?>(
          initialValue: _assignedTo,
          decoration: const InputDecoration(
            labelText: 'Responsável (membro do Raízes)',
            border: OutlineInputBorder(),
          ),
          items: <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Sem responsável'),
            ),
            ...list.map(
              (v) => DropdownMenuItem<String?>(
                value: v['id'],
                child: Text(v['name'] ?? ''),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _assignedTo = v),
        );
      },
    );
  }

  Widget _dateField(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) setState(() => _date = picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Data *',
          border: OutlineInputBorder(),
        ),
        child: Text(
          '${_date.day.toString().padLeft(2, '0')}/'
          '${_date.month.toString().padLeft(2, '0')}/${_date.year}',
        ),
      ),
    );
  }

  Widget _timeField(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _time ?? const TimeOfDay(hour: 19, minute: 0),
        );
        if (picked != null) {
          setState(() {
            _time = picked;
            _period = null; // hora exclui período
          });
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Horário',
          border: OutlineInputBorder(),
        ),
        child: Text(_time == null
            ? '—'
            : '${_time!.hour.toString().padLeft(2, '0')}:'
                '${_time!.minute.toString().padLeft(2, '0')}'),
      ),
    );
  }

  Widget _periodField() {
    return DropdownButtonFormField<RaizesVisitPeriod?>(
      initialValue: _period,
      decoration: const InputDecoration(
        labelText: 'ou Período',
        border: OutlineInputBorder(),
      ),
      items: <DropdownMenuItem<RaizesVisitPeriod?>>[
        const DropdownMenuItem<RaizesVisitPeriod?>(value: null, child: Text('—')),
        ...RaizesVisitPeriod.values.map(
          (p) => DropdownMenuItem<RaizesVisitPeriod?>(
            value: p,
            child: Text(p.label),
          ),
        ),
      ],
      onChanged: (p) => setState(() {
        _period = p;
        if (p != null) _time = null;
      }),
    );
  }

  Future<void> _save() async {
    if (_visitorId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(raizesRepositoryProvider);
      await repo.createVisit(
        ministryId: widget.ministryId,
        visitorId: _visitorId!,
        assignedTo: _assignedTo,
        scheduledDate: DateTime(_date.year, _date.month, _date.day),
        scheduledTime: _time == null
            ? null
            : '${_time!.hour.toString().padLeft(2, '0')}:'
                '${_time!.minute.toString().padLeft(2, '0')}:00',
        period: _period,
        notes:
            _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
