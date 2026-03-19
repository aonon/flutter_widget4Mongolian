// Copyright 2014 The Flutter Authors.
// Copyright 2020 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'mongol_button_bar.dart';

/// 此类改编自Flutter的[Dialog]类
///
/// 用于显示垂直方向的对话框，支持蒙古文垂直文本布局。
class MongolDialog extends StatelessWidget {
  /// 创建一个MongolDialog
  ///
  /// [backgroundColor]：对话框的背景颜色
  /// [elevation]：对话框的海拔高度
  /// [insetAnimationDuration]：插入动画的持续时间
  /// [insetAnimationCurve]：插入动画的曲线
  /// [shape]：对话框的形状
  /// [child]：对话框的子部件
  const MongolDialog({
    super.key,
    this.backgroundColor,
    this.elevation,
    this.insetAnimationDuration = const Duration(milliseconds: 100),
    this.insetAnimationCurve = Curves.decelerate,
    this.shape,
    this.child,
  });

  final Color? backgroundColor; // 对话框的背景颜色
  final double? elevation; // 对话框的海拔高度
  final Duration insetAnimationDuration; // 插入动画的持续时间
  final Curve insetAnimationCurve; // 插入动画的曲线
  final ShapeBorder? shape; // 对话框的形状
  final Widget? child; // 对话框的子部件

  static const RoundedRectangleBorder _defaultDialogShape =
      RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2.0))); // 默认对话框形状
  static const double _defaultElevation = 24.0; // 默认海拔高度

  /// 构建对话框UI
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

/// 此类改编自Flutter的[AlertDialog]类
///
/// 用于显示垂直方向的警告对话框，支持蒙古文垂直文本布局。
class MongolAlertDialog extends StatelessWidget {
  /// 创建一个MongolAlertDialog
  ///
  /// [title]：对话框的标题
  /// [titlePadding]：标题的内边距
  /// [titleTextStyle]：标题的文本样式
  /// [content]：对话框的内容
  /// [contentPadding]：内容的内边距
  /// [contentTextStyle]：内容的文本样式
  /// [actions]：对话框的操作按钮
  /// [actionsPadding]：操作按钮的内边距
  /// [actionsOverflowDirection]：操作按钮溢出方向
  /// [buttonPadding]：按钮的内边距
  /// [backgroundColor]：对话框的背景颜色
  /// [elevation]：对话框的海拔高度
  /// [shape]：对话框的形状
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

  final Widget? title; // 对话框的标题
  final EdgeInsetsGeometry? titlePadding; // 标题的内边距
  final TextStyle? titleTextStyle; // 标题的文本样式
  final Widget? content; // 对话框的内容
  final EdgeInsetsGeometry contentPadding; // 内容的内边距
  final TextStyle? contentTextStyle; // 内容的文本样式
  final List<Widget>? actions; // 对话框的操作按钮
  final EdgeInsetsGeometry actionsPadding; // 操作按钮的内边距
  final VerticalDirection? actionsOverflowDirection; // 操作按钮溢出方向
  final EdgeInsetsGeometry? buttonPadding; // 按钮的内边距
  final Color? backgroundColor; // 对话框的背景颜色
  final double? elevation; // 对话框的海拔高度
  final ShapeBorder? shape; // 对话框的形状

  /// 构建警告对话框UI
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dialogTheme = DialogTheme.of(context);

    Widget? titleWidget;
    Widget? contentWidget;
    Widget? actionsWidget;
    if (title != null) {
      titleWidget = Padding(
        padding: titlePadding ??
            EdgeInsets.fromLTRB(24.0, 24.0, 24.0, content == null ? 20.0 : 0.0),
        child: DefaultTextStyle(
          style: titleTextStyle ??
              dialogTheme.titleTextStyle ??
              theme.textTheme.titleLarge!,
          child: Semantics(
            namesRoute: true,
            container: true,
            child: title,
          ),
        ),
      );
    }

    if (content != null) {
      contentWidget = Padding(
        padding: contentPadding,
        child: DefaultTextStyle(
          style: contentTextStyle ??
              dialogTheme.contentTextStyle ??
              theme.textTheme.titleMedium!,
          child: content!,
        ),
      );
    }

    if (actions != null) {
      actionsWidget = Padding(
        padding: actionsPadding,
        child: MongolButtonBar(
          buttonPadding: buttonPadding,
          children: actions!,
        ),
      );
    }

    List<Widget> rowChildren;
    rowChildren = <Widget>[
      if (title != null || content != null)
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (title != null) titleWidget!,
              if (content != null) contentWidget!,
            ],
          ),
        ),
      if (actions != null) actionsWidget!,
    ];

    Widget dialogChild = IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rowChildren,
      ),
    );

    return MongolDialog(
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape,
      child: dialogChild,
    );
  }
}
