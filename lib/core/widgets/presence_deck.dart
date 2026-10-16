import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';

import '../design/community_design.dart';

/// Uma pessoa na pilha de cartas da presença.
class PresenceCardData {
  final String id;
  final String name;
  final String? photoUrl;

  /// Linha curta embaixo do nome (ex.: "Membro", "Visitante").
  final String? subtitle;

  /// Destaque opcional (ex.: "Check-in pelo GPS · 19:28 · 12 m").
  final String? hint;
  final IconData? hintIcon;

  const PresenceCardData({
    required this.id,
    required this.name,
    this.photoUrl,
    this.subtitle,
    this.hint,
    this.hintIcon,
  });
}

/// Pilha de cartas para registrar presença (16/10, "Match de Presença"):
/// direita = presente, esquerda = não está, Desfazer volta a última.
/// Quem usa guarda as decisões e decide quando gravar; a pilha só avisa.
class PresenceDeck extends StatefulWidget {
  final List<PresenceCardData> people;
  final void Function(PresenceCardData person, bool present) onDecide;
  final void Function(PresenceCardData person) onUndo;

  /// Mostrado no lugar das cartas quando todas foram decididas.
  final Widget done;

  /// Botão principal do rodapé depois da última carta (ex.: Salvar).
  final Widget doneAction;
  final bool disabled;

  const PresenceDeck({
    super.key,
    required this.people,
    required this.onDecide,
    required this.onUndo,
    required this.done,
    required this.doneAction,
    this.disabled = false,
  });

  @override
  State<PresenceDeck> createState() => _PresenceDeckState();
}

class _PresenceDeckState extends State<PresenceDeck> {
  final _controller = CardSwiperController();
  final List<PresenceCardData> _history = [];

  bool get _done => _history.length == widget.people.length;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final people = widget.people;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Text(
            _done
                ? 'Todos conferidos'
                : '${_history.length + 1} de ${people.length} · '
                      'arraste para a direita se a pessoa está aqui',
            textAlign: TextAlign.center,
            style: CommunityDesign.metaStyle(context),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              if (_done) Center(child: widget.done),
              if (people.isNotEmpty)
                CardSwiper(
                  controller: _controller,
                  cardsCount: people.length,
                  numberOfCardsDisplayed: math.min(3, people.length),
                  isLoop: false,
                  isDisabled: widget.disabled,
                  allowedSwipeDirection: const AllowedSwipeDirection.only(left: true, right: true),
                  onSwipe: (i, _, direction) {
                    setState(() => _history.add(people[i]));
                    widget.onDecide(people[i], direction == CardSwiperDirection.right);
                    return true;
                  },
                  onUndo: (_, _, _) {
                    final last = _history.removeLast();
                    setState(() {});
                    widget.onUndo(last);
                    return true;
                  },
                  cardBuilder: (context, i, dx, _) => _PresenceCard(person: people[i], dragPercent: dx),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: widget.disabled
              ? const SizedBox(height: 64, child: Center(child: CircularProgressIndicator()))
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
                      onTap: _history.isEmpty ? null : _controller.undo,
                    ),
                    if (!_done)
                      _RoundAction(
                        icon: Icons.check_rounded,
                        color: Colors.green,
                        tooltip: 'Presente',
                        onTap: () => _controller.swipe(CardSwiperDirection.right),
                      )
                    else
                      widget.doneAction,
                  ],
                ),
        ),
      ],
    );
  }
}

class _PresenceCard extends StatelessWidget {
  final PresenceCardData person;

  /// -100..100 enquanto arrasta: negativo = indo para a esquerda.
  final int dragPercent;

  const _PresenceCard({required this.person, required this.dragPercent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = person;
    final photo = (p.photoUrl ?? '').trim();
    final name = p.name.trim().isEmpty ? 'Sem nome' : p.name.trim();
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
                    radius: 72,
                    backgroundColor: cs.primary.withValues(alpha: 0.1),
                    backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                    child: photo.isEmpty
                        ? Text(
                            name.characters.first.toUpperCase(),
                            style: TextStyle(fontSize: 48, color: cs.primary, fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (p.subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(p.subtitle!, style: CommunityDesign.metaStyle(context)),
                  ],
                  if (p.hint != null) ...[
                    const SizedBox(height: 16),
                    Chip(
                      avatar: p.hintIcon == null ? null : Icon(p.hintIcon, size: 18, color: cs.primary),
                      label: Text(p.hint!),
                      shape: const StadiumBorder(),
                    ),
                  ],
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
