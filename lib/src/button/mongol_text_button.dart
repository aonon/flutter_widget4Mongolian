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

import 'mongol_button_style_button.dart';

/// 垂直方向的Material Design "文本按钮"
///
/// 文本按钮没有可见边框，通过相对于其他内容的位置提供上下文。
/// 适用于工具栏、对话框或与其他内容内联使用。
///
/// 按钮标签以[ButtonStyle.foregroundColor]显示，触摸时填充[ButtonStyle.backgroundColor]。
///
/// 样式可通过[style]参数、[TextButtonTheme]或[ThemeData.textButtonTheme]覆盖。
/// 静态[styleFrom]方法提供了从简单值创建样式的便捷方式。
///
/// 如果[onPressed]和[onLongPress]都为null，按钮将被禁用。
///
/// {@tool dartpad --template=stateless_widget_scaffold}
///
/// 此示例显示如何渲染禁用的TextButton、启用的MongolTextButton以及带有渐变背景的MongolTextButton。
///
/// ```dart
/// Widget build(BuildContext context) {
///   return Center(
///     child: Column(
///       mainAxisSize: MainAxisSize.min,
///       children: <Widget>[
///         MongolTextButton(
///            style: MongolTextButton.styleFrom(
///              textStyle: const TextStyle(fontSize: 20),
///            ),
///            onPressed: null,
///            child: const Text('禁用'),
///         ),
///         const SizedBox(height: 30),
///         MongolTextButton(
///           style: MongolTextButton.styleFrom(
///             textStyle: const TextStyle(fontSize: 20),
///           ),
///           onPressed: () {},
///           child: const MongolText('启用'),
///         ),
///         const SizedBox(height: 30),
///         ClipRRect(
///           borderRadius: BorderRadius.circular(4),
///           child: Stack(
///             children: <Widget>[
///               Positioned.fill(
///                 child: Container(
///                   decoration: const BoxDecoration(
///                     gradient: LinearGradient(
///                       colors: <Color>[
///                         Color(0xFF0D47A1),
///                         Color(0xFF1976D2),
///                         Color(0xFF42A5F5),
///                       ],
///                     ),
///                   ),
///                 ),
///               ),
///               MongolTextButton(
///                 style: MongolTextButton.styleFrom(
///                   padding: const EdgeInsets.all(16.0),
///                   primary: Colors.white,
///                   textStyle: const TextStyle(fontSize: 20),
///                 ),
///                 onPressed: () {},
///                  child: const MongolText('渐变'),
///               ),
///             ],
///           ),
///         ),
///       ],
///     ),
///   );
/// }
///
/// ```
/// {@end-tool}
///
/// 另请参见：
///
///  * [MongolElevatedButton]，一种填充的垂直按钮，其材质在按下时会升高。
///  * [MongolFilledButton]，一种填充的垂直按钮，按下时不会升高。
///  * [MongolFilledButton.tonal]，一种填充的垂直按钮变体，使用次要填充颜色。
///  * [MongolOutlinedButton]，一种带有轮廓边框且无填充颜色的垂直按钮。
///  * <https://material.io/design/components/buttons.html>
///  * <https://m3.material.io/components/buttons>
class MongolTextButton extends MongolButtonStyleButton {
  /// 创建一个MongolTextButton。
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
    required Widget super.child,
  });

  /// 从一对用作按钮[icon]和[label]的小部件创建文本按钮。
  ///
  /// 图标和标签排列在一列中，两端有8个逻辑像素的填充，中间有8个像素的间隙。
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

  /// 一个静态便捷方法，根据简单的值构造文本按钮[ButtonStyle]。
  ///
  /// [foregroundColor]和[disabledForegroundColor]颜色用于创建[MaterialStateProperty] [ButtonStyle.foregroundColor]，
  /// 以及派生的[ButtonStyle.overlayColor]。
  ///
  /// [backgroundColor]和[disabledBackgroundColor]颜色用于创建[MaterialStateProperty] [ButtonStyle.backgroundColor]。
  ///
  /// 类似地，[enabledMouseCursor]和[disabledMouseCursor]参数用于构造[ButtonStyle.mouseCursor]。
  ///
  /// 所有其他参数要么直接使用，要么用于为所有状态创建具有单个值的[WidgetStateProperty]。
  ///
  /// 所有参数默认为null。默认情况下此方法返回一个不覆盖任何内容的[ButtonStyle]。
  ///
  /// 例如，要覆盖[MongolTextButton]的默认文本和图标颜色及其覆盖颜色，以及按下、焦点和悬停状态的标准不透明度调整，
  /// 可以编写：
  ///
  /// ```dart
  /// MongolTextButton(
  ///   style: TextButton.styleFrom(primary: Colors.green),
  /// )
  /// ```
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
    final WidgetStateProperty<Color?>? foregroundColorProp =
        (foreground == null && disabledForeground == null)
            ? null
            : _TextButtonDefaultColor(foreground, disabledForeground);
    final WidgetStateProperty<Color?>? backgroundColorProp = (backgroundColor ==
                null &&
            disabledBackgroundColor == null)
        ? null
        : disabledBackgroundColor == null
            ? ButtonStyleButton.allOrNull<Color?>(backgroundColor)
            : _TextButtonDefaultColor(backgroundColor, disabledBackgroundColor);
    final WidgetStateProperty<Color?>? overlayColor =
        (foreground == null) ? null : _TextButtonDefaultOverlay(foreground);
    final WidgetStateProperty<Color?>? iconColorProp =
        (iconColor == null && disabledIconColor == null)
            ? null
            : disabledIconColor == null
                ? ButtonStyleButton.allOrNull<Color?>(iconColor)
                : _TextButtonDefaultIconColor(iconColor, disabledIconColor);
    final WidgetStateProperty<MouseCursor?> mouseCursor =
        _TextButtonDefaultMouseCursor(enabledMouseCursor, disabledMouseCursor);

    return ButtonStyle(
      textStyle: ButtonStyleButton.allOrNull<TextStyle>(textStyle),
      foregroundColor: foregroundColorProp,
      backgroundColor: backgroundColorProp,
      overlayColor: overlayColor,
      shadowColor: ButtonStyleButton.allOrNull<Color>(shadowColor),
      surfaceTintColor: ButtonStyleButton.allOrNull<Color>(surfaceTintColor),
      iconColor: iconColorProp,
      elevation: ButtonStyleButton.allOrNull<double>(elevation),
      padding: ButtonStyleButton.allOrNull<EdgeInsetsGeometry>(padding),
      minimumSize: ButtonStyleButton.allOrNull<Size>(minimumSize),
      fixedSize: ButtonStyleButton.allOrNull<Size>(fixedSize),
      maximumSize: ButtonStyleButton.allOrNull<Size>(maximumSize),
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
  /// 按钮[child]的[MongolText]和[Icon]小部件使用[ButtonStyle]的前景颜色渲染。
  /// 当按钮获得焦点、悬停或按下时，按钮的[InkWell]会添加样式的覆盖颜色。
  /// 按钮的背景颜色成为其[Material]颜色，默认情况下是透明的。
  ///
  /// 所有ButtonStyle的默认值如下。
  ///
  /// 在这个列表中，"Theme.foo"是`Theme.of(context).foo`的简写。
  /// 颜色方案值如"onSurface(0.38)"是`onSurface.withValues(alpha: 0.38)`的简写。
  /// 没有后跟子列表的[WidgetStateProperty]值属性对于所有状态都具有相同的值，
  /// 否则值如为每个状态指定，"others"表示所有其他状态。
  ///
  /// 下面的"默认字体大小"指的是在[defaultStyleOf]方法中指定的字体大小（如果未指定则为14.0），
  /// 由`MediaQuery.textScalerOf(context).scale`方法缩放。
  /// 为了可读性，EdgeInsets构造函数和`EdgeInsetsGeometry.lerp`的名称已被缩写。
  ///
  /// [ButtonStyle.textStyle]的颜色不使用，而是使用[ButtonStyle.foregroundColor]颜色。
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
  ///   * `default font size <= 14` - (vertical(12), horizontal(8))
  ///   * `14 < default font size <= 28` - lerp(all(8), vertical(8))
  ///   * `28 < default font size <= 36` - lerp(vertical(8), vertical(4))
  ///   * `36 < default font size` - vertical(4)
  /// * `minimumSize` - Size(36, 64)
  /// * `fixedSize` - null
  /// * `maximumSize` - Size.infinite
  /// * `side` - null
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
  /// [MongolTextButton.icon]工厂的默认填充值略有不同：
  ///
  /// * `padding`
  ///   * `default font size <= 14` - all(8)
  ///   * `14 < default font size <= 28 `- lerp(all(8), vertical(4))
  ///   * `28 < default font size` - vertical(4)
  ///
  /// 定义按钮轮廓外观的`side`的默认值为null。这意味着轮廓由按钮形状的[OutlinedBorder.side]定义。
  /// 通常，[OutlinedBorder]的side的默认值是[BorderSide.none]，因此不会绘制轮廓。
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
  ///   * `default font size <= 14` - lerp(vertical(12), vertical(4))
  ///   * `14 < default font size <= 28` - lerp(all(8), vertical(8))
  ///   * `28 < default font size <= 36` - lerp(vertical(8), vertical(4))
  ///   * `36 < default font size` - vertical(4)
  /// * `minimumSize` - Size(40, 64)
  /// * `fixedSize` - null
  /// * `maximumSize` - Size.infinite
  /// * `side` - null
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
  /// 对于[MongolTextButton.icon]工厂，[padding]的结束（通常是底部）值从12增加到16。
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

  /// 返回最近的[TextButtonTheme]祖先的[TextButtonThemeData.style]。
  @override
  ButtonStyle? themeStyleOf(BuildContext context) {
    return TextButtonTheme.of(context).style;
  }
}

