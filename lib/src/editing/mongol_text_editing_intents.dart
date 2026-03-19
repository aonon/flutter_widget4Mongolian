// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

/// 扩展或移动当前选择范围，从当前 [TextSelection.extent] 位置到前一个或后一个字符边界
///
/// 用于垂直蒙古文文本的字符级选择操作
class MongolExtendSelectionByCharacterIntent
    extends ExtendSelectionByCharacterIntent {
  /// 创建一个 [MongolExtendSelectionByCharacterIntent]
  ///
  /// [forward] 表示是否向前移动（true）或向后移动（false）
  /// [collapseSelection] 表示是否在移动后折叠选择范围
  const MongolExtendSelectionByCharacterIntent(
      {required super.forward, required super.collapseSelection});
}

/// 扩展或移动当前选择范围，从当前 [TextSelection.extent] 位置到相邻行上的最近位置
///
/// 用于垂直蒙古文文本的行级选择操作
class MongolExtendSelectionHorizontallyToAdjacentLineIntent
    extends ExtendSelectionVerticallyToAdjacentLineIntent {
  /// 创建一个 [MongolExtendSelectionHorizontallyToAdjacentLineIntent]
  ///
  /// [forward] 表示是否向前移动（true）或向后移动（false）
  /// [collapseSelection] 表示是否在移动后折叠选择范围
  const MongolExtendSelectionHorizontallyToAdjacentLineIntent(
      {required super.forward, required super.collapseSelection});
}

/// 将当前选择范围扩展到 [forward] 方向上最近的行 break
///
/// 基础或扩展点都可以移动，以更接近行 break 的为准
/// 选择范围永远不会缩小
///
/// 这种行为在 MacOS 上很常见
///
/// 另请参见：
///
///   [MongolExtendSelectionToLineBreakIntent]，它类似但总是移动扩展点
class MongolExpandSelectionToLineBreakIntent
    extends ExpandSelectionToLineBreakIntent {
  /// 创建一个 [MongolExpandSelectionToLineBreakIntent]
  ///
  /// [forward] 表示扩展的方向
  const MongolExpandSelectionToLineBreakIntent({required super.forward});
}

/// 扩展或移动当前选择范围，从当前 [TextSelection.extent] 位置到 [forward] 方向上最近的行 break
///
/// 另请参见：
///
///   [ExpandSelectionToLineBreakIntent]，它类似但总是增加选择范围的大小
class MongolExtendSelectionToLineBreakIntent
    extends ExtendSelectionToLineBreakIntent {
  /// 创建一个 [MongolExtendSelectionToLineBreakIntent]
  ///
  /// [forward] 表示扩展的方向
  /// [collapseSelection] 表示是否在移动后折叠选择范围
  /// [collapseAtReversal] 表示在选择范围反转时是否折叠
  /// [continuesAtWrap] 表示是否在换行处继续
  const MongolExtendSelectionToLineBreakIntent(
      {required super.forward,
      required super.collapseSelection,
      super.collapseAtReversal,
      super.continuesAtWrap});
}

/// 扩展或移动当前选择范围，从当前 [TextSelection.extent] 位置到文档的开头或结尾
///
/// 另请参见：
///
///   [ExtendSelectionToDocumentBoundaryIntent]，它类似但总是增加选择范围的大小
class MongolExtendSelectionToDocumentBoundaryIntent
    extends ExtendSelectionToDocumentBoundaryIntent {
  /// 创建一个 [MongolExtendSelectionToDocumentBoundaryIntent]
  ///
  /// [forward] 表示是否向前移动（到文档结尾）或向后移动（到文档开头）
  /// [collapseSelection] 表示是否在移动后折叠选择范围
  const MongolExtendSelectionToDocumentBoundaryIntent(
      {required super.forward, required super.collapseSelection});
}

/// 扩展或移动当前选择范围，从当前 [TextSelection.extent] 位置到前一个或后一个单词边界
///
/// 用于垂直蒙古文文本的单词级选择操作
class MongolExtendSelectionToNextWordBoundaryIntent
    extends ExtendSelectionToNextWordBoundaryIntent {
  /// 创建一个 [MongolExtendSelectionToNextWordBoundaryIntent]
  ///
  /// [forward] 表示是否向前移动（true）或向后移动（false）
  /// [collapseSelection] 表示是否在移动后折叠选择范围
  const MongolExtendSelectionToNextWordBoundaryIntent(
      {required super.forward, required super.collapseSelection});
}

/// 扩展或移动当前选择范围，从当前 [TextSelection.extent] 位置到前一个或后一个单词边界，
/// 或者如果 [TextSelection.base] 位置在移动方向上更近，则移动到该位置
///
/// 这个 [Intent] 通常与 [MongolExtendSelectionToNextWordBoundaryIntent] 具有相同的效果，
/// 除了当 [TextSelection.base] 和 [TextSelection.extent] 的顺序会反转时，它会折叠选择范围
///
/// 这通常仅在 MacOS 上使用
class MongolExtendSelectionToNextWordBoundaryOrCaretLocationIntent
    extends ExtendSelectionToNextWordBoundaryOrCaretLocationIntent {
  /// 创建一个 [MongolExtendSelectionToNextWordBoundaryOrCaretLocationIntent]
  ///
  /// [forward] 表示移动的方向
  const MongolExtendSelectionToNextWordBoundaryOrCaretLocationIntent(
      {required super.forward});
}
