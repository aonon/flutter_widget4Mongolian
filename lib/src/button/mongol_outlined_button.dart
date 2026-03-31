// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart'
    show
        ButtonStyle,
        ButtonStyleButton,
        ColorScheme,
        Colors,
        InkRipple,
        InteractiveInkFeatureFactory,
        WidgetState,
        WidgetStateProperty,
        MaterialTapTargetSize,
        OutlinedButtonTheme,
        Theme,
        ThemeData,
        VisualDensity,
        WidgetStatesController,
        WidgetStatePropertyAll,
        kThemeChangeDuration;

import 'button_style_utils.dart';
import 'mongol_button_style_button.dart';

/// 垂直方向的 Material Design “轮廓按钮”（Outlined Button）。
///
/// 轮廓按钮是中等强调程度的按钮，适用于重要但非主要的操作。
/// 它本质上是带有边框轮廓的 [MongolTextButton]。
///
/// 轮廓按钮是在海拔高度为 0 的 [Material] 组件上显示的标签 [child]。
/// 标签的 [MongolText] 和 [Icon] 以 [style] 的 [ButtonStyle.foregroundColor] 显示，
/// 轮廓的粗细和颜色由 [ButtonStyle.side] 定义。
///
/// 默认样式由 [defaultStyleOf] 定义。可以通过 [style] 参数覆盖。
///
/// 另请参阅：
///  * [MongolElevatedButton]：按下时会增加海拔高度的填充按钮。
///  * [MongolFilledButton]：带有填充背景且海拔高度不变的按钮。
///  * [MongolTextButton]：无边框和填充色的扁平按钮。
///  * <https://material.io/design/components/buttons.html>
///  * <https://m3.material.io/components/buttons>
class MongolOutlinedButton extends MongolButtonStyleButton {
  /// 创建一个 [MongolOutlinedButton]。
  const MongolOutlinedButton({
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
    required super.child,
  });

  /// 创建一个带有图标和标签的轮廓按钮。
  factory MongolOutlinedButton.icon({
    Key? key,
    required VoidCallback? onPressed,
    VoidCallback? onLongPress,
    ButtonStyle? style,
    FocusNode? focusNode,
    bool? autofocus,
    Clip? clipBehavior,
    WidgetStatesController? statesController,
    required Widget icon,
    required Widget label,
  }) = _MongolOutlinedButtonWithIcon;

