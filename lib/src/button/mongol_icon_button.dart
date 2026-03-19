// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show
        Brightness,
        ButtonStyle,
        ButtonStyleButton,
        ColorScheme,
        Colors,
        IconButton,
        IconButtonTheme,
        InkResponse,
        InteractiveInkFeatureFactory,
        Material,
        WidgetState,
        WidgetStateProperty,
        WidgetStatePropertyAll,
        WidgetStatesController,
        MaterialTapTargetSize,
        Theme,
        ThemeData,
        VisualDensity,
        debugCheckHasMaterial,
        kDefaultIconDarkColor,
        kDefaultIconLightColor,
        kMinInteractiveDimension,
        kThemeChangeDuration;
import 'package:flutter/widgets.dart';

import '../menu/mongol_tooltip.dart';

// 图标按钮的最小逻辑像素大小。
// 参考：<https://material.io/design/usability/accessibility.html#layout-typography>。
const double _kMinButtonSize = kMinInteractiveDimension;

/// 图标按钮的变体类型枚举
/// 
/// - standard: 标准图标按钮
/// - filled: 填充式图标按钮
/// - filledTonal: 填充色调图标按钮
/// - outlined: 轮廓式图标按钮
enum _IconButtonVariant { standard, filled, filledTonal, outlined }

/// 使用MongolTooltip的图标按钮
///
/// 除了使用MongolTooltip作为提示外，此组件的其他行为与标准IconButton完全相同。
/// 这是为了支持蒙古文垂直文本布局的提示显示。
class MongolIconButton extends IconButton {
  /// 创建一个标准的Mongol图标按钮
  ///
  /// [icon]：显示的图标
  /// [onPressed]：点击按钮时的回调函数
  /// [tooltip]：鼠标悬停时显示的提示文本（使用MongolTooltip支持垂直文本）
  const MongolIconButton({
    super.key,
    super.iconSize, // 图标大小
    super.visualDensity, // 视觉密度
    super.padding, // 内边距
    super.alignment, // 对齐方式
    super.splashRadius, // 点击时水波纹效果的半径
    super.color, // 图标颜色
    super.focusColor, // 获得焦点时的颜色
    super.hoverColor, // 鼠标悬停时的颜色
    super.highlightColor, // 高亮时的颜色
    super.splashColor, // 水波纹颜色
    super.disabledColor, // 禁用时的颜色
    required super.onPressed, // 点击回调
    super.mouseCursor, // 鼠标光标
    super.focusNode, // 焦点节点
    super.autofocus = false, // 是否自动获得焦点
    super.tooltip, // 提示文本
    super.enableFeedback, // 是否启用反馈
    super.constraints, // 约束条件
    super.style, // 按钮样式
    super.isSelected, // 是否被选中
    super.selectedIcon, // 选中状态下的图标
    required super.icon, // 图标
  }) : _variant = _IconButtonVariant.standard;

  /// 创建一个填充式的Mongol图标按钮
  ///
  /// 填充式图标按钮具有更高的视觉冲击力，适用于高强调的操作，
  /// 例如关闭麦克风或相机等重要操作。
  const MongolIconButton.filled({
    super.key,
    super.iconSize,
    super.visualDensity,
    super.padding,
    super.alignment,
    super.splashRadius,
    super.color,
    super.focusColor,
    super.hoverColor,
    super.highlightColor,
    super.splashColor,
    super.disabledColor,
    required super.onPressed,
    super.mouseCursor,
    super.focusNode,
    super.autofocus = false,
    super.tooltip,
    super.enableFeedback,
    super.constraints,
    super.style,
    super.isSelected,
    super.selectedIcon,
    required super.icon,
  }) : _variant = _IconButtonVariant.filled;

  /// 创建一个填充色调的Mongol图标按钮
  ///
  /// 填充色调图标按钮是填充式和轮廓式图标按钮之间的中间地带。
  /// 它们适用于按钮需要比轮廓式更多强调的场景，例如与高强调操作配对的次要操作。
  const MongolIconButton.filledTonal({
    super.key,
    super.iconSize,
    super.visualDensity,
    super.padding,
    super.alignment,
    super.splashRadius,
    super.color,
    super.focusColor,
    super.hoverColor,
    super.highlightColor,
    super.splashColor,
    super.disabledColor,
    required super.onPressed,
    super.mouseCursor,
    super.focusNode,
    super.autofocus = false,
    super.tooltip,
    super.enableFeedback,
    super.constraints,
    super.style,
    super.isSelected,
    super.selectedIcon,
    required super.icon,
  }) : _variant = _IconButtonVariant.filledTonal;

  /// 创建一个轮廓式的Mongol图标按钮
  ///
  /// 轮廓式图标按钮是中等强调的按钮。当图标按钮需要比标准图标按钮更多的强调，
  /// 但又少于填充式或填充色调图标按钮时，它们非常有用。
  const MongolIconButton.outlined({
    super.key,
    super.iconSize,
    super.visualDensity,
    super.padding,
    super.alignment,
    super.splashRadius,
    super.color,
    super.focusColor,
    super.hoverColor,
    super.highlightColor,
    super.splashColor,
    super.disabledColor,
    required super.onPressed,
    super.mouseCursor,
    super.focusNode,
    super.autofocus = false,
    super.tooltip,
    super.enableFeedback,
    super.constraints,
    super.style,
    super.isSelected,
    super.selectedIcon,
    required super.icon,
  }) : _variant = _IconButtonVariant.outlined;

