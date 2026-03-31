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

import 'button_style_utils.dart';
import '../menu/mongol_tooltip.dart';

/// 图标按钮的最小点击区域尺寸（逻辑像素）。
const double _kMinButtonSize = kMinInteractiveDimension;

/// 图标按钮的变体类型。
enum _IconButtonVariant {
  /// 标准图标按钮。
  standard,

  /// 填充式图标按钮（Filled）。
  filled,

  /// 色调填充图标按钮（Filled Tonal）。
  filledTonal,

  /// 轮廓式图标按钮（Outlined）。
  outlined
}

/// 支持蒙古语垂直文本提示的图标按钮。
///
/// 该组件在行为上与标准 [IconButton] 一致，但使用了 [MongolTooltip] 来确保
/// 提示文本在垂直布局下正确显示。
class MongolIconButton extends IconButton {
  /// 创建一个标准的 [MongolIconButton]。
  const MongolIconButton({
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
  }) : _variant = _IconButtonVariant.standard;

  /// 创建一个填充式的 [MongolIconButton]。
  ///
  /// 适用于具有高视觉冲击力的操作。
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

  /// 创建一个填充色调的 [MongolIconButton]。
  ///
  /// 视觉强调程度介于填充式和轮廓式之间。
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

  /// 创建一个轮廓式的 [MongolIconButton]。
  ///
  /// 视觉强调程度适中。
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

  /// 根据简单值构造图标按钮 [ButtonStyle] 的静态便捷方法。
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
    final WidgetStateProperty<Color?>? backgroundColorProperty =
        (backgroundColor == null && disabledBackgroundColor == null)
            ? null
            : _IconButtonDefaultBackground(
                backgroundColor, disabledBackgroundColor);
    final WidgetStateProperty<Color?>? foregroundColorProperty =
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
      backgroundColor: backgroundColorProperty,
      foregroundColor: foregroundColorProperty,
      overlayColor: overlayColor,
      shadowColor: widgetStateAllOrNull<Color>(shadowColor),
      surfaceTintColor: widgetStateAllOrNull<Color>(surfaceTintColor),
      elevation: widgetStateAllOrNull<double>(elevation),
      padding: widgetStateAllOrNull<EdgeInsetsGeometry>(padding),
      minimumSize: widgetStateAllOrNull<Size>(minimumSize),
      fixedSize: widgetStateAllOrNull<Size>(fixedSize),
      maximumSize: widgetStateAllOrNull<Size>(maximumSize),
      iconSize: widgetStateAllOrNull<double>(iconSize),
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (theme.useMaterial3) {
      final Size? minSize = constraints == null
          ? null
          : Size(constraints!.minWidth, constraints!.minHeight);
      final Size? maxSize = constraints == null
          ? null
          : Size(constraints!.maxWidth, constraints!.maxHeight);

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
      if (style != null) {
        adjustedStyle = style!.merge(adjustedStyle);
      }

      Widget effectiveIcon = icon;
      if ((isSelected ?? false) && selectedIcon != null) {
        effectiveIcon = selectedIcon!;
      }

      Widget iconButton = effectiveIcon;
      if (tooltip != null) {
        iconButton = MongolTooltip(
          message: tooltip!,
          child: effectiveIcon,
        );
      }

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

    Color? currentColor;
    if (onPressed != null) {
      currentColor = color;
    } else {
      currentColor = disabledColor ?? theme.disabledColor;
    }

    final VisualDensity effectiveVisualDensity =
        visualDensity ?? theme.visualDensity;

    final BoxConstraints unadjustedConstraints = constraints ??
        const BoxConstraints(
          minWidth: _kMinButtonSize,
          minHeight: _kMinButtonSize,
        );
    final BoxConstraints adjustedConstraints =
        effectiveVisualDensity.effectiveConstraints(unadjustedConstraints);

    final double effectiveIconSize =
        iconSize ?? IconTheme.of(context).size ?? 24.0;

    final EdgeInsetsGeometry effectivePadding =
        padding ?? const EdgeInsets.all(8.0);

    final AlignmentGeometry effectiveAlignment = alignment ?? Alignment.center;

    final bool effectiveEnableFeedback = enableFeedback ?? true;

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

    if (tooltip != null) {
      result = MongolTooltip(
        message: tooltip!,
        child: result,
      );
    }

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
            ),
        child: result,
      ),
    );
  }
}

class _SelectableIconButton extends StatefulWidget {
  const _SelectableIconButton({
    this.isSelected,
    this.style,
    this.focusNode,
    required this.variant,
    required this.autofocus,
    required this.onPressed,
    required this.child,
  });

  final bool? isSelected;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final _IconButtonVariant variant;
  final bool autofocus;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  State<_SelectableIconButton> createState() => _SelectableIconButtonState();
}

class _SelectableIconButtonState extends State<_SelectableIconButton> {
  late final WidgetStatesController statesController;

  @override
  void initState() {
    super.initState();
    if (widget.isSelected == null) {
      statesController = WidgetStatesController();
    } else {
      statesController = WidgetStatesController(
          <WidgetState>{if (widget.isSelected!) WidgetState.selected});
    }
  }

