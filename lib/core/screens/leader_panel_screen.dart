import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/ministries/batismo/domain/baptism_pdf_renderer.dart'
    show pdfSafeText;

// G5 (roadmap 14/10, pedido de 16/10): "Seu painel", a tela do pastor/líder
// aberta pelo perfil da igreja. Tudo vem de uma RPC (`leader_panel`,
// migration 20261008008700): o pastor vê a igreja, o líder vê só os
// ministérios dele, e cada bloco só vem com a permissão do card equivalente
// da Dashboard. `null` = a pessoa não é pastor nem líder.

/// O jsonb da `leader_panel()`; `null` esconde a tela e o cartão.
final leaderPanelProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final res = await ref.watch(supabaseClientProvider).rpc('leader_panel');
  return res == null ? null : Map<String, dynamic>.from(res as Map);
});

final _money = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
final _day = DateFormat('dd/MM');

int _int(Object? v) => (v as num?)?.toInt() ?? 0;
List<Map<String, dynamic>> _list(Object? v) => [
  for (final e in (v as List?) ?? const []) Map<String, dynamic>.from(e as Map),
];

/// Um número dos últimos 30 dias, com o dos 30 anteriores quando há.
typedef _Stat = ({
  String label,
  String value,
  int? now,
  int? prev,
  String? note,
  IconData icon,
  Color color,
});

List<_Stat> _overview(Map<String, dynamic> p) {
  final presence = p['presence'] as Map?;
  final members = p['members'] as Map?;
  final visitors = p['visitors'] as Map?;
  final money = p['contributions'] as Map?;
  return [
    if (presence != null)
      (
        label: 'Presença média por culto',
        value: presence['avg'] == null ? '–' : '${_int(presence['avg'])}',
        now: presence['avg'] == null ? null : _int(presence['avg']),
        prev: presence['prev_avg'] == null ? null : _int(presence['prev_avg']),
        note: '${_int(presence['cultos'])} cultos',
        icon: Icons.groups_outlined,
        color: Colors.indigo,
      ),
    if (members != null) ...[
      (
        label: 'Novos membros',
        value: '${_int(members['new_members'])}',
        now: _int(members['new_members']),
        prev: _int(members['prev_new_members']),
        note: null,
        icon: Icons.person_add_alt_1_outlined,
        color: Colors.teal,
      ),
      (
        label: 'Batismos',
        value: '${_int(members['baptisms'])}',
        now: null,
        prev: null,
        note: null,
        icon: Icons.water_drop_outlined,
        color: Colors.lightBlue,
      ),
    ],
    if (p['graduations'] != null)
      (
        label: 'Formaturas (certificados)',
        value: '${_int(p['graduations'])}',
        now: null,
        prev: null,
        note: null,
        icon: Icons.school_outlined,
        color: Colors.deepPurple,
      ),
    if (visitors != null) ...[
      (
        label: 'Visitantes novos',
        value: '${_int(visitors['new'])}',
        now: null,
        prev: null,
        note: null,
        icon: Icons.waving_hand_outlined,
        color: Colors.orange,
      ),
      (
        label: 'Visitantes que voltaram',
        value: '${_int(visitors['returned'])}',
        now: null,
        prev: null,
        note: null,
        icon: Icons.replay_outlined,
        color: Colors.pink,
      ),
    ],
    if (money != null)
      (
        label: 'Contribuições recebidas',
        value: _money.format((money['total'] as num?) ?? 0),
        now: ((money['total'] as num?) ?? 0).round(),
        prev: ((money['prev_total'] as num?) ?? 0).round(),
        note: null,
        icon: Icons.savings_outlined,
        color: Colors.green,
      ),
  ];
}

/// `/dashboard/painel`.
class LeaderPanelScreen extends ConsumerWidget {
  const LeaderPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panel = ref.watch(leaderPanelProvider);
    final data = panel.valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seu painel'),
        actions: [
          if (data != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Resumo em PDF',
              onPressed: () => _sharePdf(data),
            ),
        ],
      ),
      body: panel.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Não deu para carregar o painel.\n$e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (p) => p == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'O painel é para pastores e líderes de ministério.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(leaderPanelProvider.future),
                child: _PanelBody(panel: p),
              ),
      ),
    );
  }
}

class _PanelBody extends StatelessWidget {
  const _PanelBody({required this.panel});

  final Map<String, dynamic> panel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = panel;
    final leader = p['scope'] == 'leader';
    final stats = _overview(p);
    final absent = p['absent_3'] as Map?;
    final noFollowup = p['visitors_no_followup'] as Map?;
    final gaps = p['schedule_gaps'] as Map?;
    final birthdays = _list(p['birthdays']);
    final health = _list(p['ministry_health']);

