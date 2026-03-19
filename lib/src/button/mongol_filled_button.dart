// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../text/mongol_text.dart';
import 'mongol_button_style_button.dart';
import 'mongol_text_button.dart';
import 'mongol_outlined_button.dart';
import 'mongol_elevated_button.dart';

enum _MongolFilledButtonVariant { filled, tonal }

/// Material Design 蒙古文填充按钮。
///
/// 填充按钮在 [FloatingActionButton] 之后具有最强的视觉冲击力，
/// 应该用于完成流程的重要最终操作，
/// 例如 **保存**、**立即加入** 或 **确认**。
///
/// 填充按钮是一个显示在 [Material]
/// 小部件上的标签 [child]。标签的 [MongolText] 和 [Icon] 小部件以
/// [style] 的 [ButtonStyle.foregroundColor] 显示，按钮的填充
/// 背景是 [ButtonStyle.backgroundColor]。
///
/// 填充按钮的默认样式由
/// [defaultStyleOf] 定义。此填充按钮的样式可以
/// 通过其 [style] 参数覆盖。子树中所有填充
/// 按钮的样式可以通过
/// [FilledButtonTheme] 覆盖，应用中所有填充
/// 按钮的样式可以通过 [Theme] 的
/// [ThemeData.filledButtonTheme] 属性覆盖。
///
/// 静态 [styleFrom] 方法是创建填充按钮
/// [ButtonStyle] 的便捷方法，可从简单值创建。
///
/// 如果 [onPressed] 和 [onLongPress] 回调为 null，则按钮将被禁用。
///
/// 要创建 "填充色调" 按钮，请使用 [MongolFilledButton.tonal]。
///
/// {@tool dartpad}
/// This sample produces enabled and disabled filled and filled tonal
/// buttons.
///
/// ** See code in examples/api/lib/material/filled_button/filled_button.0.dart **
/// {@end-tool}
///
/// See also:
///
///  * [MongolElevatedButton], a filled button whose material elevates when pressed.
///  * [MongolOutlinedButton], a button with an outlined border and no fill color.
///  * [MongolTextButton], a button with no outline or fill color.
///  * <https://material.io/design/components/buttons.html>
///  * <https://m3.material.io/components/buttons>
class MongolFilledButton extends MongolButtonStyleButton {
  /// 创建一个 MongolFilledButton。
  const MongolFilledButton({
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
  }) : _variant = _MongolFilledButtonVariant.filled;

  /// 从 [icon] 和 [label] 创建一个蒙古文填充按钮。
  ///
  /// 图标和标签排列成一列，开头和结尾有填充，
  /// 中间有一个间隙。
  factory MongolFilledButton.icon({
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
  }) = _MongolFilledButtonWithIcon;

  /// 创建 MongolFilledButton 的色调变体。
  ///
  /// 填充色调按钮是 [MongolFilledButton] 和 [MongolOutlinedButton] 之间的中间选择。
  /// 它们在低优先级按钮需要比轮廓更多强调的上下文中很有用，
  /// 例如入门流程中的 "下一步"。
  const MongolFilledButton.tonal({
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
  }) : _variant = _MongolFilledButtonVariant.tonal;

  /// 从 [icon] 和 [label] 创建一个蒙古文填充色调按钮。
  ///
  /// 图标和标签排列成一列，开头和结尾有填充，
  /// 中间有一个间隙。
  factory MongolFilledButton.tonalIcon({
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
  }) {
    return _MongolFilledButtonWithIcon.tonal(
      key: key,
      onPressed: onPressed,
      onLongPress: onLongPress,
      onHover: onHover,
      onFocusChange: onFocusChange,
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      statesController: statesController,
      icon: icon,
      label: label,
    );
  }

