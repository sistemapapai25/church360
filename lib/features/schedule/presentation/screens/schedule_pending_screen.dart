import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/csv_writer.dart';
import '../../../../core/utils/file_download.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';
import '../../../notifications/domain/models/notification.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../providers/schedule_provider.dart';

/// Lote 4: tela dedicada de pendências de escala. Substitui o diálogo
/// anterior. Suporta filtros por status / ministério / função / intervalo
/// de datas e mantém as ações "Resolvi manualmente" / "Descartar".
class SchedulePendingScreen extends ConsumerStatefulWidget {
  /// Ministério inicial selecionado. Pode ser null para "todos".
  final String? initialMinistryId;
  const SchedulePendingScreen({super.key, this.initialMinistryId});

  @override
  ConsumerState<SchedulePendingScreen> createState() =>
      _SchedulePendingScreenState();
}

class _SchedulePendingScreenState extends ConsumerState<SchedulePendingScreen> {
  /// Status atual do filtro. null = todos. Default = 'open' (caso de uso
  /// mais frequente: revisar pendências em aberto).
  String? _status = 'open';
  String? _ministryId;
  /// Lote 7: filtro de atribuição. null = todos, '__mine__' = pendências
  /// atribuídas ao usuário atual, '__unassigned__' = sem responsável.
  String? _assignedFilter;
  final TextEditingController _funcCtrl = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;

  bool _loading = false;
  List<Map<String, dynamic>> _items = const [];
  Map<String, String> _assigneeNames = const {};
  Object? _error;

  @override
  void initState() {
    super.initState();
    _ministryId = widget.initialMinistryId;
    _refresh();
  }

  @override
  void dispose() {
    _funcCtrl.dispose();
    super.dispose();
  }

  String? get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;