  final _IconButtonVariant _variant;

  /// 静态便捷方法，用于根据简单的值构造图标按钮的[ButtonStyle]。
  /// 此方法仅用于Material 3。
  ///
  /// [foregroundColor]用于创建[ButtonStyle.foregroundColor]的值，指定按钮图标的颜色。
  /// [hoverColor]、[focusColor]和[highlightColor]用于指示悬停、焦点和按下状态。
  /// [backgroundColor]用于按钮的背景填充颜色。
  /// [disabledForegroundColor]和[disabledBackgroundColor]用于指定按钮禁用时的图标和填充颜色。
  ///
  /// 类似地，[enabledMouseCursor]和[disabledMouseCursor]参数用于构造[ButtonStyle].mouseCursor。
  ///
  /// 所有其他参数要么直接使用，要么用于为所有状态创建具有单个值的[WidgetStateProperty]。
  ///
  /// 所有参数默认为null，默认情况下此方法返回一个不覆盖任何内容的[ButtonStyle]。
  ///
  /// 例如，要覆盖[IconButton]的默认图标颜色及其覆盖颜色，以及按下、焦点和悬停状态的标准不透明度调整，
  /// 可以编写：
  ///
  /// ```dart
  /// IconButton(
  ///   icon: const Icon(Icons.pets),
  ///   style: IconButton.styleFrom(foregroundColor: Colors.green),
  ///   onPressed: () {
  ///     // ...
  ///   },
  /// ),
  /// ```
  static ButtonStyle styleFrom({
    Color? foregroundColor,
    Color? backgroundColor,
    Color? disabledForegroundColor,
    Color? disabledBackgroundColor,
    Color? focusColor,
    Color? hoverColor,
    Color? highlightColor,
    Color? shadowColor,
    Color? surfaceTintColor,
    double? elevation,
    Size? minimumSize,
    Size? fixedSize,
    Size? maximumSize,
    double? iconSize,
    BorderSide? side,
    OutlinedBorder? shape,
    EdgeInsetsGeometry? padding,
    MouseCursor? enabledMouseCursor,
    MouseCursor? disabledMouseCursor,
    VisualDensity? visualDensity,
    MaterialTapTargetSize? tapTargetSize,
    Duration? animationDuration,
    bool? enableFeedback,
    AlignmentGeometry? alignment,
    InteractiveInkFeatureFactory? splashFactory,
  }) {
    final WidgetStateProperty<Color?>? buttonBackgroundColor =
        (backgroundColor == null && disabledBackgroundColor == null)
            ? null
            : _IconButtonDefaultBackground(
                backgroundColor, disabledBackgroundColor);
    final WidgetStateProperty<Color?>? buttonForegroundColor =
        (foregroundColor == null && disabledForegroundColor == null)
            ? null
            : _IconButtonDefaultForeground(
                foregroundColor, disabledForegroundColor);
    final WidgetStateProperty<Color?>? overlayColor =
        (foregroundColor == null &&
                hoverColor == null &&
                focusColor == null &&
                highlightColor == null)
            ? null
            : _IconButtonDefaultOverlay(
                foregroundColor, focusColor, hoverColor, highlightColor);
    final WidgetStateProperty<MouseCursor?> mouseCursor =
        _IconButtonDefaultMouseCursor(enabledMouseCursor, disabledMouseCursor);

    return ButtonStyle(
      backgroundColor: buttonBackgroundColor,
      foregroundColor: buttonForegroundColor,
      overlayColor: overlayColor,
      shadowColor: ButtonStyleButton.allOrNull<Color>(shadowColor),
      surfaceTintColor: ButtonStyleButton.allOrNull<Color>(surfaceTintColor),
      elevation: ButtonStyleButton.allOrNull<double>(elevation),
      padding: ButtonStyleButton.allOrNull<EdgeInsetsGeometry>(padding),
      minimumSize: ButtonStyleButton.allOrNull<Size>(minimumSize),
      fixedSize: ButtonStyleButton.allOrNull<Size>(fixedSize),
      maximumSize: ButtonStyleButton.allOrNull<Size>(maximumSize),
      iconSize: ButtonStyleButton.allOrNull<double>(iconSize),
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

  /// 构建Mongol图标按钮的UI
  ///
  /// 根据当前主题和配置，构建适当的图标按钮UI，
  /// 包括处理Material 3和Material 2的不同实现。
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (theme.useMaterial3) {
      // 处理约束条件
      final Size? minSize = constraints == null
          ? null
          : Size(constraints!.minWidth, constraints!.minHeight);
      final Size? maxSize = constraints == null
          ? null
          : Size(constraints!.maxWidth, constraints!.maxHeight);

      // 构建调整后的样式
      ButtonStyle adjustedStyle = styleFrom(
        visualDensity: visualDensity,
        foregroundColor: color,
        disabledForegroundColor: disabledColor,
        focusColor: focusColor,
        hoverColor: hoverColor,
        highlightColor: highlightColor,
        padding: padding,
        minimumSize: minSize,
        maximumSize: maxSize,
        iconSize: iconSize,
        alignment: alignment,
        enabledMouseCursor: mouseCursor,
        disabledMouseCursor: mouseCursor,
        enableFeedback: enableFeedback,
      );
      // 如果提供了自定义样式，则合并
      if (style != null) {
        adjustedStyle = style!.merge(adjustedStyle);
      }

      // 确定要显示的图标（选中状态或默认状态）
      Widget effectiveIcon = icon;
      if ((isSelected ?? false) && selectedIcon != null) {
        effectiveIcon = selectedIcon!;
      }

      // 如果有提示文本，使用MongolTooltip包装
      Widget iconButton = effectiveIcon;
      if (tooltip != null) {
        iconButton = MongolTooltip(
          message: tooltip!,
          child: effectiveIcon,
        );
      }

      // 返回可选择的图标按钮
      return _SelectableIconButton(
        style: adjustedStyle,
        onPressed: onPressed,
        autofocus: autofocus,
        focusNode: focusNode,
        isSelected: isSelected,
        variant: _variant,
        child: iconButton,
      );
    }

    assert(debugCheckHasMaterial(context));

    // 确定当前图标颜色
    Color? currentColor;
    if (onPressed != null) {
      currentColor = color;
    } else {
      currentColor = disabledColor ?? theme.disabledColor;
    }

    // 确定有效的视觉密度
    final VisualDensity effectiveVisualDensity =
        visualDensity ?? theme.visualDensity;

    // 确定约束条件
    final BoxConstraints unadjustedConstraints = constraints ??
        const BoxConstraints(
          minWidth: _kMinButtonSize,
          minHeight: _kMinButtonSize,
        );
    final BoxConstraints adjustedConstraints =
        effectiveVisualDensity.effectiveConstraints(unadjustedConstraints);
    
    // 确定图标大小
    final double effectiveIconSize =
        iconSize ?? IconTheme.of(context).size ?? 24.0;
    
    // 确定内边距
    final EdgeInsetsGeometry effectivePadding =
        padding ?? const EdgeInsets.all(8.0);
    
    // 确定对齐方式
    final AlignmentGeometry effectiveAlignment = alignment ?? Alignment.center;
    
    // 确定是否启用反馈
    final bool effectiveEnableFeedback = enableFeedback ?? true;

    // 构建图标按钮的基本结构
    Widget result = ConstrainedBox(
      constraints: adjustedConstraints,
      child: Padding(
        padding: effectivePadding,
        child: SizedBox(
          height: effectiveIconSize,
          width: effectiveIconSize,
          child: Align(
            alignment: effectiveAlignment,
            child: IconTheme.merge(
              data: IconThemeData(
                size: effectiveIconSize,
                color: currentColor,
              ),
              child: icon,
            ),
          ),
        ),
      ),
    );

    // 如果有提示文本，使用MongolTooltip包装
    if (tooltip != null) {
      result = MongolTooltip(
        message: tooltip!,
        child: result,
      );
    }

    // 返回带有语义和墨水响应的按钮
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: InkResponse(
        focusNode: focusNode,
        autofocus: autofocus,
        canRequestFocus: onPressed != null,
        onTap: onPressed,
        mouseCursor: mouseCursor ??
            (onPressed == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click),
        enableFeedback: effectiveEnableFeedback,
        focusColor: focusColor ?? theme.focusColor,
        hoverColor: hoverColor ?? theme.hoverColor,
        highlightColor: highlightColor ?? theme.highlightColor,
        splashColor: splashColor ?? theme.splashColor,
        radius: splashRadius ??
            math.max(
              Material.defaultSplashRadius,
              (effectiveIconSize +
                      math.min(effectivePadding.horizontal,
                          effectivePadding.vertical)) *
                  0.7,
              // x 0.5 for diameter -> radius and + 40% overflow derived from other Material apps.
            ),
        child: result,
      ),
    );
  }
}

