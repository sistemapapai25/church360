import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Uma aba da barra [AppTabs].
class AppTab {
  final String label;

  /// Contador opcional exibido ao lado do rotulo. Texto livre de proposito:
  /// tanto `9` quanto `10/41` aparecem no desenho de referencia.
  final String? count;

  final IconData? icon;

  const AppTab({required this.label, this.count, this.icon});
}

/// Largura reservada para o controle fixo do fim da trilha
/// ([AppTabs.trailing]). Usada so na conta que decide entre distribuir e
/// rolar.
const double _kTrailingSlot = 48;

/// Barra de sub-abas em pilula, com contador opcional por aba.
///
/// Agrupa sub-secoes de uma MESMA tela de gestao (Alunos / Checklist /
/// Presenca / WhatsApp / Relatorios de uma turma). Nao substitui a
/// navegacao principal do app nem o `TabBar` do Material em telas que ja
/// usam `TabController`.
///
/// Receita do sistema de design (componente Tabs): trilha em pilula com
/// fundo `muted` e borda `border`; aba ativa com fundo `primary` e texto
/// `primaryForeground`, contador em selo branco translucido; abas inativas
/// em `mutedForeground`, contador com fundo `border`.
///
/// A trilha ocupa a largura toda. Quando as abas cabem nela, cada uma recebe
/// a mesma fatia — a distribuicao pareja do desenho de referencia, em vez de
/// um bloco de abas encostado na esquerda com a metade direita vazia. Quando
/// nao cabem (celular), a trilha rola na horizontal: cortar a ultima aba
/// esconderia uma secao inteira.
class AppTabs extends StatelessWidget {
  final List<AppTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Controle fixo na ponta direita da trilha, dentro da mesma pilula — a
  /// engrenagem do ministerio, por exemplo.
  ///
  /// Fica fora da parte rolavel de proposito: quando as abas nao cabem, um
  /// controle no fim do trilho so apareceria depois de arrastar tudo ate o
  /// fim.
  final Widget? trailing;

  const AppTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final track = dark ? AppTheme.darkInput : AppTheme.muted;
    final borderColor = dark ? AppTheme.darkBorder : AppTheme.border;
    final natural = _naturalWidth(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final fits =
            constraints.maxWidth.isFinite && natural <= constraints.maxWidth;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: track,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Expanded(child: fits ? _spread() : _scroller()),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                trailing!,
              ],
            ],
          ),
        );
      },
    );
  }

  /// Abas dividindo a largura em partes iguais.
  Widget _spread() {
    return Row(
      children: [
        for (var i = 0; i < tabs.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: _AppTabPill(
              tab: tabs[i],
              selected: i == selectedIndex,
              expanded: true,
              onTap: () => onChanged(i),
            ),
          ),
        ],
      ],
    );
  }

  /// Abas com a largura do proprio conteudo, rolando na horizontal.
  Widget _scroller() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            _AppTabPill(
              tab: tabs[i],
              selected: i == selectedIndex,
              onTap: () => onChanged(i),
            ),
          ],
        ],
      ),
    );
  }

  /// Largura que a trilha pediria com cada aba no tamanho do seu conteudo.
  ///
  /// E medida, e nao chutada, porque e ela que decide entre distribuir e
  /// rolar: uma conta por baixo espremeria os rotulos, uma por cima mandaria
  /// rolar uma barra que cabia. A aba ativa e a mais larga (peso w600), entao
  /// todas sao medidas assim.
  double _naturalWidth(BuildContext context) {
    var total = 10.0; // padding da trilha (4+4) + borda (1+1)
    if (trailing != null) total += _kTrailingSlot;

    for (var i = 0; i < tabs.length; i++) {
      if (i > 0) total += 4;
      total += 32; // padding horizontal da pilula
      total += _textWidth(
        context,
        tabs[i].label,
        const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.2),
      );
      if (tabs[i].icon != null) total += 21; // icone 15 + respiro 6
      final count = tabs[i].count;
      if (count != null) {
        total += 20; // respiro 6 + padding do selo 7+7
        total += _textWidth(
          context,
          count,
          const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        );
      }
    }
    return total;
  }

  static double _textWidth(
    BuildContext context,
    String text,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.width;
  }
}

class _AppTabPill extends StatelessWidget {
  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  /// `true` quando a aba recebeu uma fatia fixa da trilha: o conteudo passa a
  /// ser centrado e o rotulo aceita reticencias, para uma medida por baixo
  /// nunca virar overflow.
  final bool expanded;

  const _AppTabPill({
    required this.tab,
    required this.selected,
    required this.onTap,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(999);

    final foreground = selected
        ? AppTheme.primaryForeground
        : (dark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground);

    // O contador da aba ativa e um veu branco sobre o azul; o das inativas
    // usa `border` como fundo, com o texto na cor de leitura do tema — no
    // escuro, `foreground` claro, nunca o `#0F172A` do tema claro.
    final counterBackground = selected
        ? Colors.white.withValues(alpha: 0.28)
        : (dark ? AppTheme.darkBorder : AppTheme.border);
    final counterForeground = selected
        ? AppTheme.primaryForeground
        : (dark ? AppTheme.darkForeground : AppTheme.foreground);

    final label = Text(
      tab.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: foreground,
        fontSize: 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        height: 1.2,
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: radius,
          ),
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (tab.icon != null) ...[
                Icon(tab.icon, size: 15, color: foreground),
                const SizedBox(width: 6),
              ],
              expanded ? Flexible(child: label) : label,
              if (tab.count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: counterBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tab.count!,
                    style: TextStyle(
                      color: counterForeground,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
