// Copyright 2014 The Flutter Authors.
// Copyright 2020 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart' show Offset, Rect;
import 'mongol_paragraph.dart';

/// 蒙古文文本工具集合
///
/// 此模块包含与蒙古文文本处理相关的各种工具函数和验证方法，
/// 包括 UTF-16 编码检查、坐标转换和光标导航等功能。
///
/// 这些工具函数被 [MongolTextPainter] 和其他文本处理组件使用，
/// 但也可以在其他需要处理蒙古文文本的地方独立使用。
abstract final class MongolTextTools {
  /// ============================================================================
  /// UTF-16 编码检查函数
  /// ============================================================================
  ///
  /// UTF-16 是一种可变长度的字符编码方案。单个字符可能由一个或两个代码单元组成：
  /// - 基本多语言平面 (BMP) 的字符：1 个代码单元
  /// - 补充平面的字符（如表情符号）：2 个代码单元（代理对）
  ///
  /// 这些函数用于识别和验证 UTF-16 代码单元的不同类型。

  /// 检查给定值是否为有效的 UTF-16 代码单元
  ///
  /// UTF-16 代码单元的有效范围是 [0x0000, 0xFFFF]（0 到 65535）。
  ///
  /// 示例：
  /// ```dart
  /// MongolTextTools.isUTF16(0x0041);    // true  (拉丁大写字母 A)
  /// MongolTextTools.isUTF16(0xD800);    // true  (高代理)
  /// MongolTextTools.isUTF16(0x110000);  // false (超出范围)
  /// ```
  static bool isUTF16(int value) {
    return value >= 0x0 && value <= 0xFFFF;
  }

  /// 检查给定值是否为有效的 UTF-16 高代理（第一个代理代码单元）
  ///
  /// 高代理（High Surrogate）用于表示补充字符（Unicode 代码点 U+010000 到 U+10FFFF）
  /// 的第一部分。有效范围：0xD800 到 0xDBFF。
  ///
  /// 高代理总是与后面的低代理一起使用，形成代理对来代表一个完整字符。
  ///
  /// 参数 [value] 必须是有效的 UTF-16 代码单元（[0x0000, 0xFFFF]），否则断言失败。
  ///
  /// 示例：
  /// ```dart
  /// MongolTextTools.isHighSurrogate(0xD800);  // true
  /// MongolTextTools.isHighSurrogate(0xDBFF);  // true
  /// MongolTextTools.isHighSurrogate(0xDC00);  // false (低代理)
  /// MongolTextTools.isHighSurrogate(0x0041);  // false (普通字符)
  /// ```
  ///
  /// 相关链接：
  /// - https://en.wikipedia.org/wiki/UTF-16#Code_points_from_U+010000_to_U+10FFFF
  /// - [isLowSurrogate]
  static bool isHighSurrogate(int value) {
    assert(isUTF16(value),
        'U+${value.toRadixString(16).toUpperCase().padLeft(4, '0')} is not a valid UTF-16 code unit.');
    return value & 0xFC00 == 0xD800;
  }

  /// 检查给定值是否为有效的 UTF-16 低代理（第二个代理代码单元）
  ///
  /// 低代理（Low Surrogate）用于表示补充字符的第二部分。有效范围：0xDC00 到 0xDFFF。
  ///
  /// 低代理总是跟在高代理之后，一起形成代理对。
  ///
  /// 参数 [value] 必须是有效的 UTF-16 代码单元（[0x0000, 0xFFFF]），否则断言失败。
  ///
  /// 示例：
  /// ```dart
  /// MongolTextTools.isLowSurrogate(0xDC00);  // true
  /// MongolTextTools.isLowSurrogate(0xDFFF);  // true
  /// MongolTextTools.isLowSurrogate(0xD800);  // false (高代理)
  /// MongolTextTools.isLowSurrogate(0x0041);  // false (普通字符)
  /// ```
  ///
  /// 相关链接：
  /// - https://en.wikipedia.org/wiki/UTF-16#Code_points_from_U+010000_to_U+10FFFF
  /// - [isHighSurrogate]
  static bool isLowSurrogate(int value) {
    assert(isUTF16(value),
        'U+${value.toRadixString(16).toUpperCase().padLeft(4, '0')} is not a valid UTF-16 code unit.');
    return value & 0xFC00 == 0xDC00;
  }

