import 'package:flutter/material.dart';

import '../design/app_icons.dart';
import '../theme/app_theme.dart';
import 'pearl_button.dart';

/// Altura unica dos controles da barra. Busca, filtros, ordenacao e acoes
/// ficam todos nela para a linha ler como uma faixa so.
const double _kControlHeight = 44;

/// Largura minima que a busca guarda para si quando divide a linha com os
/// controles. Abaixo disso o campo deixa de caber um nome.
const double _kMinSearchWidth = 240;

/// Acao de uma [AppFilterBar].
class AppFilterAction {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const AppFilterAction({required this.label, this.icon, this.onPressed});
}

/// Barra de busca, filtros e acoes do topo de uma listagem administrativa.
///
/// Receita do sistema de design (componente FilterBar): a busca ocupa o
/// espaco disponivel; filtros e ordenacao usam o mesmo fundo `input`, borda
/// `border` e raio 12px do campo de texto, para lerem como uma familia so;
/// a acao secundaria e `secondary` solido e a primaria e o botao pilula
/// (PearlButton) em `primary`.
///
/// Nasce em `core/` porque hoje cada tela de lista (Membros, Visitantes,
/// Ministerios, Cursos) resolve busca e filtro do seu jeito. Os filtros sao
/// passados de fora — os que ja existem em `core/widgets/` continuam
/// valendo; para um filtro novo simples, use [AppFilterButton], que ja vem
/// com a casca certa.
///
/// Em tela estreita a barra vira duas linhas: a busca em cima, ocupando a
/// largura toda, e os controles embaixo numa faixa que rola na horizontal.
/// Sem isso, seis controles numa linha so espremeriam a busca a nada no
/// celular.
class AppFilterBar extends StatelessWidget {
  final TextEditingController? searchController;
  final String searchHint;
  final ValueChanged<String>? onSearchChanged;

  /// Filtros da linha. Cada um cuida do proprio estado.
  final List<Widget> filters;

  /// Botao quadrado de ordenacao. Nulo = sem botao.
  final VoidCallback? onSort;
  final IconData sortIcon;
  final String sortTooltip;

  /// Ações de apoio, antes da ação principal. São várias porque a barra
  /// de referência leva duas (abrir as turmas e o link de inscrição) lado
  /// a lado, na mesma linha da busca.
  final List<AppFilterAction> secondaryActions;

  final AppFilterAction? primaryAction;

  /// Largura abaixo da qual a barra quebra em duas linhas.
  final double compactBreakpoint;

