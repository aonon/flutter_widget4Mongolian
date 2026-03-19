// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// 如果适合，将工具栏定位到 [anchorLeft] 的左侧，否则定位到 [anchorRight] 的右侧。
///
/// 另请参阅：
///
///   * [MongolTextSelectionToolbar]，它使用此来定位自己。
class MongolTextSelectionToolbarLayoutDelegate extends SingleChildLayoutDelegate {
  /// 创建 MongolTextSelectionToolbarLayoutDelegate 的实例。
  MongolTextSelectionToolbarLayoutDelegate({
    required this.anchorLeft,
    required this.anchorRight,
    this.fitsLeft,
  });

  /// 工具栏尝试定位到其左侧的焦点。
  ///
  /// 如果在到达屏幕左侧之前左侧没有足够的空间，
  /// 则工具栏将定位到 [anchorRight] 的右侧。
  ///
  /// 应以局部坐标提供。
  final Offset anchorLeft;

  /// 如果工具栏不适合 [anchorLeft] 的左侧，则它尝试定位到其右侧的焦点。
  ///
  /// 应以局部坐标提供。
  final Offset anchorRight;

  /// 子项是否应被视为适合 anchorLeft 的左侧。
  ///
  /// 通常用于强制子项即使不适合也绘制在 anchorLeft 处，
  /// 例如当 [MongolTextSelectionToolbar] 绘制打开的溢出菜单时。
  ///
  /// 如果未提供，将进行计算。
  final bool? fitsLeft;

  // 返回尽可能将高度居中到位置的值，同时适应最小和最大值。
  static double _centerOn(double position, double height, double max) {
    // 如果它向上溢出，将其尽可能向上放置。
    if (position - height / 2.0 < 0.0) {
      return 0.0;
    }

    // 如果它向下溢出，将其尽可能向下放置。
    if (position + height / 2.0 > max) {
      return max - height;
    }

    // 否则它在完全居中的情况下适合。
    return position - height / 2.0;
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return constraints.loosen();
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final fitsLeft = this.fitsLeft ?? anchorLeft.dx >= childSize.width;
    final anchor = fitsLeft ? anchorLeft : anchorRight;

    return Offset(
      fitsLeft
        ? math.max(0.0, anchor.dx - childSize.width)
        : anchor.dx,
      _centerOn(
        anchor.dy,
        childSize.height,
        size.height,
      ),
    );
  }

  @override
  bool shouldRelayout(MongolTextSelectionToolbarLayoutDelegate oldDelegate) {
    return anchorLeft != oldDelegate.anchorLeft
        || anchorRight != oldDelegate.anchorRight
        || fitsLeft != oldDelegate.fitsLeft;
  }
}
