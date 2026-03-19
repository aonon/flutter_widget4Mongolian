// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart'
    show
        ThemeData,
        Theme,
        Feedback,
        TooltipThemeData,
        TooltipTheme,
        Brightness,
        Colors;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:mongol/src/text/mongol_text.dart';

/// 蒙古文 Material Design 提示工具（Tooltip）
///
/// 提示工具提供文本标签，帮助解释按钮或其他用户界面操作的功能。
/// 将按钮包装在 [MongolTooltip] 小部件中，并提供一个消息，当长按该小部件时会显示该消息。
///
/// 许多小部件，如 [IconButton]、[FloatingActionButton] 和 [MongolPopupMenuButton] 都有一个
/// `tooltip` 属性，当该属性不为 null 时，会导致小部件在其构建中包含一个 [Tooltip]。
///
/// 提示工具通过提供小部件的文本表示来提高视觉小部件的可访问性，例如，屏幕阅读器可以朗读这些文本。
///
/// {@youtube 560 315 https://www.youtube.com/watch?v=EeEfD5fI-5Q}
///
/// {@tool dartpad --template=stateless_widget_scaffold_center}
///
/// 这个例子展示了一个基本的 [MongolTooltip]，它有一个 [MongolText] 作为子部件。
/// [message] 包含当鼠标悬停在 web 或桌面端的子部件上时要显示的标签。
/// 在移动端，当长按小部件时会显示提示工具。
///
/// ```dart
/// Widget build(BuildContext context) {
///   return const MongolTooltip(
///     message: 'I am a Tooltip',
///     child: MongolText('Hover over the text to show a tooltip.'),
///   );
/// }
/// ```
/// {@end-tool}
///
/// {@tool dartpad --template=stateless_widget_scaffold_center}
///
/// 这个例子涵盖了 MongolTooltip 中可用的大多数属性。
/// `decoration` 用于为 MongolTooltip 提供渐变和边框半径。
/// `width` 用于设置 MongolTooltip 的特定宽度。
/// `preferRight` 为 false 时，提示工具将优先显示在 [MongolTooltip] 子部件的左侧。
/// 但是，如果左侧空间不足，它可能会在右侧显示提示工具。
/// `textStyle` 用于设置 'message' 的字体大小。
/// `showDuration` 接受一个 Duration，表示长按释放后继续显示消息的时间。
/// `waitDuration` 接受一个 Duration，表示鼠标指针必须悬停在子部件上多长时间才显示提示工具。
///
/// ```dart
/// Widget build(BuildContext context) {
///   return MongolTooltip(
///     message: 'I am a Tooltip',
///     child: const Text('Tap this text and hold down to show a tooltip.'),
///     decoration: BoxDecoration(
///       borderRadius: BorderRadius.circular(25),
///       gradient: const LinearGradient(colors: <Color>[Colors.amber, Colors.red]),
///     ),
///     width: 50,
///     padding: const EdgeInsets.all(8.0),
///     preferRight: false,
///     textStyle: const TextStyle(
///       fontSize: 24,
///     ),
///     showDuration: const Duration(seconds: 2),
///     waitDuration: const Duration(seconds: 1),
///   );
/// }
/// ```
/// {@end-tool}
///
/// 另请参阅：
///
///  * <https://material.io/design/components/tooltips.html>
///  * [TooltipTheme] 或 [ThemeData.tooltipTheme]
class MongolTooltip extends StatefulWidget {
  /// 创建一个蒙古文提示工具。
  ///
  /// 默认情况下，提示工具应遵循
  /// [Material 规范](https://material.io/design/components/tooltips.html#spec)。
  /// 如果未定义可选构造函数参数，则如果存在 [TooltipTheme] 或在 [ThemeData] 中指定，
  /// 将使用 [TooltipTheme.of] 提供的值。
  ///
  /// 在构造函数中定义的所有参数将覆盖默认值和 [TooltipTheme.of] 中的值。
  const MongolTooltip({
    super.key,
    required this.message,
    this.width,
    this.padding,
    this.margin,
    this.horizontalOffset,
    this.preferRight,
    this.excludeFromSemantics,
    this.decoration,
    this.textStyle,
    this.waitDuration,
    this.showDuration,
    this.child,
  });

