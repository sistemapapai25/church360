import 'package:flutter/material.dart';

/// Qual arte da logo usar.
///
/// - [auto]: gota solta sobre o fundo da tela — colorida no tema claro,
///   branca no escuro.
/// - [colorida] / [branca]: força uma das duas (fundo fixo, como o cartão
///   branco do cadastro ou o degradê do login).
/// - [selo]: quadrado com o degradê da marca, para círculos e caixas que a
///   logo preenche (avatares, cabeçalho de A Igreja). Recortar com
///   ClipOval/ClipRRect.
enum AppLogoVariant { auto, colorida, branca, selo }

class AppLogo extends StatelessWidget {
  final double? size;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AppLogoVariant variant;

  /// Pinta a gota de uma cor só (ex.: ícone ativo/inativo da barra).
  /// Usa a silhueta da branca, então ignora [variant].
  final Color? color;

  const AppLogo({
    super.key,
    this.size,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.variant = AppLogoVariant.auto,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = color != null
        ? AppLogoVariant.branca
        : variant == AppLogoVariant.auto
        ? (Theme.of(context).brightness == Brightness.dark
              ? AppLogoVariant.branca
              : AppLogoVariant.colorida)
        : variant;

    return Image.asset(
      switch (resolved) {
        AppLogoVariant.branca => 'assets/images/logo_branca.png',
        AppLogoVariant.selo => 'assets/images/logo_selo.png',
        _ => 'assets/images/logo_colorida.png',
      },
      width: size ?? width,
      height: size ?? height,
      fit: fit,
      color: color,
      colorBlendMode: color != null ? BlendMode.srcIn : null,
    );
  }
}
