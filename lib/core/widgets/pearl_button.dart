import 'package:flutter/material.dart';

/// Superfície "perolada" 3D (glossy/glass pill), fiel à arquitetura do
/// componente CSS de referência (`.pearl-button`):
///
/// - Fundo sólido escuro (não gradiente claro→cor→escuro) tintado pela cor
///   do item — a cor aparece nos reflexos/meios-tons, não satura a base.
/// - Volume produzido por camadas simulando os `inset box-shadow` originais
///   (realce superior, penumbra inferior, "underglow" branco de baixo).
/// - `wrap::before` → glow amplo e difuso atrás do conteúdo.
/// - `wrap::after` → faixa de brilho (shine cap) por CIMA do ícone/label.
/// - Máscara de fade no conteúdo (equivalente ao `mask-image` do CSS).
///
/// Três estados independentes, como no original:
/// - NORMAL: repouso.
/// - HOVER: só o ponteiro entra (sem clicar) — o brilho "ganha vida".
/// - ACTIVE: só enquanto pressionado — o botão afunda ~4px.
///
/// [dark] e [moldingEnabled] são opt-in (default = comportamento clássico,
/// usado em todo o app hoje). Servem para validar no playground a revisão
/// pedida (pérola clara real no Light + moldagem carcaça/face) sem alterar
/// nenhuma tela em produção enquanto não for aprovada.
class PearlButton extends StatefulWidget {
  final Widget child;
  final Color color;
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  /// Tema da pérola. `true` (default) = pérola escura/fumê clássica, igual
  /// à usada hoje em todo o app. `false` = pérola clara/leitosa (Light).
  /// Só tem efeito quando [moldingEnabled] é `true`.
  final bool dark;

  /// Liga a revisão visual (moldagem carcaça+face + tema claro/escuro real).
  /// Default `false` preserva pixel a pixel o render atual — nenhuma tela
  /// real muda até esse parâmetro ser explicitamente ligado.
  final bool moldingEnabled;

  /// Reforço extra de tint no Light Mode, além do padrão do tema (0..~0.3).
  /// Só tem efeito com [moldingEnabled] + `dark: false`. Serve pra dar mais
  /// presença cromática a um CTA específico (ex.: Contribua) sem alterar o
  /// tint padrão dos demais itens da família Pearl.
  final double lightTintBoost;

  const PearlButton({
    super.key,
    required this.child,
    required this.color,
    this.width = 160,
    this.height = 56,
    this.borderRadius,
    this.onTap,
    this.dark = true,
    this.moldingEnabled = false,
    this.lightTintBoost = 0.0,
  });

  @override
  State<PearlButton> createState() => _PearlButtonState();
}

class _PearlButtonState extends State<PearlButton> {
  static const _duration = Duration(milliseconds: 260);
  static const _curve = Curves.easeOut;

  bool _hovering = false;
  bool _pressed = false;

  void _setHover(bool value) {
    if (_hovering == value) return;
    setState(() {
      _hovering = value;
      // Sair do botão com o mouse pressionado cancela o "active" também
      // (equivalente a :active só existir dentro de :hover).
      if (!value) _pressed = false;
    });
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return widget.moldingEnabled ? _buildRefined(context) : _buildClassic(context);
  }

