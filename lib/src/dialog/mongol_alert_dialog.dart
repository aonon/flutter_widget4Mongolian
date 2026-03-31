// Copyright 2014 The Flutter Authors.
// Copyright 2020 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'mongol_button_bar.dart';

/// 改编自 Flutter 的 [Dialog]，用于垂直文本布局。
///
/// 显示一个可自定义样式的模态对话框，支持
/// 蒙古文垂直文本布局。
class MongolDialog extends StatelessWidget {
  /// 创建对话框组件。
  const MongolDialog({
    super.key,
    this.backgroundColor,
    this.elevation,
    this.insetAnimationDuration = const Duration(milliseconds: 100),
    this.insetAnimationCurve = Curves.decelerate,
    this.shape,
    this.child,
  });

  /// 背景颜色。默认为 [DialogTheme.backgroundColor] 或主题默认颜色。
  final Color? backgroundColor;

  /// 阴影高度。默认为 24.0。
  final double? elevation;

  /// 插入动画的持续时间。
  final Duration insetAnimationDuration;

  /// 插入动画的曲线。
  final Curve insetAnimationCurve;

  /// 对话框边框的形状。
  final ShapeBorder? shape;

  /// 内容组件。
  final Widget? child;

  static const RoundedRectangleBorder _defaultDialogShape =
      RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2.0)));
  static const double _defaultElevation = 24.0;

  @override
  Widget build(BuildContext context) {
    final dialogTheme = DialogTheme.of(context);
    return AnimatedPadding(
      padding: MediaQuery.of(context).viewInsets +
          const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
      duration: insetAnimationDuration,
      curve: insetAnimationCurve,
      child: MediaQuery.removeViewInsets(
        removeLeft: true,
        removeTop: true,
        removeRight: true,
        removeBottom: true,
        context: context,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 280.0),
            child: Material(
              color: backgroundColor ??
                  dialogTheme.backgroundColor ??
                  Theme.of(context).dialogTheme.backgroundColor,
              elevation:
                  elevation ?? dialogTheme.elevation ?? _defaultElevation,
              shape: shape ?? dialogTheme.shape ?? _defaultDialogShape,
              type: MaterialType.card,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 改编自 Flutter 的 [AlertDialog]，用于垂直文本布局。
///
/// 显示包含标题、内容和操作按钮的警告对话框，
/// 支持蒙古文垂直文本布局。
class MongolAlertDialog extends StatelessWidget {
  /// 创建警告对话框。
  const MongolAlertDialog({
    super.key,
    this.title,
    this.titlePadding,
    this.titleTextStyle,
    this.content,
    this.contentPadding = const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
    this.contentTextStyle,
    this.actions,
    this.actionsPadding = EdgeInsets.zero,
    this.actionsOverflowDirection,
    this.buttonPadding,
    this.backgroundColor,
    this.elevation,
    this.shape,
  });

  /// 标题组件，通常为 [MongolText]。
  final Widget? title;

  /// 标题的内边距。默认为根据上下文调整的间距。
  final EdgeInsetsGeometry? titlePadding;

  /// 标题的文本样式。默认为 [DialogTheme.titleTextStyle]。
  final TextStyle? titleTextStyle;

  /// 内容组件。
  final Widget? content;

  /// 内容的内边距。默认为对称和底部间距。
  final EdgeInsetsGeometry contentPadding;

  /// 内容的文本样式。默认为 [DialogTheme.contentTextStyle]。
  final TextStyle? contentTextStyle;

  /// 操作按钮，通常为 [TextButton] 或 [ElevatedButton]。
  final List<Widget>? actions;

  /// 操作部分的内边距。
  final EdgeInsetsGeometry actionsPadding;

  /// 空间不足时操作按钮的溢出方向。
  final VerticalDirection? actionsOverflowDirection;

  /// 单个按钮的内边距。
  final EdgeInsetsGeometry? buttonPadding;

  /// 背景颜色。默认为 [DialogTheme.backgroundColor]。
  final Color? backgroundColor;

  /// 阴影高度。默认为 [DialogTheme.elevation]。
  final double? elevation;

  /// 对话框边框形状。默认为 [DialogTheme.shape]。
  final ShapeBorder? shape;

  @override
  Widget build(BuildContext context) {
    final rowChildren = <Widget>[
      if (title != null || content != null)
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (title != null) _buildTitleWidget(context),
              if (content != null) _buildContentWidget(context),
            ],
          ),
        ),
      if (actions != null) _buildActionsWidget(),
    ];

    return MongolDialog(
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rowChildren,
        ),
      ),
    );
  }

  Widget _buildTitleWidget(BuildContext context) {
    final theme = Theme.of(context);
    final dialogTheme = DialogTheme.of(context);

    return Padding(
      padding: titlePadding ??
          EdgeInsets.fromLTRB(24.0, 24.0, 24.0, content == null ? 20.0 : 0.0),
      child: DefaultTextStyle(
        style: titleTextStyle ??
            dialogTheme.titleTextStyle ??
            theme.textTheme.titleLarge!,
        child: Semantics(
          namesRoute: true,
          container: true,
          child: title!,
        ),
      ),
    );
  }

  Widget _buildContentWidget(BuildContext context) {
    final theme = Theme.of(context);
    final dialogTheme = DialogTheme.of(context);

    return Padding(
      padding: contentPadding,
      child: DefaultTextStyle(
        style: contentTextStyle ??
            dialogTheme.contentTextStyle ??
            theme.textTheme.titleMedium!,
        child: content!,
      ),
    );
  }

  Widget _buildActionsWidget() {
    return Padding(
      padding: actionsPadding,
      child: MongolButtonBar(
        buttonPadding: buttonPadding,
        children: actions!,
      ),
    );
  }
}