  @override
  void didUpdateWidget(_SelectableIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected == null) {
      if (statesController.value.contains(WidgetState.selected)) {
        statesController.update(WidgetState.selected, false);
      }
      return;
    }
    if (widget.isSelected != oldWidget.isSelected) {
      statesController.update(WidgetState.selected, widget.isSelected!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool toggleable = widget.isSelected != null;

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

  @override
  void dispose() {
    statesController.dispose();
    super.dispose();
  }
}

class _IconButtonM3 extends ButtonStyleButton {
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

  final _IconButtonVariant variant;
  final bool toggleable;

  @override
  ButtonStyle defaultStyleOf(BuildContext context) {
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

  @override
  ButtonStyle? themeStyleOf(BuildContext context) {
    final IconThemeData iconTheme = IconTheme.of(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    bool isIconThemeDefault(Color? color) {
      if (isDark) {
        return identical(color, kDefaultIconLightColor);
      }
      return identical(color, kDefaultIconDarkColor);
    }

    final bool isDefaultColor = isIconThemeDefault(iconTheme.color);
    final bool isDefaultSize =
        iconTheme.size == const IconThemeData.fallback().size;

    final ButtonStyle iconThemeStyle = IconButton.styleFrom(
        foregroundColor: isDefaultColor ? null : iconTheme.color,
        iconSize: isDefaultSize ? null : iconTheme.size);

    return IconButtonTheme.of(context).style?.merge(iconThemeStyle) ??
        iconThemeStyle;
  }
}

@immutable
class _IconButtonDefaultBackground extends WidgetStateProperty<Color?> {
  _IconButtonDefaultBackground(this.activeColor, this.disabledColor);

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
class _IconButtonDefaultForeground extends WidgetStateProperty<Color?> {
  _IconButtonDefaultForeground(this.activeColor, this.disabledColor);

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
class _IconButtonDefaultOverlay extends WidgetStateProperty<Color?> {
  _IconButtonDefaultOverlay(this.foregroundColor, this.focusColor,
      this.hoverColor, this.highlightColor);

  final Color? foregroundColor;
  final Color? focusColor;
  final Color? hoverColor;
  final Color? highlightColor;

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
}

@immutable
class _IconButtonDefaultMouseCursor extends WidgetStateProperty<MouseCursor?>
    with Diagnosticable {
  _IconButtonDefaultMouseCursor(this.enabledCursor, this.disabledCursor);

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

/// 标准图标按钮的 Material 3 默认样式。
class _IconButtonDefaultsM3 extends ButtonStyle {
  _IconButtonDefaultsM3(this.context, this.toggleable)
      : super(
          animationDuration: kThemeChangeDuration,
          enableFeedback: true,
          alignment: Alignment.center,
        );

  final BuildContext context;
  final bool toggleable;
  late final ColorScheme _colors = Theme.of(context).colorScheme;

  @override
  WidgetStateProperty<Color?>? get backgroundColor =>
      const WidgetStatePropertyAll<Color?>(Colors.transparent);

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
      });

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
      });

  @override
  WidgetStateProperty<double>? get elevation =>
      const WidgetStatePropertyAll<double>(0.0);

  @override
  WidgetStateProperty<Color>? get shadowColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent);

  @override
  WidgetStateProperty<Color>? get surfaceTintColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent);

  @override
  WidgetStateProperty<EdgeInsetsGeometry>? get padding =>
      const WidgetStatePropertyAll<EdgeInsetsGeometry>(EdgeInsets.all(8.0));

  @override
  WidgetStateProperty<Size>? get minimumSize =>
      const WidgetStatePropertyAll<Size>(Size(40.0, 40.0));

  @override
  WidgetStateProperty<Size>? get maximumSize =>
      const WidgetStatePropertyAll<Size>(Size.infinite);

  @override
  WidgetStateProperty<double>? get iconSize =>
      const WidgetStatePropertyAll<double>(24.0);

  @override
  WidgetStateProperty<BorderSide?>? get side => null;

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
  VisualDensity? get visualDensity => VisualDensity.standard;

  @override
  MaterialTapTargetSize? get tapTargetSize =>
      Theme.of(context).materialTapTargetSize;

  @override
  InteractiveInkFeatureFactory? get splashFactory =>
      Theme.of(context).splashFactory;
}

/// 填充式图标按钮的 Material 3 默认样式。
class _FilledIconButtonDefaultsM3 extends ButtonStyle {
  _FilledIconButtonDefaultsM3(this.context, this.toggleable)
      : super(
          animationDuration: kThemeChangeDuration,
          enableFeedback: true,
          alignment: Alignment.center,
        );

