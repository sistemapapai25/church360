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

/// Logo da igreja do tenant (church_info.logo_url). Sem logo, ou se a imagem
/// falhar, mostra as iniciais do nome (ou um ícone, sem nome). Não cai na gota
/// do [AppLogo]: ela é a marca da Águas Purificadoras e apareceria para
/// qualquer outra igreja sem logo cadastrada. Recortar com ClipOval/ClipRRect.
class ChurchLogo extends StatelessWidget {
  final String? url;
  final String name;
  final BoxFit fit;

  const ChurchLogo({
    super.key,
    required this.url,
    required this.name,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.length > 2);
    final initials = (words.isEmpty ? [name.trim()] : words)
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final fallback = Container(
      color: cs.primaryContainer,
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        child: initials.isEmpty
            ? Icon(Icons.church_outlined, color: cs.onPrimaryContainer)
            : Text(
                initials,
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
    final u = url?.trim() ?? '';
    if (u.isEmpty) return fallback;
    return Image.network(u, fit: fit, errorBuilder: (_, __, ___) => fallback);
  }
}
