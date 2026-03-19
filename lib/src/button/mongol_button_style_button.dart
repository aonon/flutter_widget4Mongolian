// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: todo

// TODO: remove this method if the following issue is resolved
// https://github.com/flutter/flutter/issues/90374
// If it is resolved then you can directly extend ButtonStyleButton for all of
// the buttons.

// NOTE: This file is a copy of the original file from the Flutter SDK and only deviates
// in the VisualDensity adjustment from the _MongolButtonStyleState.build method.
// In this file, the VisualDensity adjustment only reduces the vertical size of the button.
// This is opposite to the original file.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show
        ButtonStyle,
        Colors,
        WidgetStateProperty,
        VisualDensity,
        InkWell,
        WidgetPropertyResolver,
        MaterialType,
        MaterialTapTargetSize,
        Material,
        kMinInteractiveDimension,
        WidgetStateMouseCursor,
        InteractiveInkFeatureFactory,
        WidgetStatesController,
        WidgetState;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 按钮的基础类，样式由 [ButtonStyle] 对象定义
///
/// 具体子类必须重写 [defaultStyleOf] 和 [themeStyleOf] 方法
///
/// 另请参阅：
///  * [MongolTextButton] - 无轮廓和填充色的简单按钮
///  * [MongolFilledButton] - 填充色按钮，按下时不提升
///  * [MongolElevatedButton] - 填充色按钮，按下时材质会提升
///  * [MongolOutlinedButton] - 带轮廓的按钮，无填充色
abstract class MongolButtonStyleButton extends StatefulWidget {
  /// 创建按钮样式按钮
  const MongolButtonStyleButton({
    super.key,
    required this.onPressed,
    required this.onLongPress,
    required this.onHover,
    required this.onFocusChange,
    required this.style,
    required this.focusNode,
    required this.autofocus,
    required this.clipBehavior,
    this.statesController,
    this.isSemanticButton = true,
    required this.child,
  });

  /// 当按钮被点击或以其他方式激活时调用。
  ///
  /// 如果此回调和 [onLongPress] 都为 null，则按钮将被禁用。
  ///
  /// 另请参阅：
  ///
  ///  * [enabled]，如果按钮已启用，则为 true。
  final VoidCallback? onPressed;

  /// 当按钮被长按时调用。
  ///
  /// 如果此回调和 [onPressed] 都为 null，则按钮将被禁用。
  ///
  /// 另请参阅：
  ///
  ///  * [enabled]，如果按钮已启用，则为 true。
  final VoidCallback? onLongPress;

  /// 当指针进入或退出按钮响应区域时调用。
  ///
  /// 传递给回调的值为 true，如果指针已进入此
  /// 材质部分，为 false 如果指针已退出此材质部分。
  final ValueChanged<bool>? onHover;

  /// 当焦点变化时调用的处理程序。
  ///
  /// 如果此小部件的节点获得焦点，则调用 true，如果失去焦点，则调用 false。
  final ValueChanged<bool>? onFocusChange;

  /// 自定义此按钮的外观。
  ///
  /// 此样式的非空属性会覆盖 [themeStyleOf] 和 [defaultStyleOf] 中的相应
  /// 属性。解析为非空值的 [WidgetStateProperty] 也会类似地覆盖 [themeStyleOf] 和 [defaultStyleOf] 中的相应
  /// [WidgetStateProperty]。
  ///
  /// 默认值为 null。
  final ButtonStyle? style;

  /// {@macro flutter.material.Material.clipBehavior}
  ///
  /// 默认值为 [Clip.none]，且不能为空。
  final Clip clipBehavior;

  /// {@macro flutter.widgets.Focus.focusNode}
  final FocusNode? focusNode;

  /// {@macro flutter.widgets.Focus.autofocus}
  final bool autofocus;

  /// {@macro flutter.material.inkwell.statesController}
  final WidgetStatesController? statesController;

  /// 确定此子树是否表示按钮。
  ///
  /// 如果为 null，则屏幕阅读器在此
  /// 获得焦点时不会宣布 "button"。这对于 [MenuItemButton] 和 [SubmenuButton] 在我们
  /// 遍历菜单系统时很有用。
  ///
  /// 默认值为 true。
  final bool? isSemanticButton;