/// 可选择的图标按钮组件
///
/// 用于处理图标按钮的选择状态，支持Material 3的设计规范。
class _SelectableIconButton extends StatefulWidget {
  /// 创建一个可选择的图标按钮
  ///
  /// [isSelected]：是否被选中
  /// [style]：按钮样式
  /// [focusNode]：焦点节点
  /// [variant]：图标按钮变体
  /// [autofocus]：是否自动获得焦点
  /// [onPressed]：点击回调
  /// [child]：子组件
  const _SelectableIconButton({
    this.isSelected,
    this.style,
    this.focusNode,
    required this.variant,
    required this.autofocus,
    required this.onPressed,
    required this.child,
  });

  final bool? isSelected; // 是否被选中
  final ButtonStyle? style; // 按钮样式
  final FocusNode? focusNode; // 焦点节点
  final _IconButtonVariant variant; // 图标按钮变体
  final bool autofocus; // 是否自动获得焦点
  final VoidCallback? onPressed; // 点击回调
  final Widget child; // 子组件

  @override
  State<_SelectableIconButton> createState() => _SelectableIconButtonState();
}

/// 可选择图标按钮的状态类
///
/// 管理图标按钮的选择状态和状态控制器。
class _SelectableIconButtonState extends State<_SelectableIconButton> {
  late final WidgetStatesController statesController; // 状态控制器

  /// 初始化状态
  @override
  void initState() {
    super.initState();
    // 根据初始的isSelected值创建状态控制器
    if (widget.isSelected == null) {
      statesController = WidgetStatesController();
    } else {
      statesController = WidgetStatesController(
          <WidgetState>{if (widget.isSelected!) WidgetState.selected});
    }
  }