/// 计算按钮的缩放内边距
///
/// 根据主题和文本缩放因子计算按钮的内边距。
EdgeInsetsGeometry _scaledPadding(BuildContext context) {
  final ThemeData theme = Theme.of(context);
  final double defaultFontSize = theme.textTheme.labelLarge?.fontSize ?? 14.0; // 默认字体大小
  final double effectiveTextScale =
      MediaQuery.textScalerOf(context).scale(defaultFontSize) / 14.0; // 有效的文本缩放因子
  return ButtonStyleButton.scaledPadding(
    theme.useMaterial3
        ? const EdgeInsets.symmetric(vertical: 12, horizontal: 8) // Material 3的内边距
        : const EdgeInsets.all(8), // Material 2的内边距
    const EdgeInsets.symmetric(vertical: 8), // 中等内边距
    const EdgeInsets.symmetric(vertical: 4), // 小内边距
    effectiveTextScale, // 文本缩放因子
  );
}

/// 文本按钮的默认颜色属性
///
/// 根据按钮状态返回不同的颜色。
@immutable
class _TextButtonDefaultColor extends WidgetStateProperty<Color?> {
  /// 创建一个文本按钮默认颜色属性
  ///
  /// [color]：正常状态下的颜色
  /// [disabled]：禁用状态下的颜色
  _TextButtonDefaultColor(this.color, this.disabled);

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

