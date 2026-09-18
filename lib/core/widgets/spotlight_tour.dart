import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Um passo do tour: o alvo a destacar e o que dizer sobre ele.
class SpotlightStep {
  const SpotlightStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.onEnter,
  });

  /// Chave do widget que fica dentro do furo. Se o alvo não estiver montado
  /// na hora do passo, o passo é **pulado** — nunca trava o tour.
  final GlobalKey targetKey;

  final String title;
  final String description;

  /// Roda antes de medir o alvo. É por aqui que o tour troca de aba antes de
  /// apontar para algo que só existe em outra aba. Nunca navega por rota.
  final Future<void> Function()? onEnter;
}

/// Overlay de tour: desfoca a tela inteira menos um furo arredondado em volta
/// do alvo, e mostra um balão com o texto do passo.
///
/// Decisões que valem a pena não reaprender:
/// - O alvo é medido **depois** do frame (`addPostFrameCallback`). Medir antes
///   devolve tamanho zero e o furo vai parar no canto superior esquerdo.
/// - Alvo não encontrado pula o passo. Um tour que trava a tela inteira é pior
///   do que um tour que falta.
/// - O overlay absorve todos os toques: durante o tour ninguém navega sem
///   querer no que está embaixo.
class SpotlightTour extends StatefulWidget {
  const SpotlightTour({
    super.key,
    required this.steps,
    required this.onFinish,
    this.rotuloFinal = 'Concluir',
  });

  final List<SpotlightStep> steps;

  /// Chamado ao concluir **e** ao pular — `concluiu` separa os dois. Quem
  /// pulou não quer ver de novo, e também não quer ser levado para a etapa
  /// seguinte do roteiro: só quem chega ao fim segue para o perfil.
  final void Function(bool concluiu) onFinish;

  /// Texto do botão no último passo. O padrão encerra ('Concluir'); quando
  /// este tour é a primeira metade de um roteiro maior, quem monta passa
  /// 'Continuar' para não prometer um fim que não é o fim.
  final String rotuloFinal;

  @override
  State<SpotlightTour> createState() => _SpotlightTourState();
}

class _SpotlightTourState extends State<SpotlightTour> {
  static const double _holePadding = 8;
  static const double _holeRadius = 20;
  static const double _gutter = 16;

