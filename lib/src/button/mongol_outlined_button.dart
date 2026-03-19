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

import 'mongol_button_style_button.dart';

/// 垂直方向的Material Design "轮廓按钮"；本质上是带有轮廓边框的[MongolTextButton]。
///
/// 轮廓按钮是中等强调的按钮。它们包含重要的操作，但不是应用程序中的主要操作。
///
/// 轮廓按钮是在（零海拔）[Material]小部件上显示的标签[child]。标签的[MongolText]和[Icon]
/// 小部件以[style]的[ButtonStyle.foregroundColor]显示，轮廓的权重和颜色
/// 由[ButtonStyle.side]定义。按钮通过填充[style]的[ButtonStyle.backgroundColor]来响应触摸。
///
/// 轮廓按钮的默认样式由[defaultStyleOf]定义。
/// 此轮廓按钮的样式可以通过其[style]参数覆盖。子树中所有文本按钮的样式可以通过[OutlinedButtonTheme]覆盖，
/// 应用程序中所有轮廓按钮的样式可以通过[Theme]的[ThemeData.outlinedButtonTheme]属性覆盖。
///
/// 与[MongolTextButton]或[MongolElevatedButton]不同，轮廓按钮有一个默认的[ButtonStyle.side]，
/// 它定义了轮廓的外观。因为默认的`side`不为空，所以它无条件地覆盖形状的[OutlinedBorder.side]。
/// 换句话说，要指定轮廓按钮的形状和轮廓的外观，必须同时指定[ButtonStyle.shape]和[ButtonStyle.side]属性。
///
/// {@tool dartpad --template=stateless_widget_scaffold_center}
///
/// 以下是基本[MongolOutlinedButton]的示例。
///
/// ```dart
/// Widget build(BuildContext context) {
///   return MongolOutlinedButton(
///     onPressed: () {
///       print('Received click');
///     },
///     child: const MongolText('点击我'),
///   );
/// }
/// ```
/// {@end-tool}
///
/// 静态[styleFrom]方法是从简单值创建轮廓按钮[ButtonStyle]的便捷方法。
///
/// 另请参见：
///
///  * [MongolElevatedButton]，一种填充的垂直按钮，其材质在按下时会升高。
///  * [FilledButton]，一种填充的垂直按钮，按下时不会升高。
///  * [FilledButton.tonal]，一种填充的垂直按钮变体，使用次要填充颜色。
///  * [MongolTextButton]，一种没有轮廓或填充颜色的垂直按钮。
///  * <https://material.io/design/components/buttons.html>
///  * <https://m3.material.io/components/buttons>
class MongolOutlinedButton extends MongolButtonStyleButton {
  /// 创建一个MongolOutlinedButton。
  ///
  /// [autofocus]和[clipBehavior]参数不能为空。
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

  /// 从一对用作按钮[icon]和[label]的小部件创建文本按钮。
  ///
  /// 图标和标签排列在一列中，开头有12个逻辑像素的填充，结尾有16个逻辑像素的填充，中间有8个像素的间隙。
  ///
  /// [icon]和[label]参数不能为空。
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