  /// 通常是按钮的标签。
  final Widget? child;

  /// 返回一个非空的 [ButtonStyle]，主要基于 [Theme] 的
  /// [ThemeData.textTheme] 和 [ThemeData.colorScheme]。
  ///
  /// 返回的样式可以被 [style] 参数和
  /// [themeStyleOf] 返回的样式覆盖。例如，[TextButton] 子类的默认
  /// 样式可以通过其 [TextButton.style] 构造函数参数或使用
  /// [TextButtonTheme] 来覆盖。
  ///
  /// 具体的按钮子类应该返回一个 ButtonStyle，
  /// 该样式没有 null 属性，并且所有 [WidgetStateProperty]
  /// 属性都解析为非空值。
  ///
  /// 另请参阅：
  ///
  ///  * [themeStyleOf]，返回此按钮的组件主题的 ButtonStyle。
  @protected
  ButtonStyle defaultStyleOf(BuildContext context);

  /// 返回属于按钮组件主题的 ButtonStyle。
  ///
  /// 返回的样式可以被 [style] 参数覆盖。
  ///
  /// 具体的按钮子类应该返回最近的子类特定继承主题的 ButtonStyle，
  /// 如果不存在这样的主题，则返回整体 [Theme] 中的相同值。
  ///
  /// 另请参阅：
  ///
  ///  * [defaultStyleOf]，返回此按钮的默认 [ButtonStyle]。
  @protected
  ButtonStyle? themeStyleOf(BuildContext context);

  /// 按钮是否启用或禁用。
  ///
  /// 按钮默认是禁用的。要启用按钮，请将其 [onPressed]
  /// 或 [onLongPress] 属性设置为非 null 值。
  bool get enabled => onPressed != null || onLongPress != null;

  @override
  State<MongolButtonStyleButton> createState() => _MongolButtonStyleState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
        .add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'));
    properties.add(
        DiagnosticsProperty<ButtonStyle>('style', style, defaultValue: null));
    properties.add(DiagnosticsProperty<FocusNode>('focusNode', focusNode,
        defaultValue: null));
  }
}

