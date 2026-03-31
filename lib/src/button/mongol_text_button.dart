// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show
        ButtonStyle,
        ButtonStyleButton,
        ColorScheme,
        Colors,
        InkRipple,
        InteractiveInkFeatureFactory,
        WidgetStateProperty,
        MaterialTapTargetSize,
        WidgetState,
        TextButtonTheme,
        Theme,
        ThemeData,
        VisualDensity,
        WidgetStatesController,
        WidgetStatePropertyAll,
        kThemeChangeDuration;
import 'package:flutter/widgets.dart';

import 'button_style_utils.dart';
import 'mongol_button_style_button.dart';

/// 垂直方向的 Material Design “文本按钮”（Text Button）。
///
/// 文本按钮没有可见边框，主要通过其相对于其他内容的位置来提供上下文。
/// 适用于工具栏、对话框或与其他内容内联使用。
///
/// 标签文本以 [ButtonStyle.foregroundColor] 显示，触摸时会填充 [ButtonStyle.backgroundColor]。
///
/// 默认样式由 [defaultStyleOf] 定义。可以通过 [style] 参数覆盖。
///
/// 另请参阅：
///  * [MongolElevatedButton]：按下时会增加海拔高度的填充按钮。
///  * [MongolFilledButton]：带有填充背景且海拔高度不变的按钮。
///  * [MongolOutlinedButton]：带有边框轮廓且无填充色的按钮。
///  * <https://material.io/design/components/buttons.html>
///  * <https://m3.material.io/components/buttons>
class MongolTextButton extends MongolButtonStyleButton {
  /// 创建一个 [MongolTextButton]。
  const MongolTextButton({
    super.key,
    required super.onPressed,
    super.onLongPress,
    super.onHover,
    super.onFocusChange,
    super.style,
    super.focusNode,
    super.autofocus = false,
    super.clipBehavior = Clip.none,
    super.statesController,
    super.isSemanticButton,
    required super.child,
  });

  /// 创建一个带有图标和标签的文本按钮。
  factory MongolTextButton.icon({
    Key? key,
    required VoidCallback? onPressed,
    VoidCallback? onLongPress,
    ValueChanged<bool>? onHover,
    ValueChanged<bool>? onFocusChange,
    ButtonStyle? style,
    FocusNode? focusNode,
    bool? autofocus,
    Clip? clipBehavior,
    WidgetStatesController? statesController,
    required Widget icon,
    required Widget label,
  }) = _MongolTextButtonWithIcon;

  /// 根据简单值构造文本按钮 [ButtonStyle] 的静态便捷方法。
  static ButtonStyle styleFrom({
    Color? foregroundColor,
    Color? backgroundColor,
    Color? disabledForegroundColor,
    Color? disabledBackgroundColor,
    Color? shadowColor,
    Color? surfaceTintColor,
    Color? iconColor,
    Color? disabledIconColor,
    double? elevation,
    TextStyle? textStyle,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    Size? fixedSize,
    Size? maximumSize,
    BorderSide? side,
    OutlinedBorder? shape,
    MouseCursor? enabledMouseCursor,
    MouseCursor? disabledMouseCursor,
    VisualDensity? visualDensity,
    MaterialTapTargetSize? tapTargetSize,
    Duration? animationDuration,
    bool? enableFeedback,
    AlignmentGeometry? alignment,
    InteractiveInkFeatureFactory? splashFactory,
  }) {
    final Color? foreground = foregroundColor;
    final Color? disabledForeground = disabledForegroundColor;
    final WidgetStateProperty<Color?>? foregroundColorProperty =
        (foreground == null && disabledForeground == null)
            ? null
            : _TextButtonDefaultColor(foreground, disabledForeground);
    final WidgetStateProperty<Color?>? backgroundColorProperty =
        (backgroundColor == null && disabledBackgroundColor == null)
            ? null
            : disabledBackgroundColor == null
                ? widgetStateAllOrNull<Color?>(backgroundColor)
                : _TextButtonDefaultColor(
                    backgroundColor, disabledBackgroundColor);
    final WidgetStateProperty<Color?>? overlayColor =
        (foreground == null) ? null : _TextButtonDefaultOverlay(foreground);
    final WidgetStateProperty<Color?>? iconColorProperty =
        (iconColor == null && disabledIconColor == null)
            ? null
            : disabledIconColor == null
                ? widgetStateAllOrNull<Color?>(iconColor)
                : _TextButtonDefaultIconColor(iconColor, disabledIconColor);
    final WidgetStateProperty<MouseCursor?> mouseCursor =
        _TextButtonDefaultMouseCursor(enabledMouseCursor, disabledMouseCursor);

    return ButtonStyle(
      textStyle: widgetStateAllOrNull<TextStyle>(textStyle),
      foregroundColor: foregroundColorProperty,
      backgroundColor: backgroundColorProperty,
      overlayColor: overlayColor,
      shadowColor: widgetStateAllOrNull<Color>(shadowColor),
      surfaceTintColor: widgetStateAllOrNull<Color>(surfaceTintColor),
      iconColor: iconColorProperty,
      elevation: widgetStateAllOrNull<double>(elevation),
      padding: widgetStateAllOrNull<EdgeInsetsGeometry>(padding),
      minimumSize: widgetStateAllOrNull<Size>(minimumSize),
      fixedSize: widgetStateAllOrNull<Size>(fixedSize),
      maximumSize: widgetStateAllOrNull<Size>(maximumSize),
      side: widgetStateAllOrNull<BorderSide>(side),
      shape: widgetStateAllOrNull<OutlinedBorder>(shape),
      mouseCursor: mouseCursor,
      visualDensity: visualDensity,
      tapTargetSize: tapTargetSize,
      animationDuration: animationDuration,
      enableFeedback: enableFeedback,
      alignment: alignment,
      splashFactory: splashFactory,
    );
  }

