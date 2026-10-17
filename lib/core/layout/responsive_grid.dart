import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'breakpoints.dart';

/// Grade de cards do padrão web (17/10/2026): 1 coluna no celular, 2 no
/// tablet, 3 no PC, pela regra de [gridColumns]. No celular fica igual a uma
/// `Column` esticada com [gap] entre os itens.
///
/// Filho com altura zero (um `PermissionGate`/gate que devolveu
/// `SizedBox.shrink`) não ocupa célula: a grade não fica com buraco no lugar
/// do item escondido. Por isso não é um `Wrap` com `SizedBox(width:)`.
///
/// [rowGap] separa as linhas (padrão: [gap]); 0 quando o card já traz o
/// próprio espaço embaixo, para o celular ficar igual.
class ResponsiveGrid extends MultiChildRenderObjectWidget {
  const ResponsiveGrid({
    super.key,
    required super.children,
    this.gap = 12,
    double? rowGap,
    this.minCardWidth = 320,
  }) : rowGap = rowGap ?? gap;

  final double gap;
  final double rowGap;

  /// Nenhuma coluna fica mais estreita que isto.
  final double minCardWidth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderResponsiveGrid(
        gap: gap,
        rowGap: rowGap,
        minCardWidth: minCardWidth,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderResponsiveGrid renderObject,
  ) {
    renderObject
      ..gap = gap
      ..rowGap = rowGap
      ..minCardWidth = minCardWidth;
  }
}

class _GridParentData extends ContainerBoxParentData<RenderBox> {}

class RenderResponsiveGrid extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _GridParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _GridParentData> {
  RenderResponsiveGrid({
    required double gap,
    required double rowGap,
    required double minCardWidth,
  }) : _gap = gap,
       _rowGap = rowGap,
       _minCardWidth = minCardWidth;

  double _gap;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsLayout();
  }

  double _rowGap;
  set rowGap(double v) {
    if (v == _rowGap) return;
    _rowGap = v;
    markNeedsLayout();
  }

  double _minCardWidth;
  set minCardWidth(double v) {
    if (v == _minCardWidth) return;
    _minCardWidth = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _GridParentData) {
      child.parentData = _GridParentData();
    }
  }

  Size _layout(BoxConstraints constraints, {required bool dry}) {
    assert(constraints.hasBoundedWidth, 'ResponsiveGrid precisa de largura');
    final width = constraints.maxWidth;
    final cols = gridColumns(width, minCardWidth: _minCardWidth);
    final cellWidth = (width - _gap * (cols - 1)) / cols;
    final cell = BoxConstraints.tightFor(width: cellWidth);

    var y = 0.0;
    var rowHeight = 0.0;
    var col = 0;
    var any = false;
    var child = firstChild;
    while (child != null) {
      final pd = child.parentData! as _GridParentData;
      final size = dry
          ? child.getDryLayout(cell)
          : (child..layout(cell, parentUsesSize: true)).size;
      if (size.height > 0) {
        if (col == cols) {
          y += rowHeight + _rowGap;
          rowHeight = 0;
          col = 0;
        }
        if (!dry) pd.offset = Offset(col * (cellWidth + _gap), y);
        rowHeight = math.max(rowHeight, size.height);
        col++;
        any = true;
      } else if (!dry) {
        pd.offset = Offset.zero;
      }
      child = pd.nextSibling;
    }
    return constraints.constrain(Size(width, any ? y + rowHeight : 0));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, dry: true);

  @override
  void performLayout() => size = _layout(constraints, dry: false);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// [ResponsiveGrid] para lista longa (membros, eventos): monta só as linhas
/// visíveis, como um `ListView.builder`. Cada linha tem [gridColumns] cards
/// lado a lado, alinhados pelo topo. [rowGap] separa as linhas (0 quando o
/// item já traz o próprio espaço embaixo).
class ResponsiveGridList extends StatelessWidget {
  const ResponsiveGridList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
    this.gap = 16,
    double? rowGap,
    this.minCardWidth = 320,
  }) : rowGap = rowGap ?? gap;

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsets padding;
  final double gap;
  final double rowGap;
  final double minCardWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final cols = gridColumns(
            c.maxWidth - padding.horizontal,
            minCardWidth: minCardWidth,
          );
          return ListView.separated(
            padding: padding,
            itemCount: (itemCount / cols).ceil(),
            separatorBuilder: (_, __) => SizedBox(height: rowGap),
            itemBuilder: (context, row) {
              if (cols == 1) return itemBuilder(context, row);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < cols; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    Expanded(
                      child: row * cols + i < itemCount
                          ? itemBuilder(context, row * cols + i)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              );
            },
          );
        },
      );
}
