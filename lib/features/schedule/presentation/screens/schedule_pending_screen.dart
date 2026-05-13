import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../ministries/presentation/providers/ministries_provider.dart';
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
  final TextEditingController _funcCtrl = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;

  bool _loading = false;
  List<Map<String, dynamic>> _items = const [];
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
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
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

  @override
  Widget build(BuildContext context) {
    final ministriesAsync = ref.watch(allMinistriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendências de escala'),
        actions: [
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
        itemBuilder: (_, i) => _PendingCard(
          item: _items[i],
          onResolved: () => _markResolved(_items[i]['id'].toString()),
          onDismissed: () => _markDismissed(_items[i]['id'].toString()),
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onResolved;
  final VoidCallback onDismissed;
  const _PendingCard({
    required this.item,
    required this.onResolved,
    required this.onDismissed,
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
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onResolved,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Resolvi manualmente'),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: onDismissed,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Descartar'),
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