  /// 定义按钮的默认外观样式。
  @override
  ButtonStyle defaultStyleOf(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Theme.of(context).useMaterial3
        ? _MongolTextButtonDefaultsM3(context)
        : styleFrom(
            foregroundColor: colorScheme.primary,
            disabledForegroundColor:
                colorScheme.onSurface.withValues(alpha: 0.38),
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: theme.shadowColor,
            elevation: 0,
            textStyle: theme.textTheme.labelLarge,
            padding: _scaledPadding(context),
            minimumSize: const Size(36, 64),
            maximumSize: Size.infinite,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(4))),
            enabledMouseCursor: SystemMouseCursors.click,
            disabledMouseCursor: SystemMouseCursors.basic,
            visualDensity: theme.visualDensity,
            tapTargetSize: theme.materialTapTargetSize,
            animationDuration: kThemeChangeDuration,
            enableFeedback: true,
            alignment: Alignment.center,
            splashFactory: InkRipple.splashFactory,
          );
  }

  /// 获取文本按钮主题中的样式。
  @override
  ButtonStyle? themeStyleOf(BuildContext context) {
    return TextButtonTheme.of(context).style;
  }
}

/// 计算经过缩放调整后的内边距。
EdgeInsetsGeometry _scaledPadding(BuildContext context) {
  final ThemeData theme = Theme.of(context);
  final double defaultFontSize = theme.textTheme.labelLarge?.fontSize ?? 14.0;
  final double effectiveTextScale =
      MediaQuery.textScalerOf(context).scale(defaultFontSize) / 14.0;
  return ButtonStyleButton.scaledPadding(
    theme.useMaterial3
        ? const EdgeInsets.symmetric(vertical: 12, horizontal: 8)
        : const EdgeInsets.all(8),
    const EdgeInsets.symmetric(vertical: 8),
    const EdgeInsets.symmetric(vertical: 4),
    effectiveTextScale,
  );
}

@immutable
class _TextButtonDefaultColor extends WidgetStateProperty<Color?> {
  _TextButtonDefaultColor(this.activeColor, this.disabledColor);

  final Color? activeColor;
  final Color? disabledColor;

  @override
  Color? resolve(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return disabledColor;
    }
    return activeColor;
  }
}

@immutable
class _TextButtonDefaultOverlay extends WidgetStateProperty<Color?> {
  _TextButtonDefaultOverlay(this.baseColor);

  final Color baseColor;

  @override
  Color? resolve(Set<WidgetState> states) {
    if (states.contains(WidgetState.pressed)) {
      return baseColor.withValues(alpha: 0.12);
    }
    if (states.contains(WidgetState.hovered)) {
      return baseColor.withValues(alpha: 0.04);
    }
    if (states.contains(WidgetState.focused)) {
      return baseColor.withValues(alpha: 0.12);
    }
    return null;
  }
}

@immutable
class _TextButtonDefaultIconColor extends WidgetStateProperty<Color?> {
  _TextButtonDefaultIconColor(this.activeColor, this.disabledColor);

  final Color? activeColor;
  final Color? disabledColor;

  @override
  Color? resolve(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return disabledColor;
    }
    return activeColor;
  }
}

@immutable
class _TextButtonDefaultMouseCursor extends WidgetStateProperty<MouseCursor?>
    with Diagnosticable {
  _TextButtonDefaultMouseCursor(this.enabledCursor, this.disabledCursor);

  final MouseCursor? enabledCursor;
  final MouseCursor? disabledCursor;

  @override
  MouseCursor? resolve(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return disabledCursor;
    }
    return enabledCursor;
  }
}