  /// 一个静态便捷方法，根据简单的值构造轮廓按钮[ButtonStyle]。
  ///
  /// [foregroundColor]和[disabledForegroundColor]颜色用于创建[MaterialStateProperty] [ButtonStyle.foregroundColor]，
  /// 以及派生的[ButtonStyle.overlayColor]。
  ///
  /// [backgroundColor]和[disabledBackgroundColor]颜色用于创建[MaterialStateProperty] [ButtonStyle.backgroundColor]。
  /// 禁用的文本和图标颜色。
  ///
  /// 类似地，[enabledMouseCursor]和[disabledMouseCursor]参数用于构造[ButtonStyle.mouseCursor]。
  ///
  /// 所有其他参数要么直接使用，要么用于为所有状态创建具有单个值的[WidgetStateProperty]。
  ///
  /// 所有参数默认为null，默认情况下此方法返回一个不覆盖任何内容的[ButtonStyle]。
  ///
  /// 例如，要覆盖[MongolOutlinedButton]的默认形状和轮廓，可以编写：
  ///
  /// ```dart
  /// MongolOutlinedButton(
  ///   style: OutlinedButton.styleFrom(
  ///      shape: StadiumBorder(),
  ///      side: BorderSide(width: 2, color: Colors.green),
  ///   ),
  /// )
  /// ```
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
    final WidgetStateProperty<Color?>? foregroundColorProp =
        (foreground == null && disabledForeground == null)
            ? null
            : _OutlinedButtonDefaultColor(foreground, disabledForeground);
    final WidgetStateProperty<Color?>? backgroundColorProp =
        (backgroundColor == null && disabledBackgroundColor == null)
            ? null
            : disabledBackgroundColor == null
                ? ButtonStyleButton.allOrNull<Color?>(backgroundColor)
                : _OutlinedButtonDefaultColor(
                    backgroundColor, disabledBackgroundColor);
    final WidgetStateProperty<Color?>? overlayColor =
        (foreground == null) ? null : _OutlinedButtonDefaultOverlay(foreground);
    final WidgetStateProperty<MouseCursor?> mouseCursor =
        _OutlinedButtonDefaultMouseCursor(
            enabledMouseCursor, disabledMouseCursor);