  /// 检查给定的 UTF-16 代码单元是否为 Unicode 方向性标记
  ///
  /// 方向性标记（Directional Marks）是零宽度字符，不占用可见空间，
  /// 用于控制双向（Bidirectional）文本的显示方向。
  ///
  /// 检查的标记：
  /// - 0x200F：RLM (Right-to-Left Mark) - 强制后续文本为右到左方向
  /// - 0x200E：LRM (Left-to-Right Mark) - 强制后续文本为左到右方向
  ///
  /// 这些字符在处理混合文本方向（如英文中混入阿拉伯文）时很有用。
  ///
  /// 示例：
  /// ```dart
  /// MongolTextTools.isUnicodeDirectionality(0x200F);  // true  (RLM)
  /// MongolTextTools.isUnicodeDirectionality(0x200E);  // true  (LRM)
  /// MongolTextTools.isUnicodeDirectionality(0x0041);  // false (普通字符)
  /// ```
  static bool isUnicodeDirectionality(int value) {
    return value == 0x200F || value == 0x200E;
  }

  /// ============================================================================
  /// 坐标转换函数
  /// ============================================================================
  ///
  /// 这些函数用于在坐标系统之间转换，特别是在段落内部坐标系和绘制坐标系之间。
  /// 当文本有对齐偏移（paintOffset）时，需要应用这些坐标转换。

  /// 对行度量信息应用偏移量变换
  ///
  /// 将指定的行度量信息中的所有坐标通过 [offset] 进行平移。
  /// 这是从段落内部坐标系转换到绘制坐标系的关键操作。
  ///
  /// 此方法创建一个新的 [MongolLineMetrics] 对象，其中包含平移后的坐标值。
  /// 原始对象保持不变。
  ///
  /// 参数说明：
  /// - [metrics]：原始的行度量信息
  /// - [offset]：要应用的坐标偏移（必须是有限值）
  ///
  /// 返回值：
  /// - 新的行度量信息，所有坐标值（`top` 和 `baseline`）都偏移了指定的量
  ///
  /// 示例：
  /// ```dart
  /// final metrics = MongolLineMetrics(
  ///   top: 0.0,
  ///   baseline: 50.0,
  ///   // ... 其他参数
  /// );
  /// final offset = Offset(10.0, 20.0);
  /// final shifted = MongolTextTools.shiftLineMetrics(metrics, offset);
  /// assert(shifted.top == 20.0);       // 0.0 + offset.dy
  /// assert(shifted.baseline == 70.0);  // 50.0 + offset.dx
  /// ```
  static MongolLineMetrics shiftLineMetrics(
      MongolLineMetrics metrics, Offset offset) {
    assert(offset.dx.isFinite, 'Offset.dx must be finite, got ${offset.dx}');
    assert(offset.dy.isFinite, 'Offset.dy must be finite, got ${offset.dy}');
    return MongolLineMetrics(
      hardBreak: metrics.hardBreak,
      ascent: metrics.ascent,
      descent: metrics.descent,
      unscaledAscent: metrics.unscaledAscent,
      height: metrics.height,
      width: metrics.width,
      top: metrics.top + offset.dy,
      baseline: metrics.baseline + offset.dx,
      lineNumber: metrics.lineNumber,
    );
  }

  /// 对文本选择边框应用偏移量变换
  ///
  /// 将指定的矩形通过 [offset] 进行平移。
  /// 这是从段落内部坐标系转换到绘制坐标系的关键操作。
  ///
  /// 此方法创建一个新的 [Rect] 对象，其中所有坐标都被平移。
  /// 原始矩形保持不变。
  ///
  /// 参数说明：
  /// - [box]：原始矩形
  /// - [offset]：要应用的坐标偏移（必须是有限值）
  ///
  /// 返回值：
  /// - 新的矩形，所有坐标值都偏移了指定的量
  ///
  /// 示例：
  /// ```dart
  /// final box = Rect.fromLTRB(10.0, 20.0, 30.0, 40.0);
  /// final offset = Offset(5.0, 10.0);
  /// final shifted = MongolTextTools.shiftTextBox(box, offset);
  /// assert(shifted.left == 15.0);    // 10.0 + 5.0
  /// assert(shifted.top == 30.0);     // 20.0 + 10.0
  /// assert(shifted.right == 35.0);   // 30.0 + 5.0
  /// assert(shifted.bottom == 50.0);  // 40.0 + 10.0
  /// ```
  static Rect shiftTextBox(Rect box, Offset offset) {
    assert(offset.dx.isFinite, 'Offset.dx must be finite, got ${offset.dx}');
    assert(offset.dy.isFinite, 'Offset.dy must be finite, got ${offset.dy}');
    return Rect.fromLTRB(
      box.left + offset.dx,
      box.top + offset.dy,
      box.right + offset.dx,
      box.bottom + offset.dy,
    );
  }

  /// ============================================================================
  /// 光标导航函数
  /// ============================================================================
  ///
  /// 这些函数用于处理文本编辑中的光标导航，特别是处理 UTF-16 代理对的情况。
  /// 确保光标不会放在代理对的中间，导致文本损坏。

