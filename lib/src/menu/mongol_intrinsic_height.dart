// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 根据子级最大内在高度进行布局的组件。
///
/// 适用于父级给出宽松或无限高度时，希望子级不要无限扩展的场景。
/// 若设置 [stepHeight]/[stepWidth]，会把结果向上取整到对应步长倍数。
///
/// 该组件会增加一次额外的推测布局，性能成本较高，应按需使用。
///
/// 另请参阅：
///
///  * [Align]，一个在其内部对齐其子级的小部件。这可用于
///    放松传递给 [MongolRenderIntrinsicHeight] 的约束，
///    允许 [MongolRenderIntrinsicHeight] 的子级小于其父级。
///  * [Column]，当与 [CrossAxisAlignment.stretch] 一起使用时，可用于
///    仅放松传递给 [MongolRenderIntrinsicHeight] 的高度约束，
///    允许 [MongolRenderIntrinsicHeight] 的子级的高度小于其父级。
class MongolIntrinsicHeight extends SingleChildRenderObjectWidget {
  /// 创建一个将其子级大小调整为子级内在高度的小部件。
  ///
  /// 此类相对昂贵。尽可能避免使用它。
  const MongolIntrinsicHeight(
      {super.key, this.stepHeight, this.stepWidth, super.child})
      : assert(stepHeight == null || stepHeight >= 0.0),
        assert(stepWidth == null || stepWidth >= 0.0);

  /// 子级高度步长。
  ///
  /// 为 null 或 0.0 时，按子级最大内在高度布局。
  /// 该值不能为负数。
  final double? stepHeight;

  /// 子级宽度步长。
  ///
  /// 为 null 或 0.0 时，不额外做步长取整。
  /// 该值不能为负数。
  final double? stepWidth;

  double? get _stepHeight => stepHeight == 0.0 ? null : stepHeight;

  double? get _stepWidth => stepWidth == 0.0 ? null : stepWidth;

  /// 创建此小部件的渲染对象。
  @override
  MongolRenderIntrinsicHeight createRenderObject(BuildContext context) {
    return MongolRenderIntrinsicHeight(
        stepHeight: _stepHeight, stepWidth: _stepWidth);
  }

  /// 更新此小部件的渲染对象。
  @override
  void updateRenderObject(
      BuildContext context, MongolRenderIntrinsicHeight renderObject) {
    renderObject
      ..stepHeight = _stepHeight
      ..stepWidth = _stepWidth;
  }
}

/// [MongolIntrinsicHeight] 对应的渲染对象实现。
///
/// 负责在布局前基于子级内在尺寸推导约束，并应用步长取整规则。
///
/// 另请参阅：
///
///  * [Align]，一个在其内部对齐其子级的小部件。这可用于
///    放松传递给 [MongolRenderIntrinsicHeight] 的约束，
///    允许 [MongolRenderIntrinsicHeight] 的子级小于其父级。
///  * [Column]，当与 [CrossAxisAlignment.stretch] 一起使用时，可用于
///    仅放松传递给 [MongolRenderIntrinsicHeight] 的高度约束，
///    允许 [MongolRenderIntrinsicHeight] 的子级的高度小于其父级。
class MongolRenderIntrinsicHeight extends RenderProxyBox {
  /// 创建一个将自身大小调整为其子级内在高度的渲染对象。
  ///
  /// 如果 [stepHeight] 不为 null，则必须 > 0.0。同样，如果 [stepWidth] 不为 null，
  /// 则必须 > 0.0。
  MongolRenderIntrinsicHeight({
    double? stepHeight,
    double? stepWidth,
    RenderBox? child,
  })  : assert(stepHeight == null || stepHeight > 0.0),
        assert(stepWidth == null || stepWidth > 0.0),
        _stepHeight = stepHeight,
        _stepWidth = stepWidth,
        super(child);

  /// 如果不为 null，强制子级的高度为该值的倍数。
  ///
  /// 此值必须为 null 或 > 0.0。
  double? get stepHeight => _stepHeight;
  double? _stepHeight;
  set stepHeight(double? value) {
    assert(value == null || value > 0.0);
    if (value == _stepHeight) return;
    _stepHeight = value;
    markNeedsLayout();
  }