  /// 更新组件时的处理
  @override
  void didUpdateWidget(_SelectableIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果isSelected变为null，移除selected状态
    if (widget.isSelected == null) {
      if (statesController.value.contains(WidgetState.selected)) {
        statesController.update(WidgetState.selected, false);
      }
      return;
    }
    // 如果isSelected值发生变化，更新状态
    if (widget.isSelected != oldWidget.isSelected) {
      statesController.update(WidgetState.selected, widget.isSelected!);
    }
  }

  /// 构建UI
  @override
  Widget build(BuildContext context) {
    final bool toggleable = widget.isSelected != null; // 是否可切换

    return _IconButtonM3(
      statesController: statesController,
      style: widget.style,
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      onPressed: widget.onPressed,
      variant: widget.variant,
      toggleable: toggleable,
      child: Semantics(
        selected: widget.isSelected,
        child: widget.child,
      ),
    );
  }

  /// 销毁组件时的处理
  @override
  void dispose() {
    statesController.dispose(); // 销毁状态控制器
    super.dispose();
  }
}

/// Material 3风格的图标按钮
///
/// 实现Material 3设计规范的图标按钮，支持不同变体和状态。
class _IconButtonM3 extends ButtonStyleButton {
  /// 创建一个Material 3风格的图标按钮
  ///
  /// [onPressed]：点击回调
  /// [style]：按钮样式
  /// [focusNode]：焦点节点
  /// [autofocus]：是否自动获得焦点
  /// [statesController]：状态控制器
  /// [variant]：图标按钮变体
  /// [toggleable]：是否可切换
  /// [child]：子组件
  const _IconButtonM3({
    required super.onPressed,
    super.style,
    super.focusNode,
    super.autofocus = false,
    super.statesController,
    required this.variant,
    required this.toggleable,
    required Widget super.child,
  }) : super(
            onLongPress: null,
            onHover: null,
            onFocusChange: null,
            clipBehavior: Clip.none);

  final _IconButtonVariant variant; // 图标按钮变体
  final bool toggleable; // 是否可切换

  /// ## Material 3 默认值
  ///
  /// 如果[ThemeData.useMaterial3]设置为true，将使用以下默认值：
  ///
  /// * `textStyle` - null
  /// * `backgroundColor` - transparent
  /// * `foregroundColor`
  ///   * disabled - Theme.colorScheme.onSurface(0.38)
  ///   * selected - Theme.colorScheme.primary
  ///   * others - Theme.colorScheme.onSurfaceVariant
  /// * `overlayColor`
  ///   * selected
  ///      * hovered - Theme.colorScheme.primary(0.08)
  ///      * focused or pressed - Theme.colorScheme.primary(0.12)
  ///   * hovered or focused - Theme.colorScheme.onSurfaceVariant(0.08)
  ///   * pressed - Theme.colorScheme.onSurfaceVariant(0.12)
  ///   * others - null
  /// * `shadowColor` - null
  /// * `surfaceTintColor` - null
  /// * `elevation` - 0
  /// * `padding` - all(8)
  /// * `minimumSize` - Size(40, 40)
  /// * `fixedSize` - null
  /// * `maximumSize` - Size.infinite
  /// * `iconSize` - 24
  /// * `side` - null
  /// * `shape` - StadiumBorder()
  /// * `mouseCursor`
  ///   * disabled - SystemMouseCursors.basic
  ///   * others - SystemMouseCursors.click
  /// * `visualDensity` - VisualDensity.standard
  /// * `tapTargetSize` - theme.materialTapTargetSize
  /// * `animationDuration` - kThemeChangeDuration
  /// * `enableFeedback` - true
  /// * `alignment` - Alignment.center
  /// * `splashFactory` - Theme.splashFactory
  @override
  ButtonStyle defaultStyleOf(BuildContext context) {
    // 根据不同的变体返回对应的默认样式
    switch (variant) {
      case _IconButtonVariant.filled:
        return _FilledIconButtonDefaultsM3(context, toggleable);
      case _IconButtonVariant.filledTonal:
        return _FilledTonalIconButtonDefaultsM3(context, toggleable);
      case _IconButtonVariant.outlined:
        return _OutlinedIconButtonDefaultsM3(context, toggleable);
      case _IconButtonVariant.standard:
        return _IconButtonDefaultsM3(context, toggleable);
    }
  }

  /// 返回最近的[IconButtonTheme]祖先的[IconButtonThemeData.style]。
  /// 如果[IconButtonTheme]中相同属性的值为null，颜色和图标大小也可以通过[IconTheme]配置。
  /// 但是，如果[IconButtonTheme]和[IconTheme]中都存在任何属性，[IconTheme]将被覆盖。
  @override
  ButtonStyle? themeStyleOf(BuildContext context) {
    // 获取当前的图标主题
    final IconThemeData iconTheme = IconTheme.of(context);
    // 判断当前是否为深色主题
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // 检查图标主题颜色是否为默认颜色
    bool isIconThemeDefault(Color? color) {
      if (isDark) {
        return identical(color, kDefaultIconLightColor);
      }
      return identical(color, kDefaultIconDarkColor);
    }

    // 检查颜色和大小是否为默认值
    final bool isDefaultColor = isIconThemeDefault(iconTheme.color);
    final bool isDefaultSize =
        iconTheme.size == const IconThemeData.fallback().size;

    // 从图标主题创建样式
    final ButtonStyle iconThemeStyle = IconButton.styleFrom(
        foregroundColor: isDefaultColor ? null : iconTheme.color,
        iconSize: isDefaultSize ? null : iconTheme.size);

    // 合并图标按钮主题样式和图标主题样式
    return IconButtonTheme.of(context).style?.merge(iconThemeStyle) ??
        iconThemeStyle;
  }
}

