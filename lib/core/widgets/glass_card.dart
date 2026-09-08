import 'dart:ui';

import 'package:flutter/material.dart';

/// Família "vidro" dos cards do app — três variações sobre a mesma
/// materialidade translúcida já usada no `PearlGlassDock` (blur 20, base
/// branca/carvão a ~70% de opacidade, borda de luz no topo):
///
/// - [GlassCard]: padrão neutro, usado na maioria das telas (Bíblia,
///   Cursos, seções compactas da Home).
/// - [GlassCardAccent]: mesmo vidro + filete de cor na borda direita, pra
///   destacar hierarquia ou sinalizar um tipo de conteúdo. Passe uma cor
///   já existente no app (ex.: `CommunityDesign.devotionalAccent` ou as
///   cores de `CommunityDesign.typeBadge`) em vez de uma nova.
/// - [GlassCardDevotional]: gradiente sólido vibrante, sem translucidez —
///   a referência visual original não é vidro — com um glaze no canto
///   pra conversar com a família Pearl.
///
/// Validado antes num preview isolado (Home/Bíblia/Cursos, claro e
/// escuro) antes de entrar em produção.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Filete de cor na borda direita. `null` = sem destaque (GlassCard
  /// simples). Prefira usar [GlassCardAccent] em vez de setar isto direto.
  final Color? accentColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.onTap,
    this.onLongPress,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(radius);
    final hasAccent = accentColor != null;

    final baseColor = dark ? const Color(0xFF14161B) : Colors.white;
    final borderLight = Colors.white.withValues(alpha: dark ? 0.10 : 0.65);
    final borderSoft = Colors.white.withValues(alpha: dark ? 0.05 : 0.35);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    baseColor.withValues(alpha: dark ? 0.72 : 0.80),
                    baseColor.withValues(alpha: dark ? 0.46 : 0.48),
                  ],
                ),
                border: Border(
                  top: BorderSide(color: borderLight, width: 1.2),
                  left: BorderSide(color: borderSoft, width: 1),
                  right: BorderSide(color: borderSoft, width: 1),
                  bottom: BorderSide(color: borderSoft, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.35 : 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Reflexo diagonal sutil — materialidade de vidro (ref. 08.12.37).
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: const Alignment(-0.7, -1),
                            end: const Alignment(0.7, 1),
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: dark ? 0.05 : 0.28),
                              Colors.transparent,
                            ],
                            stops: const [0.28, 0.46, 0.64],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (hasAccent)
                    Positioned(
                      top: 8,
                      bottom: 8,
                      right: 0,
                      width: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor!.withValues(alpha: 0.55),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: hasAccent
                        ? padding.add(const EdgeInsets.only(right: 10))
                        : padding,
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vidro com filete de cor na borda direita — mesma materialidade do
/// [GlassCard], só com um sinal visual extra. Reaproveite paletas que já
/// existem (tipo de post da Comunidade, categoria de devocional) em vez
/// de inventar uma cor nova pra cada uso.
class GlassCardAccent extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  const GlassCardAccent({
    super.key,
    required this.child,
    required this.accentColor,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: radius,
      onTap: onTap,
      padding: padding,
      accentColor: accentColor,
      child: child,
    );
  }
}

/// Vidro colorido ("tinted glass") — família "devocionais complementares"
/// da Home. Pertence à mesma materialidade do [GlassCard] (blur, borda de
/// luz, translucidez), só que com um tint de gradiente forte por cima em
/// vez do branco/carvão neutro — não é mais um retângulo de gradiente
/// opaco, é vidro com cor.
class GlassCardDevotional extends StatelessWidget {
  final Widget child;
  final List<Color> gradientColors;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  const GlassCardDevotional({
    super.key,
    required this.child,
    required this.gradientColors,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.onTap,
  }) : assert(gradientColors.length == 2, 'gradientColors precisa de 2 cores');

  /// Presets alinhados a `CommunityDesign.devotionalAccent`, só que como
  /// par de cores (gradiente) em vez de cor única.
  static List<Color> gradientForCategory(String? category) {
    switch (category?.toLowerCase()) {
      case 'domingo':
        return const [Color(0xFF3B82F6), Color(0xFF7C4DFF)];
      case 'quarta':
      case 'quarta-feira':
        return const [Color(0xFF1AA6C9), Color(0xFF0B5FA5)];
      case 'especial':
        return const [Color(0xFF5A3BA6), Color(0xFF3B82F6)];
      default:
        return const [Color(0xFF3B82F6), Color(0xFF7C4DFF)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final borderLight = Colors.white.withValues(alpha: 0.35);
    final borderSoft = Colors.white.withValues(alpha: 0.16);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        // Mesmo blur da família GlassCard — é isso que faz o tint ler como
        // vidro em vez de bloco opaco, mesmo com o gradiente forte por cima.
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  // Translúcido (não opaco) — é o que dá a leitura de vidro
                  // colorido em vez de retângulo de gradiente sólido.
                  colors: [
                    gradientColors.first.withValues(alpha: 0.86),
                    gradientColors.last.withValues(alpha: 0.72),
                  ],
                ),
                border: Border(
                  top: BorderSide(color: borderLight, width: 1.2),
                  left: BorderSide(color: borderSoft, width: 1),
                  right: BorderSide(color: borderSoft, width: 1),
                  bottom: BorderSide(color: borderSoft, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.last.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: borderRadius,
                child: Stack(
                  children: [
                    // Reflexo diagonal sutil — mesma linguagem do GlassCard.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: const Alignment(-0.7, -1),
                              end: const Alignment(0.7, 1),
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.16),
                                Colors.transparent,
                              ],
                              stops: const [0.28, 0.46, 0.64],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Catch-light — mesma linguagem do glaze do PearlButton.
                    Positioned(
                      top: -40,
                      left: -30,
                      child: IgnorePointer(
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.45),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(padding: padding, child: child),
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