  /// 如果不为 null，强制子级的宽度为该值的倍数。
  ///
  /// 此值必须为 null 或 > 0.0。
  double? get stepWidth => _stepWidth;
  double? _stepWidth;
  set stepWidth(double? value) {
    assert(value == null || value > 0.0);
    if (value == _stepWidth) return;
    _stepWidth = value;
    markNeedsLayout();
  }

  /// 应用步长值到输入值，将输入值向上取整到步长的倍数。
  static double _applyStep(double input, double? step) {
    assert(input.isFinite);
    if (step == null) return input;
    return (input / step).ceil() * step;
  }

  /// 计算此渲染对象的最小内在高度。
  ///
  /// 对于 [MongolRenderIntrinsicHeight]，最小内在高度与最大内在高度相同。
  @override
  double computeMinIntrinsicHeight(double width) {
    return computeMaxIntrinsicHeight(width);
  }

  /// 计算此渲染对象的最大内在高度。
  ///
  /// 如果没有子级，返回 0.0。否则，返回子级的最大内在高度，
  /// 并应用 [stepHeight] 步长值。
  @override
  double computeMaxIntrinsicHeight(double width) {
    if (child == null) return 0.0;
    final double height = child!.getMaxIntrinsicHeight(width);
    return _applyStep(height, _stepHeight);
  }

  /// 计算此渲染对象的最小内在宽度。
  ///
  /// 如果没有子级，返回 0.0。如果高度不是有限值，
  /// 则使用最大内在高度作为高度值。然后返回子级的最小内在宽度，
  /// 并应用 [stepWidth] 步长值。
  @override
  double computeMinIntrinsicWidth(double height) {
    if (child == null) return 0.0;
    final double resolvedHeight = _effectiveHeightForIntrinsicWidth(height);
    final double width = child!.getMinIntrinsicWidth(resolvedHeight);
    return _applyStep(width, _stepWidth);
  }

  /// 计算此渲染对象的最大内在宽度。
  ///
  /// 如果没有子级，返回 0.0。如果高度不是有限值，
  /// 则使用最大内在高度作为高度值。然后返回子级的最大内在宽度，
  /// 并应用 [stepWidth] 步长值。
  @override
  double computeMaxIntrinsicWidth(double height) {
    if (child == null) return 0.0;
    final double resolvedHeight = _effectiveHeightForIntrinsicWidth(height);
    final double width = child!.getMaxIntrinsicWidth(resolvedHeight);
    return _applyStep(width, _stepWidth);
  }

  double _effectiveHeightForIntrinsicWidth(double height) {
    if (height.isFinite) {
      return height;
    }
    final double intrinsicHeight = computeMaxIntrinsicHeight(double.infinity);
    assert(intrinsicHeight.isFinite);
    return intrinsicHeight;
  }

  /// 计算此渲染对象的大小。
  ///
  /// 如果有子级，并且约束没有固定高度，则计算子级的最大内在高度，
  /// 并应用 [stepHeight] 步长值来收紧高度约束。如果 [stepWidth] 不为 null，
  /// 则计算子级的最大内在宽度，并应用 [stepWidth] 步长值来收紧宽度约束。
  /// 然后使用这些约束来布局子级。如果没有子级，则返回约束的最小大小。
  Size _computeSize(
      {required ChildLayouter layoutChild,
      required BoxConstraints constraints}) {
    if (child != null) {
      if (!constraints.hasTightHeight) {
        final double height =
            child!.getMaxIntrinsicHeight(constraints.maxWidth);
        assert(height.isFinite);
        constraints =
            constraints.tighten(height: _applyStep(height, _stepHeight));
      }
      if (_stepWidth != null) {
        final double width = child!.getMaxIntrinsicWidth(constraints.maxHeight);
        assert(width.isFinite);
        constraints = constraints.tighten(width: _applyStep(width, _stepWidth));
      }
      return layoutChild(child!, constraints);
    } else {
      return constraints.smallest;
    }
  }

  /// 执行干布局计算，返回此渲染对象的大小，而不实际布局子级。
  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return _computeSize(
      layoutChild: ChildLayoutHelper.dryLayoutChild,
      constraints: constraints,
    );
  }

  /// 执行实际布局，设置此渲染对象的大小，并布局其子级。
  @override
  void performLayout() {
    size = _computeSize(
      layoutChild: ChildLayoutHelper.layoutChild,
      constraints: constraints,
    );
  }

  /// 填充诊断属性，用于调试。
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('stepHeight', stepHeight));
    properties.add(DoubleProperty('stepWidth', stepWidth));
  }
}