/// 图标按钮的默认背景颜色属性
///
/// 根据按钮状态返回不同的背景颜色。
@immutable
class _IconButtonDefaultBackground extends WidgetStateProperty<Color?> {
  /// 创建一个图标按钮默认背景颜色属性
  ///
  /// [background]：正常状态下的背景颜色
  /// [disabledBackground]：禁用状态下的背景颜色
  _IconButtonDefaultBackground(this.background, this.disabledBackground);

  final Color? background; // 正常状态下的背景颜色
  final Color? disabledBackground; // 禁用状态下的背景颜色

  /// 根据状态解析颜色
  @override
  Color? resolve(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return disabledBackground;
    }
    return background;
  }

  /// 转换为字符串表示
  @override
  String toString() {
    return '{disabled: $disabledBackground, otherwise: $background}';
  }
}

/// 图标按钮的默认前景颜色属性
///
/// 根据按钮状态返回不同的前景颜色。
@immutable
class _IconButtonDefaultForeground extends WidgetStateProperty<Color?> {
  /// 创建一个图标按钮默认前景颜色属性
  ///
  /// [foregroundColor]：正常状态下的前景颜色
  /// [disabledForegroundColor]：禁用状态下的前景颜色
  _IconButtonDefaultForeground(
      this.foregroundColor, this.disabledForegroundColor);

  final Color? foregroundColor; // 正常状态下的前景颜色
  final Color? disabledForegroundColor; // 禁用状态下的前景颜色

  /// 根据状态解析颜色
  @override
  Color? resolve(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return disabledForegroundColor;
    }
    return foregroundColor;
  }

  /// 转换为字符串表示
  @override
  String toString() {
    return '{disabled: $disabledForegroundColor, otherwise: $foregroundColor}';
  }
}

/// 图标按钮的默认覆盖颜色属性
///
/// 根据按钮状态返回不同的覆盖颜色，用于悬停、焦点和按下状态。
@immutable
class _IconButtonDefaultOverlay extends WidgetStateProperty<Color?> {
  /// 创建一个图标按钮默认覆盖颜色属性
  ///
  /// [foregroundColor]：前景颜色
  /// [focusColor]：焦点状态下的颜色
  /// [hoverColor]：悬停状态下的颜色
  /// [highlightColor]：按下状态下的颜色
  _IconButtonDefaultOverlay(this.foregroundColor, this.focusColor,
      this.hoverColor, this.highlightColor);

  final Color? foregroundColor; // 前景颜色
  final Color? focusColor; // 焦点状态下的颜色
  final Color? hoverColor; // 悬停状态下的颜色
  final Color? highlightColor; // 按下状态下的颜色

  /// 根据状态解析颜色
  @override
  Color? resolve(Set<WidgetState> states) {
    if (states.contains(WidgetState.selected)) {
      if (states.contains(WidgetState.pressed)) {
        return highlightColor ?? foregroundColor?.withValues(alpha: 0.12);
      }
      if (states.contains(WidgetState.hovered)) {
        return hoverColor ?? foregroundColor?.withValues(alpha: 0.08);
      }
      if (states.contains(WidgetState.focused)) {
        return focusColor ?? foregroundColor?.withValues(alpha: 0.12);
      }
    }
    if (states.contains(WidgetState.pressed)) {
      return highlightColor ?? foregroundColor?.withValues(alpha: 0.12);
    }
    if (states.contains(WidgetState.hovered)) {
      return hoverColor ?? foregroundColor?.withValues(alpha: 0.08);
    }
    if (states.contains(WidgetState.focused)) {
      return focusColor ?? foregroundColor?.withValues(alpha: 0.08);
    }
    return null;
  }

  /// 转换为字符串表示
  @override
  String toString() {
    return '{hovered: $hoverColor, focused: $focusColor, pressed: $highlightColor, otherwise: null}';
  }
}

