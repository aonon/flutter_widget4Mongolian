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

/// 蒙古语风格按钮的基类，其外观通过 [ButtonStyle] 进行定义。
///
/// 具体的子类（如 [MongolTextButton]、[MongolElevatedButton] 等）必须实现
/// [defaultStyleOf] 和 [themeStyleOf] 方法，以提供特定组件的默认样式。
///
/// 另请参阅：
///  * [MongolTextButton]：无背景和轮廓的简单文字按钮。
///  * [MongolFilledButton]：带有填充背景且按下时不会提升的海拔（Elevation）按钮。
///  * [MongolElevatedButton]：带有背景且按下时海拔会增加的悬浮按钮。
///  * [MongolOutlinedButton]：带有轮廓但通常没有背景填充的按钮。
abstract class MongolButtonStyleButton extends StatefulWidget {
  /// 创建一个 [MongolButtonStyleButton]。
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

  /// 当按钮被点击或以其他方式激活时调用的回调。
  ///
  /// 如果此回调和 [onLongPress] 都为 null，则按钮将被禁用。
  ///
  /// 另请参阅：
  ///  * [enabled]：如果按钮已启用，则为 true。
  final VoidCallback? onPressed;

  /// 当按钮被长按时调用的回调。
  ///
  /// 如果此回调和 [onPressed] 都为 null，则按钮将被禁用。
  ///
  /// 另请参阅：
  ///  * [enabled]：如果按钮已启用，则为 true。
  final VoidCallback? onLongPress;

  /// 当鼠标指针进入或离开按钮响应区域时调用的回调。
  final ValueChanged<bool>? onHover;

  /// 当按钮焦点状态发生变化时调用的回调。
  final ValueChanged<bool>? onFocusChange;

  /// 自定义此按钮样式的配置对象。
  ///
  /// 此样式的非空属性会覆盖 [themeStyleOf] 和 [defaultStyleOf] 中的相应属性。
  final ButtonStyle? style;

  /// {@macro flutter.material.Material.clipBehavior}
  final Clip clipBehavior;

  /// {@macro flutter.widgets.Focus.focusNode}
  final FocusNode? focusNode;

  /// {@macro flutter.widgets.Focus.autofocus}
  final bool autofocus;

  /// {@macro flutter.material.inkwell.statesController}
  final WidgetStatesController? statesController;

  /// 确定此子树是否表示按钮。
  ///
  /// 默认为 true。
  final bool? isSemanticButton;

  /// 按钮的内容，通常是标签。
  final Widget? child;

  /// 返回此按钮的默认 [ButtonStyle]。
  ///
  /// 返回的样式可以被 [style] 参数和 [themeStyleOf] 返回的样式覆盖。
  @protected
  ButtonStyle defaultStyleOf(BuildContext context);

  /// 返回属于按钮组件主题的 [ButtonStyle]。
  ///
  /// 返回的样式可以被 [style] 参数覆盖。
  @protected
  ButtonStyle? themeStyleOf(BuildContext context);

  /// 按钮当前是否处于启用状态。
  ///
  /// 当 [onPressed] 或 [onLongPress] 非空时，按钮被视为启用。
  bool get enabled => onPressed != null || onLongPress != null;

  @override
  State<MongolButtonStyleButton> createState() => _MongolButtonStyleState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'));
    properties.add(DiagnosticsProperty<ButtonStyle>('style', style, defaultValue: null));
    properties.add(DiagnosticsProperty<FocusNode>('focusNode', focusNode, defaultValue: null));
  }
}