  /// 一个静态便捷方法，根据简单值构造填充按钮的 [ButtonStyle]。
  ///
  /// [foregroundColor] 和 [disabledForegroundColor] 颜色用于创建
  /// [MaterialStateProperty] [ButtonStyle.foregroundColor] 值。
  /// [backgroundColor] 和 [disabledBackgroundColor] 用于创建
  /// [MaterialStateProperty] [ButtonStyle.backgroundColor] 值。
  ///
  /// 按钮的海拔高度是相对于 [elevation]
  /// 参数定义的。禁用的海拔高度与参数值相同，
  /// 当按钮被悬停或聚焦时使用 [elevation] + 2，当按钮被按下时使用 elevation + 6。
  ///
  /// 同样，[enabledMouseCursor] 和 [disabledMouseCursor]
  /// 参数用于构造 [ButtonStyle.mouseCursor]。
  ///
  /// 所有其他参数要么直接使用，要么用于
  /// 为所有状态创建具有单一值的 [WidgetStateProperty]。
  ///
  /// 所有参数默认为 null，默认情况下此方法返回
  /// 一个不覆盖任何内容的 [ButtonStyle]。
  ///
  /// 例如，要覆盖 [MongolFilledButton] 的默认文本和图标颜色，
  /// 以及其覆盖颜色，并为按下、聚焦和
  /// 悬停状态提供所有标准不透明度调整，可以这样写：
  ///
  /// ```dart
  /// MongolFilledButton(
  ///   style: MongolFilledButton.styleFrom(foregroundColor: Colors.green),
  ///   onPressed: () {},
  ///   child: const Text('Filled button'),
  /// );
  /// ```
  ///
  /// 或者对于填充色调变体：
  /// ```dart
  /// MongolFilledButton.tonal(
  ///   style: MongolFilledButton.styleFrom(foregroundColor: Colors.green),
  ///   onPressed: () {},
  ///   child: const Text('Filled tonal button'),
  /// );
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
    final WidgetStateProperty<Color?>? backgroundColorProp =
        (backgroundColor == null && disabledBackgroundColor == null)
            ? null
            : _MongolFilledButtonDefaultColor(
                backgroundColor, disabledBackgroundColor);
    final Color? foreground = foregroundColor;
    final Color? disabledForeground = disabledForegroundColor;
    final WidgetStateProperty<Color?>? foregroundColorProp =
        (foreground == null && disabledForeground == null)
            ? null
            : _MongolFilledButtonDefaultColor(foreground, disabledForeground);
    final WidgetStateProperty<Color?>? overlayColor = (foreground == null)
        ? null
        : _MongolFilledButtonDefaultOverlay(foreground);
    final WidgetStateProperty<MouseCursor?> mouseCursor =
        _MongolFilledButtonDefaultMouseCursor(
            enabledMouseCursor, disabledMouseCursor);