  /// 根据简单值构造轮廓按钮 [ButtonStyle] 的静态便捷方法。
  static ButtonStyle styleFrom({
    Color? foregroundColor,
    Color? backgroundColor,
    Color? disabledForegroundColor,
    Color? disabledBackgroundColor,
    Color? shadowColor,
    Color? surfaceTintColor,
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
            : _OutlinedButtonDefaultColor(foreground, disabledForeground);
    final WidgetStateProperty<Color?>? backgroundColorProperty =
        (backgroundColor == null && disabledBackgroundColor == null)
            ? null
            : disabledBackgroundColor == null
                ? widgetStateAllOrNull<Color?>(backgroundColor)
                : _OutlinedButtonDefaultColor(
                    backgroundColor, disabledBackgroundColor);
    final WidgetStateProperty<Color?>? overlayColor =
        (foreground == null) ? null : _OutlinedButtonDefaultOverlay(foreground);
    final WidgetStateProperty<MouseCursor?> mouseCursor =
        _OutlinedButtonDefaultMouseCursor(
            enabledMouseCursor, disabledMouseCursor);

    return ButtonStyle(
      textStyle: widgetStateAllOrNull<TextStyle>(textStyle),
      foregroundColor: foregroundColorProperty,
      backgroundColor: backgroundColorProperty,
      overlayColor: overlayColor,
      shadowColor: widgetStateAllOrNull<Color>(shadowColor),
      surfaceTintColor: widgetStateAllOrNull<Color>(surfaceTintColor),
      elevation: widgetStateAllOrNull<double>(elevation),
      padding: widgetStateAllOrNull<EdgeInsetsGeometry>(padding),
      minimumSize: widgetStateAllOrNull<Size>(minimumSize),
      maximumSize: widgetStateAllOrNull<Size>(maximumSize),
      fixedSize: widgetStateAllOrNull<Size>(fixedSize),
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
        ? _MongolOutlinedButtonDefaultsM3(context)
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
            side: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.12),
            ),
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

  /// 获取轮廓按钮主题中的样式。
  @override
  ButtonStyle? themeStyleOf(BuildContext context) {
    return OutlinedButtonTheme.of(context).style;
  }
}

/// 计算经过缩放调整后的内边距。
EdgeInsetsGeometry _scaledPadding(BuildContext context) {
  final ThemeData theme = Theme.of(context);
  final double paddingBase = theme.useMaterial3 ? 24.0 : 16.0;
  final double defaultFontSize = theme.textTheme.labelLarge?.fontSize ?? 14.0;
  final double effectiveTextScale =
      MediaQuery.textScalerOf(context).scale(defaultFontSize) / 14.0;
  return ButtonStyleButton.scaledPadding(
    EdgeInsets.symmetric(vertical: paddingBase),
    EdgeInsets.symmetric(vertical: paddingBase / 2),
    EdgeInsets.symmetric(vertical: paddingBase / 4),
    effectiveTextScale,
  );
}

@immutable
class _OutlinedButtonDefaultColor extends WidgetStateProperty<Color?>
    with Diagnosticable {
  _OutlinedButtonDefaultColor(this.activeColor, this.disabledColor);

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
class _OutlinedButtonDefaultOverlay extends WidgetStateProperty<Color?>
    with Diagnosticable {
  _OutlinedButtonDefaultOverlay(this.baseColor);

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
class _OutlinedButtonDefaultMouseCursor
    extends WidgetStateProperty<MouseCursor?> with Diagnosticable {
  _OutlinedButtonDefaultMouseCursor(this.enabledCursor, this.disabledCursor);

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

class _MongolOutlinedButtonWithIcon extends MongolOutlinedButton {
  _MongolOutlinedButtonWithIcon({
    super.key,
    required super.onPressed,
    super.onLongPress,
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
          child: _MongolOutlinedButtonWithIconChild(icon: icon, label: label),
        );

  @override
  ButtonStyle defaultStyleOf(BuildContext context) {
    final bool useMaterial3 = Theme.of(context).useMaterial3;
    if (!useMaterial3) {
      return super.defaultStyleOf(context);
    }
    final ButtonStyle buttonStyle = super.defaultStyleOf(context);
    final double defaultFontSize =
        buttonStyle.textStyle?.resolve(const <WidgetState>{})?.fontSize ?? 14.0;
    final double effectiveTextScale =
        MediaQuery.textScalerOf(context).scale(defaultFontSize) / 14.0;
    final EdgeInsetsGeometry scaledPadding = ButtonStyleButton.scaledPadding(
      const EdgeInsetsDirectional.fromSTEB(0, 16, 0, 24),
      const EdgeInsetsDirectional.fromSTEB(0, 8, 0, 12),
      const EdgeInsetsDirectional.fromSTEB(0, 4, 0, 6),
      effectiveTextScale,
    );
    return buttonStyle.copyWith(
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(scaledPadding),
    );
  }
}

class _MongolOutlinedButtonWithIconChild extends StatelessWidget {
  const _MongolOutlinedButtonWithIconChild({
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

/// Material 3 轮廓按钮的默认样式实现。
class _MongolOutlinedButtonDefaultsM3 extends ButtonStyle {
  _MongolOutlinedButtonDefaultsM3(this.context)
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
  WidgetStateProperty<BorderSide>? get side =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(color: _colors.onSurface.withValues(alpha: 0.12));
        }
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: _colors.primary);
        }
        return BorderSide(color: _colors.outline);
      });

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