  /// 要在提示工具中显示的文本。
  final String message;

  /// 提示工具的 [child] 的宽度。
  ///
  /// 如果 [child] 为 null，则这是提示工具的固有宽度。
  final double? width;

  /// 提示工具的 [child] 的内边距。
  ///
  /// 默认为每个方向 16.0 逻辑像素。
  final EdgeInsetsGeometry? padding;

  /// 围绕提示工具的空白空间。
  ///
  /// 定义提示工具的外部 [Container.margin]。默认情况下，长提示工具将跨越其窗口的高度。
  /// 如果足够高，提示工具也可能跨越窗口的宽度。此属性允许定义提示工具必须从其显示窗口边缘插入的空间量。
  ///
  /// 如果此属性为 null，则使用 [TooltipThemeData.margin]。
  /// 如果 [TooltipThemeData.margin] 也为 null，则默认边距为所有边 0.0 逻辑像素。
  final EdgeInsetsGeometry? margin;

  /// 小部件和显示的提示工具之间的水平间隙。
  ///
  /// 当 [preferRight] 设置为 true 且提示工具有足够的空间显示自己时，此属性定义提示工具将在其对应小部件右侧定位的水平空间量。
  /// 否则，提示工具将以给定的偏移量定位在其对应小部件的左侧。
  final double? horizontalOffset;

  /// 提示工具是否默认显示在小部件的右侧。
  ///
  /// 默认为 true。如果在首选方向显示提示工具的空间不足，提示工具将在相反方向显示。
  final bool? preferRight;

  /// 提示工具的 [message] 是否应从语义树中排除。
  ///
  /// 默认为 false。提示工具将添加一个 [Semantics] 标签，该标签设置为 [MongolTooltip.message]。
  /// 如果应用程序将提供自己的自定义语义标签，请将此属性设置为 true。
  final bool? excludeFromSemantics;

  /// 此小部件下方树中的小部件。
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget? child;

  /// 指定提示工具的形状和背景颜色。
  ///
  /// 提示工具形状默认为边框半径为 4.0 的圆角矩形。如果 [ThemeData.brightness] 为 [Brightness.dark]，
  /// 提示工具还将默认为 90% 的不透明度和 [Colors.grey[700]] 颜色；如果为 [Brightness.light]，则为 [Colors.white]。
  final Decoration? decoration;

  /// 用于提示工具消息的样式。
  ///
  /// 如果为 null，消息的 [TextStyle] 将基于 [ThemeData] 确定。
  /// 如果 [ThemeData.brightness] 设置为 [Brightness.dark]，则将使用 [ThemeData.textTheme] 的 [TextTheme.bodyText2] 和 [Colors.white]。
  /// 否则，如果 [ThemeData.brightness] 设置为 [Brightness.light]，则将使用 [ThemeData.textTheme] 的 [TextTheme.bodyText2] 和 [Colors.black]。
  final TextStyle? textStyle;

  /// 指针必须悬停在提示工具的小部件上才能显示提示工具的时间长度。
  ///
  /// 一旦指针离开小部件，提示工具将立即消失。
  ///
  /// 默认为 0 毫秒（悬停时立即显示提示工具）。
  final Duration? waitDuration;

  /// 长按释放后提示工具将显示的时间长度。
  ///
  /// 默认为 1.5 秒。
  final Duration? showDuration;

