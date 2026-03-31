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
        ElevatedButtonTheme,
        InkRipple,
        InteractiveInkFeatureFactory,
        WidgetState,
        WidgetStateProperty,
        MaterialTapTargetSize,
        Theme,
        ThemeData,
        VisualDensity,
        WidgetStatesController,
        WidgetStatePropertyAll,
        kThemeChangeDuration;

import 'button_style_utils.dart';
import 'mongol_button_style_button.dart';

/// 垂直方向的 Material Design “凸起按钮”（Elevated Button）。
///
/// 使用凸起按钮为原本大部分是平面的布局添加维度，例如在长而繁忙的内容列表中，
/// 或在宽阔的空间中。应避免在已经具有海拔高度的内容（如对话框或卡片）上使用凸起按钮。
///
/// 凸起按钮是在 [Material] 组件上显示的标签 [child]，当按钮被按下时，
/// 其 [Material.elevation] 会增加。标签的 [MongolText] 和 [Icon] 组件以
/// [style] 的 [ButtonStyle.foregroundColor] 显示，背景填充色为 [ButtonStyle.backgroundColor]。
///
/// 默认样式由 [defaultStyleOf] 定义。可以通过 [style] 参数覆盖。
/// 子树中所有凸起按钮的样式可以通过 [ElevatedButtonTheme] 覆盖。
/// 应用全局样式可以通过 [ThemeData.elevatedButtonTheme] 覆盖。
///
/// 静态方法 [styleFrom] 是创建凸起按钮 [ButtonStyle] 的便捷方式。
///
/// 如果 [onPressed] 和 [onLongPress] 回调均为 null，则按钮将被禁用。
///
/// 另请参阅：
///  * [MongolFilledButton]：垂直填充按钮，按下时不增加海拔高度。
///  * [MongolFilledButton.tonal]：使用次要填充颜色的填充按钮。
///  * [MongolTextButton]：不带阴影的简单扁平按钮。
///  * [MongolOutlinedButton]：带有边框轮廓的 [MongolTextButton]。
///  * <https://material.io/design/components/buttons.html>
///  * <https://m3.material.io/components/buttons>
class MongolElevatedButton extends MongolButtonStyleButton {
  /// 创建一个 [MongolElevatedButton]。
  const MongolElevatedButton({
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

  /// 创建一个带有图标和标签的凸起按钮。
  ///
  /// 图标和标签垂直排列，顶部填充 12 像素，底部填充 16 像素，中间间距 8 像素。
  factory MongolElevatedButton.icon({
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
  }) = _MongolElevatedButtonWithIcon;

  /// 根据简单值构造凸起按钮 [ButtonStyle] 的静态便捷方法。
  ///
  /// [foregroundColor] 和 [disabledForegroundColor] 用于创建前景色及其交互效果。
  /// [backgroundColor] 和 [disabledBackgroundColor] 用于创建背景色。
  /// [elevation] 定义相对于基准的海拔高度：禁用时为 0，悬停/聚焦时 +2，按下时 +6。
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
    final Color? background = backgroundColor;
    final Color? disabledBackground = disabledBackgroundColor;
    final WidgetStateProperty<Color?>? backgroundColorProperty =
        (background == null && disabledBackground == null)
            ? null
            : _ElevatedButtonDefaultColor(background, disabledBackground);
    final Color? foreground = foregroundColor;
    final Color? disabledForeground = disabledForegroundColor;
    final WidgetStateProperty<Color?>? foregroundColorProperty =
        (foreground == null && disabledForeground == null)
            ? null
            : _ElevatedButtonDefaultColor(foreground, disabledForeground);
    final WidgetStateProperty<Color?>? overlayColor =
        (foreground == null) ? null : _ElevatedButtonDefaultOverlay(foreground);
    final WidgetStateProperty<double>? elevationProperty =
        (elevation == null) ? null : _ElevatedButtonDefaultElevation(elevation);
    final WidgetStateProperty<MouseCursor?> mouseCursor =
        _ElevatedButtonDefaultMouseCursor(
            enabledMouseCursor, disabledMouseCursor);

    return ButtonStyle(
      textStyle: WidgetStateProperty.all<TextStyle?>(textStyle),
      backgroundColor: backgroundColorProperty,
      foregroundColor: foregroundColorProperty,
      overlayColor: overlayColor,
      shadowColor: widgetStateAllOrNull<Color>(shadowColor),
      surfaceTintColor: widgetStateAllOrNull<Color>(surfaceTintColor),
      elevation: elevationProperty,
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
        ? _ElevatedButtonDefaultsM3(context)
        : styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            disabledBackgroundColor:
                colorScheme.onSurface.withValues(alpha: 0.12),
            disabledForegroundColor:
                colorScheme.onSurface.withValues(alpha: 0.38),
            shadowColor: theme.shadowColor,
            elevation: 2,
            textStyle: theme.textTheme.labelLarge,
            padding: _scaledPadding(context),
            minimumSize: const Size(36, 64),
            maximumSize: Size.infinite,
            side: null,
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

  /// 获取主题样式。
  @override
  ButtonStyle? themeStyleOf(BuildContext context) {
    return ElevatedButtonTheme.of(context).style;
  }
}

/// 根据文本缩放计算内边距。
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
class _ElevatedButtonDefaultColor extends WidgetStateProperty<Color?>
    with Diagnosticable {
  _ElevatedButtonDefaultColor(this.activeColor, this.disabledColor);

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
class _ElevatedButtonDefaultOverlay extends WidgetStateProperty<Color?>
    with Diagnosticable {
  _ElevatedButtonDefaultOverlay(this.baseColor);

  final Color baseColor;

  @override
  Color? resolve(Set<WidgetState> states) {
    if (states.contains(WidgetState.pressed)) {
      return baseColor.withValues(alpha: 0.24);
    }
    if (states.contains(WidgetState.hovered)) {
      return baseColor.withValues(alpha: 0.08);
    }
    if (states.contains(WidgetState.focused)) {
      return baseColor.withValues(alpha: 0.24);
    }
    return null;
  }
}

@immutable
class _ElevatedButtonDefaultElevation extends WidgetStateProperty<double>
    with Diagnosticable {
  _ElevatedButtonDefaultElevation(this.baseElevation);

  final double baseElevation;

  @override
  double resolve(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return 0;
    }
    if (states.contains(WidgetState.pressed)) {
      return baseElevation + 6;
    }
    if (states.contains(WidgetState.hovered)) {
      return baseElevation + 2;
    }
    if (states.contains(WidgetState.focused)) {
      return baseElevation + 2;
    }
    return baseElevation;
  }
}

@immutable
class _ElevatedButtonDefaultMouseCursor
    extends WidgetStateProperty<MouseCursor?> with Diagnosticable {
  _ElevatedButtonDefaultMouseCursor(this.enabledCursor, this.disabledCursor);

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

class _MongolElevatedButtonWithIcon extends MongolElevatedButton {
  _MongolElevatedButtonWithIcon({
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
          child: _MongolElevatedButtonWithIconChild(icon: icon, label: label),
        );

  @override
  ButtonStyle defaultStyleOf(BuildContext context) {
    final bool useMaterial3 = Theme.of(context).useMaterial3;
    final ButtonStyle buttonStyle = super.defaultStyleOf(context);
    final double defaultFontSize =
        buttonStyle.textStyle?.resolve(const <WidgetState>{})?.fontSize ?? 14.0;
    final double effectiveTextScale =
        MediaQuery.textScalerOf(context).scale(defaultFontSize) / 14.0;

    final EdgeInsetsGeometry scaledPadding = useMaterial3
        ? ButtonStyleButton.scaledPadding(
            const EdgeInsetsDirectional.fromSTEB(0, 16, 0, 24),
            const EdgeInsetsDirectional.fromSTEB(0, 8, 0, 12),
            const EdgeInsetsDirectional.fromSTEB(0, 4, 0, 6),
            effectiveTextScale,
          )
        : ButtonStyleButton.scaledPadding(
            const EdgeInsetsDirectional.fromSTEB(0, 12, 0, 16),
            const EdgeInsets.symmetric(vertical: 8),
            const EdgeInsetsDirectional.fromSTEB(0, 8, 0, 4),
            effectiveTextScale,
          );
    return buttonStyle.copyWith(
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(scaledPadding),
    );
  }
}

class _MongolElevatedButtonWithIconChild extends StatelessWidget {
  const _MongolElevatedButtonWithIconChild(
      {required this.label, required this.icon});

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

/// Material 3 的默认样式实现。
class _ElevatedButtonDefaultsM3 extends ButtonStyle {
  _ElevatedButtonDefaultsM3(this.context)
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
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return _colors.onSurface.withValues(alpha: 0.12);
        }
        return _colors.surface;
      });

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
      WidgetStatePropertyAll<Color>(_colors.shadow);

  @override
  WidgetStateProperty<Color>? get surfaceTintColor =>
      WidgetStatePropertyAll<Color>(_colors.surfaceTint);

  @override
  WidgetStateProperty<double>? get elevation =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return 0.0;
        }
        if (states.contains(WidgetState.pressed)) {
          return 1.0;
        }
        if (states.contains(WidgetState.hovered)) {
          return 3.0;
        }
        if (states.contains(WidgetState.focused)) {
          return 1.0;
        }
        return 1.0;
      });

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
