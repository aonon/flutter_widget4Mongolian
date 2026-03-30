// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'mongol_text_editing_intents.dart';

/// 切换上下箭头键和左右箭头键的行为
///
/// 将此小部件插入到 MaterialApp（或 WidgetsApp 或 CupertinoApp）正下方，
/// 以使箭头键在 `MongolTextField` 中按预期工作
///
/// ```
/// MaterialApp(
///   builder: (context, child) => MongolTextEditingShortcuts(child: child),
/// ```
class MongolTextEditingShortcuts extends StatelessWidget {
  /// 创建一个 [MongolTextEditingShortcuts] 小部件
  ///
  /// [child] 是子小部件
  const MongolTextEditingShortcuts({super.key, required this.child});

  /// 子小部件
  final Widget? child;

  /// 大多数平台共享的快捷键，除了 macOS，它使用不同的修饰键来进行行/单词修饰
  static const Map<ShortcutActivator, Intent> _commonShortcuts =
      <ShortcutActivator, Intent>{
    // 箭头键：移动选择范围
    SingleActivator(LogicalKeyboardKey.arrowUp):
        MongolExtendSelectionByCharacterIntent(
            forward: false, collapseSelection: true), // 上箭头：向上移动一个字符
    SingleActivator(LogicalKeyboardKey.arrowDown):
        MongolExtendSelectionByCharacterIntent(
            forward: true, collapseSelection: true), // 下箭头：向下移动一个字符
    SingleActivator(LogicalKeyboardKey.arrowLeft):
        MongolExtendSelectionHorizontallyToAdjacentLineIntent(
            forward: false, collapseSelection: true), // 左箭头：向左移动到相邻行
    SingleActivator(LogicalKeyboardKey.arrowRight):
        MongolExtendSelectionHorizontallyToAdjacentLineIntent(
            forward: true, collapseSelection: true), // 右箭头：向右移动到相邻行

    // Shift + 箭头：扩展选择范围
    SingleActivator(LogicalKeyboardKey.arrowUp, shift: true):
        MongolExtendSelectionByCharacterIntent(
            forward: false, collapseSelection: false), // Shift + 上箭头：向上扩展选择一个字符
    SingleActivator(LogicalKeyboardKey.arrowDown, shift: true):
        MongolExtendSelectionByCharacterIntent(
            forward: true, collapseSelection: false), // Shift + 下箭头：向下扩展选择一个字符
    SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
        MongolExtendSelectionHorizontallyToAdjacentLineIntent(
            forward: false, collapseSelection: false), // Shift + 左箭头：向左扩展选择到相邻行
    SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
        MongolExtendSelectionHorizontallyToAdjacentLineIntent(
            forward: true, collapseSelection: false), // Shift + 右箭头：向右扩展选择到相邻行

    // Alt + 箭头：移动到行 break 或文档边界
    SingleActivator(LogicalKeyboardKey.arrowUp, alt: true):
        MongolExtendSelectionToLineBreakIntent(
            forward: false, collapseSelection: true), // Alt + 上箭头：移动到上行的行首
    SingleActivator(LogicalKeyboardKey.arrowDown, alt: true):
        MongolExtendSelectionToLineBreakIntent(
            forward: true, collapseSelection: true), // Alt + 下箭头：移动到下行的行首
    SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
        MongolExtendSelectionToDocumentBoundaryIntent(
            forward: false, collapseSelection: true), // Alt + 左箭头：移动到文档开头
    SingleActivator(LogicalKeyboardKey.arrowRight, alt: true):
        MongolExtendSelectionToDocumentBoundaryIntent(
            forward: true, collapseSelection: true), // Alt + 右箭头：移动到文档结尾

    // Shift + Alt + 箭头：扩展选择到行 break 或文档边界
    SingleActivator(LogicalKeyboardKey.arrowUp, shift: true, alt: true):
        MongolExtendSelectionToLineBreakIntent(
            forward: false,
            collapseSelection: false), // Shift + Alt + 上箭头：向上扩展选择到行首
    SingleActivator(LogicalKeyboardKey.arrowDown, shift: true, alt: true):
        MongolExtendSelectionToLineBreakIntent(
            forward: true,
            collapseSelection: false), // Shift + Alt + 下箭头：向下扩展选择到行首
    SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true, alt: true):
        MongolExtendSelectionToDocumentBoundaryIntent(
            forward: false,
            collapseSelection: false), // Shift + Alt + 左箭头：扩展选择到文档开头
    SingleActivator(LogicalKeyboardKey.arrowRight, shift: true, alt: true):
        MongolExtendSelectionToDocumentBoundaryIntent(
            forward: true,
            collapseSelection: false), // Shift + Alt + 右箭头：扩展选择到文档结尾