/// 图标按钮的默认鼠标光标属性
///
/// 根据按钮状态返回不同的鼠标光标。
@immutable
class _IconButtonDefaultMouseCursor extends WidgetStateProperty<MouseCursor?>
    with Diagnosticable {
  /// 创建一个图标按钮默认鼠标光标属性
  ///
  /// [enabledCursor]：启用状态下的鼠标光标
  /// [disabledCursor]：禁用状态下的鼠标光标
  _IconButtonDefaultMouseCursor(this.enabledCursor, this.disabledCursor);

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

// BEGIN GENERATED TOKEN PROPERTIES - IconButton

// 请勿手动编辑。"BEGIN GENERATED"和"END GENERATED"注释之间的代码是从Material
// Design token数据库通过脚本生成的：
//   dev/tools/gen_defaults/bin/gen_defaults.dart。

/// 标准图标按钮的Material 3默认样式
class _IconButtonDefaultsM3 extends ButtonStyle {
  /// 创建标准图标按钮的Material 3默认样式
  ///
  /// [context]：构建上下文
  /// [toggleable]：是否可切换
  _IconButtonDefaultsM3(this.context, this.toggleable)
      : super(
          animationDuration: kThemeChangeDuration,
          enableFeedback: true,
          alignment: Alignment.center,
        );

  final BuildContext context; // 构建上下文
  final bool toggleable; // 是否可切换
  late final ColorScheme _colors = Theme.of(context).colorScheme; // 颜色方案

  // 无默认文本样式

  @override
  WidgetStateProperty<Color?>? get backgroundColor =>
      const WidgetStatePropertyAll<Color?>(Colors.transparent); // 背景颜色

  @override
  WidgetStateProperty<Color?>? get foregroundColor =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return _colors.onSurface.withValues(alpha: 0.38);
        }
        if (states.contains(WidgetState.selected)) {
          return _colors.primary;
        }
        return _colors.onSurfaceVariant;
      }); // 前景颜色

  @override
  WidgetStateProperty<Color?>? get overlayColor =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          if (states.contains(WidgetState.pressed)) {
            return _colors.primary.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.hovered)) {
            return _colors.primary.withValues(alpha: 0.08);
          }
          if (states.contains(WidgetState.focused)) {
            return _colors.primary.withValues(alpha: 0.12);
          }
        }
        if (states.contains(WidgetState.pressed)) {
          return _colors.onSurfaceVariant.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return _colors.onSurfaceVariant.withValues(alpha: 0.08);
        }
        if (states.contains(WidgetState.focused)) {
          return _colors.onSurfaceVariant.withValues(alpha: 0.12);
        }
        return Colors.transparent;
      }); // 覆盖颜色

  @override
  WidgetStateProperty<double>? get elevation =>
      const WidgetStatePropertyAll<double>(0.0); // 海拔高度

  @override
  WidgetStateProperty<Color>? get shadowColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent); // 阴影颜色

  @override
  WidgetStateProperty<Color>? get surfaceTintColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent); // 表面色调

  @override
  WidgetStateProperty<EdgeInsetsGeometry>? get padding =>
      const WidgetStatePropertyAll<EdgeInsetsGeometry>(EdgeInsets.all(8.0)); // 内边距

  @override
  WidgetStateProperty<Size>? get minimumSize =>
      const WidgetStatePropertyAll<Size>(Size(40.0, 40.0)); // 最小大小

  // 无默认固定大小

  @override
  WidgetStateProperty<Size>? get maximumSize =>
      const WidgetStatePropertyAll<Size>(Size.infinite); // 最大大小

  @override
  WidgetStateProperty<double>? get iconSize =>
      const WidgetStatePropertyAll<double>(24.0); // 图标大小

  @override
  WidgetStateProperty<BorderSide?>? get side => null; // 边框

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
  VisualDensity? get visualDensity => VisualDensity.standard; // 视觉密度

  @override
  MaterialTapTargetSize? get tapTargetSize =>
      Theme.of(context).materialTapTargetSize; // 点击目标大小

  @override
  InteractiveInkFeatureFactory? get splashFactory =>
      Theme.of(context).splashFactory; // 水波纹效果工厂
}

// END GENERATED TOKEN PROPERTIES - IconButton

// BEGIN GENERATED TOKEN PROPERTIES - FilledIconButton

// 请勿手动编辑。"BEGIN GENERATED"和"END GENERATED"注释之间的代码是从Material
// Design token数据库通过脚本生成的：
//   dev/tools/gen_defaults/bin/gen_defaults.dart。

/// 填充式图标按钮的Material 3默认样式
class _FilledIconButtonDefaultsM3 extends ButtonStyle {
  /// 创建填充式图标按钮的Material 3默认样式
  ///
  /// [context]：构建上下文
  /// [toggleable]：是否可切换
  _FilledIconButtonDefaultsM3(this.context, this.toggleable)
      : super(
          animationDuration: kThemeChangeDuration,
          enableFeedback: true,
          alignment: Alignment.center,
        );

  final BuildContext context; // 构建上下文
  final bool toggleable; // 是否可切换
  late final ColorScheme _colors = Theme.of(context).colorScheme; // 颜色方案

  // 无默认文本样式

