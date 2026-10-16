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
/// direita = presente, esquerda = não está, para cima = depois (a carta vai
/// para o fim da pilha), para baixo = falta justificada (só com [onJustify]),
/// Desfazer volta a última.
/// Quem usa guarda as decisões e decide quando gravar; a pilha só avisa.
class PresenceDeck extends StatefulWidget {
  final List<PresenceCardData> people;
  final void Function(PresenceCardData person, bool present) onDecide;

  /// Desfaz um [onDecide] ou um [onJustify].
  final void Function(PresenceCardData person) onUndo;

  /// Só onde existe falta justificada (ex.: Batismo). Sem ele, não há
  /// carta para baixo.
  final void Function(PresenceCardData person)? onJustify;

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
    this.onJustify,
    this.disabled = false,
  });

  @override
  State<PresenceDeck> createState() => _PresenceDeckState();
}

class _PresenceDeckState extends State<PresenceDeck> {
  final _controller = CardSwiperController();

  /// Ordem atual das cartas: "Depois" leva a pessoa para o fim.
  late final List<PresenceCardData> _queue = List.of(widget.people);

  /// Índice da carta adiada, ou null para decisão (essa o swiper desfaz).
  final List<int?> _history = [];

  int get _decided => _history.where((i) => i == null).length;
  bool get _done => _decided == _queue.length;
  int get _remaining => _queue.length - _decided;

  /// O swiper não sabe de "Depois": cancela a carta e a pilha a manda para o
  /// fim, então a próxima pessoa aparece no mesmo índice.
  bool _onSwipe(int i, CardSwiperDirection direction) {
    final person = _queue[i];
    if (direction == CardSwiperDirection.top) {
      setState(() {
        _queue.add(_queue.removeAt(i));
        _history.add(i);
      });
      return false;
    }
    setState(() => _history.add(null));
    if (direction == CardSwiperDirection.bottom) {
      widget.onJustify!(person);
    } else {
      widget.onDecide(person, direction == CardSwiperDirection.right);
    }
    return true;
  }