  /// 转换为字符串表示
  @override
  String toString() {
    return '{disabled: $disabled, otherwise: $color}';
  }
}

/// 文本按钮的默认覆盖颜色属性
///
/// 根据按钮状态返回不同的覆盖颜色，用于悬停、焦点和按下状态。
@immutable
class _TextButtonDefaultOverlay extends WidgetStateProperty<Color?> {
  /// 创建一个文本按钮默认覆盖颜色属性
  ///
  /// [primary]：主要颜色
  _TextButtonDefaultOverlay(this.primary);

  final Color primary; // 主要颜色

  /// 根据状态解析颜色
  @override
  Color? resolve(Set<WidgetState> states) {
    if (states.contains(WidgetState.pressed)) {
      return primary.withValues(alpha: 0.12);
    }
    if (states.contains(WidgetState.hovered)) {
      return primary.withValues(alpha: 0.04);
    }
    if (states.contains(WidgetState.focused)) {
      return primary.withValues(alpha: 0.12);
    }
    return null;
  }

  /// 转换为字符串表示
  @override
  String toString() {
    return '{hovered: ${primary.withValues(alpha: 0.04)}, focused,pressed: ${primary.withValues(alpha: 0.12)}, otherwise: null}';
  }
}

/// 文本按钮的默认图标颜色属性
///
/// 根据按钮状态返回不同的图标颜色。
@immutable
class _TextButtonDefaultIconColor extends WidgetStateProperty<Color?> {
  /// 创建一个文本按钮默认图标颜色属性
  ///
  /// [iconColor]：正常状态下的图标颜色
  /// [disabledIconColor]：禁用状态下的图标颜色
  _TextButtonDefaultIconColor(this.iconColor, this.disabledIconColor);

