import 'package:flutter/widgets.dart';

/// Faixas de largura do app (B7 do roadmap Home/culto/Dashboard, 14/10/2026).
///
/// Os mesmos números que `AppFilterBar` (640) e o financeiro (900) já usavam
/// soltos. Só código novo usa; telas antigas não são tocadas por isso.
enum Breakpoint {
  /// Celular (< 640).
  compact,

  /// Tablet em pé / janela estreita (640–899).
  medium,

  /// Tablet deitado / PC (≥ 900).
  expanded;

  /// Quantas colunas de card cabem nesta faixa.
  int get columns => switch (this) {
        compact => 1,
        medium => 2,
        expanded => 3,
      };
}

Breakpoint breakpointOf(double width) => width < 640
    ? Breakpoint.compact
    : width < 900
        ? Breakpoint.medium
        : Breakpoint.expanded;

/// Colunas para uma grade de cards com [width] disponível: a faixa manda, mas
/// nenhuma coluna fica mais estreita que [minCardWidth] (um card desenhado
/// para o celular não precisa funcionar abaixo disso).
int gridColumns(double width, {double minCardWidth = 320}) {
  final byWidth = (width ~/ minCardWidth).clamp(1, 3);
  return breakpointOf(width).columns.clamp(1, byWidth);
}

extension BreakpointContext on BuildContext {
  Breakpoint get breakpoint => breakpointOf(MediaQuery.sizeOf(this).width);
}