    return ButtonStyle(
      textStyle: WidgetStatePropertyAll<TextStyle?>(textStyle),
      backgroundColor: backgroundColorProp,
      foregroundColor: foregroundColorProp,
      overlayColor: overlayColor,
      shadowColor: ButtonStyleButton.allOrNull<Color>(shadowColor),
      surfaceTintColor: ButtonStyleButton.allOrNull<Color>(surfaceTintColor),
      elevation: ButtonStyleButton.allOrNull(elevation),
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

  final _MongolFilledButtonVariant _variant;

  /// 定义按钮的默认外观。
  ///
  /// 按钮 [child] 的 [MongolText] 和 [Icon] 小部件以
  /// [ButtonStyle] 的前景色渲染。按钮的 [InkWell] 在按钮被聚焦、悬停
  /// 或按下时添加样式的覆盖颜色。按钮的背景颜色成为其 [Material]
  /// 颜色。
  ///
  /// 以下是 ButtonStyle 的所有默认值。在此列表中
  /// "Theme.foo" 是 `Theme.of(context).foo` 的简写。颜色
  /// 方案值如 "onSurface(0.38)" 是 `onSurface.withValues(alpha: 0.38)` 的简写。
  /// [WidgetStateProperty] 类型的属性如果后面没有子列表，则所有状态都具有相同
  /// 的值，否则值按每个状态指定，"others" 表示所有其他状态。
  ///
  /// {@macro flutter.material.elevated_button.default_font_size}
  ///
  /// [ButtonStyle.textStyle] 的颜色不使用，而是使用
  /// [ButtonStyle.foregroundColor] 颜色。
  ///
  /// * `textStyle` - Theme.textTheme.labelLarge
  /// * `backgroundColor`
  ///   * disabled - Theme.colorScheme.onSurface(0.12)
  ///   * others - Theme.colorScheme.secondaryContainer
  /// * `foregroundColor`
  ///   * disabled - Theme.colorScheme.onSurface(0.38)
  ///   * others - Theme.colorScheme.onSecondaryContainer
  /// * `overlayColor`
  ///   * hovered - Theme.colorScheme.onSecondaryContainer(0.08)
  ///   * focused or pressed - Theme.colorScheme.onSecondaryContainer(0.12)
  /// * `shadowColor` - Theme.colorScheme.shadow
  /// * `surfaceTintColor` - null
  /// * `elevation`
  ///   * disabled - 0
  ///   * default - 0
  ///   * hovered - 1
  ///   * focused or pressed - 0
  /// * `padding`
  ///   * `default font size <= 14` - vertical(16)
  ///   * `14 < default font size <= 28` - lerp(vertical(16), vertical(8))
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
  /// * `visualDensity` - Theme.visualDensity
  /// * `tapTargetSize` - Theme.materialTapTargetSize
  /// * `animationDuration` - kThemeChangeDuration
  /// * `enableFeedback` - true
  /// * `alignment` - Alignment.center
  /// * `splashFactory` - Theme.splashFactory
  ///
  /// [MongolFilledButton.icon] 工厂的默认填充值略有不同：
  ///
  /// * `padding`
  ///   * `default font size <= 14` - start(12) end(16)
  ///   * `14 < default font size <= 28` - lerp(start(12) end(16), vertical(8))
  ///   * `28 < default font size <= 36` - lerp(vertical(8), vertical(4))
  ///   * `36 < default font size` - vertical(4)
  ///
  /// `side` 的默认值（定义按钮轮廓的外观）为 null。这意味着轮廓由按钮
  /// 形状的 [OutlinedBorder.side] 定义。通常，[OutlinedBorder]
  /// 的 side 的默认值是 [BorderSide.none]，因此不绘制轮廓。
  ///
  /// ## Material 3 默认值
  ///
  /// 如果 [ThemeData.useMaterial3] 设置为 true，则将使用以下默认值：
  ///
  /// * `textStyle` - Theme.textTheme.labelLarge
  /// * `backgroundColor`
  ///   * disabled - Theme.colorScheme.onSurface(0.12)
  ///   * others - Theme.colorScheme.secondaryContainer
  /// * `foregroundColor`
  ///   * disabled - Theme.colorScheme.onSurface(0.38)
  ///   * others - Theme.colorScheme.onSecondaryContainer
  /// * `overlayColor`
  ///   * hovered - Theme.colorScheme.onSecondaryContainer(0.08)
  ///   * focused or pressed - Theme.colorScheme.onSecondaryContainer(0.12)
  /// * `shadowColor` - Theme.colorScheme.shadow
  /// * `surfaceTintColor` - Colors.transparent
  /// * `elevation`
  ///   * disabled - 0
  ///   * default - 1
  ///   * hovered - 3
  ///   * focused or pressed - 1
  /// * `padding`
  ///   * `default font size <= 14` - vertical(24)
  ///   * `14 < default font size <= 28` - lerp(vertical(24), vertical(12))
  ///   * `28 < default font size <= 36` - lerp(vertical(12), vertical(6))
  ///   * `36 < default font size` - vertical(6)
  /// * `minimumSize` - Size(40, 64)
  /// * `fixedSize` - null
  /// * `maximumSize` - Size.infinite
  /// * `side` - null
  /// * `shape` - StadiumBorder()
  /// * `mouseCursor`
  ///   * disabled - SystemMouseCursors.basic
  ///   * others - SystemMouseCursors.click
  /// * `visualDensity` - Theme.visualDensity
  /// * `tapTargetSize` - Theme.materialTapTargetSize
  /// * `animationDuration` - kThemeChangeDuration
  /// * `enableFeedback` - true
  /// * `alignment` - Alignment.center
  /// * `splashFactory` - Theme.splashFactory
  ///
  /// 对于 [MongolFilledButton.icon] 工厂，[padding] 的开始（通常是顶部）值
  /// 从 24 减少到 16。
  @override
  ButtonStyle defaultStyleOf(BuildContext context) {
    switch (_variant) {
      case _MongolFilledButtonVariant.filled:
        return _MongolFilledButtonDefaultsM3(context);
      case _MongolFilledButtonVariant.tonal:
        return _MongolFilledTonalButtonDefaultsM3(context);
    }
  }

  /// Returns the [FilledButtonThemeData.style] of the closest
  /// [FilledButtonTheme] ancestor.
  @override
  ButtonStyle? themeStyleOf(BuildContext context) {
    return FilledButtonTheme.of(context).style;
  }
}

EdgeInsetsGeometry _scaledPadding(BuildContext context) {
  final ThemeData theme = Theme.of(context);
  final double defaultFontSize = theme.textTheme.labelLarge?.fontSize ?? 14.0;
  final double effectiveTextScale =
      MediaQuery.textScalerOf(context).scale(defaultFontSize) / 14.0;
  final double padding1x = theme.useMaterial3 ? 24.0 : 16.0;
  return ButtonStyleButton.scaledPadding(
    EdgeInsets.symmetric(vertical: padding1x),
    EdgeInsets.symmetric(vertical: padding1x / 2),
    EdgeInsets.symmetric(vertical: padding1x / 2 / 2),
    effectiveTextScale,
  );
}

@immutable
class _MongolFilledButtonDefaultColor extends WidgetStateProperty<Color?>
    with Diagnosticable {
  _MongolFilledButtonDefaultColor(this.color, this.disabled);

  final Color? color;
  final Color? disabled;

  @override
  Color? resolve(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return disabled;
    }
    return color;
  }
}

