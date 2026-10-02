import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_filter_bar.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../domain/ministry_stock.dart';
import '../providers/ministry_stock_providers.dart';
import 'ministry_stock_sheets.dart';

/// Lado Auditoria da aba Financeiro (canvas tela 7): quem fez o quê no
/// Caixa e no Estoque, com o antes e o depois.
///
/// Os filtros rodam no cliente sobre o feed (`ministry_audit_feed`, até 500
/// linhas). Quem não pode auditar nem chega aqui; se chegasse, o banco
/// devolveria lista vazia.
class MinistryAuditView extends ConsumerStatefulWidget {
  final String ministryId;

  const MinistryAuditView({super.key, required this.ministryId});

  @override
  ConsumerState<MinistryAuditView> createState() => _MinistryAuditViewState();
}

class _MinistryAuditViewState extends ConsumerState<MinistryAuditView> {
  String? _area; // null = todos
  String _who = ''; // '' = todas
  String _action = '';
  int _days = 30; // 0 = todo o período

  /// Escolha de uma opção; `''`/`0` é "todas".
  Future<T?> _pick<T>(String title, List<(T, String)> options, T current) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  title,
                  style: CommunityDesign.titleStyle(
                    context,
                  ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              for (final o in options)
                ListTile(
                  title: Text(o.$2),
                  trailing: o.$1 == current
                      ? const Icon(Icons.check, size: 18)
                      : null,
                  onTap: () => Navigator.of(context).pop(o.$1),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(ministryAuditFeedProvider(widget.ministryId));

    return feedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Não deu para carregar a auditoria: $e'),
            TextButton(
              onPressed: () =>
                  ref.invalidate(ministryAuditFeedProvider(widget.ministryId)),
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
      data: (feed) {
        final people = {
          for (final e in feed)
            if (e.who != null) e.who!,
        }.toList()..sort();
        final actions = {for (final e in feed) auditActionLabel(e)}.toList()
          ..sort();
        final since = _days == 0
            ? null
            : DateTime.now().subtract(Duration(days: _days));
        final visible = feed.where((e) {
          if (_area != null && e.area != _area) return false;
          if (_who.isNotEmpty && e.who != _who) return false;
          if (_action.isNotEmpty && auditActionLabel(e) != _action) {
            return false;
          }
          if (since != null && e.happenedAt.isBefore(since)) return false;
          return true;
        }).toList();

        return RefreshIndicator(
          onRefresh: () =>
              ref.refresh(ministryAuditFeedProvider(widget.ministryId).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              Wrap(
                spacing: 6,
                children: [
                  for (final (key, label) in [
                    (null, 'Todos'),
                    ('caixa', 'Caixa'),
                    ('estoque', 'Estoque'),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _area == key,
                      onSelected: (_) => setState(() => _area = key),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    AppFilterButton(
                      label: _who.isEmpty ? 'Pessoa' : _who,
                      active: _who.isNotEmpty,
                      onTap: () async {
                        final v = await _pick('Pessoa', [
                          ('', 'Todas'),
                          for (final p in people) (p, p),
                        ], _who);
                        if (v != null) setState(() => _who = v);
                      },
                    ),
                    const SizedBox(width: 8),
                    AppFilterButton(
                      label: _days == 0
                          ? 'Todo o período'
                          : 'Últimos $_days dias',
                      active: _days != 30,
                      onTap: () async {
                        final v = await _pick('Período', [
                          (7, 'Últimos 7 dias'),
                          (30, 'Últimos 30 dias'),
                          (90, 'Últimos 90 dias'),
                          (0, 'Todo o período'),
                        ], _days);
                        if (v != null) setState(() => _days = v);
                      },
                    ),
                    const SizedBox(width: 8),
                    AppFilterButton(
                      label: _action.isEmpty ? 'Ação' : _action,
                      active: _action.isNotEmpty,
                      onTap: () async {
                        final v = await _pick('Ação', [
                          ('', 'Todas'),
                          for (final a in actions) (a, a),
                        ], _action);
                        if (v != null) setState(() => _action = v);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    feed.isEmpty
                        ? 'Nada registrado ainda no caixa nem no estoque.'
                        : 'Nenhum registro com esses filtros.',
                    textAlign: TextAlign.center,
                    style: CommunityDesign.metaStyle(context),
                  ),
                ),
              for (final e in visible) _AuditCard(entry: e),
            ],
          ),
        );
      },
    );
  }
}

/// Rótulo da ação para o filtro e para o cartão.
String auditActionLabel(AuditEntry e) {
  final kind = StockMoveKind.from(e.action);
  if (!e.isCaixa && kind != null) return kind.label;
  return switch (e.action) {
    'CREATE' => e.isCaixa ? 'Lançamento criado' : 'Item cadastrado',
    'UPDATE' => 'Edição',
    'DELETE' => 'Exclusão',
    'STATUS_CHANGE' => e.isCaixa ? 'Mudança de status' : 'Arquivamento',
    _ => e.action,
  };
}

final _money = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
final _date = DateFormat('dd/MM/yyyy');
final _dateTime = DateFormat('dd/MM/yyyy HH:mm');

const _caixaFields = {
  'valor': 'Valor',
  'descricao': 'Descrição',
  'vencimento': 'Data',
  'status': 'Status',
  'approval_status': 'Aprovação',
  'deleted_at': 'Excluído',
};

const _itemFields = {
  'name': 'Nome',
  'unit': 'Unidade',
  'category': 'Categoria',
  'location': 'Local',
  'min_quantity': 'Mínimo',
  'archived_at': 'Arquivado',
};

const _labels = {
  'EM_ABERTO': 'Em aberto',
  'PAGO': 'Pago',
  'PENDENTE': 'Pendente',
  'APROVADO': 'Aprovado',
  'REJEITADO': 'Rejeitado',
};

String _fmt(String field, Object? v) {
  if (v == null || (v is String && v.isEmpty)) return '—';
  switch (field) {
    case 'valor':
      return _money.format(num.tryParse('$v') ?? 0);
    case 'min_quantity':
      return formatStockQuantity(num.tryParse('$v') ?? 0);
    case 'vencimento':
      final d = DateTime.tryParse('$v');
      return d == null ? '$v' : _date.format(d);
    case 'deleted_at':
    case 'archived_at':
      return 'sim';
  }
  return _labels['$v'] ?? '$v';
}

/// Uma linha "campo: antes → depois" por campo que mudou.
List<(String, String, String)> auditDiff(AuditEntry e) {
  final fields = e.isCaixa ? _caixaFields : _itemFields;
  final antes = e.antes ?? const {};
  final depois = e.depois ?? const {};
  return [
    for (final f in fields.entries)
      if ('${antes[f.key]}' != '${depois[f.key]}')
        (f.value, _fmt(f.key, antes[f.key]), _fmt(f.key, depois[f.key])),
  ];
}

class _AuditCard extends StatelessWidget {
  final AuditEntry entry;

  const _AuditCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final muted = stockMuted(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StockBadge(
                  label: e.isCaixa ? 'Caixa' : 'Estoque',
                  color: e.isCaixa ? AppTheme.primary : AppTheme.successColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.subject ?? (e.isCaixa ? 'Lançamento' : 'Item'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._body(context),
            if (e.note != null) ...[
              const SizedBox(height: 4),
              Text('Obs.: ${e.note}', style: CommunityDesign.metaStyle(context)),
            ],
            const SizedBox(height: 6),
            Text(
              '${e.who ?? 'alguém'} · ${_dateTime.format(e.happenedAt)}',
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    final e = entry;
    const style = TextStyle(fontSize: 13.5);

    if (e.isMovement) {
      final kind = StockMoveKind.from(e.action)!;
      final delta = e.delta ?? 0;
      if (kind == StockMoveKind.conferencia) {
        final after = e.quantityAfter ?? 0;
        return [
          Text.rich(
            TextSpan(
              style: style,
              children: [
                TextSpan(
                  text:
                      'Conferência: esperado ${formatStockQuantity(after - delta)}, '
                      'contado ${formatStockQuantity(after)} (',
                ),
                TextSpan(
                  text: formatStockDelta(delta),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: delta < 0 ? AppTheme.errorColor : null,
                  ),
                ),
                const TextSpan(text: ')'),
              ],
            ),
          ),
        ];
      }
      return [
        Text(
          '${kind.label}: ${formatStockDelta(delta)} · ficou '
          '${formatStockQuantity(e.quantityAfter ?? 0)}',
          style: style,
        ),
      ];
    }

    if (e.action == 'CREATE') {
      final d = e.depois ?? const {};
      final text = e.isCaixa
          ? [
              d['tipo'] == 'RECEITA' ? 'Entrada criada' : 'Saída criada',
              _fmt('valor', d['valor']),
              if (d['approval_status'] == 'PENDENTE') 'aguardando aprovação',
            ].join(' · ')
          : 'Item cadastrado';
      return [Text(text, style: style)];
    }
    if (e.action == 'DELETE') {
      return [const Text('Excluído', style: style)];
    }

    final diff = auditDiff(e);
    if (diff.isEmpty) return [Text(auditActionLabel(e), style: style)];
    return [
      for (final (label, before, after) in diff)
        Text.rich(
          TextSpan(
            style: style,
            children: [
              TextSpan(text: '$label: '),
              TextSpan(
                text: before,
                style: const TextStyle(decoration: TextDecoration.lineThrough),
              ),
              const TextSpan(text: ' → '),
              TextSpan(
                text: after,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
    ];
  }
}
