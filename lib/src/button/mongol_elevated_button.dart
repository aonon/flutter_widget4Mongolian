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

import 'mongol_button_style_button.dart';

/// 垂直方向的 Material Design "提升按钮"。
///
/// 使用提升按钮为原本大部分是平面的
/// 布局添加维度，例如在长而繁忙的内容列表中，或在宽
/// 空间中。避免在已经提升的内容上使用提升按钮，
/// 例如对话框或卡片。
///
/// 提升按钮是一个显示在 [Material]
/// 小部件上的标签 [child]，当按钮被
/// 按下时，其 [Material.elevation] 会增加。标签的 [MongolText] 和 [Icon] 小部件以
/// [style] 的 [ButtonStyle.foregroundColor] 显示，按钮的填充
/// 背景是 [ButtonStyle.backgroundColor]。
///
/// 提升按钮的默认样式由
/// [defaultStyleOf] 定义。此提升按钮的样式可以
/// 通过其 [style] 参数覆盖。子树中所有提升
/// 按钮的样式可以通过
/// [ElevatedButtonTheme] 覆盖，应用中所有提升
/// 按钮的样式可以通过 [Theme] 的
/// [ThemeData.elevatedButtonTheme] 属性覆盖。
///
/// 静态 [styleFrom] 方法是创建提升按钮
/// [ButtonStyle] 的便捷方法，可从简单值创建。
///
/// 如果 [onPressed] 和 [onLongPress] 回调为 null，则按钮将被禁用。
///
/// {@tool dartpad --template=stateful_widget_scaffold}
///
/// This sample produces an enabled and a disabled MongolElevatedButton.
///
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   final ButtonStyle style =
///     MongolElevatedButton.styleFrom(textStyle: const TextStyle(fontSize: 20));
///
///   return Center(
///     child: Column(
///       mainAxisSize: MainAxisSize.min,
///       children: <Widget>[
///         MongolElevatedButton(
///            style: style,
///            onPressed: null,
///            child: const Text('Disabled'),
///         ),
///         const SizedBox(height: 30),
///         MongolElevatedButton(
///           style: style,
///           onPressed: () {},
///           child: const Text('Enabled'),
///         ),
///       ],
///     ),
///   );
/// }
///
/// ```
/// {@end-tool}
///
/// See also:
///
///  * [MongolFilledButton], a vertical filled button that doesn't elevate when pressed.
///  * [MongolFilledButton.tonal], a vertical filled button variant that uses a secondary fill color.
///  * [MongolTextButton], a simple flat button without a shadow.
///  * [MongolOutlinedButton], a [MongolTextButton] with a border outline.
///  * <https://material.io/design/components/buttons.html>
///  * <https://m3.material.io/components/buttons>
class MongolElevatedButton extends MongolButtonStyleButton {
  /// 创建一个 MongolElevatedButton。
  ///
  /// [autofocus] 和 [clipBehavior] 参数不能为空。
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

  /// 从一对作为按钮的 [icon] 和 [label] 的小部件创建提升按钮。
  ///
  /// 图标和标签排列成一列，开头有 12 个逻辑像素的填充，
  /// 末尾有 16 个逻辑像素的填充，中间有 8 个像素的间隙。
  ///
  /// [icon] 和 [label] 参数不能为空。
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