/// 按钮的基础 [State] 类，其样式由 [ButtonStyle] 对象定义。
///
/// 另请参阅：
///
///  * [MongolButtonStyleButton]，此类是其 [State] 的 [StatefulWidget] 子类。
///  * [MongolTextButton]，一个没有阴影的简单按钮。
///  * [MongolElevatedButton]，一个填充的按钮，按下时其材质会提升。
///  * [MongolFilledButton]，一个填充的 ButtonStyleButton，按下时不会提升。
///  * [MongolOutlinedButton]，类似于 [MongolTextButton]，但带有轮廓。
class _MongolButtonStyleState extends State<MongolButtonStyleButton>
    with TickerProviderStateMixin {
  AnimationController? _controller; // 动画控制器
  double? _elevation; // 按钮的海拔高度
  Color? _backgroundColor; // 按钮的背景颜色
  WidgetStatesController? internalStatesController; // 内部状态控制器

  /// 处理状态控制器变化
  void handleStatesControllerChange() {
    // 强制重建以解析 MaterialStateProperty 属性
    setState(() {});
  }

  /// 获取状态控制器
  WidgetStatesController get statesController =>
      widget.statesController ?? internalStatesController!;

  /// 初始化状态控制器
  void initStatesController() {
    if (widget.statesController == null) {
      internalStatesController = WidgetStatesController();
    }
    statesController.update(WidgetState.disabled, !widget.enabled);
    statesController.addListener(handleStatesControllerChange);
  }

  @override
  void initState() {
    super.initState();
    initStatesController();
  }

  @override
  void dispose() {
    statesController.removeListener(handleStatesControllerChange);
    internalStatesController?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MongolButtonStyleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.statesController != oldWidget.statesController) {
      oldWidget.statesController?.removeListener(handleStatesControllerChange);
      if (widget.statesController != null) {
        internalStatesController?.dispose();
        internalStatesController = null;
      }
      initStatesController();
    }
    if (widget.enabled != oldWidget.enabled) {
      statesController.update(WidgetState.disabled, !widget.enabled);
      if (!widget.enabled) {
        // The button may have been disabled while a press gesture is currently underway.
        statesController.update(WidgetState.pressed, false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ButtonStyle? widgetStyle = widget.style;
    final ButtonStyle? themeStyle = widget.themeStyleOf(context);
    final ButtonStyle defaultStyle = widget.defaultStyleOf(context);

    /// 获取有效值，优先级为：widget.style > themeStyle > defaultStyle
    T? effectiveValue<T>(T? Function(ButtonStyle? style) getProperty) {
      final T? widgetValue = getProperty(widgetStyle);
      final T? themeValue = getProperty(themeStyle);
      final T? defaultValue = getProperty(defaultStyle);
      return widgetValue ?? themeValue ?? defaultValue;
    }

    /// 解析 WidgetStateProperty 值
    T? resolve<T>(
        WidgetStateProperty<T>? Function(ButtonStyle? style) getProperty) {
      return effectiveValue(
        (ButtonStyle? style) =>
            getProperty(style)?.resolve(statesController.value),
      );
    }

    final double? resolvedElevation =
        resolve<double?>((ButtonStyle? style) => style?.elevation);
    final TextStyle? resolvedTextStyle =
        resolve<TextStyle?>((ButtonStyle? style) => style?.textStyle);
    Color? resolvedBackgroundColor =
        resolve<Color?>((ButtonStyle? style) => style?.backgroundColor);
    final Color? resolvedForegroundColor =
        resolve<Color?>((ButtonStyle? style) => style?.foregroundColor);
    final Color? resolvedShadowColor =
        resolve<Color?>((ButtonStyle? style) => style?.shadowColor);
    final Color? resolvedSurfaceTintColor =
        resolve<Color?>((ButtonStyle? style) => style?.surfaceTintColor);
    final EdgeInsetsGeometry? resolvedPadding =
        resolve<EdgeInsetsGeometry?>((ButtonStyle? style) => style?.padding);
    final Size? resolvedMinimumSize =
        resolve<Size?>((ButtonStyle? style) => style?.minimumSize);
    final Size? resolvedFixedSize =
        resolve<Size?>((ButtonStyle? style) => style?.fixedSize);
    final Size? resolvedMaximumSize =
        resolve<Size?>((ButtonStyle? style) => style?.maximumSize);
    final Color? resolvedIconColor =
        resolve<Color?>((ButtonStyle? style) => style?.iconColor);
    final double? resolvedIconSize =
        resolve<double?>((ButtonStyle? style) => style?.iconSize);
    final BorderSide? resolvedSide =
        resolve<BorderSide?>((ButtonStyle? style) => style?.side);
    final OutlinedBorder? resolvedShape =
        resolve<OutlinedBorder?>((ButtonStyle? style) => style?.shape);

    final WidgetStateMouseCursor resolvedMouseCursor = _MouseCursor(
      (Set<WidgetState> states) => effectiveValue(
          (ButtonStyle? style) => style?.mouseCursor?.resolve(states)),
    );

    final WidgetStateProperty<Color?> overlayColor =
        WidgetStateProperty.resolveWith<Color?>(
      (Set<WidgetState> states) => effectiveValue(
          (ButtonStyle? style) => style?.overlayColor?.resolve(states)),
    );

    final VisualDensity? resolvedVisualDensity =
        effectiveValue((ButtonStyle? style) => style?.visualDensity);
    final MaterialTapTargetSize? resolvedTapTargetSize =
        effectiveValue((ButtonStyle? style) => style?.tapTargetSize);
    final Duration? resolvedAnimationDuration =
        effectiveValue((ButtonStyle? style) => style?.animationDuration);
    final bool? resolvedEnableFeedback =
        effectiveValue((ButtonStyle? style) => style?.enableFeedback);
    final AlignmentGeometry? resolvedAlignment =
        effectiveValue((ButtonStyle? style) => style?.alignment);
    final Offset densityAdjustment = resolvedVisualDensity!.baseSizeAdjustment;
    final InteractiveInkFeatureFactory? resolvedSplashFactory =
        effectiveValue((ButtonStyle? style) => style?.splashFactory);

    BoxConstraints effectiveConstraints =
        resolvedVisualDensity.effectiveConstraints(
      BoxConstraints(
        minWidth: resolvedMinimumSize!.width,
        minHeight: resolvedMinimumSize.height,
        maxWidth: resolvedMaximumSize!.width,
        maxHeight: resolvedMaximumSize.height,
      ),
    );
    if (resolvedFixedSize != null) {
      final Size size = effectiveConstraints.constrain(resolvedFixedSize);
      if (size.width.isFinite) {
        effectiveConstraints = effectiveConstraints.copyWith(
          minWidth: size.width,
          maxWidth: size.width,
        );
      }
      if (size.height.isFinite) {
        effectiveConstraints = effectiveConstraints.copyWith(
          minHeight: size.height,
          maxHeight: size.height,
        );
      }
    }

    // This is the only deviation from [_ButtonStyleState] in the original.
    //
    // Per the Material Design team: don't allow the VisualDensity
    // adjustment to reduce the height of the top/bottom padding. If we
    // did, VisualDensity.compact, the default for desktop/web, would
    // reduce the vertical padding to zero.
    final double dy = math.max(0, densityAdjustment.dy);
    final double dx = densityAdjustment.dx;
    final EdgeInsetsGeometry padding = resolvedPadding!
        .add(EdgeInsets.fromLTRB(dx, dy, dx, dy))
        .clamp(EdgeInsets.zero, EdgeInsetsGeometry.infinity);

    // If an opaque button's background is becoming translucent while its
    // elevation is changing, change the elevation first. Material implicitly
    // animates its elevation but not its color. SKIA renders non-zero
    // elevations as a shadow colored fill behind the Material's background.
    if (resolvedAnimationDuration! > Duration.zero &&
        _elevation != null &&
        _backgroundColor != null &&
        _elevation != resolvedElevation &&
        _backgroundColor!.r != resolvedBackgroundColor!.r &&
        _backgroundColor!.g != resolvedBackgroundColor.g &&
        _backgroundColor!.b != resolvedBackgroundColor.b &&
        _backgroundColor!.a == 1.0 &&
        resolvedBackgroundColor.a < 1.0 &&
        resolvedElevation == 0) {
      if (_controller?.duration != resolvedAnimationDuration) {
        _controller?.dispose();
        _controller = AnimationController(
          duration: resolvedAnimationDuration,
          vsync: this,
        )..addStatusListener((AnimationStatus status) {
            if (status == AnimationStatus.completed) {
              setState(() {}); // Rebuild with the final background color.
            }
          });
      }
      // Defer changing the background color.
      resolvedBackgroundColor = _backgroundColor;
      _controller!.value = 0;
      _controller!.forward();
    }
    _elevation = resolvedElevation;
    _backgroundColor = resolvedBackgroundColor;

    final Widget result = ConstrainedBox(
      constraints: effectiveConstraints,
      child: Material(
        elevation: resolvedElevation!,
        textStyle: resolvedTextStyle?.copyWith(color: resolvedForegroundColor),
        shape: resolvedShape!.copyWith(side: resolvedSide),
        color: resolvedBackgroundColor,
        shadowColor: resolvedShadowColor,
        surfaceTintColor: resolvedSurfaceTintColor,
        type: resolvedBackgroundColor == null
            ? MaterialType.transparency
            : MaterialType.button,
        animationDuration: resolvedAnimationDuration,
        clipBehavior: widget.clipBehavior,
        child: InkWell(
          onTap: widget.onPressed,
          onLongPress: widget.onLongPress,
          onHover: widget.onHover,
          mouseCursor: resolvedMouseCursor,
          enableFeedback: resolvedEnableFeedback ?? true,
          focusNode: widget.focusNode,
          canRequestFocus: widget.enabled,
          onFocusChange: widget.onFocusChange,
          autofocus: widget.autofocus,
          splashFactory: resolvedSplashFactory,
          overlayColor: overlayColor,
          highlightColor: Colors.transparent,
          customBorder: resolvedShape.copyWith(side: resolvedSide),
          statesController: statesController,
          child: IconTheme.merge(
            data: IconThemeData(
                color: resolvedIconColor ?? resolvedForegroundColor,
                size: resolvedIconSize),
            child: Padding(
              padding: padding,
              child: Align(
                alignment: resolvedAlignment!,
                widthFactor: 1.0,
                heightFactor: 1.0,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );

    final Size minSize;
    switch (resolvedTapTargetSize!) {
      case MaterialTapTargetSize.padded:
        minSize = Size(
          kMinInteractiveDimension + densityAdjustment.dx,
          kMinInteractiveDimension + densityAdjustment.dy,
        );
        assert(minSize.width >= 0.0);
        assert(minSize.height >= 0.0);
        break;
      case MaterialTapTargetSize.shrinkWrap:
        minSize = Size.zero;
        break;
    }

    return Semantics(
      container: true,
      button: true,
      enabled: widget.enabled,
      child: _InputPadding(
        minSize: minSize,
        child: result,
      ),
    );
  }
}

/// 自定义鼠标光标类
class _MouseCursor extends WidgetStateMouseCursor {
  const _MouseCursor(this.resolveCallback);

  final WidgetPropertyResolver<MouseCursor?> resolveCallback;

  @override
  MouseCursor resolve(Set<WidgetState> states) => resolveCallback(states)!;

  @override
  String get debugDescription => 'ButtonStyleButton_MouseCursor';
}

/// 一个小部件，用于在 [MaterialButton] 的内部 [Material] 周围填充区域。
///
/// 将发生在子项周围填充区域中的点击重定向到子项的中心。
/// 这增加了按钮的大小和按钮的
/// "点击目标"，但不增加其材质或墨水飞溅。
class _InputPadding extends SingleChildRenderObjectWidget {
  const _InputPadding({
    super.child,
    required this.minSize,
  });

  final Size minSize;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderInputPadding(minSize);
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant _RenderInputPadding renderObject) {
    renderObject.minSize = minSize;
  }
}

/// _InputPadding 的渲染对象
class _RenderInputPadding extends RenderShiftedBox {
  _RenderInputPadding(this._minSize, [RenderBox? child]) : super(child);

  Size get minSize => _minSize;
  Size _minSize;
  set minSize(Size value) {
    if (_minSize == value) return;
    _minSize = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if (child != null) {
      return math.max(child!.getMinIntrinsicWidth(height), minSize.width);
    }
    return 0.0;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (child != null) {
      return math.max(child!.getMinIntrinsicHeight(width), minSize.height);
    }
    return 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (child != null) {
      return math.max(child!.getMaxIntrinsicWidth(height), minSize.width);
    }
    return 0.0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (child != null) {
      return math.max(child!.getMaxIntrinsicHeight(width), minSize.height);
    }
    return 0.0;
  }

  /// 计算大小
  Size _computeSize(
      {required BoxConstraints constraints,
      required ChildLayouter layoutChild}) {
    if (child != null) {
      final Size childSize = layoutChild(child!, constraints);
      final double height = math.max(childSize.width, minSize.width);
      final double width = math.max(childSize.height, minSize.height);
      return constraints.constrain(Size(height, width));
    }
    return Size.zero;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return _computeSize(
      constraints: constraints,
      layoutChild: ChildLayoutHelper.dryLayoutChild,
    );
  }

  @override
  void performLayout() {
    size = _computeSize(
      constraints: constraints,
      layoutChild: ChildLayoutHelper.layoutChild,
    );
    if (child != null) {
      final BoxParentData childParentData = child!.parentData! as BoxParentData;
      childParentData.offset =
          Alignment.center.alongOffset(size - child!.size as Offset);
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (super.hitTest(result, position: position)) {
      return true;
    }
    final Offset center = child!.size.center(Offset.zero);
    return result.addWithRawTransform(
      transform: MatrixUtils.forceToPoint(center),
      position: center,
      hitTest: (BoxHitTestResult result, Offset? position) {
        assert(position == center);
        return child!.hitTest(result, position: center);
      },
    );
  }
}