  void _undo() {
    final later = _history.last;
    if (later == null) return _controller.undo();
    setState(() {
      _history.removeLast();
      _queue.insert(later, _queue.removeLast());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final people = _queue;
    final canLater = _remaining > 1;
    final canJustify = widget.onJustify != null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Text(
            _done
                ? 'Todos conferidos'
                : '${_decided + 1} de ${people.length} · '
                      'direita: está aqui · para cima: depois'
                      '${canJustify ? ' · para baixo: justificada' : ''}',
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
                  allowedSwipeDirection: AllowedSwipeDirection.only(
                    left: true,
                    right: true,
                    up: canLater,
                    down: canJustify,
                  ),
                  onSwipe: (i, _, direction) => _onSwipe(i, direction),
                  onUndo: (_, i, _) {
                    setState(() => _history.removeLast());
                    widget.onUndo(people[i]);
                    return true;
                  },
                  cardBuilder: (context, i, dx, dy) => _PresenceCard(
                    person: people[i],
                    dx: dx,
                    dy: (dy < 0 ? canLater : canJustify) ? dy : 0,
                  ),
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
                      onTap: _history.isEmpty ? null : _undo,
                    ),
                    if (!_done)
                      _RoundAction(
                        icon: Icons.schedule_rounded,
                        color: Colors.blue,
                        tooltip: 'Depois',
                        small: true,
                        onTap: canLater ? () => _controller.swipe(CardSwiperDirection.top) : null,
                      ),
                    if (!_done && canJustify)
                      _RoundAction(
                        icon: Icons.event_busy_rounded,
                        color: Colors.orange,
                        tooltip: 'Justificada',
                        small: true,
                        onTap: () => _controller.swipe(CardSwiperDirection.bottom),
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

  /// -100..100 enquanto arrasta: negativo = esquerda / para cima.
  final int dx;
  final int dy;

  const _PresenceCard({required this.person, required this.dx, required this.dy});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = person;
    final photo = (p.photoUrl ?? '').trim();
    final name = p.name.trim().isEmpty ? 'Sem nome' : p.name.trim();
    final vertical = dy.abs() > dx.abs();
    final pull = ((vertical ? dy : dx).abs() / 60).clamp(0.0, 1.0);
    final (stampColor, stamp) = switch ((vertical, vertical ? dy < 0 : dx >= 0)) {
      (true, true) => (Colors.blue, 'DEPOIS'),
      (true, false) => (Colors.orange, 'JUSTIFICADA'),
      (false, true) => (Colors.green, 'PRESENTE'),
      (false, false) => (Colors.red, 'NÃO ESTÁ'),
    };

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
              left: vertical || dx >= 0 ? 24 : null,
              right: !vertical && dx < 0 ? 24 : null,
              child: Opacity(
                opacity: pull,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: stampColor, width: 3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    stamp,
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

enum PresenceMark { present, absent, justified }

/// A chamada em cartas numa tela própria (fase 2): Cultos, Batismo, Turma,
/// Casa de Vida. Devolve as marcas (id → marca) no "Salvar", ou null se a
/// pessoa saiu sem salvar. Quem abre grava, cada um na sua tabela.
class PresenceDeckScreen extends StatefulWidget {
  final String title;
  final List<PresenceCardData> people;
  final bool allowJustified;

  const PresenceDeckScreen({
    super.key,
    required this.title,
    required this.people,
    this.allowJustified = false,
  });

  static Future<Map<String, PresenceMark>?> open(
    BuildContext context, {
    required String title,
    required List<PresenceCardData> people,
    bool allowJustified = false,
  }) => Navigator.of(context).push<Map<String, PresenceMark>>(
    MaterialPageRoute(
      builder: (_) => PresenceDeckScreen(title: title, people: people, allowJustified: allowJustified),
    ),
  );

  @override
  State<PresenceDeckScreen> createState() => _PresenceDeckScreenState();
}

class _PresenceDeckScreenState extends State<PresenceDeckScreen> {
  final Map<String, PresenceMark> _marks = {};

  int _count(PresenceMark m) => _marks.values.where((v) => v == m).length;
  String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair sem salvar?'),
        content: Text('Você marcou ${_marks.length} e ainda não salvou.'),
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
    final justified = _count(PresenceMark.justified);
    return PopScope(
      canPop: _marks.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
        appBar: AppBar(title: Text(widget.title), backgroundColor: CommunityDesign.headerColor(context)),
        body: SafeArea(
          child: PresenceDeck(
            people: widget.people,
            onDecide: (p, ok) => setState(() => _marks[p.id] = ok ? PresenceMark.present : PresenceMark.absent),
            onJustify: widget.allowJustified ? (p) => setState(() => _marks[p.id] = PresenceMark.justified) : null,
            onUndo: (p) => setState(() => _marks.remove(p.id)),
            done: Text(
              [
                _plural(_count(PresenceMark.present), 'presente'),
                _plural(_count(PresenceMark.absent), 'ausente'),
                if (justified > 0) _plural(justified, 'justificada'),
              ].join(' · '),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            // Navigator.pop não passa pelo PopScope (só o voltar do sistema).
            doneAction: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(_marks),
              icon: const Icon(Icons.save_rounded),
              label: const Text('Salvar'),
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
                minimumSize: const Size(0, 52),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão "Chamada em cartas (N)" das telas de chamada; some sem ninguém.
class PresenceCardsButton extends StatelessWidget {
  final int count;
  final VoidCallback? onPressed;

  const PresenceCardsButton({super.key, required this.count, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.style_rounded),
        label: Text('Chamada em cartas ($count)'),
        style: FilledButton.styleFrom(shape: const StadiumBorder(), minimumSize: const Size.fromHeight(48)),
      ),
    );
  }
}