    Widget title(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _PanelHeader(
          title: leader ? 'Seus ministérios' : 'Visão da igreja',
          subtitle: leader
              ? (p['ministries'] as List? ?? const []).join(', ')
              : 'A igreja toda nos últimos 30 dias',
          attention: _attention(p),
        ),
        if (stats.isNotEmpty) ...[
          title('Últimos 30 dias'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final s in stats) _StatTile(stat: s)],
          ),
        ],
        title('Precisa da sua atenção'),
        if (absent != null)
          _PeopleTile(
            icon: Icons.person_off_outlined,
            color: Colors.deepOrange,
            label: 'Faltaram nos 3 últimos cultos',
            total: _int(absent['total']),
            people: _list(absent['people']),
          ),
        if (noFollowup != null)
          _PeopleTile(
            icon: Icons.support_agent,
            color: Colors.blue,
            label: 'Visitantes sem acompanhamento',
            total: _int(noFollowup['total']),
            people: _list(noFollowup['people']),
          ),
        if (gaps != null)
          _ListTileGroup(
            icon: Icons.event_busy_outlined,
            color: Colors.purple,
            label: 'Escalas sem gente (7 dias)',
            total: _int(gaps['total']),
            children: [
              for (final g in _list(gaps['items']))
                ListTile(
                  dense: true,
                  title: Text('${g['ministry_name']} · ${g['func_name']}'),
                  subtitle: Text(
                    '${g['event_name']} · ${_wallDay(g['start_date'])} · '
                    'faltam ${_int(g['missing'])}',
                  ),
                  onTap: () => context.push('/ministries/${g['ministry_id']}'),
                ),
            ],
          ),
        if (p['prayer_pending'] != null)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const _TintedIcon(
              Icons.volunteer_activism_outlined,
              Colors.pink,
            ),
            title: const Text('Pedidos de oração aguardando'),
            trailing: _Count(_int(p['prayer_pending'])),
            onTap: () => context.push('/prayer-requests?from=dashboard'),
          ),
        _PeopleTile(
          icon: Icons.cake_outlined,
          color: Colors.amber,
          label: 'Aniversariantes da semana',
          total: birthdays.length,
          people: birthdays,
          trailingOf: (b) => _day.format(DateTime.parse(b['day'] as String)),
          alert: false,
        ),
        if (health.isNotEmpty) ...[
          title('Saúde dos ministérios'),
          for (final m in health)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text('${m['name']}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_int(m['members'])} na equipe · '
                    '${_int(m['scheduled'])} escalados nos próximos 7 dias',
                  ),
                  if (_int(m['scheduled']) + _int(m['missing']) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value:
                              _int(m['scheduled']) /
                              (_int(m['scheduled']) + _int(m['missing'])),
                          color: _int(m['missing']) > 0
                              ? Colors.orange
                              : Colors.green,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                ],
              ),
              trailing: _int(m['missing']) > 0
                  ? Chip(
                      label: Text('faltam ${_int(m['missing'])}'),
                      visualDensity: VisualDensity.compact,
                    )
                  : const Icon(Icons.check_circle, color: Colors.green),
              onTap: () => context.push('/ministries/${m['id']}'),
            ),
        ],
        title('Ferramentas'),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: const Icon(Icons.picture_as_pdf_outlined),
          title: const Text('Resumo do mês em PDF'),
          onTap: () => _sharePdf(p),
        ),
        if (p['can_reports'] == true)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Relatórios'),
            onTap: () => context.push('/custom-reports'),
          ),
        if (p['can_analytics'] == true)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.analytics_outlined),
            title: const Text('Analytics'),
            onTap: () => context.push('/analytics'),
          ),
        if (p['can_message'] == true) const _MessageLeadersTile(),
      ],
    );
  }
}