  @override
  State<MongolTooltip> createState() => _MongolTooltipState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('message', message, showName: false));
    properties.add(DoubleProperty('width', width, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding,
        defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('margin', margin,
        defaultValue: null));
    properties.add(DoubleProperty('horizontal offset', horizontalOffset,
        defaultValue: null));
    properties.add(FlagProperty('position',
        value: preferRight,
        ifTrue: 'right',
        ifFalse: 'left',
        showName: true,
        defaultValue: null));
    properties.add(FlagProperty('semantics',
        value: excludeFromSemantics,
        ifTrue: 'excluded',
        showName: true,
        defaultValue: null));
    properties.add(DiagnosticsProperty<Duration>('wait duration', waitDuration,
        defaultValue: null));
    properties.add(DiagnosticsProperty<Duration>('show duration', showDuration,
        defaultValue: null));
  }
}

/// MongolTooltip 的状态类
class _MongolTooltipState extends State<MongolTooltip>
    with SingleTickerProviderStateMixin {
  // 默认的水平偏移量
  static const double _defaultHorizontalOffset = 24.0;
  // 默认是否优先显示在右侧
  static const bool _defaultPreferRight = true;
  // 默认边距
  static const EdgeInsetsGeometry _defaultMargin = EdgeInsets.zero;
  // 淡入动画持续时间
  static const Duration _fadeInDuration = Duration(milliseconds: 150);
  // 淡出动画持续时间
  static const Duration _fadeOutDuration = Duration(milliseconds: 75);
  // 默认显示持续时间
  static const Duration _defaultShowDuration = Duration(milliseconds: 1500);
  // 默认等待持续时间
  static const Duration _defaultWaitDuration = Duration.zero;
  // 默认是否从语义树中排除
  static const bool _defaultExcludeFromSemantics = false;

  // 提示工具宽度
  late double width;
  // 内边距
  late EdgeInsetsGeometry padding;
  // 外边距
  late EdgeInsetsGeometry margin;
  // 装饰
  late Decoration decoration;
  // 文本样式
  late TextStyle textStyle;
  // 水平偏移量
  late double horizontalOffset;
  // 是否优先显示在右侧
  late bool preferRight;
  // 是否从语义树中排除
  late bool excludeFromSemantics;
  // 动画控制器
  late AnimationController _controller;
  // 覆盖条目
  OverlayEntry? _entry;
  // 隐藏计时器
  Timer? _hideTimer;
  // 显示计时器
  Timer? _showTimer;
  // 显示持续时间
  late Duration showDuration;
  // 等待持续时间
  late Duration waitDuration;
  // 鼠标是否连接
  late bool _mouseIsConnected;
  // 是否通过长按激活
  bool _longPressActivated = false;

  @override
  void initState() {
    super.initState();
    // 检查鼠标是否连接
    _mouseIsConnected = RendererBinding.instance.mouseTracker.mouseIsConnected;
    // 初始化动画控制器
    _controller = AnimationController(
      duration: _fadeInDuration,
      reverseDuration: _fadeOutDuration,
      vsync: this,
    )..addStatusListener(_handleStatusChanged);
    // 监听鼠标连接状态变化
    RendererBinding.instance.mouseTracker
        .addListener(_handleMouseTrackerChange);
    // 监听全局指针事件，以便在点击其他控件时立即隐藏提示工具
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handlePointerEvent);
  }

  // 根据 Material 设计规范获取默认提示工具宽度
  // https://material.io/components/tooltips#specs
  double _getDefaultTooltipWidth() {
    final ThemeData theme = Theme.of(context);
    switch (theme.platform) {
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return 24.0;
      default:
        return 32.0;
    }
  }

  // 获取默认内边距
  EdgeInsets _getDefaultPadding() {
    final ThemeData theme = Theme.of(context);
    switch (theme.platform) {
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return const EdgeInsets.symmetric(vertical: 8.0);
      default:
        return const EdgeInsets.symmetric(vertical: 16.0);
    }
  }

  // 获取默认字体大小
  double _getDefaultFontSize() {
    final ThemeData theme = Theme.of(context);
    switch (theme.platform) {
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return 10.0;
      default:
        return 14.0;
    }
  }

  // 如果添加或移除了鼠标，则强制重建
  void _handleMouseTrackerChange() {
    if (!mounted) {
      return;
    }
    final bool mouseIsConnected = RendererBinding.instance.mouseTracker.mouseIsConnected;
    if (mouseIsConnected != _mouseIsConnected) {
      setState(() {
        _mouseIsConnected = mouseIsConnected;
      });
    }
  }

  // 处理动画状态变化
  void _handleStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _hideTooltip(immediately: true);
    }
  }

  // 隐藏提示工具
  void _hideTooltip({bool immediately = false}) {
    _showTimer?.cancel();
    _showTimer = null;
    if (immediately) {
      _removeEntry();
      return;
    }
    if (_longPressActivated) {
      // 通过长按激活的提示工具应在 showDuration 时间内保持显示
      _hideTimer ??= Timer(showDuration, _controller.reverse);
    } else {
      // 通过悬停激活的提示工具应在鼠标离开控件时立即消失
      _controller.reverse();
    }
    _longPressActivated = false;
  }

  // 显示提示工具
  void _showTooltip({bool immediately = false}) {
    _hideTimer?.cancel();
    _hideTimer = null;
    if (immediately) {
      ensureTooltipVisible();
      return;
    }
    _showTimer ??= Timer(waitDuration, ensureTooltipVisible);
  }

  /// 如果提示工具尚未可见，则显示它。
  ///
  /// 当提示工具已经可见或上下文变为 null 时返回 `false`。
  bool ensureTooltipVisible() {
    _showTimer?.cancel();
    _showTimer = null;
    if (_entry != null) {
      // 如果我们正在尝试隐藏，则停止
      _hideTimer?.cancel();
      _hideTimer = null;
      _controller.forward();
      return false; // 已经可见
    }
    _createNewEntry();
    _controller.forward();
    return true;
  }

  // 创建新的覆盖条目
  void _createNewEntry() {
    final OverlayState overlayState = Overlay.of(
      context,
      debugRequiredFor: widget,
    );

    final RenderBox box = context.findRenderObject()! as RenderBox;
    final Offset target = box.localToGlobal(
      box.size.center(Offset.zero),
      ancestor: overlayState.context.findRenderObject(),
    );

    // 我们在覆盖条目构建器外部创建此小部件，以防止更新的值在覆盖重建时泄漏到覆盖中
    final Widget overlay = Directionality(
      textDirection: TextDirection.ltr,
      child: _MongolTooltipOverlay(
        message: widget.message,
        width: width,
        padding: padding,
        margin: margin,
        decoration: decoration,
        textStyle: textStyle,
        animation: CurvedAnimation(
          parent: _controller,
          curve: Curves.fastOutSlowIn,
        ),
        target: target,
        horizontalOffset: horizontalOffset,
        preferRight: preferRight,
      ),
    );
    _entry = OverlayEntry(builder: (BuildContext context) => overlay);
    overlayState.insert(_entry!);
    SemanticsService.tooltip(widget.message);
  }

  // 移除覆盖条目
  void _removeEntry() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _showTimer?.cancel();
    _showTimer = null;
    _entry?.remove();
    _entry = null;
  }

  // 处理指针事件
  void _handlePointerEvent(PointerEvent event) {
    if (_entry == null) {
      return;
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _hideTooltip();
    } else if (event is PointerDownEvent) {
      _hideTooltip(immediately: true);
    }
  }

  @override
  void deactivate() {
    if (_entry != null) {
      _hideTooltip(immediately: true);
    }
    _showTimer?.cancel();
    super.deactivate();
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter
        .removeGlobalRoute(_handlePointerEvent);
    RendererBinding.instance.mouseTracker
        .removeListener(_handleMouseTrackerChange);
    if (_entry != null) {
      _removeEntry();
    }
    _controller.dispose();
    super.dispose();
  }

  // 处理长按事件
  void _handleLongPress() {
    _longPressActivated = true;
    final bool tooltipCreated = ensureTooltipVisible();
    if (tooltipCreated) {
      Feedback.forLongPress(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TooltipThemeData tooltipTheme = TooltipTheme.of(context);
    final TextStyle defaultTextStyle;
    final BoxDecoration defaultDecoration;
    if (theme.brightness == Brightness.dark) {
      defaultTextStyle = theme.textTheme.bodyMedium!.copyWith(
        color: Colors.black,
        fontSize: _getDefaultFontSize(),
      );
      defaultDecoration = BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      );
    } else {
      defaultTextStyle = theme.textTheme.bodyMedium!.copyWith(
        color: Colors.white,
        fontSize: _getDefaultFontSize(),
      );
      defaultDecoration = BoxDecoration(
        color: Colors.grey[700]!.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      );
    }

    // 设置各种属性的值，优先使用 widget 提供的值，然后是主题提供的值，最后是默认值
    width = widget.width ?? tooltipTheme.constraints?.minHeight ?? _getDefaultTooltipWidth();
    padding = widget.padding ?? tooltipTheme.padding ?? _getDefaultPadding();
    margin = widget.margin ?? tooltipTheme.margin ?? _defaultMargin;
    horizontalOffset = widget.horizontalOffset ??
        tooltipTheme.verticalOffset ??
        _defaultHorizontalOffset;
    preferRight =
        widget.preferRight ?? tooltipTheme.preferBelow ?? _defaultPreferRight;
    excludeFromSemantics = widget.excludeFromSemantics ??
        tooltipTheme.excludeFromSemantics ??
        _defaultExcludeFromSemantics;
    decoration =
        widget.decoration ?? tooltipTheme.decoration ?? defaultDecoration;
    textStyle = widget.textStyle ?? tooltipTheme.textStyle ?? defaultTextStyle;
    waitDuration = widget.waitDuration ??
        tooltipTheme.waitDuration ??
        _defaultWaitDuration;
    showDuration = widget.showDuration ??
        tooltipTheme.showDuration ??
        _defaultShowDuration;

    // 创建一个 GestureDetector 来处理长按事件
    Widget result = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: _handleLongPress,
      excludeFromSemantics: true,
      child: Semantics(
        label: excludeFromSemantics ? null : widget.message,
        child: widget.child,
      ),
    );

    // 只有在鼠标连接时才检查悬停
    if (_mouseIsConnected) {
      result = MouseRegion(
        onEnter: (PointerEnterEvent event) => _showTooltip(),
        onExit: (PointerExitEvent event) => _hideTooltip(),
        child: result,
      );
    }

    return result;
  }
}

