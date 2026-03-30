// Copyright 2014 The Flutter Authors.
// Copyright 2022 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart'
    show
        InputBorder,
        OutlineInputBorder,
        BorderSide,
        BorderRadius,
        Radius,
        EdgeInsetsGeometry,
        EdgeInsets,
        ShapeBorder;

/// 为 [MongolInputDecorator] 的容器右侧绘制一条垂直线，并定义容器的形状。
///
/// 输入装饰器的"容器"是装饰器的辅助文本、错误文本和计数器左侧的可选填充区域。
///
/// 另请参见：
///
///  * [OutlineInputBorder]，一个 [InputDecorator] 边框，它在输入装饰器的容器周围绘制一个
///    圆角矩形。
///  * [InputDecoration]，用于配置 [MongolInputDecorator]。
class SidelineInputBorder extends InputBorder {
  /// 为 [MongolInputDecorator] 创建右侧的单线条边框。
  ///
  /// [borderSide] 参数默认为 [BorderSide.none]（不能为空）。应用程序通常不指定
  /// [borderSide] 参数，因为输入装饰器会根据当前主题和 [MongolInputDecorator.isFocused]
  /// 使用 [copyWith] 替换自己的边框。
  ///
  /// [borderRadius] 参数默认为左上角和左下角具有 4.0 圆形半径的值。
  /// [borderRadius] 参数不能为空。
  const SidelineInputBorder({
    super.borderSide = const BorderSide(),
    this.borderRadius = const BorderRadius.only(
      topLeft: Radius.circular(4.0),
      bottomLeft: Radius.circular(4.0),
    ),
  });

  /// 边框圆角矩形角的半径。
  ///
  /// 当此边框与填充的输入装饰器一起使用时，参见 [InputDecoration.filled]，
  /// 边框半径定义背景填充的形状以及边线本身的右上和右下边缘。
  ///
  /// 默认情况下，左上角和左下角的圆形半径为 4.0。
  final BorderRadius borderRadius;

  @override
  bool get isOutline => false;

  @override
  SidelineInputBorder copyWith(
      {BorderSide? borderSide, BorderRadius? borderRadius}) {
    return SidelineInputBorder(
      borderSide: borderSide ?? this.borderSide,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  @override
  EdgeInsetsGeometry get dimensions {
    return EdgeInsets.only(right: borderSide.width);
  }

  @override
  SidelineInputBorder scale(double t) {
    return SidelineInputBorder(
      borderSide: borderSide.scale(t),
      borderRadius: borderRadius * t,
    );
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..addRect(Rect.fromLTWH(rect.left, rect.top,
          math.max(0.0, rect.width - borderSide.width), rect.height));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRRect(borderRadius.toRRect(rect));
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is SidelineInputBorder) {
      return SidelineInputBorder(
        borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
        borderRadius: BorderRadius.lerp(a.borderRadius, borderRadius, t)!,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is SidelineInputBorder) {
      return SidelineInputBorder(
        borderSide: BorderSide.lerp(borderSide, b.borderSide, t),
        borderRadius: BorderRadius.lerp(borderRadius, b.borderRadius, t)!,
      );
    }
    return super.lerpTo(b, t);
  }

  /// 在 [rect] 的右侧绘制一条垂直线。
  ///
  /// [borderSide] 定义线条的颜色和粗细。
  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    if (borderRadius.topRight != Radius.zero ||
        borderRadius.bottomRight != Radius.zero) {
      canvas.clipPath(getOuterPath(rect, textDirection: textDirection));
    }
    canvas.drawLine(rect.topRight, rect.bottomRight, borderSide.toPaint());
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is SidelineInputBorder &&
        other.borderSide == borderSide &&
        other.borderRadius == borderRadius;
  }

  @override
  int get hashCode => Object.hash(borderSide, borderRadius);
}

/// 在 [MongolInputDecorator] 的容器周围绘制一个圆角矩形。
///
/// 当输入装饰器的标签浮动时，例如因为其输入子项获得焦点，标签会出现在边框轮廓的间隙中。
///
/// 另请参见：
///
///  * [SidelineInputBorder]，默认的 [InputDecorator] 边框，它在输入装饰器的容器右侧绘制一条垂直线。
///  * [InputDecoration]，用于配置 [MongolInputDecorator]。
class MongolOutlineInputBorder extends InputBorder {
  /// 为 [MongolInputDecorator] 创建一个圆角矩形轮廓边框。
  ///
  /// 如果 [borderSide] 参数为 [BorderSide.none]，则不会绘制边框。
  /// 但是，它仍然会定义一个形状（如果 [InputDecoration.filled] 为 true，您可以看到）。
  ///
  /// 如果应用程序未指定值为 [BorderSide.none] 的 [borderSide] 参数，
  /// 输入装饰器会使用 [copyWith] 替换自己的边框，基于当前主题和 [InputDecorator.isFocused]。
  ///
  /// [borderRadius] 参数默认为所有四个角都有 4.0 圆形半径的值。
  /// [borderRadius] 参数不能为空，且角半径必须是圆形的，即它们的
  /// [Radius.x] 和 [Radius.y] 值必须相同。
  ///
  /// 另请参见：
  ///
  ///  * [InputDecoration.floatingLabelBehavior]，当 [borderSide] 为
  ///    [BorderSide.none] 时，应设置为 [FloatingLabelBehavior.never]。
  ///    如果保留为 [FloatingLabelBehavior.auto]，标签将延伸超出容器，就好像边框仍在绘制一样。
  const MongolOutlineInputBorder({
    super.borderSide = const BorderSide(),
    this.borderRadius = const BorderRadius.all(Radius.circular(4.0)),
    this.gapPadding = 4.0,
  }) : assert(gapPadding >= 0.0);