/// `start_date` de evento é hora de parede de SP rotulada UTC: lê sem
/// converter fuso.
String _wallDay(Object? iso) {
  final d = DateTime.tryParse('${iso ?? ''}');
  return d == null
      ? ''
      : DateFormat('EEE dd/MM HH:mm', 'pt_BR').format(d.toUtc());
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});

  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (now, prev) = (stat.now, stat.prev);
    String? trend;
    Color? color;
    if (now != null && prev != null && prev > 0) {
      final pct = ((now - prev) * 100 / prev).round();
      trend = pct == 0
          ? '= 30 dias antes'
          : '${pct > 0 ? '▲' : '▼'} ${pct.abs()}%';
      color = pct > 0
          ? Colors.green
          : (pct < 0 ? theme.colorScheme.error : null);
    }
    return SizedBox(
      width: 160,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: stat.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: stat.color.withValues(alpha: 0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TintedIcon(stat.icon, stat.color),
              const SizedBox(height: 8),
              Text(
                stat.value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(stat.label, style: theme.textTheme.bodySmall),
              if (trend != null)
                Text(
                  trend,
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
              if (stat.note != null)
                Text(stat.note!, style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

int _attention(Map<String, dynamic> p) =>
    _int((p['absent_3'] as Map?)?['total']) +
    _int((p['visitors_no_followup'] as Map?)?['total']) +
    _int((p['schedule_gaps'] as Map?)?['total']) +
    _int(p['prayer_pending']);

/// Fundo em degradê da cor do tema, usado no topo do painel e no cartão.
BoxDecoration _heroDecoration(ColorScheme scheme) => BoxDecoration(
  borderRadius: BorderRadius.circular(20),
  gradient: LinearGradient(
    colors: [scheme.primary, scheme.tertiary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
);

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.subtitle,
    required this.attention,
  });

  final String title;
  final String subtitle;
  final int attention;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = theme.colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _heroDecoration(theme.colorScheme),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: on.withValues(alpha: 0.18),
            child: Icon(Icons.insights, color: on),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: on,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: on.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: on.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    attention > 0
                        ? attention == 1
                              ? '1 item pede sua atenção'
                              : '$attention itens pedem sua atenção'
                        : 'Tudo em dia por aqui',
                    style: theme.textTheme.labelMedium?.copyWith(color: on),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TintedIcon extends StatelessWidget {
  const _TintedIcon(this.icon, this.color);

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(icon, color: color, size: 20),
  );
}

class _Count extends StatelessWidget {
  const _Count(this.n, {this.alert = true});

  final int n;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 14,
      backgroundColor: n > 0 && alert
          ? scheme.errorContainer
          : scheme.surfaceContainerHighest,
      child: Text('$n', style: const TextStyle(fontSize: 12)),
    );
  }
}

class _ListTileGroup extends StatelessWidget {
  const _ListTileGroup({
    required this.icon,
    required this.label,
    required this.total,
    required this.children,
    required this.color,
    this.alert = true,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int total;
  final List<Widget> children;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: _TintedIcon(icon, color),
        title: Text(label),
        trailing: _Count(total, alert: alert),
      );
    }
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: _TintedIcon(icon, color),
      title: Text(label),
      trailing: _Count(total, alert: alert),
      children: children,
    );
  }
}

class _PeopleTile extends StatelessWidget {
  const _PeopleTile({
    required this.icon,
    required this.label,
    required this.total,
    required this.people,
    required this.color,
    this.trailingOf,
    this.alert = true,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int total;
  final List<Map<String, dynamic>> people;
  final String Function(Map<String, dynamic>)? trailingOf;
  final bool alert;

  @override
  Widget build(BuildContext context) => _ListTileGroup(
    icon: icon,
    color: color,
    label: label,
    total: total,
    alert: alert,
    children: [
      for (final person in people)
        ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 16,
            backgroundImage:
                (person['photo_url'] as String?)?.isNotEmpty == true
                ? NetworkImage(person['photo_url'] as String)
                : null,
            child: (person['photo_url'] as String?)?.isNotEmpty == true
                ? null
                : const Icon(Icons.person, size: 18),
          ),
          title: Text('${person['name'] ?? ''}'),
          trailing: trailingOf == null ? null : Text(trailingOf!(person)),
          onTap: () => context.push('/members/${person['id']}'),
        ),
      if (total > people.length)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text('e mais ${total - people.length}'),
        ),
    ],
  );
}

class _MessageLeadersTile extends ConsumerWidget {
  const _MessageLeadersTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    leading: const Icon(Icons.campaign_outlined),
    title: const Text('Mensagem para todos os líderes'),
    subtitle: const Text('Chega como notificação no celular'),
    onTap: () => _send(context, ref),
  );

  Future<void> _send(BuildContext context, WidgetRef ref) async {
    final titleCtl = TextEditingController();
    final bodyCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mensagem para os líderes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtl,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            TextField(
              controller: bodyCtl,
              maxLength: 1000,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Mensagem'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    final title = titleCtl.text.trim();
    final body = bodyCtl.text.trim();
    titleCtl.dispose();
    bodyCtl.dispose();
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (title.isEmpty || body.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Preencha o título e a mensagem.')),
      );
      return;
    }
    try {
      final n = await ref
          .read(supabaseClientProvider)
          .rpc(
            'panel_message_leaders',
            params: {'p_title': title, 'p_body': body},
          );
      messenger.showSnackBar(
        SnackBar(content: Text('Mensagem enviada para $n líderes.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Não deu para enviar: $e')),
      );
    }
  }
}