    return ButtonStyle(
      textStyle: ButtonStyleButton.allOrNull<TextStyle>(textStyle),
      foregroundColor: foregroundColorProp,
      backgroundColor: backgroundColorProp,
      overlayColor: overlayColor,
      shadowColor: ButtonStyleButton.allOrNull<Color>(shadowColor),
      surfaceTintColor: ButtonStyleButton.allOrNull<Color>(surfaceTintColor),
      elevation: ButtonStyleButton.allOrNull<double>(elevation),
      padding: ButtonStyleButton.allOrNull<EdgeInsetsGeometry>(padding),
      minimumSize: ButtonStyleButton.allOrNull<Size>(minimumSize),
      maximumSize: ButtonStyleButton.allOrNull<Size>(maximumSize),
      fixedSize: ButtonStyleButton.allOrNull<Size>(fixedSize),
      side: ButtonStyleButton.allOrNull<BorderSide>(side),
      shape: ButtonStyleButton.allOrNull<OutlinedBorder>(shape),
      mouseCursor: mouseCursor,
      visualDensity: visualDensity,
      tapTargetSize: tapTargetSize,
      animationDuration: animationDuration,
      enableFeedback: enableFeedback,
      alignment: alignment,
      splashFactory: splashFactory,
    );
  }

  /// 定义按钮的默认外观。
  ///
  /// 除了定义轮廓的[ButtonStyle.side]和[ButtonStyle.padding]外，返回的样式与[MongolTextButton]相同。
  ///
  /// 按钮[child]的[MongolText]和[Icon]小部件使用[ButtonStyle]的前景颜色渲染。
  /// 当按钮获得焦点、悬停或按下时，按钮的[InkWell]会添加样式的覆盖颜色。
  /// 按钮的背景颜色成为其[Material]颜色，默认情况下是透明的。
  ///
  /// 所有ButtonStyle的默认值如下。在这个列表中，"Theme.foo"是`Theme.of(context).foo`的简写。
  /// 颜色方案值如"onSurface(0.38)"是`onSurface.withValues(alpha: 0.38)`的简写。
  /// 没有后跟子列表的[WidgetStateProperty]值属性对于所有状态都具有相同的值，
  /// 否则值如为每个状态指定，"others"表示所有其他状态。
  ///
  /// [ButtonStyle.textStyle]的颜色不使用，而是使用[ButtonStyle.foregroundColor]。
  ///
  /// ## Material 2 默认值
  ///
  /// * `textStyle` - Theme.textTheme.button
  /// * `backgroundColor` - transparent
  /// * `foregroundColor`
  ///   * disabled - Theme.colorScheme.onSurface(0.38)
  ///   * others - Theme.colorScheme.primary
  /// * `overlayColor`
  ///   * hovered - Theme.colorScheme.primary(0.04)
  ///   * focused or pressed - Theme.colorScheme.primary(0.12)
  /// * `shadowColor` - Theme.shadowColor
  /// * `elevation` - 0
  /// * `padding`
  ///   * `default font size <= 14` - vertical(16)
  ///   * `14 < default font size <= 28` - lerp(vertical(16), vertical(8))
  ///   * `28 < default font size <= 36` - lerp(vertical(8), vertical(4))
  ///   * `36 < default font size` - vertical(4)
  /// * `minimumSize` - Size(36, 64)
  /// * `fixedSize` - null
  /// * `maximumSize` - Size.infinite
  /// * `side` - BorderSide(width: 1, color: Theme.colorScheme.onSurface(0.12))
  /// * `shape` - RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))
  /// * `mouseCursor`
  ///   * disabled - SystemMouseCursors.forbidden
  ///   * others - SystemMouseCursors.click
  /// * `visualDensity` - theme.visualDensity
  /// * `tapTargetSize` - theme.materialTapTargetSize
  /// * `animationDuration` - kThemeChangeDuration
  /// * `enableFeedback` - true
  /// * `alignment` - Alignment.center
  /// * `splashFactory` - InkRipple.splashFactory
  ///
  /// ## Material 3 默认值
  ///
  /// 如果[ThemeData.useMaterial3]设置为true，将使用以下默认值：
  ///
  /// * `textStyle` - Theme.textTheme.labelLarge
  /// * `backgroundColor` - transparent
  /// * `foregroundColor`
  ///   * disabled - Theme.colorScheme.onSurface(0.38)
  ///   * others - Theme.colorScheme.primary
  /// * `overlayColor`
  ///   * hovered - Theme.colorScheme.primary(0.08)
  ///   * focused or pressed - Theme.colorScheme.primary(0.12)
  ///   * others - null
  /// * `shadowColor` - Colors.transparent,
  /// * `surfaceTintColor` - null
  /// * `elevation` - 0
  /// * `padding`
  ///   * `default font size <= 14` - vertical(24)
  ///   * `14 < default font size <= 28` - lerp(vertical(24), vertical(12))
  ///   * `28 < default font size <= 36` - lerp(vertical(12), vertical(6))
  ///   * `36 < default font size` - vertical(6)
  /// * `minimumSize` - Size(40, 64)
  /// * `fixedSize` - null
  /// * `maximumSize` - Size.infinite
  /// * `side`
  ///   * disabled - BorderSide(color: Theme.colorScheme.onSurface(0.12))
  ///   * others - BorderSide(color: Theme.colorScheme.outline)
  /// * `shape` - StadiumBorder()
  /// * `mouseCursor`
  ///   * disabled - SystemMouseCursors.basic
  ///   * others - SystemMouseCursors.click
  /// * `visualDensity` - theme.visualDensity
  /// * `tapTargetSize` - theme.materialTapTargetSize
  /// * `animationDuration` - kThemeChangeDuration
  /// * `enableFeedback` - true
  /// * `alignment` - Alignment.center
  /// * `splashFactory` - Theme.splashFactory
  ///
  /// 对于[OutlinedButton.icon]工厂，[padding]的开始（通常是顶部）值从24减少到16。
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

  /// 返回最近的[OutlinedButtonTheme]祖先的样式。
  @override
  ButtonStyle? themeStyleOf(BuildContext context) {
    return OutlinedButtonTheme.of(context).style;
  }
}