    // Control + 箭头：移动到单词边界
    SingleActivator(LogicalKeyboardKey.arrowUp, control: true):
        MongolExtendSelectionToNextWordBoundaryIntent(
            forward: false,
            collapseSelection: true), // Control + 上箭头：向上移动到上一个单词边界
    SingleActivator(LogicalKeyboardKey.arrowDown, control: true):
        MongolExtendSelectionToNextWordBoundaryIntent(
            forward: true,
            collapseSelection: true), // Control + 下箭头：向下移动到下一个单词边界

    // Shift + Control + 箭头：扩展选择到单词边界
    SingleActivator(LogicalKeyboardKey.arrowUp, shift: true, control: true):
        MongolExtendSelectionToNextWordBoundaryIntent(
            forward: false,
            collapseSelection: false), // Shift + Control + 上箭头：向上扩展选择到上一个单词边界
    SingleActivator(LogicalKeyboardKey.arrowDown, shift: true, control: true):
        MongolExtendSelectionToNextWordBoundaryIntent(
            forward: true,
            collapseSelection: false), // Shift + Control + 下箭头：向下扩展选择到下一个单词边界
  };

  // 以下按键组合在此平台上对文本编辑没有影响：
  //   * End
  //   * Home
  //   * Meta + X
  //   * Meta + C
  //   * Meta + V
  //   * Meta + A
  //   * Meta + shift? + Z
  //   * Meta + shift? + arrow down
  //   * Meta + shift? + arrow left
  //   * Meta + shift? + arrow right
  //   * Meta + shift? + arrow up
  //   * Shift + end
  //   * Shift + home
  //   * Meta + shift? + delete
  //   * Meta + shift? + backspace
  // macOS 文档快捷键：https://support.apple.com/en-us/HT201236
  // macOS 快捷键使用与大多数其他平台不同的单词/行修饰符
  static const Map<ShortcutActivator, Intent> _macShortcuts =
      <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowUp):
        MongolExtendSelectionByCharacterIntent(
            forward: false, collapseSelection: true), // 上箭头：向上移动一个字符
    SingleActivator(LogicalKeyboardKey.arrowDown):
        MongolExtendSelectionByCharacterIntent(
            forward: true, collapseSelection: true), // 下箭头：向下移动一个字符
    SingleActivator(LogicalKeyboardKey.arrowLeft):
        MongolExtendSelectionHorizontallyToAdjacentLineIntent(
            forward: false, collapseSelection: true), // 左箭头：向左移动到相邻行
    SingleActivator(LogicalKeyboardKey.arrowRight):
        MongolExtendSelectionHorizontallyToAdjacentLineIntent(
            forward: true, collapseSelection: true), // 右箭头：向右移动到相邻行

    // Shift + 箭头：扩展选择范围
    SingleActivator(LogicalKeyboardKey.arrowUp, shift: true):
        MongolExtendSelectionByCharacterIntent(
            forward: false, collapseSelection: false), // Shift + 上箭头：向上扩展选择一个字符
    SingleActivator(LogicalKeyboardKey.arrowDown, shift: true):
        MongolExtendSelectionByCharacterIntent(
            forward: true, collapseSelection: false), // Shift + 下箭头：向下扩展选择一个字符
    SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
        MongolExtendSelectionHorizontallyToAdjacentLineIntent(
            forward: false, collapseSelection: false), // Shift + 左箭头：向左扩展选择到相邻行
    SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
        MongolExtendSelectionHorizontallyToAdjacentLineIntent(
            forward: true, collapseSelection: false), // Shift + 右箭头：向右扩展选择到相邻行

    // Alt + 箭头：移动到单词边界或行 break
    SingleActivator(LogicalKeyboardKey.arrowUp, alt: true):
        MongolExtendSelectionToNextWordBoundaryIntent(
            forward: false, collapseSelection: true), // Alt + 上箭头：向上移动到上一个单词边界
    SingleActivator(LogicalKeyboardKey.arrowDown, alt: true):
        MongolExtendSelectionToNextWordBoundaryIntent(
            forward: true, collapseSelection: true), // Alt + 下箭头：向下移动到下一个单词边界
    SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
        MongolExtendSelectionToLineBreakIntent(
            forward: false, collapseSelection: true), // Alt + 左箭头：移动到行首
    SingleActivator(LogicalKeyboardKey.arrowRight, alt: true):
        MongolExtendSelectionToLineBreakIntent(
            forward: true, collapseSelection: true), // Alt + 右箭头：移动到行尾

    // Shift + Alt + 箭头：扩展选择到单词边界或行 break
    SingleActivator(LogicalKeyboardKey.arrowUp, shift: true, alt: true):
        MongolExtendSelectionToNextWordBoundaryOrCaretLocationIntent(
            forward: false), // Shift + Alt + 上箭头：向上扩展选择到上一个单词边界
    SingleActivator(LogicalKeyboardKey.arrowDown, shift: true, alt: true):
        MongolExtendSelectionToNextWordBoundaryOrCaretLocationIntent(
            forward: true), // Shift + Alt + 下箭头：向下扩展选择到下一个单词边界
    SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true, alt: true):
        MongolExtendSelectionToLineBreakIntent(
            forward: false,
            collapseSelection: false,
            collapseAtReversal: true), // Shift + Alt + 左箭头：扩展选择到行首
    SingleActivator(LogicalKeyboardKey.arrowRight, shift: true, alt: true):
        MongolExtendSelectionToLineBreakIntent(
            forward: true,
            collapseSelection: false,
            collapseAtReversal: true), // Shift + Alt + 右箭头：扩展选择到行尾

    // Meta + 箭头：移动到行 break 或文档边界
    SingleActivator(LogicalKeyboardKey.arrowUp, meta: true):
        MongolExtendSelectionToLineBreakIntent(
            forward: false, collapseSelection: true), // Meta + 上箭头：移动到文档开头
    SingleActivator(LogicalKeyboardKey.arrowDown, meta: true):
        MongolExtendSelectionToLineBreakIntent(
            forward: true, collapseSelection: true), // Meta + 下箭头：移动到文档结尾
    SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true):
        MongolExtendSelectionToDocumentBoundaryIntent(
            forward: false, collapseSelection: true), // Meta + 左箭头：移动到文档开头
    SingleActivator(LogicalKeyboardKey.arrowRight, meta: true):
        MongolExtendSelectionToDocumentBoundaryIntent(
            forward: true, collapseSelection: true), // Meta + 右箭头：移动到文档结尾

    // Shift + Meta + 箭头：扩展选择到行 break 或文档边界
    SingleActivator(LogicalKeyboardKey.arrowUp, shift: true, meta: true):
        MongolExpandSelectionToLineBreakIntent(
            forward: false), // Shift + Meta + 上箭头：扩展选择到文档开头
    SingleActivator(LogicalKeyboardKey.arrowDown, shift: true, meta: true):
        MongolExpandSelectionToLineBreakIntent(
            forward: true), // Shift + Meta + 下箭头：扩展选择到文档结尾
    SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true, meta: true):
        MongolExtendSelectionToDocumentBoundaryIntent(
            forward: false,
            collapseSelection: false), // Shift + Meta + 左箭头：扩展选择到文档开头
    SingleActivator(LogicalKeyboardKey.arrowRight, shift: true, meta: true):
        MongolExtendSelectionToDocumentBoundaryIntent(
            forward: true,
            collapseSelection: false), // Shift + Meta + 右箭头：扩展选择到文档结尾
  };

  // iOS 快捷键没有完整的文档。现在使用 macOS 快捷键。
  static const Map<ShortcutActivator, Intent> _appleShortcuts = _macShortcuts;

  static Map<ShortcutActivator, Intent> _shortcutsForPlatform(
    TargetPlatform platform,
  ) {
    switch (platform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return _commonShortcuts;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return _appleShortcuts;
    }
  }

  /// 根据当前平台获取对应的快捷键映射
  static Map<ShortcutActivator, Intent> get shortcuts =>
      _shortcutsForPlatform(defaultTargetPlatform);

  @override

  /// 构建小部件
  ///
  /// [context] 是构建上下文
  Widget build(BuildContext context) {
    return Shortcuts(
        debugLabel: '<Mongol Text Editing Shortcuts>',
        shortcuts: shortcuts,
        child: child ?? const SizedBox.shrink());
  }
}