  final BuildContext context;
  final bool toggleable;
  late final ColorScheme _colors = Theme.of(context).colorScheme;

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
          return _colors.surfaceContainerHighest;
        }
        return _colors.primary;
      });

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
          return _colors.primary;
        }
        return _colors.onPrimary;
      });

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
      });

  @override
  WidgetStateProperty<double>? get elevation =>
      const WidgetStatePropertyAll<double>(0.0);

  @override
  WidgetStateProperty<Color>? get shadowColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent);

  @override
  WidgetStateProperty<Color>? get surfaceTintColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent);

  @override
  WidgetStateProperty<EdgeInsetsGeometry>? get padding =>
      const WidgetStatePropertyAll<EdgeInsetsGeometry>(EdgeInsets.all(8.0));

  @override
  WidgetStateProperty<Size>? get minimumSize =>
      const WidgetStatePropertyAll<Size>(Size(40.0, 40.0));

  @override
  WidgetStateProperty<Size>? get maximumSize =>
      const WidgetStatePropertyAll<Size>(Size.infinite);

  @override
  WidgetStateProperty<double>? get iconSize =>
      const WidgetStatePropertyAll<double>(24.0);

  @override
  WidgetStateProperty<BorderSide?>? get side => null;

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
  VisualDensity? get visualDensity => VisualDensity.standard;

  @override
  MaterialTapTargetSize? get tapTargetSize =>
      Theme.of(context).materialTapTargetSize;

  @override
  InteractiveInkFeatureFactory? get splashFactory =>
      Theme.of(context).splashFactory;
}

/// 填充色调图标按钮的 Material 3 默认样式。
class _FilledTonalIconButtonDefaultsM3 extends ButtonStyle {
  _FilledTonalIconButtonDefaultsM3(this.context, this.toggleable)
      : super(
          animationDuration: kThemeChangeDuration,
          enableFeedback: true,
          alignment: Alignment.center,
        );

  final BuildContext context;
  final bool toggleable;
  late final ColorScheme _colors = Theme.of(context).colorScheme;

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
          return _colors.surfaceContainerHighest;
        }
        return _colors.secondaryContainer;
      });

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
          return _colors.onSurfaceVariant;
        }
        return _colors.onSecondaryContainer;
      });

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
      });

  @override
  WidgetStateProperty<double>? get elevation =>
      const WidgetStatePropertyAll<double>(0.0);

  @override
  WidgetStateProperty<Color>? get shadowColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent);

  @override
  WidgetStateProperty<Color>? get surfaceTintColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent);

  @override
  WidgetStateProperty<EdgeInsetsGeometry>? get padding =>
      const WidgetStatePropertyAll<EdgeInsetsGeometry>(EdgeInsets.all(8.0));

  @override
  WidgetStateProperty<Size>? get minimumSize =>
      const WidgetStatePropertyAll<Size>(Size(40.0, 40.0));

  @override
  WidgetStateProperty<Size>? get maximumSize =>
      const WidgetStatePropertyAll<Size>(Size.infinite);

  @override
  WidgetStateProperty<double>? get iconSize =>
      const WidgetStatePropertyAll<double>(24.0);

  @override
  WidgetStateProperty<BorderSide?>? get side => null;

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
  VisualDensity? get visualDensity => VisualDensity.standard;

  @override
  MaterialTapTargetSize? get tapTargetSize =>
      Theme.of(context).materialTapTargetSize;

  @override
  InteractiveInkFeatureFactory? get splashFactory =>
      Theme.of(context).splashFactory;
}

/// 轮廓式图标按钮的 Material 3 默认样式。
class _OutlinedIconButtonDefaultsM3 extends ButtonStyle {
  _OutlinedIconButtonDefaultsM3(this.context, this.toggleable)
      : super(
          animationDuration: kThemeChangeDuration,
          enableFeedback: true,
          alignment: Alignment.center,
        );

  final BuildContext context;
  final bool toggleable;
  late final ColorScheme _colors = Theme.of(context).colorScheme;

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
      });

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
      });

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
      });

  @override
  WidgetStateProperty<double>? get elevation =>
      const WidgetStatePropertyAll<double>(0.0);

  @override
  WidgetStateProperty<Color>? get shadowColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent);

  @override
  WidgetStateProperty<Color>? get surfaceTintColor =>
      const WidgetStatePropertyAll<Color>(Colors.transparent);

  @override
  WidgetStateProperty<EdgeInsetsGeometry>? get padding =>
      const WidgetStatePropertyAll<EdgeInsetsGeometry>(EdgeInsets.all(8.0));

  @override
  WidgetStateProperty<Size>? get minimumSize =>
      const WidgetStatePropertyAll<Size>(Size(40.0, 40.0));

  @override
  WidgetStateProperty<Size>? get maximumSize =>
      const WidgetStatePropertyAll<Size>(Size.infinite);

  @override
  WidgetStateProperty<double>? get iconSize =>
      const WidgetStatePropertyAll<double>(24.0);

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
  VisualDensity? get visualDensity => VisualDensity.standard;

  @override
  MaterialTapTargetSize? get tapTargetSize =>
      Theme.of(context).materialTapTargetSize;

  @override
  InteractiveInkFeatureFactory? get splashFactory =>
      Theme.of(context).splashFactory;
}