/// 计算按钮的缩放内边距
///
/// 根据主题和文本缩放因子计算按钮的垂直内边距。
EdgeInsetsGeometry _scaledPadding(BuildContext context) {
  final ThemeData theme = Theme.of(context);
  final double padding1x = theme.useMaterial3 ? 24.0 : 16.0; // Material 3使用24，Material 2使用16
  final double defaultFontSize = theme.textTheme.labelLarge?.fontSize ?? 14.0; // 默认字体大小
  final double effectiveTextScale =
      MediaQuery.textScalerOf(context).scale(defaultFontSize) / 14.0; // 有效的文本缩放因子
  return ButtonStyleButton.scaledPadding(
    EdgeInsets.symmetric(vertical: padding1x), // 正常内边距
    EdgeInsets.symmetric(vertical: padding1x / 2), // 中等内边距
    EdgeInsets.symmetric(vertical: padding1x / 2 / 2), // 小内边距
    effectiveTextScale, // 文本缩放因子
  );
}

/// 轮廓按钮的默认颜色属性
///
/// 根据按钮状态返回不同的颜色。
@immutable
class _OutlinedButtonDefaultColor extends WidgetStateProperty<Color?>
    with Diagnosticable {
  /// 创建一个轮廓按钮默认颜色属性
  ///
  /// [color]：正常状态下的颜色
  /// [disabled]：禁用状态下的颜色
  _OutlinedButtonDefaultColor(this.color, this.disabled);

  final Color? color; // 正常状态下的颜色
  final Color? disabled; // 禁用状态下的颜色

  /// 根据状态解析颜色
  @override
  Color? resolve(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return disabled;
    }
    return color;
  }
}

/// 轮廓按钮的默认覆盖颜色属性
///
/// 根据按钮状态返回不同的覆盖颜色，用于悬停、焦点和按下状态。
@immutable
class _OutlinedButtonDefaultOverlay extends WidgetStateProperty<Color?>
    with Diagnosticable {
  /// 创建一个轮廓按钮默认覆盖颜色属性
  ///
  /// [foreground]：前景颜色
  _OutlinedButtonDefaultOverlay(this.foreground);

  final Color foreground; // 前景颜色

  /// 根据状态解析颜色
  @override
  Color? resolve(Set<WidgetState> states) {
    if (states.contains(WidgetState.pressed)) {
      return foreground.withValues(alpha: 0.12);
    }
    if (states.contains(WidgetState.hovered)) {
      return foreground.withValues(alpha: 0.04);
    }
    if (states.contains(WidgetState.focused)) {
      return foreground.withValues(alpha: 0.12);
    }
    return null;
  }
}

/// 轮廓按钮的默认鼠标光标属性
///
/// 根据按钮状态返回不同的鼠标光标。
@immutable
class _OutlinedButtonDefaultMouseCursor
    extends WidgetStateProperty<MouseCursor?> with Diagnosticable {
  /// 创建一个轮廓按钮默认鼠标光标属性
  ///
  /// [enabledCursor]：启用状态下的鼠标光标
  /// [disabledCursor]：禁用状态下的鼠标光标
  _OutlinedButtonDefaultMouseCursor(this.enabledCursor, this.disabledCursor);

  final MouseCursor? enabledCursor; // 启用状态下的鼠标光标
  final MouseCursor? disabledCursor; // 禁用状态下的鼠标光标

  /// 根据状态解析鼠标光标
  @override
  MouseCursor? resolve(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return disabledCursor;
    }
    return enabledCursor;
  }
}

/// 带有图标的Mongol轮廓按钮
class _MongolOutlinedButtonWithIcon extends MongolOutlinedButton {
  /// 创建一个带有图标的Mongol轮廓按钮
  ///
  /// [icon]：按钮的图标
  /// [label]：按钮的标签
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

  /// 定义带图标的轮廓按钮的默认样式
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

/// 带有图标的Mongol轮廓按钮的子部件
class _MongolOutlinedButtonWithIconChild extends StatelessWidget {
  /// 创建一个带有图标的Mongol轮廓按钮的子部件
  ///
  /// [label]：按钮的标签
  /// [icon]：按钮的图标
  const _MongolOutlinedButtonWithIconChild({
    required this.label,
    required this.icon,
  });