  @override
  WidgetStateProperty<Color?>? get backgroundColor =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return _colors.onSurface.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.selected)) {
          return _colors.primary;
        }
        if (toggleable) {
          // 可切换但未选中的情况
          return _colors.surfaceContainerHighest;
        }
        return _colors.primary;
      }); // 背景颜色

  @override
  WidgetStateProperty<Color?>? get foregroundColor =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return _colors.onSurface.withValues(alpha: 0.38);
        }
        if (states.contains(WidgetState.selected)) {
          return _colors.onPrimary;
        }
        if (toggleable) {
          // 可切换但未选中的情况
          return _colors.primary;
        }
        return _colors.onPrimary;
      }); // 前景颜色

  @override
  WidgetStateProperty<Color?>? get overlayColor =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          if (states.contains(WidgetState.pressed)) {
            return _colors.onPrimary.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.hovered)) {
            return _colors.onPrimary.withValues(alpha: 0.08);
          }
          if (states.contains(WidgetState.focused)) {
            return _colors.onPrimary.withValues(alpha: 0.12);
          }
        }
        if (toggleable) {
          // 可切换但未选中的情况
          if (states.contains(WidgetState.pressed)) {
            return _colors.primary.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.hovered)) {
            return _colors.primary.withValues(alpha: 0.08);
          }
          if (states.contains(WidgetState.focused)) {
            return _colors.primary.withValues(alpha: 0.12);
          }
        }
        if (states.contains(WidgetState.pressed)) {
          return _colors.onPrimary.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return _colors.onPrimary.withValues(alpha: 0.08);
        }
        if (states.contains(WidgetState.focused)) {
          return _colors.onPrimary.withValues(alpha: 0.12);
        }
        return Colors.transparent;
      }); // 覆盖颜色

  @override
  WidgetStateProperty<double>? get elevation =>
      const WidgetStatePropertyAll<double>(0.0); // 海拔高度

  @override
  WidgetStateProperty<Color>? get shadowColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent); // 阴影颜色

  @override
  WidgetStateProperty<Color>? get surfaceTintColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent); // 表面色调

  @override
  WidgetStateProperty<EdgeInsetsGeometry>? get padding =>
      const WidgetStatePropertyAll<EdgeInsetsGeometry>(EdgeInsets.all(8.0)); // 内边距

  @override
  WidgetStateProperty<Size>? get minimumSize =>
      const WidgetStatePropertyAll<Size>(Size(40.0, 40.0)); // 最小大小

  // 无默认固定大小

  @override
  WidgetStateProperty<Size>? get maximumSize =>
      const WidgetStatePropertyAll<Size>(Size.infinite); // 最大大小

  @override
  WidgetStateProperty<double>? get iconSize =>
      const WidgetStatePropertyAll<double>(24.0); // 图标大小

  @override
  WidgetStateProperty<BorderSide?>? get side => null; // 边框

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
  VisualDensity? get visualDensity => VisualDensity.standard; // 视觉密度

  @override
  MaterialTapTargetSize? get tapTargetSize =>
      Theme.of(context).materialTapTargetSize; // 点击目标大小

  @override
  InteractiveInkFeatureFactory? get splashFactory =>
      Theme.of(context).splashFactory; // 水波纹效果工厂
}

// END GENERATED TOKEN PROPERTIES - FilledIconButton

// BEGIN GENERATED TOKEN PROPERTIES - FilledTonalIconButton

// 请勿手动编辑。"BEGIN GENERATED"和"END GENERATED"注释之间的代码是从Material
// Design token数据库通过脚本生成的：
//   dev/tools/gen_defaults/bin/gen_defaults.dart。

/// 填充色调图标按钮的Material 3默认样式
class _FilledTonalIconButtonDefaultsM3 extends ButtonStyle {
  /// 创建填充色调图标按钮的Material 3默认样式
  ///
  /// [context]：构建上下文
  /// [toggleable]：是否可切换
  _FilledTonalIconButtonDefaultsM3(this.context, this.toggleable)
      : super(
          animationDuration: kThemeChangeDuration,
          enableFeedback: true,
          alignment: Alignment.center,
        );

  final BuildContext context; // 构建上下文
  final bool toggleable; // 是否可切换
  late final ColorScheme _colors = Theme.of(context).colorScheme; // 颜色方案

  // 无默认文本样式

  @override
  WidgetStateProperty<Color?>? get backgroundColor =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return _colors.onSurface.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.selected)) {
          return _colors.secondaryContainer;
        }
        if (toggleable) {
          // 可切换但未选中的情况
          return _colors.surfaceContainerHighest;
        }
        return _colors.secondaryContainer;
      }); // 背景颜色

  @override
  WidgetStateProperty<Color?>? get foregroundColor =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return _colors.onSurface.withValues(alpha: 0.38);
        }
        if (states.contains(WidgetState.selected)) {
          return _colors.onSecondaryContainer;
        }
        if (toggleable) {
          // 可切换但未选中的情况
          return _colors.onSurfaceVariant;
        }
        return _colors.onSecondaryContainer;
      }); // 前景颜色

  @override
  WidgetStateProperty<Color?>? get overlayColor =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          if (states.contains(WidgetState.pressed)) {
            return _colors.onSecondaryContainer.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.hovered)) {
            return _colors.onSecondaryContainer.withValues(alpha: 0.08);
          }
          if (states.contains(WidgetState.focused)) {
            return _colors.onSecondaryContainer.withValues(alpha: 0.12);
          }
        }
        if (toggleable) {
          // 可切换但未选中的情况
          if (states.contains(WidgetState.pressed)) {
            return _colors.onSurfaceVariant.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.hovered)) {
            return _colors.onSurfaceVariant.withValues(alpha: 0.08);
          }
          if (states.contains(WidgetState.focused)) {
            return _colors.onSurfaceVariant.withValues(alpha: 0.12);
          }
        }
        if (states.contains(WidgetState.pressed)) {
          return _colors.onSecondaryContainer.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return _colors.onSecondaryContainer.withValues(alpha: 0.08);
        }
        if (states.contains(WidgetState.focused)) {
          return _colors.onSecondaryContainer.withValues(alpha: 0.12);
        }
        return Colors.transparent;
      }); // 覆盖颜色

  @override
  WidgetStateProperty<double>? get elevation =>
      const WidgetStatePropertyAll<double>(0.0); // 海拔高度

  @override
  WidgetStateProperty<Color>? get shadowColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent); // 阴影颜色

  @override
  WidgetStateProperty<Color>? get surfaceTintColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent); // 表面色调

  @override
  WidgetStateProperty<EdgeInsetsGeometry>? get padding =>
      const WidgetStatePropertyAll<EdgeInsetsGeometry>(EdgeInsets.all(8.0)); // 内边距

  @override
  WidgetStateProperty<Size>? get minimumSize =>
      const WidgetStatePropertyAll<Size>(Size(40.0, 40.0)); // 最小大小

  // 无默认固定大小

  @override
  WidgetStateProperty<Size>? get maximumSize =>
      const WidgetStatePropertyAll<Size>(Size.infinite); // 最大大小

  @override
  WidgetStateProperty<double>? get iconSize =>
      const WidgetStatePropertyAll<double>(24.0); // 图标大小

  @override
  WidgetStateProperty<BorderSide?>? get side => null; // 边框

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
  VisualDensity? get visualDensity => VisualDensity.standard; // 视觉密度

  @override
  MaterialTapTargetSize? get tapTargetSize =>
      Theme.of(context).materialTapTargetSize; // 点击目标大小

  @override
  InteractiveInkFeatureFactory? get splashFactory =>
      Theme.of(context).splashFactory; // 水波纹效果工厂
}