class _MongolTextButtonWithIcon extends MongolTextButton {
  _MongolTextButtonWithIcon({
    super.key,
    required super.onPressed,
    super.onLongPress,
    super.onHover,
    super.onFocusChange,
    super.style,
    super.focusNode,
    bool? autofocus,
    Clip? clipBehavior,
    super.statesController,
    required Widget icon,
    required Widget label,
  }) : super(
          autofocus: autofocus ?? false,
          clipBehavior: clipBehavior ?? Clip.none,
          child: _MongolTextButtonWithIconChild(icon: icon, label: label),
        );

  @override
  ButtonStyle defaultStyleOf(BuildContext context) {
    final bool useMaterial3 = Theme.of(context).useMaterial3;
    final ButtonStyle buttonStyle = super.defaultStyleOf(context);
    final double defaultFontSize =
        buttonStyle.textStyle?.resolve(const <WidgetState>{})?.fontSize ?? 14.0;
    final double effectiveTextScale =
        MediaQuery.textScalerOf(context).scale(defaultFontSize) / 14.0;
    final EdgeInsetsGeometry scaledPadding = ButtonStyleButton.scaledPadding(
      useMaterial3
          ? const EdgeInsets.fromLTRB(8, 12, 8, 16)
          : const EdgeInsets.all(8),
      const EdgeInsets.symmetric(vertical: 4),
      const EdgeInsets.symmetric(vertical: 4),
      effectiveTextScale,
    );
    return buttonStyle.copyWith(
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(scaledPadding),
    );
  }
}

class _MongolTextButtonWithIconChild extends StatelessWidget {
  const _MongolTextButtonWithIconChild({
    required this.label,
    required this.icon,
  });

  final Widget label;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final TextScaler textScaler = MediaQuery.textScalerOf(context);
    final double scale = textScaler.scale(1.0);
    final double gap =
        scale <= 1 ? 8 : lerpDouble(8, 4, math.min(scale - 1, 1))!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[icon, SizedBox(height: gap), Flexible(child: label)],
    );
  }
}

/// Material 3 文本按钮的默认样式实现。
class _MongolTextButtonDefaultsM3 extends ButtonStyle {
  _MongolTextButtonDefaultsM3(this.context)
      : super(
          animationDuration: kThemeChangeDuration,
          enableFeedback: true,
          alignment: Alignment.center,
        );

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;

  @override
  WidgetStateProperty<TextStyle?> get textStyle =>
      WidgetStatePropertyAll<TextStyle?>(
          Theme.of(context).textTheme.labelLarge);

  @override
  WidgetStateProperty<Color?>? get backgroundColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent);

  @override
  WidgetStateProperty<Color?>? get foregroundColor =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return _colors.onSurface.withValues(alpha: 0.38);
        }
        return _colors.primary;
      });

  @override
  WidgetStateProperty<Color?>? get overlayColor =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.pressed)) {
          return _colors.primary.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return _colors.primary.withValues(alpha: 0.08);
        }
        if (states.contains(WidgetState.focused)) {
          return _colors.primary.withValues(alpha: 0.12);
        }
        return null;
      });

  @override
  WidgetStateProperty<Color>? get shadowColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent);

  @override
  WidgetStateProperty<Color>? get surfaceTintColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent);

  @override
  WidgetStateProperty<double>? get elevation =>
      const WidgetStatePropertyAll<double>(0.0);

  @override
  WidgetStateProperty<EdgeInsetsGeometry>? get padding =>
      WidgetStatePropertyAll<EdgeInsetsGeometry>(_scaledPadding(context));

  @override
  WidgetStateProperty<Size>? get minimumSize =>
      const WidgetStatePropertyAll<Size>(Size(40.0, 64.0));

  @override
  WidgetStateProperty<Size>? get maximumSize =>
      const WidgetStatePropertyAll<Size>(Size.infinite);

  @override
  WidgetStateProperty<OutlinedBorder>? get shape =>
      const WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder());

  @override
  WidgetStateProperty<MouseCursor?>? get mouseCursor =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return SystemMouseCursors.basic;
        }
        return SystemMouseCursors.click;
      });

  @override
  VisualDensity? get visualDensity => Theme.of(context).visualDensity;

  @override
  MaterialTapTargetSize? get tapTargetSize =>
      Theme.of(context).materialTapTargetSize;

  @override
  InteractiveInkFeatureFactory? get splashFactory =>
      Theme.of(context).splashFactory;
}