  final Widget label; // 按钮的标签
  final Widget icon; // 按钮的图标

  /// 构建UI
  @override
  Widget build(BuildContext context) {
    final TextScaler textScaler = MediaQuery.textScalerOf(context);
    // 使用 TextScaler.scale() 替代已弃用的 textScaleFactor
    final double scale = textScaler.scale(1.0); // 文本缩放因子
    final double gap =
        scale <= 1 ? 8 : lerpDouble(8, 4, math.min(scale - 1, 1))!; // 图标和标签之间的间隙
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[icon, SizedBox(height: gap), Flexible(child: label)],
    );
  }
}

// BEGIN GENERATED TOKEN PROPERTIES - OutlinedButton

// 请勿手动编辑。"BEGIN GENERATED"和"END GENERATED"注释之间的代码是从Material
// Design token数据库通过脚本生成的：
//   dev/tools/gen_defaults/bin/gen_defaults.dart。

/// 轮廓按钮的Material 3默认样式
class _MongolOutlinedButtonDefaultsM3 extends ButtonStyle {
  /// 创建轮廓按钮的Material 3默认样式
  ///
  /// [context]：构建上下文
  _MongolOutlinedButtonDefaultsM3(this.context)
      : super(
          animationDuration: kThemeChangeDuration,
          enableFeedback: true,
          alignment: Alignment.center,
        );

  final BuildContext context; // 构建上下文
  late final ColorScheme _colors = Theme.of(context).colorScheme; // 颜色方案

  @override
  WidgetStateProperty<TextStyle?> get textStyle =>
      WidgetStatePropertyAll<TextStyle?>(
          Theme.of(context).textTheme.labelLarge); // 文本样式

  @override
  WidgetStateProperty<Color?>? get backgroundColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent); // 背景颜色

  @override
  WidgetStateProperty<Color?>? get foregroundColor =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return _colors.onSurface.withValues(alpha: 0.38);
        }
        return _colors.primary;
      }); // 前景颜色

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
      }); // 覆盖颜色

  @override
  WidgetStateProperty<Color>? get shadowColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent); // 阴影颜色

  @override
  WidgetStateProperty<Color>? get surfaceTintColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent); // 表面色调

  @override
  WidgetStateProperty<double>? get elevation =>
      const WidgetStatePropertyAll<double>(0.0); // 海拔高度

  @override
  WidgetStateProperty<EdgeInsetsGeometry>? get padding =>
      WidgetStatePropertyAll<EdgeInsetsGeometry>(_scaledPadding(context)); // 内边距

  @override
  WidgetStateProperty<Size>? get minimumSize =>
      const WidgetStatePropertyAll<Size>(Size(40.0, 64.0)); // 最小大小

  // 无默认固定大小

  @override
  WidgetStateProperty<Size>? get maximumSize =>
      const WidgetStatePropertyAll<Size>(Size.infinite); // 最大大小

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
      }); // 边框

  @override
  WidgetStateProperty<OutlinedBorder>? get shape =>
      const WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder()); // 形状

  @override
  WidgetStateProperty<MouseCursor?>? get mouseCursor =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return SystemMouseCursors.basic;
        }
        return SystemMouseCursors.click;
      }); // 鼠标光标

  @override
  VisualDensity? get visualDensity => Theme.of(context).visualDensity; // 视觉密度

  @override
  MaterialTapTargetSize? get tapTargetSize =>
      Theme.of(context).materialTapTargetSize; // 点击目标大小

  @override
  InteractiveInkFeatureFactory? get splashFactory =>
      Theme.of(context).splashFactory; // 水波纹效果工厂
}

// END GENERATED TOKEN PROPERTIES - OutlinedButton