@immutable
class _MongolFilledButtonDefaultOverlay extends WidgetStateProperty<Color?>
    with Diagnosticable {
  _MongolFilledButtonDefaultOverlay(this.overlay);

  final Color overlay;

  @override
  Color? resolve(Set<WidgetState> states) {
    if (states.contains(WidgetState.pressed)) {
      return overlay.withValues(alpha: 0.12);
    }
    if (states.contains(WidgetState.hovered)) {
      return overlay.withValues(alpha: 0.08);
    }
    if (states.contains(WidgetState.focused)) {
      return overlay.withValues(alpha: 0.12);
    }
    return null;
  }
}

@immutable
class _MongolFilledButtonDefaultMouseCursor
    extends WidgetStateProperty<MouseCursor?> with Diagnosticable {
  _MongolFilledButtonDefaultMouseCursor(
      this.enabledCursor, this.disabledCursor);

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

class _MongolFilledButtonWithIcon extends MongolFilledButton {
  _MongolFilledButtonWithIcon({
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
            child: _MongolFilledButtonWithIconChild(icon: icon, label: label));

  _MongolFilledButtonWithIcon.tonal({
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
  }) : super.tonal(
            autofocus: autofocus ?? false,
            clipBehavior: clipBehavior ?? Clip.none,
            child: _MongolFilledButtonWithIconChild(icon: icon, label: label));

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

class _MongolFilledButtonWithIconChild extends StatelessWidget {
  const _MongolFilledButtonWithIconChild(
      {required this.label, required this.icon});

  final Widget label;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final TextScaler textScaler = MediaQuery.textScalerOf(context);
    // 使用 TextScaler.scale() 替代已弃用的 textScaleFactor
    final double scale = textScaler.scale(1.0);
    // Adjust the gap based on the text scale factor. Start at 8, and lerp
    // to 4 based on how large the text is.
    final double gap =
        scale <= 1 ? 8 : lerpDouble(8, 4, math.min(scale - 1, 1))!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[icon, SizedBox(height: gap), Flexible(child: label)],
    );
  }
}

// BEGIN GENERATED TOKEN PROPERTIES - FilledButton

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

class _MongolFilledButtonDefaultsM3 extends ButtonStyle {
  _MongolFilledButtonDefaultsM3(this.context)
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
        return _colors.primary;
      });

  @override
  WidgetStateProperty<Color?>? get foregroundColor =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return _colors.onSurface.withValues(alpha: 0.38);
        }
        return _colors.onPrimary;
      });

  @override
  WidgetStateProperty<Color?>? get overlayColor =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.pressed)) {
          return _colors.onPrimary.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return _colors.onPrimary.withValues(alpha: 0.08);
        }
        if (states.contains(WidgetState.focused)) {
          return _colors.onPrimary.withValues(alpha: 0.12);
        }
        return null;
      });

  @override
  WidgetStateProperty<Color>? get shadowColor =>
      WidgetStatePropertyAll<Color>(_colors.shadow);

  @override
  WidgetStateProperty<Color>? get surfaceTintColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent);

  @override
  WidgetStateProperty<double>? get elevation =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return 0.0;
        }
        if (states.contains(WidgetState.pressed)) {
          return 0.0;
        }
        if (states.contains(WidgetState.hovered)) {
          return 1.0;
        }
        if (states.contains(WidgetState.focused)) {
          return 0.0;
        }
        return 0.0;
      });

  @override
  WidgetStateProperty<EdgeInsetsGeometry>? get padding =>
      WidgetStatePropertyAll<EdgeInsetsGeometry>(_scaledPadding(context));

  @override
  WidgetStateProperty<Size>? get minimumSize =>
      const WidgetStatePropertyAll<Size>(Size(40.0, 64.0));

  // No default fixedSize

  @override
  WidgetStateProperty<Size>? get maximumSize =>
      const WidgetStatePropertyAll<Size>(Size.infinite);

  // No default side

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