// END GENERATED TOKEN PROPERTIES - FilledTonalIconButton

// BEGIN GENERATED TOKEN PROPERTIES - OutlinedIconButton

// 请勿手动编辑。"BEGIN GENERATED"和"END GENERATED"注释之间的代码是从Material
// Design token数据库通过脚本生成的：
//   dev/tools/gen_defaults/bin/gen_defaults.dart。

/// 轮廓式图标按钮的Material 3默认样式
class _OutlinedIconButtonDefaultsM3 extends ButtonStyle {
  /// 创建轮廓式图标按钮的Material 3默认样式
  ///
  /// [context]：构建上下文
  /// [toggleable]：是否可切换
  _OutlinedIconButtonDefaultsM3(this.context, this.toggleable)
      : super(
          animationDuration: kThemeChangeDuration,
          enableFeedback: true,
          alignment: Alignment.center,
        );

  final BuildContext context; // 构建上下文
  final bool toggleable; // 是否可切换
  late final ColorScheme _colors = Theme.of(context).colorScheme; // 颜色方案

  // 无默认文本样式

  @override
  WidgetStateProperty<Color?>? get backgroundColor =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          if (states.contains(WidgetState.selected)) {
            return _colors.onSurface.withValues(alpha: 0.12);
          }
          return Colors.transparent;
        }
        if (states.contains(WidgetState.selected)) {
          return _colors.inverseSurface;
        }
        return Colors.transparent;
      }); // 背景颜色

  @override
  WidgetStateProperty<Color?>? get foregroundColor =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return _colors.onSurface.withValues(alpha: 0.38);
        }
        if (states.contains(WidgetState.selected)) {
          return _colors.onInverseSurface;
        }
        return _colors.onSurfaceVariant;
      }); // 前景颜色

  @override
  WidgetStateProperty<Color?>? get overlayColor =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          if (states.contains(WidgetState.pressed)) {
            return _colors.onInverseSurface.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.hovered)) {
            return _colors.onInverseSurface.withValues(alpha: 0.08);
          }
          if (states.contains(WidgetState.focused)) {
            return _colors.onInverseSurface.withValues(alpha: 0.08);
          }
        }
        if (states.contains(WidgetState.pressed)) {
          return _colors.onSurface.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return _colors.onSurfaceVariant.withValues(alpha: 0.08);
        }
        if (states.contains(WidgetState.focused)) {
          return _colors.onSurfaceVariant.withValues(alpha: 0.08);
        }
        return Colors.transparent;
      }); // 覆盖颜色

  @override
  WidgetStateProperty<double>? get elevation =>
      const WidgetStatePropertyAll<double>(0.0); // 海拔高度

  @override
  WidgetStateProperty<Color>? get shadowColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent); // 阴影颜色

  @override
  WidgetStateProperty<Color>? get surfaceTintColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent); // 表面色调

  @override
  WidgetStateProperty<EdgeInsetsGeometry>? get padding =>
      const WidgetStatePropertyAll<EdgeInsetsGeometry>(EdgeInsets.all(8.0)); // 内边距

  @override
  WidgetStateProperty<Size>? get minimumSize =>
      const WidgetStatePropertyAll<Size>(Size(40.0, 40.0)); // 最小大小

  // 无默认固定大小

  @override
  WidgetStateProperty<Size>? get maximumSize =>
      const WidgetStatePropertyAll<Size>(Size.infinite); // 最大大小

  @override
  WidgetStateProperty<double>? get iconSize =>
      const WidgetStatePropertyAll<double>(24.0); // 图标大小

  @override
  WidgetStateProperty<BorderSide?>? get side =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          return null;
        } else {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(color: _colors.onSurface.withValues(alpha: 0.12));
          }
          return BorderSide(color: _colors.outline);
        }
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
  VisualDensity? get visualDensity => VisualDensity.standard; // 视觉密度

  @override
  MaterialTapTargetSize? get tapTargetSize =>
      Theme.of(context).materialTapTargetSize; // 点击目标大小

  @override
  InteractiveInkFeatureFactory? get splashFactory =>
      Theme.of(context).splashFactory; // 水波纹效果工厂
}

// END GENERATED TOKEN PROPERTIES - OutlinedIconButton