  int _index = 0;
  Rect? _alvo;
  bool _medindo = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepararPasso());
  }

  Future<void> _prepararPasso() async {
    if (!mounted) return;
    setState(() {
      _medindo = true;
      _alvo = null;
    });

    var indice = _index;
    while (indice < widget.steps.length) {
      final passo = widget.steps[indice];

      final onEnter = passo.onEnter;
      if (onEnter != null) {
        await onEnter();
        if (!mounted) return;
      }

      // Dois frames: o primeiro deixa a troca de aba montar a árvore nova, o
      // segundo garante que ela já passou pelo layout.
      await _proximoFrame();
      if (!mounted) return;
      await _proximoFrame();
      if (!mounted) return;

      final rect = _medirAlvo(passo.targetKey);
      if (rect != null) {
        setState(() {
          _index = indice;
          _alvo = rect;
          _medindo = false;
        });
        return;
      }

      // Alvo ausente (aba não montou, widget condicional não apareceu): segue
      // para o próximo passo em vez de mostrar um furo no lugar errado.
      indice++;
    }

    // Acabaram os passos (todos os restantes foram pulados por falta de
    // alvo): isso conta como chegar ao fim, não como desistir.
    _encerrar(concluiu: true);
  }

  Future<void> _proximoFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
    // `addPostFrameCallback` **não** agenda frame: ele só entra na fila do
    // próximo que já for acontecer. Numa tela parada (nenhuma animação, nenhum
    // toque) esse `await` nunca resolve — e aí o overlay fica no ramo de
    // medição, invisível e absorvendo todo toque da tela.
    WidgetsBinding.instance.scheduleFrame();
    return completer.future;
  }

  Rect? _medirAlvo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;

    final render = ctx.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return null;
    if (render.size.isEmpty) return null;

    final origem = render.localToGlobal(Offset.zero);
    final rect = origem & render.size;

    final tela = MediaQuery.of(context).size;
    // Alvo fora da tela (rolado para longe) não vira furo: o véu ficaria com
    // um buraco em lugar nenhum.
    if (rect.bottom < 0 || rect.top > tela.height) return null;

    return rect;
  }

  void _avancar() {
    if (_medindo) return;
    if (_index >= widget.steps.length - 1) {
      _encerrar(concluiu: true);
      return;
    }
    _index++;
    _prepararPasso();
  }

  void _encerrar({required bool concluiu}) {
    if (!mounted) return;
    widget.onFinish(concluiu);
  }

  @override
  Widget build(BuildContext context) {
    final alvo = _alvo;
    if (alvo == null) {
      // Enquanto mede, o overlay fica invisível mas já bloqueia toque — evita
      // que um toque no meio da troca de aba caia na tela de baixo.
      return const AbsorbPointer(child: SizedBox.expand());
    }

    final passo = widget.steps[_index];
    final tela = MediaQuery.of(context).size;
    final furo = RRect.fromRectAndRadius(
      alvo.inflate(_holePadding),
      const Radius.circular(_holeRadius),
    );

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _avancar,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipPath(
                clipper: _FuroClipper(furo),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(color: Colors.black.withValues(alpha: 0.55)),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: furo.outerRect,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_holeRadius),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            _posicionarBalao(context, furo.outerRect, tela, passo),
          ],
        ),
      ),
    );
  }

  Widget _posicionarBalao(
    BuildContext context,
    Rect furo,
    Size tela,
    SpotlightStep passo,
  ) {
    const alturaEstimada = 190.0;
    final padding = MediaQuery.of(context).padding;

    final cabeEmbaixo =
        furo.bottom + 12 + alturaEstimada + padding.bottom < tela.height;

    final balao = _BalaoDoTour(
      title: passo.title,
      description: passo.description,
      indice: _index,
      total: widget.steps.length,
      onNext: _avancar,
      onSkip: () => _encerrar(concluiu: false),
      rotuloFinal: widget.rotuloFinal,
    );

    if (cabeEmbaixo) {
      return Positioned(
        left: _gutter,
        right: _gutter,
        top: furo.bottom + 12,
        child: balao,
      );
    }

    return Positioned(
      left: _gutter,
      right: _gutter,
      bottom: (tela.height - furo.top) + 12,
      child: balao,
    );
  }
}

class _FuroClipper extends CustomClipper<Path> {
  const _FuroClipper(this.furo);

  final RRect furo;

  @override
  Path getClip(Size size) {
    // O furo sai do `fillType`, **não** de `Path.combine`. No Flutter web
    // `Path.combine(PathOperation.difference, ...)` devolve um path sem buraco
    // nenhum: o véu e o blur cobriam o alvo inteiro e o tour virava uma tela
    // borrada com uma moldura branca em volta de nada. Medido em harness:
    // com `Path.combine` o miolo do furo dava 115 (branco sob o véu), igual ao
    // resto da tela; com `evenOdd` dá 255.
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(furo);
  }

  @override
  bool shouldReclip(_FuroClipper oldClipper) => oldClipper.furo != furo;
}

class _BalaoDoTour extends StatelessWidget {
  const _BalaoDoTour({
    required this.title,
    required this.description,
    required this.indice,
    required this.total,
    required this.onNext,
    required this.onSkip,
    required this.rotuloFinal,
  });

  final String title;
  final String description;
  final int indice;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final String rotuloFinal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ultimo = indice >= total - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: cs.onSurface.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                '${indice + 1} de $total',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: cs.onSurfaceVariant,
                  shape: const StadiumBorder(),
                ),
                child: const Text('Pular'),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                child: Text(ultimo ? rotuloFinal : 'Próximo'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