// END GENERATED TOKEN PROPERTIES - FilledButton

// BEGIN GENERATED TOKEN PROPERTIES - FilledTonalButton

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

class _MongolFilledTonalButtonDefaultsM3 extends ButtonStyle {
  _MongolFilledTonalButtonDefaultsM3(this.context)
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
        return _colors.secondaryContainer;
      });

  @override
  WidgetStateProperty<Color?>? get foregroundColor =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return _colors.onSurface.withValues(alpha: 0.38);
        }
        return _colors.onSecondaryContainer;
      });

  @override
  WidgetStateProperty<Color?>? get overlayColor =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.pressed)) {
          return _colors.onSecondaryContainer.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return _colors.onSecondaryContainer.withValues(alpha: 0.08);
        }
        if (states.contains(WidgetState.focused)) {
          return _colors.onSecondaryContainer.withValues(alpha: 0.12);
        }
        return null;
      });

  @override
  WidgetStateProperty<Color>? get shadowColor =>
      WidgetStatePropertyAll<Color>(_colors.shadow);

  @override
  WidgetStateProperty<Color>? get surfaceTintColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent);

  @override
  WidgetStateProperty<double>? get elevation =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return 0.0;
        }
        if (states.contains(WidgetState.pressed)) {
          return 0.0;
        }
        if (states.contains(WidgetState.hovered)) {
          return 1.0;
        }
        if (states.contains(WidgetState.focused)) {
          return 0.0;
        }
        return 0.0;
      });

  @override
  WidgetStateProperty<EdgeInsetsGeometry>? get padding =>
      WidgetStatePropertyAll<EdgeInsetsGeometry>(_scaledPadding(context));

  @override
  WidgetStateProperty<Size>? get minimumSize =>
      const WidgetStatePropertyAll<Size>(Size(40.0, 64.0));

  // No default fixedSize

  @override
  WidgetStateProperty<Size>? get maximumSize =>
      const WidgetStatePropertyAll<Size>(Size.infinite);

  // No default side

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

// END GENERATED TOKEN PROPERTIES - FilledTonalButton