/// 按钮的基础 [State] 类。
class _MongolButtonStyleState extends State<MongolButtonStyleButton>
    with TickerProviderStateMixin {
  AnimationController? _controller;
  double? _elevation;
  Color? _backgroundColor;
  WidgetStatesController? _internalStatesController;

  /// 获取当前有效的状态控制器。
  WidgetStatesController get statesController =>
      widget.statesController ?? _internalStatesController!;

  /// 处理状态控制器变化的内部回调。
  void _handleStatesControllerChange() {
    // 强制重建以解析基于状态的样式属性。
    setState(() {});
  }

  /// 初始化状态控制器及其监听器。
  void _initStatesController() {
    if (widget.statesController == null) {
      _internalStatesController = WidgetStatesController();
    }
    statesController.update(WidgetState.disabled, !widget.enabled);
    statesController.addListener(_handleStatesControllerChange);
  }

  @override
  void initState() {
    super.initState();
    _initStatesController();
  }

  @override
  void dispose() {
    statesController.removeListener(_handleStatesControllerChange);
    _internalStatesController?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MongolButtonStyleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.statesController != oldWidget.statesController) {
      oldWidget.statesController?.removeListener(_handleStatesControllerChange);
      if (widget.statesController != null) {
        _internalStatesController?.dispose();
        _internalStatesController = null;
      }
      _initStatesController();
    }
    if (widget.enabled != oldWidget.enabled) {
      statesController.update(WidgetState.disabled, !widget.enabled);
      if (!widget.enabled) {
        statesController.update(WidgetState.pressed, false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ButtonStyle? widgetStyle = widget.style;
    final ButtonStyle? themeStyle = widget.themeStyleOf(context);
    final ButtonStyle defaultStyle = widget.defaultStyleOf(context);

    /// 按优先级（Widget > Theme > Default）获取有效的样式属性。
    T? getEffectiveValue<T>(T? Function(ButtonStyle? style) getProperty) {
      final T? widgetValue = getProperty(widgetStyle);
      final T? themeValue = getProperty(themeStyle);
      final T? defaultValue = getProperty(defaultStyle);
      return widgetValue ?? themeValue ?? defaultValue;
    }

    /// 解析 [WidgetStateProperty] 在当前状态下的值。
    T? resolveStateProperty<T>(
        WidgetStateProperty<T>? Function(ButtonStyle? style) getProperty) {
      return getEffectiveValue(
        (ButtonStyle? style) => getProperty(style)?.resolve(statesController.value),
      );
    }

    final double? resolvedElevation = resolveStateProperty<double?>((style) => style?.elevation);
    final TextStyle? resolvedTextStyle = resolveStateProperty<TextStyle?>((style) => style?.textStyle);
    Color? resolvedBackgroundColor = resolveStateProperty<Color?>((style) => style?.backgroundColor);
    final Color? resolvedForegroundColor = resolveStateProperty<Color?>((style) => style?.foregroundColor);
    final Color? resolvedShadowColor = resolveStateProperty<Color?>((style) => style?.shadowColor);
    final Color? resolvedSurfaceTintColor = resolveStateProperty<Color?>((style) => style?.surfaceTintColor);
    final EdgeInsetsGeometry? resolvedPadding = resolveStateProperty<EdgeInsetsGeometry?>((style) => style?.padding);
    final Size? resolvedMinimumSize = resolveStateProperty<Size?>((style) => style?.minimumSize);
    final Size? resolvedFixedSize = resolveStateProperty<Size?>((style) => style?.fixedSize);
    final Size? resolvedMaximumSize = resolveStateProperty<Size?>((style) => style?.maximumSize);
    final Color? resolvedIconColor = resolveStateProperty<Color?>((style) => style?.iconColor);
    final double? resolvedIconSize = resolveStateProperty<double?>((style) => style?.iconSize);
    final BorderSide? resolvedSide = resolveStateProperty<BorderSide?>((style) => style?.side);
    final OutlinedBorder? resolvedShape = resolveStateProperty<OutlinedBorder?>((style) => style?.shape);

    final WidgetStateMouseCursor resolvedMouseCursor = _MouseCursor(
      (Set<WidgetState> states) => getEffectiveValue(
          (ButtonStyle? style) => style?.mouseCursor?.resolve(states)),
    );

    final WidgetStateProperty<Color?> overlayColor =
        WidgetStateProperty.resolveWith<Color?>(
      (Set<WidgetState> states) => getEffectiveValue(
          (ButtonStyle? style) => style?.overlayColor?.resolve(states)),
    );

    final VisualDensity? resolvedVisualDensity = getEffectiveValue((style) => style?.visualDensity);
    final MaterialTapTargetSize? resolvedTapTargetSize = getEffectiveValue((style) => style?.tapTargetSize);
    final Duration? resolvedAnimationDuration = getEffectiveValue((style) => style?.animationDuration);
    final bool? resolvedEnableFeedback = getEffectiveValue((style) => style?.enableFeedback);
    final AlignmentGeometry? resolvedAlignment = getEffectiveValue((style) => style?.alignment);
    final Offset densityAdjustment = resolvedVisualDensity!.baseSizeAdjustment;
    final InteractiveInkFeatureFactory? resolvedSplashFactory = getEffectiveValue((style) => style?.splashFactory);

    BoxConstraints effectiveConstraints = resolvedVisualDensity.effectiveConstraints(
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

    // 蒙古语垂直布局的特殊调整：
    // 不允许 VisualDensity 减小顶部/底部内边距，这与原始 SDK 逻辑相反。
    final double dy = math.max(0, densityAdjustment.dy);
    final double dx = densityAdjustment.dx;
    final EdgeInsetsGeometry padding = resolvedPadding!
        .add(EdgeInsets.fromLTRB(dx, dy, dx, dy))
        .clamp(EdgeInsets.zero, EdgeInsetsGeometry.infinity);

    // 动画处理：当背景颜色由不透明变为半透明且海拔高度发生变化时，优先改变海拔。
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
              setState(() {});
            }
          });
      }
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

    final Size minInteractiveSize;
    switch (resolvedTapTargetSize!) {
      case MaterialTapTargetSize.padded:
        minInteractiveSize = Size(
          kMinInteractiveDimension + densityAdjustment.dx,
          kMinInteractiveDimension + densityAdjustment.dy,
        );
        assert(minInteractiveSize.width >= 0.0);
        assert(minInteractiveSize.height >= 0.0);
        break;
      case MaterialTapTargetSize.shrinkWrap:
        minInteractiveSize = Size.zero;
        break;
    }

    return Semantics(
      container: true,
      button: true,
      enabled: widget.enabled,
      child: _InputPadding(
        minSize: minInteractiveSize,
        child: result,
      ),
    );
  }
}