/// 用于计算提示工具布局的委托，提示工具将显示在全局坐标系中指定目标的左侧或右侧
class _MongolTooltipPositionDelegate extends SingleChildLayoutDelegate {
  /// 创建一个用于计算提示工具布局的委托
  ///
  /// 参数不能为空
  _MongolTooltipPositionDelegate({
    required this.target,
    required this.horizontalOffset,
    required this.preferRight,
  });

  /// 提示工具在全局坐标系中定位的目标偏移量
  final Offset target;

  /// 目标和显示的提示工具之间的水平距离
  final double horizontalOffset;

  /// 提示工具是否默认显示在其小部件的右侧
  ///
  /// 如果在首选方向显示提示工具的空间不足，提示工具将在相反方向显示
  final bool preferRight;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    return positionMongolDependentBox(
      size: size,
      childSize: childSize,
      target: target,
      horizontalOffset: horizontalOffset,
      preferRight: preferRight,
    );
  }

  @override
  bool shouldRelayout(_MongolTooltipPositionDelegate oldDelegate) {
    return target != oldDelegate.target ||
        horizontalOffset != oldDelegate.horizontalOffset ||
        preferRight != oldDelegate.preferRight;
  }
}

/// 蒙古文提示工具覆盖层
class _MongolTooltipOverlay extends StatelessWidget {
  const _MongolTooltipOverlay({
    required this.message,
    required this.width,
    this.padding,
    this.margin,
    this.decoration,
    this.textStyle,
    required this.animation,
    required this.target,
    required this.horizontalOffset,
    required this.preferRight,
  });

