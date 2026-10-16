import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:printing/printing.dart';

import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/utils/whatsapp_launcher.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../domain/kids_badges_pdf.dart';
import '../../domain/models/kids_checkin.dart';
import '../providers/kids_providers.dart';

/// Balcão do Infantil (K3, cartilha §7): check-in pelo QR dos pais ou pelo
/// nome, "na sala agora" e check-out só para quem está autorizado.
///
/// Mora em dois lugares: a aba Check-in do ministério do tipo 'infantil' (a
/// equipe) e a aba Check-in de Kids - Gestão (kids.manage). Quem não é da
/// equipe (kids_is_team) vê só o aviso; o banco recusa as RPCs do mesmo jeito.
class KidsCheckinPanel extends ConsumerWidget {
  const KidsCheckinPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(kidsIsTeamProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(AppErrorHandler.userMessage(e, feature: 'kids.team')),
          ),
          data: (isTeam) => isTeam
              ? const _Board()
              : const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'O check-in das crianças é feito pela equipe do Infantil.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
        );
  }
}

class _Board extends ConsumerStatefulWidget {
  const _Board();

  @override
  ConsumerState<_Board> createState() => _BoardState();
}

class _BoardState extends ConsumerState<_Board> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<KidsChildCard>? _results;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _results = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final r = await ref.read(kidsRepositoryProvider).searchChildren(q);
        if (mounted && _search.text == q) setState(() => _results = r);
      } catch (e) {
        _error(e);
      }
    });
  }

  void _error(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppErrorHandler.userMessage(e, feature: 'kids.checkin')),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _done(String msg) {
    ref.invalidate(kidsBoardProvider);
    if (_search.text.trim().length >= 2) _onSearch(_search.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _scan() async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const _ScannerPage()));
    if (code == null || !mounted) return;
    try {
      final card = await ref.read(kidsRepositoryProvider).scan(code.trim());
      if (!mounted) return;
      if (card.isPresent) {
        await _checkOut(card, token: card.token, preselect: card.generatedBy);
      } else {
        await _checkIn(card, token: card.token);
      }
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _checkIn(KidsChildCard card, {String? token}) async {
    final rooms = await ref
        .read(kidsRoomsProvider.future)
        .catchError((_) => const <KidsRoom>[]);
    if (!mounted) return;
    String? roomId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('Check-in: ${card.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (card.age != null) Text('${card.age} anos'),
                _Alerts(card: card),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: roomId,
                  decoration: const InputDecoration(labelText: 'Sala'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Pela idade'),
                    ),
                    for (final r in rooms.where((r) => r.isActive))
                      DropdownMenuItem(
                        value: r.id,
                        child: Text('${r.name} (${r.ageLabel})'),
                      ),
                  ],
                  onChanged: (v) => setDialog(() => roomId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Fazer check-in'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final r = await ref
          .read(kidsRepositoryProvider)
          .checkIn(
            token: token,
            childId: token == null ? card.childId : null,
            roomId: roomId,
          );
      _done(
        r.roomName == null
            ? 'Check-in feito: ${r.name}'
            : 'Check-in feito: ${r.name} → ${r.roomName}',
      );
    } catch (e) {
      _error(e);
    }
  }

  /// Etiquetas das crianças na sala (K5): PDF para imprimir fora.
  Future<void> _badges(KidsBoard board) async {
    try {
      final bytes = await buildKidsBadgesPdf(
        board.present,
        eventName: board.eventName,
      );
      await Printing.sharePdf(bytes: bytes, filename: 'etiquetas_infantil.pdf');
    } catch (e) {
      _error(e);
    }
  }

  /// Aula de hoje + tarefa para casa (cartilha §3, K7).
  Future<void> _lesson() async {
    Map<String, dynamic>? current;
    try {
      current = await ref.read(kidsRepositoryProvider).getTodayLesson();
    } catch (e) {
      _error(e);
      return;
    }
    if (!mounted) return;
    final theme = TextEditingController(text: current?['theme'] as String?);
    final verse = TextEditingController(text: current?['verse'] as String?);
    final activity = TextEditingController(
      text: current?['activity'] as String?,
    );
    var notify = current?['notified_at'] == null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Aula de hoje'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: theme,
                  decoration: const InputDecoration(labelText: 'Tema'),
                ),
                TextField(
                  controller: verse,
                  decoration: const InputDecoration(labelText: 'Versículo'),
                ),
                TextField(
                  controller: activity,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Tarefa para casa (opcional)',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Avisar os pais agora'),
                  subtitle: const Text(
                    'Notifica os responsáveis das crianças com check-in hoje.',
                  ),
                  value: notify,
                  onChanged: (v) => setDialog(() => notify = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (theme.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final n = await ref
          .read(kidsRepositoryProvider)
          .saveLesson(
            theme: theme.text,
            verse: verse.text,
            activity: activity.text,
            notify: notify,
          );
      _done(
        notify
            ? 'Aula salva. $n ${n == 1 ? 'responsável avisado' : 'responsáveis avisados'}.'
            : 'Aula salva.',
      );
    } catch (e) {
      _error(e);
    }
  }

  /// Chama o responsável (cartilha §7.2): push aos pais e à Mídia (Data
  /// Show) e, se quiser, WhatsApp do celular da equipe.
  Future<void> _call(KidsChildCard card) async {
    final attendanceId = card.attendanceId;
    if (attendanceId == null) return;
    const reasons = [
      'Banheiro',
      'Chorando / com saudade',
      'Não está bem',
      'Outro',
    ];
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Chamar o responsável por ${card.name}'),
        children: [
          for (final r in reasons)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, r),
              child: Text(r),
            ),
        ],
      ),
    );
    if (reason == null) return;
    KidsCallResult result;
    try {
      result = await ref
          .read(kidsRepositoryProvider)
          .callGuardian(
            attendanceId,
            reason == 'Outro' ? null : reason.toLowerCase(),
          );
    } catch (e) {
      _error(e);
      return;
    }
    ref.invalidate(kidsBoardProvider);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Responsável chamado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.notified == 0
                  ? 'Nenhum responsável tem o app: use o WhatsApp abaixo.'
                  : 'Aviso enviado pelo app a ${result.notified} '
                        '${result.notified == 1 ? 'responsável' : 'responsáveis'}.',
            ),
            Text(
              result.media == 0
                  ? 'Ninguém da Mídia (Data Show) recebeu: o ministério precisa ter "Data Show" ou "Mídia" no nome.'
                  : 'A equipe da Mídia (Data Show) também foi avisada.',
            ),
            for (final p in result.phones)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.chat_outlined),
                title: Text(p.name),
                subtitle: const Text('Mandar WhatsApp'),
                onTap: () async {
                  final r = await launchWhatsAppMessage(
                    phone: p.phone,
                    message: result.message,
                  );
                  if (r != WhatsAppLaunchResult.launched && ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Não foi possível abrir o WhatsApp.'),
                      ),
                    );
                  }
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkOut(
    KidsChildCard card, {
    String? token,
    String? preselect,
  }) async {
    final attendanceId = card.attendanceId;
    if (attendanceId == null) return;
    List<KidsPicker> options;
    try {
      options = await ref
          .read(kidsRepositoryProvider)
          .getCheckoutOptions(attendanceId);
    } catch (e) {
      _error(e);
      return;
    }
    if (!mounted) return;
    String? picked = options.any((o) => o.userId == preselect)
        ? preselect
        : null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(
            'Retirar ${card.name} (etiqueta ${kidsPickupCode(card)})',
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: options.isEmpty
                ? const Text(
                    'Esta criança não tem ninguém autorizado a retirá-la. '
                    'Ela não sai sozinha: chame a liderança do Infantil e '
                    'cadastre o responsável na ficha.',
                  )
                : RadioGroup<String>(
                    groupValue: picked,
                    onChanged: (v) => setDialog(() => picked = v),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        const Text('Quem está retirando?'),
                        for (final o in options)
                          RadioListTile<String>(
                            value: o.userId,
                            title: Text(o.name),
                            subtitle: o.relationship == null
                                ? null
                                : Text(o.relationship!),
                          ),
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            if (options.isNotEmpty)
              FilledButton(
                onPressed: picked == null
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: const Text('Confirmar retirada'),
              ),
          ],
        ),
      ),
    );
    if (ok != true || picked == null) return;
    try {
      await ref
          .read(kidsRepositoryProvider)
          .checkOut(
            attendanceId: attendanceId,
            pickedUpBy: picked!,
            token: token,
          );
      _done('${card.name} foi retirada');
    } catch (e) {
      _error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final boardAsync = ref.watch(kidsBoardProvider);
    final board = boardAsync.asData?.value;
    final hasEvent = board?.hasEvent ?? false;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(kidsBoardProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppFilterBar(
            searchController: _search,
            searchHint: 'Buscar criança pelo nome',
            onSearchChanged: _onSearch,
            secondaryActions: [
              AppFilterAction(
                label: 'Aula de hoje',
                icon: Icons.menu_book_outlined,
                onPressed: hasEvent ? _lesson : null,
              ),
              AppFilterAction(
                label: 'Etiquetas',
                icon: Icons.badge_outlined,
                onPressed: (board?.present.isNotEmpty ?? false)
                    ? () => _badges(board!)
                    : null,
              ),
              AppFilterAction(
                label: 'Salas',
                icon: Icons.meeting_room_outlined,
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const _RoomsDialog(),
                ),
              ),
            ],
            primaryAction: AppFilterAction(
              label: 'Ler QR',
              icon: Icons.qr_code_scanner,
              onPressed: hasEvent ? _scan : null,
            ),
          ),
          const SizedBox(height: 12),
          boardAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) =>
                Text(AppErrorHandler.userMessage(e, feature: 'kids.board')),
            data: (b) => Text(
              b.hasEvent
                  ? '${b.eventName ?? 'Culto de hoje'} · ${b.present.length} na sala'
                        '${b.checkedOut > 0 ? ' · ${b.checkedOut} já retiradas' : ''}'
                  : 'Não há culto na Agenda de hoje. O check-in abre no dia do culto.',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (_results != null) ...[
            const SizedBox(height: 12),
            if (_results!.isEmpty) const Text('Nenhuma criança com esse nome.'),
            for (final c in _results!)
              _ChildTile(
                card: c,
                trailing:
                    (board?.present.any((p) => p.childId == c.childId) ?? false)
                    ? const Chip(label: Text('Na sala'))
                    : FilledButton(
                        onPressed: hasEvent ? () => _checkIn(c) : null,
                        child: const Text('Check-in'),
                      ),
              ),
            const Divider(height: 32),
          ],
          if (board != null && board.present.isNotEmpty) ...[
            Text(
              'Na sala agora',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final c in board.present)
              _ChildTile(
                card: c,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Chamar responsável',
                      icon: const Icon(Icons.campaign_outlined),
                      onPressed: () => _call(c),
                    ),
                    OutlinedButton(
                      onPressed: () => _checkOut(c),
                      child: const Text('Retirar'),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ChildTile extends StatelessWidget {
  final KidsChildCard card;
  final Widget trailing;

  const _ChildTile({required this.card, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final details = [
      if (card.age != null) '${card.age} anos',
      if (card.roomName != null) card.roomName!,
      if (card.checkInTime != null)
        'desde ${DateFormat('HH:mm').format(card.checkInTime!)}',
      if (card.lastCallAt != null)
        'chamado às ${DateFormat('HH:mm').format(card.lastCallAt!)}',
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: card.avatarUrl != null
              ? NetworkImage(card.avatarUrl!)
              : null,
          child: card.avatarUrl == null
              ? Text(card.name.characters.first.toUpperCase())
              : null,
        ),
        title: Text(card.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (details.isNotEmpty) Text(details),
            _Alerts(card: card, compact: true),
          ],
        ),
        trailing: trailing,
      ),
    );
  }
}

/// Selos do Balcão: alergia (cartilha §8.3), sem autorização de imagem
/// (§5.3) e cadastro incompleto (§6).
class _Alerts extends StatelessWidget {
  final KidsChildCard card;
  final bool compact;

  const _Alerts({required this.card, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final health = card.healthAlert;
    Widget chip(IconData icon, String label) => Chip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: Icon(icon, size: 16, color: error),
      label: Text(label, style: TextStyle(color: error, fontSize: 12)),
      side: BorderSide(color: error.withValues(alpha: 0.4)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if (card.foodAlert) chip(Icons.warning_amber_rounded, 'Alergia'),
            if (!card.imageConsent) chip(Icons.no_photography, 'Sem foto'),
            if (card.missing.isNotEmpty)
              chip(Icons.assignment_late_outlined, 'Cadastro incompleto'),
          ],
        ),
        if (!compact && health.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(health, style: TextStyle(color: error)),
        ],
        if (!compact && card.missing.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Falta no cadastro: ${card.missing.join(', ')}. '
            'Peça aos responsáveis para completar.',
          ),
        ],
      ],
    );
  }
}