  final Color? iconColor; // 正常状态下的图标颜色
  final Color? disabledIconColor; // 禁用状态下的图标颜色

  /// 根据状态解析颜色
  @override
  Color? resolve(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return disabledIconColor;
    }
    return iconColor;
  }

  /// 转换为字符串表示
  @override
  String toString() {
    return '{disabled: $disabledIconColor, color: $iconColor}';
  }
}

/// 文本按钮的默认鼠标光标属性
///
/// 根据按钮状态返回不同的鼠标光标。
@immutable
class _TextButtonDefaultMouseCursor extends WidgetStateProperty<MouseCursor?>
    with Diagnosticable {
  /// 创建一个文本按钮默认鼠标光标属性
  ///
  /// [enabledCursor]：启用状态下的鼠标光标
  /// [disabledCursor]：禁用状态下的鼠标光标
  _TextButtonDefaultMouseCursor(this.enabledCursor, this.disabledCursor);

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

/// 带有图标的Mongol文本按钮
class _MongolTextButtonWithIcon extends MongolTextButton {
  /// 创建一个带有图标的Mongol文本按钮
  ///
  /// [icon]：按钮的图标
  /// [label]：按钮的标签
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

  /// 定义带图标的文本按钮的默认样式
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

/// 带有图标的Mongol文本按钮的子部件
class _MongolTextButtonWithIconChild extends StatelessWidget {
  /// 创建一个带有图标的Mongol文本按钮的子部件
  ///
  /// [label]：按钮的标签
  /// [icon]：按钮的图标
  const _MongolTextButtonWithIconChild({
    required this.label,
    required this.icon,
  });

  final Widget label; // 按钮的标签
  final Widget icon; // 按钮的图标

  /// 构建UI
  @override
  Widget build(BuildContext context) {
    final TextScaler textScaler = MediaQuery.textScalerOf(context);
    final double scale = textScaler.scale(1.0); // 文本缩放因子
    final double gap = 
        scale <= 1 ? 8 : lerpDouble(8, 4, math.min(scale - 1, 1))!; // 图标和标签之间的间隙
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[icon, SizedBox(height: gap), Flexible(child: label)],
    );
  }
}

// BEGIN GENERATED TOKEN PROPERTIES - TextButton

// 请勿手动编辑。"BEGIN GENERATED"和"END GENERATED"注释之间的代码是从Material
// Design token数据库通过脚本生成的：
//   dev/tools/gen_defaults/bin/gen_defaults.dart。

/// 文本按钮的Material 3默认样式
class _MongolTextButtonDefaultsM3 extends ButtonStyle {
  /// 创建文本按钮的Material 3默认样式
  ///
  /// [context]：构建上下文
  _MongolTextButtonDefaultsM3(this.context)
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

  // 无默认边框

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

// END GENERATED TOKEN PROPERTIES - TextButton
