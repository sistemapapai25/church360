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
class ResponsiveGrid extends MultiChildRenderObjectWidget {
  const ResponsiveGrid({
    super.key,
    required super.children,
    this.gap = 12,
    this.minCardWidth = 320,
  });

  final double gap;

  /// Nenhuma coluna fica mais estreita que isto.
  final double minCardWidth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderResponsiveGrid(gap: gap, minCardWidth: minCardWidth);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderResponsiveGrid renderObject,
  ) {
    renderObject
      ..gap = gap
      ..minCardWidth = minCardWidth;
  }
}

class _GridParentData extends ContainerBoxParentData<RenderBox> {}

class RenderResponsiveGrid extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _GridParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _GridParentData> {
  RenderResponsiveGrid({required double gap, required double minCardWidth})
    : _gap = gap,
      _minCardWidth = minCardWidth;

  double _gap;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
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
          y += rowHeight + _gap;
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