  /// 一个静态便捷方法，根据简单值构造提升按钮的 [ButtonStyle]。
  ///
  /// [foregroundColor] 和 [disabledForegroundColor] 颜色用于
  /// 创建 [MaterialStateProperty] [ButtonStyle.foregroundColor]，以及
  /// 派生的 [ButtonStyle.overlayColor]。
  ///
  /// [backgroundColor] 和 [disabledBackgroundColor] 颜色用于
  /// 创建 [MaterialStateProperty] [ButtonStyle.backgroundColor]。
  ///
  /// 按钮的海拔高度是相对于 [elevation]
  /// 参数定义的。禁用的海拔高度与参数值相同，
  /// 当按钮被悬停或聚焦时使用 [elevation] + 2，当按钮被按下时使用 elevation + 6。
  ///
  /// 同样，[enabledMouseCursor] 和 [disabledMouseCursor]
  /// 参数用于构造 [ButtonStyle].mouseCursor。
  ///
  /// 所有其他参数要么直接使用，要么用于
  /// 为所有状态创建具有单一值的 [WidgetStateProperty]。
  ///
  /// 所有参数默认为 null，默认情况下此方法返回
  /// 一个不覆盖任何内容的 [ButtonStyle]。
  ///
  /// 例如，要覆盖 [MongolElevatedButton] 的默认文本和图标颜色，
  /// 以及其覆盖颜色，并为按下、聚焦和
  /// 悬停状态提供所有标准不透明度调整，可以这样写：
  ///
  /// ```dart
  /// MongolElevatedButton(
  ///   style: MongolElevatedButton.styleFrom(foregroundColor: Colors.green),
  ///   onPressed: () {
  ///     // ...
  ///   },
  ///   child: const Text('Jump'),
  /// ),
  /// ```
  ///
  /// 要更改填充颜色：
  ///
  /// ```dart
  /// MongolElevatedButton(
  ///   style: MongolElevatedButton.styleFrom(backgroundColor: Colors.green),
  ///   onPressed: () {
  ///     // ...
  ///   },
  ///   child: const Text('Meow'),
  /// ),
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
    final Color? background = backgroundColor;
    final Color? disabledBackground = disabledBackgroundColor;
    final WidgetStateProperty<Color?>? backgroundColorProp =
        (background == null && disabledBackground == null)
            ? null
            : _ElevatedButtonDefaultColor(background, disabledBackground);
    final Color? foreground = foregroundColor;
    final Color? disabledForeground = disabledForegroundColor;
    final WidgetStateProperty<Color?>? foregroundColorProp =
        (foreground == null && disabledForeground == null)
            ? null
            : _ElevatedButtonDefaultColor(foreground, disabledForeground);
    final WidgetStateProperty<Color?>? overlayColor =
        (foreground == null) ? null : _ElevatedButtonDefaultOverlay(foreground);
    final WidgetStateProperty<double>? elevationValue =
        (elevation == null) ? null : _ElevatedButtonDefaultElevation(elevation);
    final WidgetStateProperty<MouseCursor?> mouseCursor =
        _ElevatedButtonDefaultMouseCursor(
            enabledMouseCursor, disabledMouseCursor);

