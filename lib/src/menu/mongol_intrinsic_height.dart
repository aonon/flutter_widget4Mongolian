// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 一个将其子级大小调整为子级最大内在高度的小部件。
///
/// 此类很有用，例如，当有无限高度可用时，
/// 您希望一个否则会尝试无限扩展的子级
/// 而是将自己调整到更合理的高度。
///
/// 此小部件传递给其子级的约束将遵循父级的约束，
/// 因此如果约束不足以满足子级的最大内在高度，
/// 则子级将获得比正常情况下更少的高度。同样，
/// 如果最小高度约束大于子级的最大内在高度，
/// 子级将获得比正常情况下更多的宽度。
///
/// 如果 [stepHeight] 不为 null，则子级的高度将被调整为 [stepHeight] 的倍数。
/// 同样，如果 [stepWidth] 不为 null，则子级的宽度将被调整为 [stepWidth] 的倍数。
///
/// 此类相对昂贵，因为它在最终布局阶段之前添加了一个推测性布局过程。
/// 尽可能避免使用它。在最坏的情况下，此小部件可能导致布局的复杂度为 O(N²)，
/// 其中 N 是树的深度。
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

  /// 如果不为 null，强制子级的高度为该值的倍数。
  ///
  /// 如果为 null 或 0.0，则子级的高度将与其最大内在高度相同。
  ///
  /// 此值不能为负数。
  ///
  /// 另请参阅：
  ///
  ///  * [RenderBox.getMaxIntrinsicHeight]，它定义了小部件的最大内在高度。
  final double? stepHeight;

  /// 如果不为 null，强制子级的宽度为该值的倍数。
  ///
  /// 如果为 null 或 0.0，则子级的宽度将不受约束。
  ///
  /// 此值不能为负数。
  final double? stepWidth;

  /// 获取处理后的 stepHeight 值（将 0.0 转换为 null）。
  double? get _stepHeight => stepHeight == 0.0 ? null : stepHeight;
  /// 获取处理后的 stepWidth 值（将 0.0 转换为 null）。
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

/// 将其子级大小调整为子级最大内在高度的渲染对象。
///
/// 此类很有用，例如，当有无限高度可用时，
/// 您希望一个否则会尝试无限扩展的子级
/// 而是将自己调整到更合理的高度。
///
/// 此小部件传递给其子级的约束将遵循父级的约束，
/// 因此如果约束不足以满足子级的最大内在高度，
/// 则子级将获得比正常情况下更少的高度。同样，
/// 如果最小高度约束大于子级的最大内在高度，
/// 子级将获得比正常情况下更多的宽度。
///
/// 如果 [stepHeight] 不为 null，则子级的高度将被调整为 [stepHeight] 的倍数。
/// 同样，如果 [stepWidth] 不为 null，则子级的宽度将被调整为 [stepWidth] 的倍数。
///
/// 此类相对昂贵，因为它在最终布局阶段之前添加了一个推测性布局过程。
/// 尽可能避免使用它。在最坏的情况下，此小部件可能导致布局的复杂度为 O(N²)，
/// 其中 N 是树的深度。
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
    if (!height.isFinite) height = computeMaxIntrinsicHeight(double.infinity);
    assert(height.isFinite);
    final double width = child!.getMinIntrinsicWidth(height);
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
    if (!height.isFinite) height = computeMaxIntrinsicHeight(double.infinity);
    assert(height.isFinite);
    final double width = child!.getMaxIntrinsicWidth(height);
    return _applyStep(width, _stepWidth);
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