  /// Render original, intacto — usado em produção hoje.
  Widget _buildClassic(BuildContext context) {
    final h = widget.height;
    final w = widget.width;
    final radius = widget.borderRadius ?? BorderRadius.circular(h / 2);

    // Base sólida escura, cor só como tint sutil (não vira gradiente colorido).
    final darkBase = Color.lerp(const Color(0xFF0A0A0C), widget.color, 0.16)!;

    // Camadas equivalentes aos 3 inset box-shadow do `.pearl-button` original.
    final topHighlightAlpha = _pressed ? 0.50 : (_hovering ? 0.40 : 0.30);
    final bottomRimAlpha = _pressed ? 0.80 : 0.70;
    final underglowAlpha = _pressed ? 0.40 : (_hovering ? 0.70 : 0.50);

    // wrap::after (shine cap): dimming + desce um pouco no hover.
    final shineOpacity = _hovering ? 0.4 : 1.0;
    final shineShiftY = _hovering ? h * 0.05 : 0.0;

    // wrap::before (glow amplo): sobe um pouco no hover, intensificando.
    final glowShiftY = _hovering ? -h * 0.05 : 0.0;

    // conteúdo (ícone/label) sobe levemente no hover.
    final contentShiftY = _hovering ? -h * 0.04 : 0.0;

    // botão inteiro só afunda quando pressionado.
    final sinkY = _pressed ? 4.0 : 0.0;

    // Sem onTap = botão desabilitado: escurece e não reage a hover/toque,
    // pra não parecer clicável quando não é (ex.: evento lotado).
    final disabled = widget.onTap == null;

    return AnimatedOpacity(
      duration: _duration,
      curve: _curve,
      opacity: disabled ? 0.45 : 1.0,
      child: MouseRegion(
        cursor: disabled ? MouseCursor.defer : SystemMouseCursors.click,
        onEnter: disabled ? null : (_) => _setHover(true),
        onExit: disabled ? null : (_) => _setHover(false),
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: disabled ? null : (_) => _setPressed(true),
          onTapUp: disabled ? null : (_) => _setPressed(false),
          onTapCancel: disabled ? null : () => _setPressed(false),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: _duration,
            curve: _curve,
            transform: Matrix4.translationValues(0, sinkY, 0),
            width: w,
            height: h,
            decoration: BoxDecoration(
              borderRadius: radius,
              color: darkBase,
              boxShadow: [
                // Sombra externa ampla e suave (elevação geral).
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: h * 0.53,
                  offset: Offset(0, h * 0.53),
                ),
                // Sombra de contato, mais curta e opaca, com spread negativo
                // (equivalente ao "-0.6rem" de spread do CSS original).
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.80),
                  blurRadius: h * 0.18,
                  offset: Offset(0, h * 0.18),
                  spreadRadius: -h * 0.067,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Inset: realce superior (topo do botão).
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: h * 0.55,
                    child: AnimatedOpacity(
                      duration: _duration,
                      curve: _curve,
                      opacity: topHighlightAlpha,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.white, Color(0x00FFFFFF)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Inset: underglow branco vindo de baixo.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: h * 0.75,
                    child: AnimatedOpacity(
                      duration: _duration,
                      curve: _curve,
                      opacity: underglowAlpha,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.white, Color(0x00FFFFFF)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Inset: penumbra escura bem colada na borda inferior.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: h * 0.22,
                    child: AnimatedOpacity(
                      duration: _duration,
                      curve: _curve,
                      opacity: bottomRimAlpha,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black, Color(0x00000000)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // wrap::before — glow amplo e difuso atrás do conteúdo.
                  Center(
                    child: AnimatedContainer(
                      duration: _duration,
                      curve: _curve,
                      transform: Matrix4.translationValues(
                        0,
                        glowShiftY - h * 0.62,
                        0,
                      ),
                      width: w * 1.35,
                      height: w * 1.35,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  // Conteúdo (ícone/label) com leve subida no hover e fade na base
                  // (equivalente ao mask-image linear-gradient do CSS).
                  AnimatedContainer(
                    duration: _duration,
                    curve: _curve,
                    transform: Matrix4.translationValues(0, contentShiftY, 0),
                    child: ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.55, 1.0],
                      ).createShader(rect),
                      blendMode: BlendMode.dstIn,
                      child: widget.child,
                    ),
                  ),
                  // wrap::after — faixa de brilho por CIMA do conteúdo (glaze).
                  Positioned(
                    left: w * 0.06,
                    right: w * 0.06,
                    top: h * 0.12,
                    height: h * 0.48,
                    child: AnimatedContainer(
                      duration: _duration,
                      curve: _curve,
                      transform: Matrix4.translationValues(0, shineShiftY, 0),
                      child: AnimatedOpacity(
                        duration: _duration,
                        curve: _curve,
                        opacity: shineOpacity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(h * 0.3),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.30),
                                Colors.white.withValues(alpha: 0),
                              ],
                              stops: const [0.0, 0.5],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Render revisado (playground): tema claro/escuro real da pérola +
  /// moldagem carcaça/face (o "degrau óptico" que faltava no clássico).
  Widget _buildRefined(BuildContext context) {
    final h = widget.height;
    final w = widget.width;
    final radius = widget.borderRadius ?? BorderRadius.circular(h / 2);
    final dark = widget.dark;
    final disabled = widget.onTap == null;

    // --- cor da FACE (a pérola em si) -----------------------------------
    // Escuro: base quase preta, cor só como tint (smoked/deep pearl).
    // Claro: base leitosa/marfim, cor entra bem mais (milky/tinted pearl) —
    // pérola clara colorida, nunca cápsula preta sobre navbar clara.
    final faceSeed = dark ? const Color(0xFF0A0A0C) : const Color(0xFFFCFAF5);
    final baseTint = dark
        ? (_pressed ? 0.24 : (_hovering ? 0.20 : 0.16))
        : (_pressed ? 0.58 : (_hovering ? 0.52 : 0.42));
    // No claro, o boost some quando o botão está desabilitado — senão ele
    // fica mais saturado que um botão clicável, o que é ilógico.
    final tint = dark
        ? baseTint
        : (baseTint + (disabled ? 0.0 : widget.lightTintBoost)).clamp(0.0, 0.88);
    final faceColor = Color.lerp(faceSeed, widget.color, tint)!;

    // --- cor da CARCAÇA (aro externo) ------------------------------------
    // Um degrau tonal sutil abaixo da face — a "peça" que segura a pérola.
    final shellColor = dark
        ? Color.lerp(faceColor, Colors.black, 0.30)!
        : Color.lerp(faceColor, const Color(0xFFE7E0D2), 0.55)!;

    // Camadas equivalentes aos inset box-shadow do original, recalibradas
    // por tema (no claro a penumbra/underglow precisam ser bem mais leves
    // pra não sujar a pérola, senão ela volta a parecer escura).
    final topHighlightAlpha = _pressed ? 0.50 : (_hovering ? 0.40 : 0.30);
    final bottomRimAlpha = dark
        ? (_pressed ? 0.80 : 0.70)
        : (_pressed ? 0.34 : 0.24);
    final underglowAlpha = dark
        ? (_pressed ? 0.40 : (_hovering ? 0.70 : 0.50))
        : (_pressed ? 0.22 : (_hovering ? 0.42 : 0.28));

    final shineOpacity = _hovering ? 0.4 : 1.0;
    final shineShiftY = _hovering ? h * 0.05 : 0.0;
    final glowShiftY = _hovering ? -h * 0.05 : 0.0;
    final contentShiftY = _hovering ? -h * 0.04 : 0.0;
    final sinkY = _pressed ? 4.0 : 0.0;

    // --- moldagem: carcaça externa + face recuada ------------------------
    final outerRadiusValue = radius.topLeft.x;
    final bevel = (h * 0.09).clamp(2.0, 7.0);
    final faceRadius = BorderRadius.circular(
      (outerRadiusValue - bevel).clamp(0.0, outerRadiusValue),
    );
    final grooveColor = dark
        ? Colors.black.withValues(alpha: 0.42)
        : Colors.black.withValues(alpha: 0.11);
    final rimCatchAlpha = dark ? 0.14 : 0.85;

    return AnimatedOpacity(
      duration: _duration,
      curve: _curve,
      opacity: disabled ? 0.45 : 1.0,
      child: MouseRegion(
        cursor: disabled ? MouseCursor.defer : SystemMouseCursors.click,
        onEnter: disabled ? null : (_) => _setHover(true),
        onExit: disabled ? null : (_) => _setHover(false),
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: disabled ? null : (_) => _setPressed(true),
          onTapUp: disabled ? null : (_) => _setPressed(false),
          onTapCancel: disabled ? null : () => _setPressed(false),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: _duration,
            curve: _curve,
            transform: Matrix4.translationValues(0, sinkY, 0),
            width: w,
            height: h,
            decoration: BoxDecoration(
              borderRadius: radius,
              color: shellColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.30 : 0.13),
                  blurRadius: h * 0.53,
                  offset: Offset(0, h * 0.53),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.80 : 0.18),
                  blurRadius: h * 0.18,
                  offset: Offset(0, h * 0.18),
                  spreadRadius: -h * 0.067,
                ),
              ],
            ),
            padding: EdgeInsets.all(bevel),
            // O "degrau" entre carcaça e face: um contorno fino (groove) +
            // uma linha de luz exatamente no topo (catch-light do bevel).
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: faceRadius,
                border: Border.all(color: grooveColor, width: 1),
              ),
              child: ClipRRect(
                borderRadius: faceRadius,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    DecoratedBox(decoration: BoxDecoration(color: faceColor)),
                    // Catch-light do bevel: fio de luz bem no topo da face.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: 1.4,
                      child: Container(
                        color: Colors.white.withValues(alpha: rimCatchAlpha),
                      ),
                    ),
                    // Inset: realce superior (topo da pérola).
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: h * 0.55,
                      child: AnimatedOpacity(
                        duration: _duration,
                        curve: _curve,
                        opacity: topHighlightAlpha,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.white, Color(0x00FFFFFF)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Inset: underglow vindo de baixo.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: h * 0.75,
                      child: AnimatedOpacity(
                        duration: _duration,
                        curve: _curve,
                        opacity: underglowAlpha,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.white, Color(0x00FFFFFF)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Inset: penumbra colada na borda inferior (profundidade).
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: h * 0.22,
                      child: AnimatedOpacity(
                        duration: _duration,
                        curve: _curve,
                        opacity: bottomRimAlpha,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                dark ? Colors.black : const Color(0xFF6B5F4E),
                                dark
                                    ? const Color(0x00000000)
                                    : const Color(0x006B5F4E),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // wrap::before — glow amplo atrás do conteúdo.
                    Center(
                      child: AnimatedContainer(
                        duration: _duration,
                        curve: _curve,
                        transform: Matrix4.translationValues(
                          0,
                          glowShiftY - h * 0.62,
                          0,
                        ),
                        width: w * 1.35,
                        height: w * 1.35,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (dark ? Colors.white : widget.color)
                              .withValues(alpha: dark ? 0.12 : 0.14),
                        ),
                      ),
                    ),
                    // Conteúdo (ícone/label), leve subida no hover.
                    AnimatedContainer(
                      duration: _duration,
                      curve: _curve,
                      transform: Matrix4.translationValues(0, contentShiftY, 0),
                      child: ShaderMask(
                        shaderCallback: (rect) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.55, 1.0],
                        ).createShader(rect),
                        blendMode: BlendMode.dstIn,
                        child: widget.child,
                      ),
                    ),
                    // wrap::after — faixa de brilho (glaze) por cima do conteúdo.
                    Positioned(
                      left: w * 0.06,
                      right: w * 0.06,
                      top: h * 0.12,
                      height: h * 0.48,
                      child: AnimatedContainer(
                        duration: _duration,
                        curve: _curve,
                        transform: Matrix4.translationValues(0, shineShiftY, 0),
                        child: AnimatedOpacity(
                          duration: _duration,
                          curve: _curve,
                          opacity: shineOpacity,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(h * 0.3),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(
                                    alpha: dark ? 0.30 : 0.55,
                                  ),
                                  Colors.white.withValues(alpha: 0),
                                ],
                                stops: const [0.0, 0.5],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