  /// 提示消息
  final String message;
  /// 提示工具宽度
  final double width;
  /// 内边距
  final EdgeInsetsGeometry? padding;
  /// 外边距
  final EdgeInsetsGeometry? margin;
  /// 装饰
  final Decoration? decoration;
  /// 文本样式
  final TextStyle? textStyle;
  /// 动画
  final Animation<double> animation;
  /// 目标偏移量
  final Offset target;
  /// 水平偏移量
  final double horizontalOffset;
  /// 是否优先显示在右侧
  final bool preferRight;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomSingleChildLayout(
          delegate: _MongolTooltipPositionDelegate(
            target: target,
            horizontalOffset: horizontalOffset,
            preferRight: preferRight,
          ),
          child: FadeTransition(
            opacity: animation,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: width),
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.bodyMedium!,
                child: Container(
                  decoration: decoration,
                  padding: padding,
                  margin: margin,
                  child: Center(
                    widthFactor: 1.0,
                    heightFactor: 1.0,
                    child: MongolText(
                      message,
                      style: textStyle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 在容器框内定位子框，位于目标点的左侧或右侧
///
/// 容器的大小由 `size` 描述。
///
/// 目标点由 `target` 指定，作为从容器左上角开始的偏移量。
///
/// 子框的大小由 `childSize` 给出。
///
/// 返回值是从容器框左上角到子框左上角的建议距离。
///
/// 如果 `preferRight` 为 false，建议的位置将在目标点的左侧；如果为 true，建议的位置将在目标点的右侧，
/// 除非它无法适应首选侧但可以适应另一侧。
///
/// 建议的位置将使子框的最近一侧距离目标点 `horizontalOffset`（即使在给定该约束的情况下无法适应）。
///
/// 建议的位置将至少距离容器边缘 `margin`。如果可能，子框将被定位为使其中心与目标点对齐。
/// 如果子框在给定边距的情况下无法垂直适应容器，则子框将在容器中居中。
///
/// 由 [MongolTooltip] 用于相对于其父级定位提示工具。
///
/// 参数不能为空。
Offset positionMongolDependentBox({
  required Size size,
  required Size childSize,
  required Offset target,
  required bool preferRight,
  double horizontalOffset = 0.0,
  double margin = 10.0,
}) {
  // 水平方向
  final bool fitsRight =
      target.dx + horizontalOffset + childSize.width <= size.width - margin;
  final bool fitsLeft =
      target.dx - horizontalOffset - childSize.width >= margin;
  final bool tooltipRight =
      preferRight ? fitsRight || !fitsLeft : !(fitsLeft || !fitsRight);
  double x;
  if (tooltipRight) {
    x = math.min(target.dx + horizontalOffset, size.width - margin);
  } else {
    x = math.max(target.dx - horizontalOffset - childSize.width, margin);
  }
  // 垂直方向
  double y;
  if (size.height - margin * 2.0 < childSize.height) {
    y = (size.height - childSize.height) / 2.0;
  } else {
    final double normalizedTargetY =
        target.dy.clamp(margin, size.height - margin);
    final double edge = margin + childSize.height / 2.0;
    if (normalizedTargetY < edge) {
      y = margin;
    } else if (normalizedTargetY > size.height - edge) {
      y = size.height - margin - childSize.height;
    } else {
      y = normalizedTargetY - childSize.height / 2.0;
    }
  }
  return Offset(x, y);
}
