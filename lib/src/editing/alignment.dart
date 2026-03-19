// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

/// 输入框内垂直蒙古文文本的水平对齐方式。
///
/// 一个可以从 -1.0 到 1.0 范围的 [x] 值。-1.0 对齐到输入框的左侧，
/// 以便文本第一行的左侧适合在框及其填充内。0.0 对齐到框的中心。
/// 1.0 对齐，使文本最后一行的右侧与输入框的右内边缘对齐。
///
/// 另请参阅：
///
///  * [TextAlignVertical]，它是水平文本的 [TextField] 版本
///  * [MongolTextField.textAlignHorizontal]，它被传递给 [MongolInputDecorator]。
///  * [MongolInputDecorator.textAlignHorizontal]，它定义了 [MongolInputDecorator] 中前缀、输入和后缀的对齐方式。
class TextAlignHorizontal {
  /// 从 -1.0 到 1.0 之间的任何 x 值创建 TextAlignHorizontal。
  const TextAlignHorizontal({
    required this.x,
  }) : assert(x >= -1.0 && x <= 1.0);

  /// 一个从 -1.0 到 1.0 的值，定义输入框左侧和右侧的最左和最右位置。
  final double x;

  /// 将 MongolTextField 的输入文本与 MongolTextField 输入框内的最左侧位置对齐。
  static const TextAlignHorizontal left = TextAlignHorizontal(x: -1.0);

  /// 将 MongolTextField 的输入文本对齐到 MongolTextField 的中心。
  static const TextAlignHorizontal center = TextAlignHorizontal(x: 0.0);

  /// 将 MongolTextField 的输入文本与 MongolTextField 内的最右侧位置对齐。
  static const TextAlignHorizontal right = TextAlignHorizontal(x: 1.0);

  @override
  String toString() {
    return '${objectRuntimeType(this, 'TextAlignHorizontal')}(x: $x)';
  }
}