    return ButtonStyle(
      textStyle: WidgetStateProperty.all<TextStyle?>(textStyle),
      backgroundColor: backgroundColorProp,
      foregroundColor: foregroundColorProp,
      overlayColor: overlayColor,
      shadowColor: ButtonStyleButton.allOrNull<Color>(shadowColor),
      surfaceTintColor: ButtonStyleButton.allOrNull<Color>(surfaceTintColor),
      elevation: elevationValue,
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
  /// 按钮 [child] 的 [MongolText] 和 [Icon] 小部件以
  /// [ButtonStyle] 的前景色渲染。按钮的 [InkWell] 在按钮被聚焦、悬停
  /// 或按下时添加样式的覆盖颜色。按钮的背景颜色成为其 [Material]
  /// 颜色。
  ///
  /// 以下是 ButtonStyle 的所有默认值。在此列表中
  /// "Theme.foo" 是 `Theme.of(context).foo` 的简写。颜色
  /// 方案值如 "onSurface(0.38)" 是 `onSurface.withOpacity(0.38)` 的简写。
  /// [WidgetStateProperty] 类型的属性如果后面没有子列表，则所有状态都具有相同
  /// 的值，否则值按每个状态指定，"others" 表示所有其他状态。
  ///
  /// 下面的 "默认字体大小" 指的是 [defaultStyleOf] 方法中指定的字体大小
  ///（或未指定时为 14.0），由 `MediaQuery.textScalerOf(context).scale` 方法缩放。
  /// EdgeInsets 构造函数和 `EdgeInsetsGeometry.lerp` 的名称已缩写以提高可读性。
  ///
  /// [ButtonStyle.textStyle] 的颜色不使用，而是使用
  /// [ButtonStyle.foregroundColor] 颜色。
  ///
  /// ## Material 2 默认值
  ///
  /// * `textStyle` - Theme.textTheme.button
  /// * `backgroundColor`
  ///   * disabled - Theme.colorScheme.onSurface(0.12)
  ///   * others - Theme.colorScheme.primary
  /// * `foregroundColor`
  ///   * disabled - Theme.colorScheme.onSurface(0.38)
  ///   * others - Theme.colorScheme.onPrimary
  /// * `overlayColor`
  ///   * hovered - Theme.colorScheme.onPrimary(0.08)
  ///   * focused or pressed - Theme.colorScheme.onPrimary(0.24)
  /// * `shadowColor` - Theme.shadowColor
  /// * `elevation`
  ///   * disabled - 0
  ///   * default - 2
  ///   * hovered or focused - 4
  ///   * pressed - 8
  /// * `padding`
  ///   * `default font size <= 14` - vertical(16)
  ///   * `14 < default font size <= 28` - lerp(vertical(16), vertical(8))
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
  /// [MongolElevatedButton.icon] 工厂的默认填充值略有不同：
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
  ///   * others - Theme.colorScheme.surface
  /// * `foregroundColor`
  ///   * disabled - Theme.colorScheme.onSurface(0.38)
  ///   * others - Theme.colorScheme.primary
  /// * `overlayColor`
  ///   * hovered - Theme.colorScheme.primary(0.08)
  ///   * focused or pressed - Theme.colorScheme.primary(0.12)
  /// * `shadowColor` - Theme.colorScheme.shadow
  /// * `surfaceTintColor` - Theme.colorScheme.surfaceTint
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
  /// 对于 [MongolElevatedButton.icon] 工厂，[padding] 的开始（通常是顶部）值
  /// 从 24 减少到 16。
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

  /// 返回最近的 [ElevatedButtonTheme] 祖先的 [ElevatedButtonThemeData.style]。
  @override
  ButtonStyle? themeStyleOf(BuildContext context) {
    return ElevatedButtonTheme.of(context).style;
  }
}

EdgeInsetsGeometry _scaledPadding(BuildContext context) {
  final ThemeData theme = Theme.of(context);
  final double padding1x = theme.useMaterial3 ? 24.0 : 16.0;
  final double defaultFontSize = theme.textTheme.labelLarge?.fontSize ?? 14.0;
  final double effectiveTextScale =
      MediaQuery.textScalerOf(context).scale(defaultFontSize) / 14.0;

  return ButtonStyleButton.scaledPadding(
    EdgeInsets.symmetric(vertical: padding1x),
    EdgeInsets.symmetric(vertical: padding1x / 2),
    EdgeInsets.symmetric(vertical: padding1x / 2 / 2),
    effectiveTextScale,
  );
}

@immutable
class _ElevatedButtonDefaultColor extends WidgetStateProperty<Color?>
    with Diagnosticable {
  _ElevatedButtonDefaultColor(this.color, this.disabled);

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
class _ElevatedButtonDefaultOverlay extends WidgetStateProperty<Color?>
    with Diagnosticable {
  _ElevatedButtonDefaultOverlay(this.overlay);

  final Color overlay;

  @override
  Color? resolve(Set<WidgetState> states) {
    if (states.contains(WidgetState.pressed)) {
      return overlay.withValues(alpha: 0.24);
    }
    if (states.contains(WidgetState.hovered)) {
      return overlay.withValues(alpha: 0.08);
    }
    if (states.contains(WidgetState.focused)) {
      return overlay.withValues(alpha: 0.24);
    }
    return null;
  }
}

@immutable
class _ElevatedButtonDefaultElevation extends WidgetStateProperty<double>
    with Diagnosticable {
  _ElevatedButtonDefaultElevation(this.elevation);

  final double elevation;

  @override
  double resolve(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return 0;
    }
    if (states.contains(WidgetState.pressed)) {
      return elevation + 6;
    }
    if (states.contains(WidgetState.hovered)) {
      return elevation + 2;
    }
    if (states.contains(WidgetState.focused)) {
      return elevation + 2;
    }
    return elevation;
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
    // 使用 TextScaler.scale() 替代已弃用的 textScaleFactor
    final double scale = textScaler.scale(1.0);
    final double gap = 
        scale <= 1 ? 8 : lerpDouble(8, 4, math.min(scale - 1, 1))!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[icon, SizedBox(height: gap), Flexible(child: label)],
    );
  }
}

// BEGIN GENERATED TOKEN PROPERTIES - ElevatedButton

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

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

// END GENERATED TOKEN PROPERTIES - ElevatedButton