/// Resumo em PDF com o que o painel mostra. Fonte base do `pdf` só tem
/// Latin-1: todo texto passa por [pdfSafeText] e as setas viram palavras.
Future<void> _sharePdf(Map<String, dynamic> p) async {
  String t(String s) => pdfSafeText(s);
  final doc = pw.Document();
  final now = DateTime.now();
  final rows = <List<String>>[
    for (final s in _overview(p))
      [
        s.label,
        s.value,
        if (s.now != null && s.prev != null) '30 dias antes: ${s.prev}' else '',
      ],
  ];
  final absent = p['absent_3'] as Map?;
  final noFollowup = p['visitors_no_followup'] as Map?;
  final gaps = p['schedule_gaps'] as Map?;
  final attention = <List<String>>[
    if (absent != null)
      ['Faltaram nos 3 últimos cultos', '${_int(absent['total'])}'],
    if (noFollowup != null)
      ['Visitantes sem acompanhamento', '${_int(noFollowup['total'])}'],
    if (gaps != null)
      ['Vagas de escala sem gente (7 dias)', '${_int(gaps['total'])}'],
    if (p['prayer_pending'] != null)
      ['Pedidos de oração aguardando', '${_int(p['prayer_pending'])}'],
    ['Aniversariantes da semana', '${_list(p['birthdays']).length}'],
  ];
  final health = [
    for (final m in _list(p['ministry_health']))
      [
        '${m['name']}',
        '${_int(m['members'])}',
        '${_int(m['scheduled'])}',
        '${_int(m['missing'])}',
      ],
  ];

  pw.Widget table(List<String> head, List<List<String>> data) =>
      pw.TableHelper.fromTextArray(
        headers: head.map(t).toList(),
        data: [for (final r in data) r.map(t).toList()],
        cellStyle: const pw.TextStyle(fontSize: 10),
        headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => [
        pw.Text(
          t('Resumo do painel'),
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          t(
            p['scope'] == 'leader'
                ? 'Ministérios: ${(p['ministries'] as List? ?? const []).join(', ')}'
                : 'Igreja toda',
          ),
        ),
        pw.Text(
          t(
            'Gerado em ${DateFormat('dd/MM/yyyy HH:mm').format(now)} · últimos 30 dias',
          ),
        ),
        pw.SizedBox(height: 12),
        if (rows.isNotEmpty) table(['Número', 'Valor', 'Comparação'], rows),
        pw.SizedBox(height: 12),
        table(['Precisa de atenção', 'Total'], attention),
        if (health.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          table(['Ministério', 'Equipe', 'Escalados 7 dias', 'Faltam'], health),
        ],
      ],
    ),
  );
  await Printing.layoutPdf(
    onLayout: (_) async => doc.save(),
    name: 'resumo_painel_${DateFormat('yyyy_MM').format(now)}.pdf',
  );
}

/// Cartão "Seu painel" no perfil da igreja; some para quem não é pastor
/// nem líder (ou se o painel não carregar).
class LeaderPanelCard extends ConsumerWidget {
  const LeaderPanelCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(leaderPanelProvider).valueOrNull;
    if (p == null) return const SizedBox.shrink();
    final attention = _attention(p);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        key: const ValueKey('leader-panel-card'),
        color: Colors.transparent,
        child: Ink(
          decoration: _heroDecoration(scheme),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            iconColor: scheme.onPrimary,
            textColor: scheme.onPrimary,
            leading: CircleAvatar(
              backgroundColor: scheme.onPrimary.withValues(alpha: 0.18),
              child: Icon(Icons.insights, color: scheme.onPrimary),
            ),
            title: const Text(
              'Seu painel',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              attention > 0
                  ? attention == 1
                        ? '1 item precisa da sua atenção'
                        : '$attention itens precisam da sua atenção'
                  : 'Números da igreja e dos ministérios',
            ),
            trailing: attention > 0
                ? CircleAvatar(
                    radius: 14,
                    backgroundColor: scheme.error,
                    child: Text(
                      '$attention',
                      style: TextStyle(fontSize: 12, color: scheme.onError),
                    ),
                  )
                : const Icon(Icons.chevron_right),
            onTap: () => context.push('/dashboard/painel'),
          ),
        ),
      ),
    );
  }
}