class _ScannerPage extends StatefulWidget {
  const _ScannerPage();

  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ler QR da criança')),
      body: MobileScanner(
        onDetect: (capture) {
          final code = capture.barcodes
              .map((b) => b.rawValue)
              .whereType<String>()
              .firstOrNull;
          if (code == null || _handled) return;
          _handled = true;
          Navigator.of(context).pop(code);
        },
      ),
    );
  }
}

class _RoomsDialog extends ConsumerWidget {
  const _RoomsDialog();

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    KidsRoom? room,
  ) async {
    final name = TextEditingController(text: room?.name ?? '');
    final min = TextEditingController(text: room?.minAge?.toString() ?? '');
    final max = TextEditingController(text: room?.maxAge?.toString() ?? '');
    var active = room?.isActive ?? true;
    final saved = await showDialog<KidsRoom>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(room == null ? 'Nova sala' : 'Editar sala'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nome da sala'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: min,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Idade mín.',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: max,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Idade máx.',
                      ),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativa'),
                value: active,
                onChanged: (v) => setDialog(() => active = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(
                  ctx,
                  KidsRoom(
                    id: room?.id,
                    name: name.text.trim(),
                    minAge: int.tryParse(min.text.trim()),
                    maxAge: int.tryParse(max.text.trim()),
                    isActive: active,
                    sortOrder: room?.sortOrder ?? 0,
                  ),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (saved == null) return;
    try {
      await ref.read(kidsRepositoryProvider).saveRoom(saved);
      ref.invalidate(kidsRoomsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppErrorHandler.userMessage(e, feature: 'kids.room')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(kidsRoomsProvider);
    return AlertDialog(
      title: const Text('Salas do Infantil'),
      content: SizedBox(
        width: double.maxFinite,
        child: rooms.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Text(AppErrorHandler.userMessage(e, feature: 'kids.rooms')),
          data: (list) => list.isEmpty
              ? const Text(
                  'Nenhuma sala ainda. Crie as salas com a faixa de idade: o '
                  'check-in sugere a sala pela idade da criança.',
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final r in list)
                      ListTile(
                        title: Text(r.name),
                        subtitle: Text(
                          r.isActive ? r.ageLabel : '${r.ageLabel} · inativa',
                        ),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => _edit(context, ref, r),
                      ),
                  ],
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
        FilledButton.icon(
          onPressed: () => _edit(context, ref, null),
          icon: const Icon(Icons.add),
          label: const Text('Nova sala'),
        ),
      ],
    );
  }
}