  /// Traduz `_assignedFilter` em string aceita pela repo. '__mine__' vira
  /// o auth uid do usuário atual; '__unassigned__' passa direto.
  String? _resolvedAssignedFilter() {
    if (_assignedFilter == '__mine__') {
      return _currentUserId;
    }
    return _assignedFilter;
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(scheduleAuditRepositoryProvider);
      final items = await repo.listPendings(
        status: _status,
        ministryId: _ministryId,
        funcName: _funcCtrl.text.trim().isEmpty ? null : _funcCtrl.text.trim(),
        assignedTo: _resolvedAssignedFilter(),
        fromDate: _fromDate,
        toDate: _toDate,
      );
      // Pre-load nomes dos responsáveis para mostrar nos cards.
      final assigneeIds = items
          .map((p) => p['assigned_to']?.toString())
          .where((v) => v != null && v.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();
      final names = assigneeIds.isEmpty
          ? const <String, String>{}
          : await repo.getUserNamesByAuthIds(assigneeIds);
      if (!mounted) return;
      setState(() {
        _items = items;
        _assigneeNames = names;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: (_fromDate != null && _toDate != null)
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
      locale: const Locale('pt', 'BR'),
    );
    if (picked == null) return;
    setState(() {
      _fromDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
      _toDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
    });
    _refresh();
  }

  void _clearDate() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    _refresh();
  }

  Future<void> _markResolved(String id) async {
    final repo = ref.read(scheduleAuditRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.markResolved(id);
      messenger.showSnackBar(const SnackBar(content: Text('Marcada como resolvida.')));
      await _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Future<void> _markDismissed(String id) async {
    final repo = ref.read(scheduleAuditRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.markDismissed(id);
      messenger.showSnackBar(const SnackBar(content: Text('Descartada.')));
      await _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  /// Lote 7.1: exporta as pendências filtradas atuais como CSV.
  /// Na web baixa direto via data URL; em outras plataformas copia o CSV
  /// pra área de transferência (fallback simples).
  Future<void> _exportCsv() async {
    final csv = CsvWriter([
      'Data evento',
      'Evento',
      'Ministério',
      'Função',
      'Esperado',
      'Inseridos',
      'Motivo',
      'Status',
      'Responsável',
      'Criada em',
      'Resolvida em',
      'Nota de resolução',
    ]);
    final dtFmt = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
    for (final p in _items) {
      final ev = (p['event'] as Map?)?.cast<String, dynamic>();
      final evStart = ev?['start_date']?.toString();
      final evDate = evStart != null ? DateTime.tryParse(evStart) : null;
      final mn = (p['ministry'] as Map?)?.cast<String, dynamic>();
      final aid = p['assigned_to']?.toString();
      final createdRaw = p['created_at']?.toString();
      final created = createdRaw != null ? DateTime.tryParse(createdRaw) : null;
      final resolvedRaw = p['resolved_at']?.toString();
      final resolved =
          resolvedRaw != null ? DateTime.tryParse(resolvedRaw) : null;
      csv.addRow([
        evDate != null ? dtFmt.format(evDate) : '',
        ev?['name']?.toString() ?? '',
        mn?['name']?.toString() ?? '',
        p['func_name']?.toString() ?? '',
        p['expected'] ?? 0,
        p['inserted'] ?? 0,
        p['reason']?.toString() ?? '',
        p['status']?.toString() ?? '',
        aid == null || aid.isEmpty
            ? ''
            : (_assigneeNames[aid] ?? aid),
        created != null ? dtFmt.format(created) : '',
        resolved != null ? dtFmt.format(resolved) : '',
        p['resolution_note']?.toString() ?? '',
      ]);
    }
    final filename =
        'pendencias_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    final messenger = ScaffoldMessenger.of(context);
    final body = csv.build();
    if (kIsWeb) {
      downloadCsv(filename, body);
      messenger.showSnackBar(SnackBar(content: Text('CSV baixado: $filename')));
    } else {
      await Clipboard.setData(ClipboardData(text: body));
      messenger.showSnackBar(
        const SnackBar(content: Text('CSV copiado para a área de transferência.')),
      );
    }
  }

  /// Lote 7: abre diálogo com líderes/coordenadores do ministério da
  /// pendência e atribui a pendência ao escolhido. Passando `null` (limpar)
  /// remove a atribuição.
  Future<void> _assignPending(Map<String, dynamic> item) async {
    final ministryId = item['ministry_id']?.toString();
    if (ministryId == null || ministryId.isEmpty) return;
    final repo = ref.read(scheduleAuditRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    List<Map<String, String>> assignees;
    try {
      assignees = await repo.listMinistryAssignees(ministryId);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erro ao listar líderes: $e')));
      return;
    }
    if (!mounted) return;
    final currentAssigned = item['assigned_to']?.toString();
    final picked = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Atribuir pendência'),
          content: SizedBox(
            width: 320,
            child: assignees.isEmpty
                ? const Text(
                    'Ministério sem líderes/coordenadores com conta de acesso.')
                : ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person_off_outlined),
                        title: const Text('Sem responsável'),
                        selected: currentAssigned == null,
                        onTap: () => Navigator.pop<String?>(ctx, null),
                      ),
                      const Divider(height: 1),
                      for (final a in assignees)
                        ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(a['name'] ?? ''),
                          selected: a['auth_user_id'] == currentAssigned,
                          onTap: () =>
                              Navigator.pop<String?>(ctx, a['auth_user_id']),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop<String?>(ctx, currentAssigned),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
    // Convenção: se o usuário cancelar (currentAssigned voltou igual),
    // não persiste. Se trocou (incluindo "Sem responsável"), persiste.
    if (picked == currentAssigned) return;
    try {
      await repo.assignPending(item['id'].toString(), picked);
      // Lote 8: dispara notificação para o novo responsável quando há
      // atribuição (não notifica se foi desatribuído ou se o líder se
      // auto-atribuiu — neste último caso a pessoa já sabe).
      if (picked != null && picked.isNotEmpty && picked != _currentUserId) {
        await _notifyAssignee(picked, item, assignees);
      }
      messenger.showSnackBar(SnackBar(
        content: Text(picked == null
            ? 'Atribuição removida.'
            : 'Pendência atribuída.'),
      ));
      await _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  /// Lote 8: cria registro em `notifications` para o coordenador escolhido,
  /// linkando rota `/schedule/pending` para deep-link no app. Falha silenciosa
  /// se a inserção der erro (notificação é side effect, não bloqueia o fluxo).
  Future<void> _notifyAssignee(
    String targetAuthUserId,
    Map<String, dynamic> item,
    List<Map<String, String>> assignees,
  ) async {
    final notifRepo = ref.read(notificationRepositoryProvider);
    final ev = (item['event'] as Map?)?.cast<String, dynamic>();
    final mn = (item['ministry'] as Map?)?.cast<String, dynamic>();
    final eventName = ev?['name']?.toString() ?? 'Evento';
    final ministryName = mn?['name']?.toString() ?? '';
    final funcName = item['func_name']?.toString() ?? '';
    final expected = item['expected'] ?? 0;
    final inserted = item['inserted'] ?? 0;
    final body = StringBuffer(
        'Você foi designado para resolver uma pendência em $eventName');
    if (ministryName.isNotEmpty) body.write(' · $ministryName');
    if (funcName.isNotEmpty) {
      body.write(' — $funcName ($inserted/$expected).');
    } else {
      body.write('.');
    }
    await notifRepo.createNotificationForUser(
      targetUserId: targetAuthUserId,
      type: NotificationType.schedulePendingAssigned,
      title: 'Pendência de escala atribuída',
      body: body.toString(),
      data: {
        'pending_id': item['id']?.toString(),
        'event_id': item['event_id']?.toString(),
        'ministry_id': item['ministry_id']?.toString(),
        'func_name': funcName,
      },
      route: '/schedule/pending',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ministriesAsync = ref.watch(allMinistriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendências de escala'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Exportar CSV',
            onPressed:
                (_loading || _items.isEmpty) ? null : _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(ministriesAsync),
          const Divider(height: 1),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildFilters(AsyncValue ministriesAsync) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ExpansionTile(
        title: const Text('Filtros'),
        subtitle: Text(_filterSummary(), maxLines: 1, overflow: TextOverflow.ellipsis),
        initiallyExpanded: false,
        childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('Abertas'),
                selected: _status == 'open',
                onSelected: (_) {
                  setState(() => _status = 'open');
                  _refresh();
                },
              ),
              ChoiceChip(
                label: const Text('Resolvidas'),
                selected: _status == 'resolved',
                onSelected: (_) {
                  setState(() => _status = 'resolved');
                  _refresh();
                },
              ),
              ChoiceChip(
                label: const Text('Descartadas'),
                selected: _status == 'dismissed',
                onSelected: (_) {
                  setState(() => _status = 'dismissed');
                  _refresh();
                },
              ),
              ChoiceChip(
                label: const Text('Todas'),
                selected: _status == null,
                onSelected: (_) {
                  setState(() => _status = null);
                  _refresh();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          ministriesAsync.when(
            data: (ms) {
              final items = (ms as List).cast<dynamic>();
              return DropdownButtonFormField<String?>(
                initialValue: _ministryId,
                decoration: const InputDecoration(
                  labelText: 'Ministério',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
                  for (final m in items)
                    DropdownMenuItem<String?>(
                      value: m.id.toString(),
                      child: Text(m.name.toString()),
                    ),
                ],
                onChanged: (v) {
                  setState(() => _ministryId = v);
                  _refresh();
                },
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Erro ao carregar ministérios: $e'),
          ),
          const SizedBox(height: 8),
          // Lote 7: filtros de atribuição.
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Responsável:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('Todas'),
                selected: _assignedFilter == null,
                onSelected: (_) {
                  setState(() => _assignedFilter = null);
                  _refresh();
                },
              ),
              ChoiceChip(
                label: const Text('Minhas'),
                selected: _assignedFilter == '__mine__',
                onSelected: _currentUserId == null
                    ? null
                    : (_) {
                        setState(() => _assignedFilter = '__mine__');
                        _refresh();
                      },
              ),
              ChoiceChip(
                label: const Text('Sem responsável'),
                selected: _assignedFilter == '__unassigned__',
                onSelected: (_) {
                  setState(() => _assignedFilter = '__unassigned__');
                  _refresh();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _funcCtrl,
            decoration: InputDecoration(
              labelText: 'Função (texto exato)',
              hintText: 'ex.: Violão',
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: _funcCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _funcCtrl.clear();
                        _refresh();
                      },
                    ),
            ),
            onSubmitted: (_) => _refresh(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: Text(_fromDate == null
                      ? 'Período (data do evento)'
                      : '${DateFormat('dd/MM/yy').format(_fromDate!)} → ${DateFormat('dd/MM/yy').format(_toDate!)}'),
                  onPressed: _pickRange,
                ),
              ),
              if (_fromDate != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Limpar período',
                  onPressed: _clearDate,
                ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  String _filterSummary() {
    final parts = <String>[];
    parts.add(switch (_status) {
      'open' => 'Abertas',
      'resolved' => 'Resolvidas',
      'dismissed' => 'Descartadas',
      _ => 'Todas',
    });
    if (_ministryId != null) parts.add('1 ministério');
    final func = _funcCtrl.text.trim();
    if (func.isNotEmpty) parts.add('função: $func');
    if (_assignedFilter == '__mine__') {
      parts.add('minhas');
    } else if (_assignedFilter == '__unassigned__') {
      parts.add('sem responsável');
    }
    if (_fromDate != null) {
      parts.add(
          '${DateFormat('dd/MM').format(_fromDate!)}→${DateFormat('dd/MM').format(_toDate!)}');
    }
    return parts.join(' · ');
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Colors.red),
              const SizedBox(height: 8),
              Text('Erro: $_error', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: _refresh, child: const Text('Tentar de novo')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_turned_in_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 8),
              const Text('Sem pendências para os filtros atuais.'),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final p = _items[i];
          final aid = p['assigned_to']?.toString();
          final assigneeName = (aid != null && aid.isNotEmpty)
              ? (_assigneeNames[aid] ?? aid)
              : null;
          return _PendingCard(
            item: p,
            assigneeName: assigneeName,
            onResolved: () => _markResolved(p['id'].toString()),
            onDismissed: () => _markDismissed(p['id'].toString()),
            onAssign: () => _assignPending(p),
          );
        },
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final Map<String, dynamic> item;
  /// Nome do responsável já resolvido pelo state da tela (null = sem
  /// responsável atribuído).
  final String? assigneeName;
  final VoidCallback onResolved;
  final VoidCallback onDismissed;
  final VoidCallback onAssign;
  const _PendingCard({
    required this.item,
    required this.assigneeName,
    required this.onResolved,
    required this.onDismissed,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final eventMap = (item['event'] as Map?)?.cast<String, dynamic>();
    final eventName = eventMap?['name']?.toString() ?? '(evento)';
    final startDateStr = eventMap?['start_date']?.toString();
    final eventDate = startDateStr != null ? DateTime.tryParse(startDateStr) : null;
    final eventDateTxt = eventDate != null
        ? DateFormat('dd/MM/yy HH:mm', 'pt_BR').format(eventDate)
        : '';
    final ministryMap = (item['ministry'] as Map?)?.cast<String, dynamic>();
    final ministryName = ministryMap?['name']?.toString() ?? '';
    final funcName = item['func_name']?.toString() ?? '';
    final expected = item['expected'] ?? 0;
    final inserted = item['inserted'] ?? 0;
    final reason = item['reason']?.toString() ?? '';
    final status = item['status']?.toString() ?? 'open';
    final resolutionNote = item['resolution_note']?.toString();
    final resolvedAt = item['resolved_at']?.toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(eventName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                _statusPill(status),
              ],
            ),
            if (eventDateTxt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(eventDateTxt, style: const TextStyle(fontSize: 12)),
              ),
            if (ministryName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(ministryName,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ),
            const SizedBox(height: 6),
            // Lote 7: badge do responsável (ou "Sem responsável").
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    assigneeName != null
                        ? Icons.person
                        : Icons.person_off_outlined,
                    size: 14,
                    color: assigneeName != null
                        ? Colors.blue.shade700
                        : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    assigneeName ?? 'Sem responsável',
                    style: TextStyle(
                      fontSize: 11,
                      color: assigneeName != null
                          ? Colors.blue.shade700
                          : Colors.grey.shade600,
                      fontWeight: assigneeName != null
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Text('$funcName: $inserted/$expected',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            if (reason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(reason,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
              ),
            if (status != 'open' && resolvedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${status == 'resolved' ? 'Resolvida' : 'Descartada'} em '
                  '${DateFormat('dd/MM/yy HH:mm', 'pt_BR').format(DateTime.parse(resolvedAt))}'
                  '${resolutionNote != null && resolutionNote.isNotEmpty ? ' · $resolutionNote' : ''}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            if (status == 'open') ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: onResolved,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Resolvi manualmente'),
                  ),
                  TextButton.icon(
                    onPressed: onDismissed,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Descartar'),
                  ),
                  // Lote 7: atribuir/reatribuir responsável.
                  TextButton.icon(
                    onPressed: onAssign,
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: Text(
                        assigneeName == null ? 'Atribuir' : 'Reatribuir'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    final (color, label) = switch (status) {
      'resolved' => (Colors.green, 'Resolvida'),
      'dismissed' => (Colors.grey, 'Descartada'),
      _ => (Colors.orange, 'Aberta'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}
