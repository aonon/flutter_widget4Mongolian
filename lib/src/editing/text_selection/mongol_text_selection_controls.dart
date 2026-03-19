// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Theme, TextSelectionTheme, Icons;
import 'package:flutter/widgets.dart';

import 'mongol_text_selection_toolbar.dart';
import 'mongol_text_selection_toolbar_button.dart';

// https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/text_selection.dart
// 此文件构建长按等操作时弹出的复制/粘贴工具栏。
// 如果您想要不同的样式，可以用另一个类替换此类。
// Flutter 就是这样为 Material、Cupertino 等提供不同样式的。

const double _kHandleSize = 22.0;

// 工具栏和锚点之间的填充。
const double _kToolbarContentDistanceRight = _kHandleSize - 2.0;
const double _kToolbarContentDistance = 8.0;

/// 蒙古文风格的文本选择控件。（改编自 Android Material 版本）
///
/// 为了避免蒙古文 Unicode 和字体问题，文本编辑
/// 控件使用图标而不是文本来表示复制/剪切/粘贴/选择按钮。
class MongolTextSelectionControls extends TextSelectionControls {
  /// 返回手柄的大小。
  @override
  Size getHandleSize(double textLineWidth) =>
      const Size(_kHandleSize, _kHandleSize);

  /// 蒙古文复制/粘贴文本选择工具栏的构建器。
  @override
  Widget buildToolbar(
    BuildContext context,
    Rect globalEditableRegion,
    double textLineWidth,
    Offset selectionMidpoint,
    List<TextSelectionPoint> endpoints,
    TextSelectionDelegate delegate,
    ValueListenable<ClipboardStatus>? clipboardStatus,
    Offset? lastSecondaryTapDownPosition,
  ) {
    return _TextSelectionControlsToolbar(
      globalEditableRegion: globalEditableRegion,
      textLineWidth: textLineWidth,
      selectionMidpoint: selectionMidpoint,
      endpoints: endpoints,
      delegate: delegate,
      clipboardStatus: clipboardStatus,
      handleCut: canCut(delegate) ? () => handleCut(delegate) : null,
      handleCopy: canCopy(delegate) ? () => handleCopy(delegate) : null,
      handlePaste: canPaste(delegate) ? () => handlePaste(delegate) : null,
      handleSelectAll:
          canSelectAll(delegate) ? () => handleSelectAll(delegate) : null,
    );
  }

  /// 材质风格文本选择手柄的构建器。
  ///
  /// 宽度和高度术语在垂直文本布局上下文中
  @override
  Widget buildHandle(
      BuildContext context, TextSelectionHandleType type, double textLineWidth,
      [VoidCallback? onTap, double? startGlyphWidth, double? endGlyphWidth]) {
    final theme = Theme.of(context);
    final handleColor = TextSelectionTheme.of(context).selectionHandleColor ??
        theme.colorScheme.primary;
    final Widget handle = SizedBox(
      width: _kHandleSize,
      height: _kHandleSize,
      child: CustomPaint(
        painter: _TextSelectionHandlePainter(
          color: handleColor,
        ),
      ),
    );

    // [handle] 是一个圆圈，在该圆圈的左上角象限中有一个矩形
    // （一个指向 10:30 的洋葱）。我们旋转 [handle] 以指向
    // 下右、左上或左，具体取决于手柄类型。
    switch (type) {
      case TextSelectionHandleType.left: // 指向下右
        return Transform.rotate(
          angle: math.pi,
          child: handle,
        );
      case TextSelectionHandleType.right: // 指向上左
        return handle;
      case TextSelectionHandleType.collapsed: // 指向左
        return Transform.rotate(
          angle: -math.pi / 4.0,
          child: handle,
        );
    }
  }

  /// 获取材质风格文本选择手柄的锚点。
  ///
  /// 宽度和高度术语在垂直文本布局上下文中。
  ///
  /// 请参阅 [TextSelectionControls.getHandleAnchor]。
  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineWidth,
      [double? startGlyphWidth, double? endGlyphWidth]) {
    switch (type) {
      case TextSelectionHandleType.left:
        return const Offset(_kHandleSize, _kHandleSize);
      case TextSelectionHandleType.right:
        return Offset.zero;
      default:
        return const Offset(-4, _kHandleSize / 2);
    }
  }

  @override
  bool canSelectAll(TextSelectionDelegate delegate) {
    // Android 允许在选择未折叠时全选，除非
    // 所有内容都已被选择。
    final value = delegate.textEditingValue;
    return delegate.selectAllEnabled &&
        value.text.isNotEmpty &&
        !(value.selection.start == 0 &&
            value.selection.end == value.text.length);
  }
}

