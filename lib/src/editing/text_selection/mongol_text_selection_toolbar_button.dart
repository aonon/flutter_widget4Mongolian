// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart'
    show Theme, Brightness, Colors, IconButton;
import 'package:flutter/widgets.dart';

enum _TextSelectionToolbarItemPosition {
  /// 菜单中多个项目中的第一个。
  first,

  /// 多个项目中的一个，不是第一个或最后一个。
  middle,

  /// 菜单中多个项目中的最后一个。
  last,

  /// 菜单中的唯一项目。
  only,
}

/// 样式类似于 Material 原生 Android 文本选择菜单按钮的按钮。
class MongolTextSelectionToolbarButton extends StatelessWidget {
  /// 创建 MongolTextSelectionToolbarButton 的实例。
  const MongolTextSelectionToolbarButton({
    super.key,
    required this.child,
    required this.padding,
    this.onPressed,
  });

  // 这些值是在运行 Android 10 的 Pixel 2 上目测以匹配原生文本选择菜单。
  static const double _kMiddlePadding = 9.5;
  static const double _kEndPadding = 14.5;
  static const EdgeInsets _kFirstPadding =
      EdgeInsets.only(top: _kEndPadding, bottom: _kMiddlePadding);
  static const EdgeInsets _kMiddleItemPadding =
      EdgeInsets.only(top: _kMiddlePadding, bottom: _kMiddlePadding);
  static const EdgeInsets _kLastPadding =
      EdgeInsets.only(top: _kMiddlePadding, bottom: _kEndPadding);
  static const EdgeInsets _kOnlyPadding =
      EdgeInsets.only(top: _kEndPadding, bottom: _kEndPadding);

  /// 此按钮的子项。
  ///
  /// 通常是一个 [Icon]。
  final Widget child;

  /// 当此按钮被按下时调用。
  final VoidCallback? onPressed;

  /// 按钮边缘与其子项之间的填充。
  ///
  /// 另请参阅：
  ///
  ///  * [getPadding]，它根据按钮的位置计算标准填充。
  ///  * [ButtonStyle.padding]，这是应用此填充的地方。
  final EdgeInsets padding;

  /// 返回基于总按钮数中索引位置的按钮的标准填充。
  static EdgeInsets getPadding(int index, int total) {
    assert(total > 0 && index >= 0 && index < total);
    switch (_getPosition(index, total)) {
      case _TextSelectionToolbarItemPosition.first:
        return _kFirstPadding;
      case _TextSelectionToolbarItemPosition.middle:
        return _kMiddleItemPadding;
      case _TextSelectionToolbarItemPosition.last:
        return _kLastPadding;
      case _TextSelectionToolbarItemPosition.only:
        return _kOnlyPadding;
    }
  }

  static _TextSelectionToolbarItemPosition _getPosition(int index, int total) {
    if (index == 0) {
      return total == 1
          ? _TextSelectionToolbarItemPosition.only
          : _TextSelectionToolbarItemPosition.first;
    }
    if (index == total - 1) {
      return _TextSelectionToolbarItemPosition.last;
    }
    return _TextSelectionToolbarItemPosition.middle;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.colorScheme.brightness == Brightness.dark;
    final primary = isDark ? Colors.white : Colors.black87;

    return IconButton(
      padding: padding,
      color: primary,
      onPressed: onPressed,
      icon: child,
    );
  }
}