  // 这不能由构造函数检查，因为是 const 构造函数。
  static bool _cornersAreCircular(BorderRadius borderRadius) {
    return borderRadius.topLeft.x == borderRadius.topLeft.y &&
        borderRadius.bottomLeft.x == borderRadius.bottomLeft.y &&
        borderRadius.topRight.x == borderRadius.topRight.y &&
        borderRadius.bottomRight.x == borderRadius.bottomRight.y;
  }

  /// 边框的 [InputDecoration.labelText] 高度间隙两侧的垂直填充。
  ///
  /// 此值由 [paint] 方法用于计算实际间隙宽度。
  final double gapPadding;

  /// 边框圆角矩形角的半径。
  ///
  /// 角半径必须是圆形的，即它们的 [Radius.x] 和 [Radius.y] 值必须相同。
  final BorderRadius borderRadius;

  @override
  bool get isOutline => true;

  @override
  MongolOutlineInputBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
    double? gapPadding,
  }) {
    return MongolOutlineInputBorder(
      borderSide: borderSide ?? this.borderSide,
      borderRadius: borderRadius ?? this.borderRadius,
      gapPadding: gapPadding ?? this.gapPadding,
    );
  }

  @override
  EdgeInsetsGeometry get dimensions {
    return EdgeInsets.all(borderSide.width);
  }

  @override
  MongolOutlineInputBorder scale(double t) {
    return MongolOutlineInputBorder(
      borderSide: borderSide.scale(t),
      borderRadius: borderRadius * t,
      gapPadding: gapPadding * t,
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is MongolOutlineInputBorder) {
      final MongolOutlineInputBorder outline = a;
      return MongolOutlineInputBorder(
        borderRadius: BorderRadius.lerp(outline.borderRadius, borderRadius, t)!,
        borderSide: BorderSide.lerp(outline.borderSide, borderSide, t),
        gapPadding: lerpDouble(outline.gapPadding, gapPadding, t)!,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is MongolOutlineInputBorder) {
      final MongolOutlineInputBorder outline = b;
      return MongolOutlineInputBorder(
        borderRadius: BorderRadius.lerp(borderRadius, outline.borderRadius, t)!,
        borderSide: BorderSide.lerp(borderSide, outline.borderSide, t),
        gapPadding: lerpDouble(gapPadding, outline.gapPadding, t)!,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..addRRect(borderRadius
          .resolve(textDirection)
          .toRRect(rect)
          .deflate(borderSide.width));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRRect(borderRadius.resolve(textDirection).toRRect(rect));
  }

  Path _gapBorderPath(
      Canvas canvas, RRect center, double start, double extent) {
    // 当任何一侧的角半径加起来大于给定的宽度时，每个半径都必须缩放以不超过
    // RRect 的宽度/高度大小。
    final RRect scaledRRect = center.scaleRadii();

    final Rect tlCorner = Rect.fromLTWH(
      scaledRRect.left,
      scaledRRect.top,
      scaledRRect.tlRadiusX * 2.0,
      scaledRRect.tlRadiusY * 2.0,
    );
    final Rect trCorner = Rect.fromLTWH(
      scaledRRect.right - scaledRRect.trRadiusX * 2.0,
      scaledRRect.top,
      scaledRRect.trRadiusX * 2.0,
      scaledRRect.trRadiusY * 2.0,
    );
    final Rect brCorner = Rect.fromLTWH(
      scaledRRect.right - scaledRRect.brRadiusX * 2.0,
      scaledRRect.bottom - scaledRRect.brRadiusY * 2.0,
      scaledRRect.brRadiusX * 2.0,
      scaledRRect.brRadiusY * 2.0,
    );
    final Rect blCorner = Rect.fromLTWH(
      scaledRRect.left,
      scaledRRect.bottom - scaledRRect.blRadiusY * 2.0,
      scaledRRect.blRadiusX * 2.0,
      scaledRRect.blRadiusY * 2.0,
    );

    // 与 OutlineInputBorder 不同，MongolOutlineInputBorder 忽略角落周围的部分扫描。
    // 它在所有四个角落都是简单的 90 度。
    const double cornerArcSweep = math.pi / 2.0; // 90 度
    final Path path = Path()
      ..addArc(tlCorner, math.pi, cornerArcSweep)
      ..lineTo(scaledRRect.right - scaledRRect.trRadiusX, scaledRRect.top)
      ..addArc(trCorner, (3 * math.pi) / 2.0, cornerArcSweep)
      ..lineTo(scaledRRect.right, scaledRRect.bottom - scaledRRect.brRadiusY)
      ..addArc(brCorner, 0.0, cornerArcSweep)
      ..lineTo(scaledRRect.left + scaledRRect.blRadiusX, scaledRRect.bottom);

    // 如果文本太长，不要绘制左下角。
    if (start + extent < scaledRRect.height - scaledRRect.blRadiusY) {
      path.addArc(blCorner, math.pi / 2, cornerArcSweep);
      path.lineTo(scaledRRect.left, scaledRRect.top + start + extent);
    }

    // 不要为范围间隙绘制线条。
    path.moveTo(scaledRRect.left, start);

    // 完成从间隙顶部到角落的小线段。
    if (start > scaledRRect.tlRadiusY) {
      path.lineTo(scaledRRect.left, scaledRRect.tlRadiusY);
    }

    return path;
  }

  /// 使用 [borderRadius] 在 [rect] 周围绘制一个圆角矩形。
  ///
  /// [borderSide] 定义线条的颜色和粗细。
  ///
  /// 如果 [gapExtent] 非空，圆角矩形的顶部可能会被单个间隙中断。
  /// 在这种情况下，间隙从 `gapStart - gapPadding` 开始。
  /// 间隙的高度是 `(gapPadding + gapExtent + gapPadding) * gapPercentage`。
  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    assert(gapPercentage >= 0.0 && gapPercentage <= 1.0);
    assert(_cornersAreCircular(borderRadius));

    final Paint paint = borderSide.toPaint();
    final RRect outer = borderRadius.toRRect(rect);
    final RRect center = outer.deflate(borderSide.width / 2.0);
    if (gapStart == null || gapExtent <= 0.0 || gapPercentage == 0.0) {
      canvas.drawRRect(center, paint);
    } else {
      final double extent = lerpDouble(
        0.0,
        gapExtent + gapPadding * 2.0,
        gapPercentage,
      )!;
      final Path path = _gapBorderPath(
        canvas,
        center,
        math.max(0.0, gapStart - gapPadding),
        extent,
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is MongolOutlineInputBorder &&
        other.borderSide == borderSide &&
        other.borderRadius == borderRadius &&
        other.gapPadding == gapPadding;
  }

  @override
  int get hashCode => Object.hash(borderSide, borderRadius, gapPadding);
}