// 可用的默认文本选择菜单按钮的标签和回调。
class _TextSelectionToolbarItemData {
  const _TextSelectionToolbarItemData({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;
}

// 最高级别的工具栏小部件，由 buildToolbar 直接构建。
class _TextSelectionControlsToolbar extends StatefulWidget {
  const _TextSelectionControlsToolbar({
    required this.clipboardStatus,
    required this.delegate,
    required this.endpoints,
    required this.globalEditableRegion,
    required this.handleCut,
    required this.handleCopy,
    required this.handlePaste,
    required this.handleSelectAll,
    required this.selectionMidpoint,
    required this.textLineWidth,
  });

  final ValueListenable<ClipboardStatus>? clipboardStatus;
  final TextSelectionDelegate delegate;
  final List<TextSelectionPoint> endpoints;
  final Rect globalEditableRegion;
  final VoidCallback? handleCut;
  final VoidCallback? handleCopy;
  final VoidCallback? handlePaste;
  final VoidCallback? handleSelectAll;
  final Offset selectionMidpoint;
  final double textLineWidth;

  @override
  _TextSelectionControlsToolbarState createState() =>
      _TextSelectionControlsToolbarState();
}

class _TextSelectionControlsToolbarState
    extends State<_TextSelectionControlsToolbar> with TickerProviderStateMixin {
  void _onChangedClipboardStatus() {
    setState(() {
      // 通知小部件 clipboardStatus 的值已更改。
    });
  }

  @override
  void initState() {
    super.initState();
    widget.clipboardStatus?.addListener(_onChangedClipboardStatus);
  }

  @override
  void didUpdateWidget(_TextSelectionControlsToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clipboardStatus != oldWidget.clipboardStatus) {
      widget.clipboardStatus?.addListener(_onChangedClipboardStatus);
      oldWidget.clipboardStatus?.removeListener(_onChangedClipboardStatus);
    }
  }

  @override
  void dispose() {
    widget.clipboardStatus?.removeListener(_onChangedClipboardStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 如果没有按钮要显示，不要渲染任何内容。
    if (widget.handleCut == null &&
        widget.handleCopy == null &&
        widget.handlePaste == null &&
        widget.handleSelectAll == null) {
      return const SizedBox.shrink();
    }
    // 如果需要粘贴按钮，在知道剪贴板状态之前不要渲染任何内容，
    // 因为它用于确定是否显示粘贴。
    if (widget.handlePaste != null &&
        widget.clipboardStatus?.value == ClipboardStatus.unknown) {
      return const SizedBox.shrink();
    }

    // 计算菜单的位置。如果有足够的空间，它会放在选择的左侧，
    // 否则放在右侧。
    final startTextSelectionPoint = widget.endpoints[0];
    final endTextSelectionPoint =
        widget.endpoints.length > 1 ? widget.endpoints[1] : widget.endpoints[0];
    final anchorLeft = Offset(
        widget.globalEditableRegion.left +
            startTextSelectionPoint.point.dx -
            widget.textLineWidth -
            _kToolbarContentDistance,
        widget.globalEditableRegion.top + widget.selectionMidpoint.dy);
    final anchorRight = Offset(
        widget.globalEditableRegion.left +
            endTextSelectionPoint.point.dx +
            _kToolbarContentDistanceRight,
        widget.globalEditableRegion.top + widget.selectionMidpoint.dy);

    // 确定哪些按钮会出现，以便知道顺序和总数。
    final itemData = <_TextSelectionToolbarItemData>[
      if (widget.handleCut != null)
        _TextSelectionToolbarItemData(
          icon: Icons.cut,
          onPressed: widget.handleCut!,
        ),
      if (widget.handleCopy != null)
        _TextSelectionToolbarItemData(
          icon: Icons.copy,
          onPressed: widget.handleCopy!,
        ),
      if (widget.handlePaste != null &&
          widget.clipboardStatus?.value == ClipboardStatus.pasteable)
        _TextSelectionToolbarItemData(
          icon: Icons.paste,
          onPressed: widget.handlePaste!,
        ),
      if (widget.handleSelectAll != null)
        _TextSelectionToolbarItemData(
          icon: Icons.select_all,
          onPressed: widget.handleSelectAll!,
        ),
    ];

    // 如果没有可用选项，构建一个空小部件。
    if (itemData.isEmpty) {
      return const SizedBox(width: 0.0, height: 0.0);
    }

    return MongolTextSelectionToolbar(
      anchorLeft: anchorLeft,
      anchorRight: anchorRight,
      children: itemData
          .asMap()
          .entries
          .map((MapEntry<int, _TextSelectionToolbarItemData> entry) {
        return MongolTextSelectionToolbarButton(
          padding: MongolTextSelectionToolbarButton.getPadding(
              entry.key, itemData.length),
          onPressed: entry.value.onPressed,
          child: Icon(entry.value.icon),
        );
      }).toList(),
    );
  }
}

/// 绘制一个指向上左的文本选择手柄。
class _TextSelectionHandlePainter extends CustomPainter {
  _TextSelectionHandlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final radius = size.width / 2.0;
    final circle =
        Rect.fromCircle(center: Offset(radius, radius), radius: radius);
    final point = Rect.fromLTWH(0.0, 0.0, radius, radius);
    final path = Path()
      ..addOval(circle)
      ..addRect(point);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TextSelectionHandlePainter oldPainter) {
    return color != oldPainter.color;
  }
}

/// 遵循 Material 设计规范的文本选择控件。
final TextSelectionControls mongolTextSelectionControls =
    MongolTextSelectionControls();