  /// 获取在指定偏移量之后最近的可以放置输入光标的位置
  ///
  /// 此方法用于文本编辑中的光标导航（如按右箭头键）。
  /// 它考虑了 UTF-16 代理对，确保光标不会放在代理对的中间。
  ///
  /// 处理过程：
  /// 1. 获取当前位置的代码单元
  /// 2. 如果是高代理，下一个位置向前移动 2（跳过完整的代理对）
  /// 3. 否则向前移动 1
  ///
  /// 参数说明：
  /// - [offset]：当前光标位置
  /// - [text]：要检查的文本
  ///
  /// 返回值：
  /// - 下一个有效光标位置（如果能够向前移动）
  /// - null（如果已在文本末尾）
  ///
  /// 示例：
  /// ```dart
  /// const String text = 'Hello😀World';  // 😀 是代理对 (2个代码单元)
  ///
  /// // 在普通字符处
  /// final pos1 = MongolTextTools.getOffsetAfter(0, text);
  /// assert(pos1 == 1);  // 'H' 后移 1
  ///
  /// // 在代理对处
  /// final pos2 = MongolTextTools.getOffsetAfter(5, text);  // 在 😀 处
  /// assert(pos2 == 7);  // 跳过 2 个代码单元
  /// ```
  static int? getOffsetAfter(int offset, String text) {
    final int nextCodeUnit = text.codeUnitAt(offset);
    return isHighSurrogate(nextCodeUnit) ? offset + 2 : offset + 1;
  }

  /// 获取在指定偏移量之前最近的可以放置输入光标的位置
  ///
  /// 此方法用于文本编辑中的光标导航（如按左箭头键）。
  /// 它考虑了 UTF-16 代理对，确保光标不会放在代理对的中间。
  ///
  /// 处理过程：
  /// 1. 获取前一个位置的代码单元
  /// 2. 如果是低代理，向后移动 2（跳过完整的代理对）
  /// 3. 否则向后移动 1
  ///
  /// 参数说明：
  /// - [offset]：当前光标位置
  /// - [text]：要检查的文本
  ///
  /// 返回值：
  /// - 上一个有效光标位置（如果能够向后移动）
  /// - null（如果已在文本开头）
  ///
  /// 示例：
  /// ```dart
  /// const String text = 'Hello😀World';  // 😀 是代理对 (2个代码单元)
  ///
  /// // 在普通字符处
  /// final pos1 = MongolTextTools.getOffsetBefore(3, text);
  /// assert(pos1 == 2);  // 'l' 前移 1
  ///
  /// // 在代理对后
  /// final pos2 = MongolTextTools.getOffsetBefore(7, text);  // 在 😀 后
  /// assert(pos2 == 5);  // 向后跳过 2 个代码单元
  /// ```
  static int? getOffsetBefore(int offset, String text) {
    final int prevCodeUnit = text.codeUnitAt(offset - 1);
    return isLowSurrogate(prevCodeUnit) ? offset - 2 : offset - 1;
  }

  /// 将两个 UTF-16 代码单元（高代理 + 低代理）组合成一个表示补充字符的代码点
  ///
  /// 补充字符（大于 U+FFFF）需要用两个代码单元表示，称为"代理对"。
  /// 此方法将这对代码单元转换回原始的 Unicode 代码点。
  ///
  /// 参数说明：
  /// - [highSurrogate]：高代理（必须是高代理，否则断言失败）
  /// - [lowSurrogate]：低代理（必须是低代理，否则断言失败）
  ///
  /// 返回值：
  /// - 组合后的 Unicode 代码点（范围 U+010000 到 U+10FFFF）
  ///
  /// 示例：
  /// ```dart
  /// // 笑脸表情 😀 的代码点是 U+1F600
  /// // 在 UTF-16 中表示为代理对：
  /// final highSurrogate = 0xD83D;
  /// final lowSurrogate = 0xDE00;
  ///
  /// final codePoint = MongolTextTools.codePointFromSurrogates(
  ///   highSurrogate,
  ///   lowSurrogate,
  /// );
  /// assert(codePoint == 0x1F600);  // 笑脸表情的代码点
  /// ```
  ///
  /// 相关链接：
  /// - https://en.wikipedia.org/wiki/UTF-16#Code_points_from_U+010000_to_U+10FFFF
  static int codePointFromSurrogates(int highSurrogate, int lowSurrogate) {
    assert(
      isHighSurrogate(highSurrogate),
      'U+${highSurrogate.toRadixString(16).toUpperCase().padLeft(4, '0')} is not a high surrogate.',
    );
    assert(
      isLowSurrogate(lowSurrogate),
      'U+${lowSurrogate.toRadixString(16).toUpperCase().padLeft(4, '0')} is not a low surrogate.',
    );
    const int base = 0x010000 - (0xD800 << 10) - 0xDC00;
    return (highSurrogate << 10) + lowSurrogate + base;
  }
}
