import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../ministries/presentation/providers/ministries_provider.dart';
import '../providers/schedule_provider.dart';

/// Lote 4: histórico de auditorias de geração de escala. Lê `schedule_audit`
/// com paginação por offset e filtros por status / ministério / período /
/// regras relaxadas. Detalhe do audit expande os slots JSON.
class ScheduleAuditHistoryScreen extends ConsumerStatefulWidget {
  final String? initialMinistryId;
  const ScheduleAuditHistoryScreen({super.key, this.initialMinistryId});

  @override
  ConsumerState<ScheduleAuditHistoryScreen> createState() =>
      _ScheduleAuditHistoryScreenState();
}

class _ScheduleAuditHistoryScreenState
    extends ConsumerState<ScheduleAuditHistoryScreen> {
  static const int _pageSize = 20;

  String? _status;
  String? _ministryId;
  DateTime? _fromDate;
  DateTime? _toDate;
  final Set<String> _relaxedRules = {};

  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  List<Map<String, dynamic>> _items = [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _ministryId = widget.initialMinistryId;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
      _hasMore = true;
    });
    try {
      final repo = ref.read(scheduleAuditRepositoryProvider);
      final items = await repo.listAudits(
        status: _status,
        ministryId: _ministryId,
        fromDate: _fromDate,
        toDate: _toDate,
        relaxedRulesAny: _relaxedRules.isEmpty ? null : _relaxedRules.toList(),
        limit: _pageSize,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _hasMore = items.length == _pageSize;
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

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final repo = ref.read(scheduleAuditRepositoryProvider);
      final next = await repo.listAudits(
        status: _status,
        ministryId: _ministryId,
        fromDate: _fromDate,
        toDate: _toDate,
        relaxedRulesAny: _relaxedRules.isEmpty ? null : _relaxedRules.toList(),
        limit: _pageSize,
        offset: _items.length,
      );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...next];
        _hasMore = next.length == _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loadingMore = false;
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

  @override
  Widget build(BuildContext context) {
    final ministriesAsync = ref.watch(allMinistriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de auditorias'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
            tooltip: 'Atualizar',
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
              for (final entry in const [
                ('Todos', null),
                ('OK', 'ok'),
                ('Parcial', 'partial'),
                ('Vazio', 'empty'),
              ])
                ChoiceChip(
                  label: Text(entry.$1),
                  selected: _status == entry.$2,
                  onSelected: (_) {
                    setState(() => _status = entry.$2);
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: Text(_fromDate == null
                      ? 'Período (geração)'
                      : '${DateFormat('dd/MM/yy').format(_fromDate!)} → ${DateFormat('dd/MM/yy').format(_toDate!)}'),
                  onPressed: _pickRange,
                ),
              ),
              if (_fromDate != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Limpar período',
                  onPressed: () {
                    setState(() {
                      _fromDate = null;
                      _toDate = null;
                    });
                    _refresh();
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Regras relaxadas (qualquer uma):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final rule in const [
                ('min_days_between', 'min_days'),
                ('max_consecutive', 'consecutivos'),
                ('max_per_month', 'max/mês'),
              ])
                FilterChip(
                  label: Text(rule.$2),
                  selected: _relaxedRules.contains(rule.$1),
                  onSelected: (sel) {
                    setState(() {
                      if (sel) {
                        _relaxedRules.add(rule.$1);
                      } else {
                        _relaxedRules.remove(rule.$1);
                      }
                    });
                    _refresh();
                  },
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
      'ok' => 'OK',
      'partial' => 'Parciais',
      'empty' => 'Vazios',
      _ => 'Todos status',
    });
    if (_ministryId != null) parts.add('1 ministério');
    if (_fromDate != null) {
      parts.add(
          '${DateFormat('dd/MM').format(_fromDate!)}→${DateFormat('dd/MM').format(_toDate!)}');
    }
    if (_relaxedRules.isNotEmpty) parts.add('relax: ${_relaxedRules.length}');
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
              Icon(Icons.history,
                  size: 56,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 8),
              const Text('Nenhuma auditoria para os filtros atuais.'),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          if (i >= _items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: _loadingMore
                    ? const CircularProgressIndicator()
                    : OutlinedButton(
                        onPressed: _loadMore,
                        child: const Text('Carregar mais'),
                      ),
              ),
            );
          }
          return _AuditCard(item: _items[i]);
        },
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _AuditCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final eventMap = (item['event'] as Map?)?.cast<String, dynamic>();
    final eventName = eventMap?['name']?.toString() ?? '(evento)';
    final ministryMap = (item['ministry'] as Map?)?.cast<String, dynamic>();
    final ministryName = ministryMap?['name']?.toString();
    final generatedAtStr = item['generated_at']?.toString();
    final generatedAt =
        generatedAtStr != null ? DateTime.tryParse(generatedAtStr) : null;
    final generatedAtTxt = generatedAt != null
        ? DateFormat('dd/MM/yy HH:mm', 'pt_BR').format(generatedAt)
        : '';
    final status = item['status']?.toString() ?? 'ok';
    final totalExpected = item['total_expected'] ?? 0;
    final totalInserted = item['total_inserted'] ?? 0;
    final generalNote = item['general_note']?.toString();
    final relaxedRules = (item['relaxed_rules'] as List?)?.cast<dynamic>() ?? const [];
    final slots = (item['slots'] as List?)?.cast<dynamic>() ?? const [];

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Row(
          children: [
            Expanded(
              child: Text(eventName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ),
            _statusPill(status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ministryName != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(ministryName,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '$generatedAtTxt · $totalInserted/$totalExpected escalados',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            if (relaxedRules.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final r in relaxedRules)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          border: Border.all(color: Colors.amber.shade700),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('relaxado: ${r.toString()}',
                            style: TextStyle(
                                fontSize: 10, color: Colors.amber.shade900)),
                      ),
                  ],
                ),
              ),
          ],
        ),
        children: [
          if (generalNote != null && generalNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(generalNote,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
            ),
          if (slots.isEmpty)
            const Text('(sem detalhes de slots)',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic))
          else
            ...slots.map((s) {
              final m = (s as Map).cast<String, dynamic>();
              final func = m['func_name']?.toString() ?? '';
              final expected = m['expected'] ?? 0;
              final inserted = m['inserted'] ?? 0;
              final reason = m['reason']?.toString() ?? '';
              final slotRelaxed = (m['relaxed_rules'] as List?)?.cast<dynamic>() ?? const [];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$func: $inserted/$expected',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    if (reason.isNotEmpty)
                      Text(reason,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade700)),
                    if (slotRelaxed.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                            'regras relaxadas neste slot: ${slotRelaxed.join(', ')}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.amber.shade900)),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _statusPill(String status) {
    final (color, label) = switch (status) {
      'ok' => (Colors.green, 'OK'),
      'partial' => (Colors.orange, 'Parcial'),
      'empty' => (Colors.red, 'Vazio'),
      _ => (Colors.grey, status),
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
