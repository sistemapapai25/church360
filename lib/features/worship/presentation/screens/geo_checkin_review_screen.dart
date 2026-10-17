import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/presence_deck.dart';
import '../../domain/models/worship_service.dart';
import '../providers/worship_provider.dart';
import '../../../../core/layout/readable_width.dart';

/// Conferência em cartas da presença pelo celular (16/10, "Match de
/// Presença" fase 1): uma carta por check-in pelo GPS ainda não validado.
/// Direita = presente (valida), esquerda = não está aqui (recusa).
///
/// Nada vai ao banco antes do "Salvar": recusar apaga a linha geo (RPC
/// `worship_attendance_validate`, 007100), então o Desfazer tem de ser local.
class GeoCheckinReviewScreen extends ConsumerStatefulWidget {
  final String worshipServiceId;

  const GeoCheckinReviewScreen({super.key, required this.worshipServiceId});

  /// Abre a conferência. Devolve quem foi recusado, ou nulo se nada foi salvo.
  static Future<Set<String>?> open(BuildContext context, String worshipServiceId) =>
      Navigator.of(context).push<Set<String>>(
        MaterialPageRoute(
          builder: (_) => GeoCheckinReviewScreen(worshipServiceId: worshipServiceId),
        ),
      );

  @override
  ConsumerState<GeoCheckinReviewScreen> createState() => _GeoCheckinReviewScreenState();
}

/// Check-ins pelo GPS que ainda esperam o diácono.
List<WorshipAttendance> pendingGeoCheckins(List<WorshipAttendance> all) =>
    all.where((a) => a.isGeo && !a.isValidated).toList();

/// "Check-in pelo GPS · 19:28 · 12 m" (ou "Confirmou pelo celular · …").
String geoCheckinHint(WorshipAttendance a) => [
  a.isConfirmed ? 'Confirmou pelo celular' : 'Check-in pelo GPS',
  DateFormat.Hm().format(a.checkedInAt.toLocal()),
  if (a.distanceM != null) '${a.distanceM} m',
].join(' · ');

class _GeoCheckinReviewScreenState extends ConsumerState<GeoCheckinReviewScreen> {
  late final Future<List<WorshipAttendance>> _load = ref
      .read(worshipRepositoryProvider)
      .getWorshipAttendance(widget.worshipServiceId)
      .then(pendingGeoCheckins);

  /// Decisões na ordem das cartas: memberId → presente.
  final Map<String, bool> _decisions = {};
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(worshipRepositoryProvider);
    final rejected = <String>{};
    final failed = <String>[];
    for (final MapEntry(key: id, value: ok) in _decisions.entries) {
      try {
        await repo.validateCheckin(widget.worshipServiceId, id, ok: ok);
        if (!ok) rejected.add(id);
      } catch (_) {
        failed.add(id);
      }
    }
    if (!mounted) return;
    ref.invalidate(worshipAttendanceProvider(widget.worshipServiceId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed.isEmpty
              ? 'Conferência salva.'
              : '${failed.length} não salvaram. Tente de novo na aba Pelo celular.',
        ),
        backgroundColor: failed.isEmpty ? Colors.green : Colors.red,
      ),
    );
    // Navigator.pop não passa pelo PopScope (só o voltar do sistema).
    Navigator.of(context).pop(rejected);
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair sem salvar?'),
        content: Text('Você conferiu ${_decisions.length} e ainda não salvou.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continuar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sair')),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _decisions.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
        appBar: AppBar(
          title: const Text('Conferir check-ins'),
          backgroundColor: CommunityDesign.headerColor(context),
        ),
        body: ReadableWidth(child: FutureBuilder<List<WorshipAttendance>>(
          future: _load,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Erro ao carregar: ${snap.error}'));
            }
            final pending = snap.data!;
            if (pending.isEmpty) {
              return Center(
                child: Text(
                  'Nenhum check-in pelo GPS esperando conferência.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              );
            }
            final present = _decisions.values.where((d) => d).length;
            return SafeArea(
              child: PresenceDeck(
                people: [
                  for (final a in pending)
                    PresenceCardData(
                      id: a.memberId,
                      name: a.memberName ?? '',
                      photoUrl: a.memberPhotoUrl,
                      hint: geoCheckinHint(a),
                      hintIcon: a.isConfirmed ? Icons.phone_android : Icons.gps_fixed,
                    ),
                ],
                disabled: _saving,
                onDecide: (p, ok) => setState(() => _decisions[p.id] = ok),
                onUndo: (p) => setState(() => _decisions.remove(p.id)),
                done: Text(
                  '$present presente${present == 1 ? '' : 's'} · '
                  '${_decisions.length - present} recusado${_decisions.length - present == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                doneAction: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Salvar conferência'),
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                ),
              ),
            );
          },
        )),
      ),
    );
  }
}
