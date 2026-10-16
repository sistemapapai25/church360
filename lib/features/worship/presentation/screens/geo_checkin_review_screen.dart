import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/community_design.dart';
import '../../domain/models/worship_service.dart';
import '../providers/worship_provider.dart';

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

class _GeoCheckinReviewScreenState extends ConsumerState<GeoCheckinReviewScreen> {
  final _controller = CardSwiperController();
  late final Future<List<WorshipAttendance>> _load = ref
      .read(worshipRepositoryProvider)
      .getWorshipAttendance(widget.worshipServiceId)
      .then(pendingGeoCheckins);

  List<WorshipAttendance> _pending = const [];

  /// Uma decisão por carta já passada, na ordem: true = presente.
  final List<bool> _decisions = [];
  bool _saving = false;

  bool get _done => _pending.isNotEmpty && _decisions.length == _pending.length;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(worshipRepositoryProvider);
    final rejected = <String>{};
    final failed = <String>[];
    for (var i = 0; i < _decisions.length; i++) {
      final a = _pending[i];
      try {
        await repo.validateCheckin(widget.worshipServiceId, a.memberId, ok: _decisions[i]);
        if (!_decisions[i]) rejected.add(a.memberId);
      } catch (_) {
        failed.add(a.memberName ?? 'Sem nome');
      }
    }
    if (!mounted) return;
    ref.invalidate(worshipAttendanceProvider(widget.worshipServiceId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed.isEmpty
              ? 'Conferência salva.'
              : 'Não salvou: ${failed.join(', ')}. Tente de novo na aba Pelo celular.',
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
        body: FutureBuilder<List<WorshipAttendance>>(
          future: _load,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Erro ao carregar: ${snap.error}'));
            }
            _pending = snap.data!;
            if (_pending.isEmpty) {
              return Center(
                child: Text(
                  'Nenhum check-in pelo GPS esperando conferência.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              );
            }
            return _buildReview(context);
          },
        ),
      ),
    );
  }

  Widget _buildReview(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final present = _decisions.where((d) => d).length;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              _done
                  ? 'Tudo conferido'
                  : '${_decisions.length + 1} de ${_pending.length} · '
                        'arraste para a direita se a pessoa está no culto',
              textAlign: TextAlign.center,
              style: CommunityDesign.metaStyle(context),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                if (_done)
                  Center(
                    child: Text(
                      '$present presente${present == 1 ? '' : 's'} · '
                      '${_decisions.length - present} recusado${_decisions.length - present == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                CardSwiper(
                  controller: _controller,
                  cardsCount: _pending.length,
                  numberOfCardsDisplayed: math.min(3, _pending.length),
                  isLoop: false,
                  isDisabled: _saving,
                  allowedSwipeDirection: const AllowedSwipeDirection.only(left: true, right: true),
                  onSwipe: (_, _, direction) {
                    setState(() => _decisions.add(direction == CardSwiperDirection.right));
                    return true;
                  },
                  onUndo: (_, _, _) {
                    setState(() => _decisions.removeLast());
                    return true;
                  },
                  cardBuilder: (context, i, dx, _) => _CheckinCard(attendance: _pending[i], dragPercent: dx),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: _saving
                ? const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (!_done)
                        _RoundAction(
                          icon: Icons.close_rounded,
                          color: Colors.red,
                          tooltip: 'Não está aqui',
                          onTap: () => _controller.swipe(CardSwiperDirection.left),
                        ),
                      _RoundAction(
                        icon: Icons.undo_rounded,
                        color: cs.outline,
                        tooltip: 'Desfazer',
                        small: true,
                        onTap: _decisions.isEmpty ? null : _controller.undo,
                      ),
                      if (!_done)
                        _RoundAction(
                          icon: Icons.check_rounded,
                          color: Colors.green,
                          tooltip: 'Presente',
                          onTap: () => _controller.swipe(CardSwiperDirection.right),
                        )
                      else
                        FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Salvar conferência'),
                          style: FilledButton.styleFrom(
                            shape: const StadiumBorder(),
                            minimumSize: const Size(0, 52),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
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

class _CheckinCard extends StatelessWidget {
  final WorshipAttendance attendance;

  /// -100..100 enquanto arrasta: negativo = indo para a esquerda.
  final int dragPercent;

  const _CheckinCard({required this.attendance, required this.dragPercent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = attendance;
    final photo = (a.memberPhotoUrl ?? '').trim();
    final name = (a.memberName ?? '').trim().isEmpty ? 'Sem nome' : a.memberName!.trim();
    final pull = (dragPercent.abs() / 60).clamp(0.0, 1.0);
    final stampColor = dragPercent >= 0 ? Colors.green : Colors.red;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: CommunityDesign.cardSurfaceColor(cs),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Color.lerp(cs.outlineVariant, stampColor, pull)!, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 64,
                    backgroundColor: cs.primary.withValues(alpha: 0.1),
                    backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                    child: photo.isEmpty
                        ? Text(
                            name.characters.first.toUpperCase(),
                            style: TextStyle(fontSize: 44, color: cs.primary, fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    [
                      'Chegou às ${DateFormat.Hm().format(a.checkedInAt.toLocal())}',
                      if (a.distanceM != null) '${a.distanceM} m da igreja',
                    ].join(' · '),
                    style: CommunityDesign.metaStyle(context),
                  ),
                  const SizedBox(height: 16),
                  Chip(
                    avatar: Icon(
                      a.isConfirmed ? Icons.phone_android : Icons.gps_not_fixed,
                      size: 18,
                      color: a.isConfirmed ? cs.primary : Colors.grey,
                    ),
                    label: Text(a.isConfirmed ? 'Confirmou pelo celular' : 'Só o GPS, não confirmou'),
                    shape: const StadiumBorder(),
                  ),
                ],
              ),
            ),
          ),
          if (pull > 0)
            Positioned(
              top: 24,
              left: dragPercent >= 0 ? 24 : null,
              right: dragPercent < 0 ? 24 : null,
              child: Opacity(
                opacity: pull,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: stampColor, width: 3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    dragPercent >= 0 ? 'PRESENTE' : 'NÃO ESTÁ',
                    style: TextStyle(color: stampColor, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;
  final bool small;

  const _RoundAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = small ? 48.0 : 64.0;
    return Tooltip(
      message: tooltip,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: onTap == null ? 0.35 : 1,
        child: Material(
          shape: CircleBorder(side: BorderSide(color: color.withValues(alpha: 0.4), width: 2)),
          color: color.withValues(alpha: 0.08),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: color, size: small ? 24 : 32),
            ),
          ),
        ),
      ),
    );
  }
}