/// 自定义鼠标光标，支持基于状态的解析。
class _MouseCursor extends WidgetStateMouseCursor {
  const _MouseCursor(this.resolveCallback);

  final WidgetPropertyResolver<MouseCursor?> resolveCallback;

  @override
  MouseCursor resolve(Set<WidgetState> states) => resolveCallback(states)!;

  @override
  String get debugDescription => 'ButtonStyleButton_MouseCursor';
}

/// 用于扩展按钮点击区域的小部件。
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

/// [_InputPadding] 的渲染对象，负责调整布局以满足最小交互尺寸。
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

  /// 计算满足最小尺寸限制的大小。
  Size _calculateSize({
    required BoxConstraints constraints,
    required ChildLayouter layoutChild,
  }) {
    if (child != null) {
      final Size childSize = layoutChild(child!, constraints);
      final double width = math.max(childSize.width, minSize.width);
      final double height = math.max(childSize.height, minSize.height);
      return constraints.constrain(Size(width, height));
    }
    return Size.zero;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return _calculateSize(
      constraints: constraints,
      layoutChild: ChildLayoutHelper.dryLayoutChild,
    );
  }

  @override
  void performLayout() {
    size = _calculateSize(
      constraints: constraints,
      layoutChild: ChildLayoutHelper.layoutChild,
    );
    if (child != null) {
      final BoxParentData childParentData = child!.parentData! as BoxParentData;
      childParentData.offset = Alignment.center.alongOffset(size - child!.size as Offset);
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