  const AppFilterBar({
    super.key,
    this.searchController,
    this.searchHint = 'Buscar...',
    this.onSearchChanged,
    this.filters = const [],
    this.onSort,
    this.sortIcon = AppIcons.sort,
    this.sortTooltip = 'Ordenar',
    this.secondaryActions = const [],
    this.primaryAction,
    this.compactBreakpoint = 640,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        final controls = _controls();

        final search = _SearchField(
          controller: searchController,
          hint: searchHint,
          onChanged: onSearchChanged,
        );

        if (!compact) {
          if (controls.isEmpty) return search;

          // A busca estica e os controles ficam encostados na direita: a
          // barra tem que ocupar a largura toda, como no desenho de
          // referencia, e nao virar um bloco no canto esquerdo com meia tela
          // vazia ao lado.
          //
          // O teto de largura nos controles e o que impede o estouro: com
          // busca + dois filtros + ordenacao + duas acoes a linha pede perto
          // de 900px, e numa janela de 800 o Row estourava em barra listrada
          // (medido em teste). Limitados, eles quebram para a linha de baixo
          // sozinhos e a busca nunca desce de [_kMinSearchWidth].
          final controlsMax = (constraints.maxWidth - _kMinSearchWidth - 10)
              .clamp(0.0, constraints.maxWidth);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: search),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: controlsMax),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: controls,
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            search,
            if (controls.isNotEmpty) ...[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < controls.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      controls[i],
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _controls() {
    return [
      ...filters,
      if (onSort != null)
        _SortButton(icon: sortIcon, tooltip: sortTooltip, onTap: onSort!),
      for (final action in secondaryActions) _SecondaryAction(action: action),
      if (primaryAction != null) _PrimaryAction(action: primaryAction!),
    ];
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  const _SearchField({this.controller, required this.hint, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark
        ? AppTheme.darkMutedForeground
        : AppTheme.mutedForeground;

    return SizedBox(
      height: _kControlHeight,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: muted, fontSize: 13),
          prefixIcon: Icon(AppIcons.search, size: 18, color: muted),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          isDense: true,
          // Sem `fillColor` local: o `inputDecorationTheme` dos dois temas ja
          // define `filled` + a cor certa. Fixar branco aqui foi o bug que o
          // PR #83 varreu do app inteiro.
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}

/// Casca padrao de um controle da barra: fundo `input`, borda `border`,
/// raio 12px — a mesma familia do campo de texto.
class AppFilterShell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const AppFilterShell({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14),
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(12);

    return Material(
      color: dark ? AppTheme.darkInput : AppTheme.input,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          height: _kControlHeight,
          padding: padding,
          decoration: BoxDecoration(
            border: Border.all(
              color: dark ? AppTheme.darkBorder : AppTheme.border,
            ),
            borderRadius: radius,
          ),
          // `widthFactor: 1` e o que impede o controle de esticar: dentro de
          // um Wrap as constraints sao frouxas, e um Center sem fator ocupa
          // toda a largura disponivel — cada filtro virava uma linha inteira.
          child: Center(widthFactor: 1, child: child),
        ),
      ),
    );
  }
}

/// Filtro simples da barra: rotulo do valor escolhido + seta.
///
/// Para filtros que ja existem em `core/widgets/` (estado civil, faixa
/// etaria, periodo...), passe o widget deles direto em
/// [AppFilterBar.filters]; este aqui e para o caso simples.
class AppFilterButton extends StatelessWidget {
  /// Texto exibido — normalmente o valor atual ("Todos os status").
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Marca o filtro como aplicado: rotulo em `primary` e negrito.
  final bool active;

  const AppFilterButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppTheme.darkRing : AppTheme.primary;
    final foreground = active
        ? accent
        : (dark ? AppTheme.darkForeground : AppTheme.foreground);
    final muted = dark
        ? AppTheme.darkMutedForeground
        : AppTheme.mutedForeground;

    return AppFilterShell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: active ? accent : muted),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Icon(AppIcons.expand, size: 18, color: muted),
        ],
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _SortButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: _kControlHeight,
        child: AppFilterShell(
          onTap: onTap,
          padding: EdgeInsets.zero,
          child: Icon(
            icon,
            size: 18,
            color: dark ? AppTheme.darkForeground : AppTheme.foreground,
          ),
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  final AppFilterAction action;

  const _SecondaryAction({required this.action});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kControlHeight,
      child: FilledButton(
        onPressed: action.onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.secondary,
          foregroundColor: AppTheme.secondaryForeground,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: const RoundedRectangleBorder(borderRadius: AppTheme.radiusLg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (action.icon != null) ...[
              Icon(action.icon, size: 16),
              const SizedBox(width: 6),
            ],
            Text(
              action.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Acao primaria: o botao pilula da familia Pearl, que e a regua de CTA do
/// app. `PearlButton` pede largura fixa, entao ela e medida a partir do
/// texto — botao com largura chutada corta rotulo longo em silencio.
class _PrimaryAction extends StatelessWidget {
  final AppFilterAction action;

  const _PrimaryAction({required this.action});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppTheme.primaryForeground,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    );

    final painter = TextPainter(
      text: TextSpan(text: action.label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();

    final iconWidth = action.icon != null ? 24.0 : 0.0;
    final width = painter.width + iconWidth + 36;

    return PearlButton(
      color: AppTheme.primary,
      width: width,
      height: _kControlHeight,
      borderRadius: BorderRadius.circular(999),
      onTap: action.onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (action.icon != null) ...[
            Icon(action.icon, size: 16, color: AppTheme.primaryForeground),
            const SizedBox(width: 6),
          ],
          Text(action.label, style: style),
        ],
      ),
    );
  }
}
