// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
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

/// 蒙古文方向的 Tooltip 组件。
///
/// 在桌面端支持悬停显示，在移动端支持长按显示。
/// 常用于图标按钮、菜单按钮等操作入口的辅助说明。
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

  /// Tooltip 内容的最小宽度。
  final double? width;

  /// Tooltip 内容内边距。
  final EdgeInsetsGeometry? padding;

  /// Tooltip 外边距。
  ///
  /// 用于控制 Tooltip 与可视区域边界的最小距离。
  final EdgeInsetsGeometry? margin;

  /// 目标组件与 Tooltip 之间的水平间距。
  final double? horizontalOffset;

  /// 是否优先显示在目标右侧。
  ///
  /// 空间不足时会自动切换到另一侧。
  final bool? preferRight;

  /// 是否把 [message] 从语义树中排除。
  ///
  /// 当你已经提供自定义语义描述时可设置为 true。
  final bool? excludeFromSemantics;

  /// 此小部件下方树中的小部件。
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget? child;

  /// Tooltip 背景与形状装饰。
  final Decoration? decoration;

  /// Tooltip 文本样式。
  ///
  /// 未提供时按主题亮暗模式使用默认样式。
  final TextStyle? textStyle;

  /// 悬停触发时的延迟显示时长。
  final Duration? waitDuration;

  /// 长按触发后保持显示的时长。
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
  static const double _defaultHorizontalOffset = 24.0;
  static const bool _defaultPreferRight = true;
  static const EdgeInsetsGeometry _defaultMargin = EdgeInsets.zero;
  static const Duration _fadeInDuration = Duration(milliseconds: 150);
  static const Duration _fadeOutDuration = Duration(milliseconds: 75);
  static const Duration _defaultShowDuration = Duration(milliseconds: 1500);
  static const Duration _defaultWaitDuration = Duration.zero;
  static const bool _defaultExcludeFromSemantics = false;

  late _TooltipConfig _config;
  late AnimationController _controller;
  OverlayEntry? _entry;
  Timer? _hideTimer;
  Timer? _showTimer;
  late bool _mouseIsConnected;
  bool _longPressActivated = false;

  @override
  void initState() {
    super.initState();
    _mouseIsConnected = RendererBinding.instance.mouseTracker.mouseIsConnected;
    _controller = AnimationController(
      duration: _fadeInDuration,
      reverseDuration: _fadeOutDuration,
      vsync: this,
    )..addStatusListener(_handleStatusChanged);
    RendererBinding.instance.mouseTracker
        .addListener(_handleMouseTrackerChange);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handlePointerEvent);
  }

  double _defaultTooltipWidthForPlatform() {
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

  EdgeInsets _defaultPaddingForPlatform() {
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

  double _defaultFontSizeForPlatform() {
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
    final bool hasConnectedMouse =
        RendererBinding.instance.mouseTracker.mouseIsConnected;
    if (hasConnectedMouse != _mouseIsConnected) {
      setState(() {
        _mouseIsConnected = hasConnectedMouse;
      });
    }
  }

  void _handleStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _hideTooltip(immediately: true);
    }
  }

  void _hideTooltip({bool immediately = false}) {
    _showTimer?.cancel();
    _showTimer = null;
    if (immediately) {
      _removeEntry();
      return;
    }
    if (_longPressActivated) {
      _hideTimer ??= Timer(_config.showDuration, _controller.reverse);
    } else {
      _controller.reverse();
    }
    _longPressActivated = false;
  }

  void _showTooltip({bool immediately = false}) {
    _hideTimer?.cancel();
    _hideTimer = null;
    if (immediately) {
      ensureTooltipVisible();
      return;
    }
    _showTimer ??= Timer(_config.waitDuration, ensureTooltipVisible);
  }

  /// 如果提示工具尚未可见，则显示它。
  ///
  /// 当提示工具已经可见或上下文变为 null 时返回 `false`。
  bool ensureTooltipVisible() {
    _showTimer?.cancel();
    _showTimer = null;
    if (_entry != null) {
      _hideTimer?.cancel();
      _hideTimer = null;
      _controller.forward();
      return false;
    }
    _createNewEntry();
    _controller.forward();
    return true;
  }

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

    final Widget overlay = Directionality(
      textDirection: TextDirection.ltr,
      child: _MongolTooltipOverlay(
        message: widget.message,
        width: _config.width,
        padding: _config.padding,
        margin: _config.margin,
        decoration: _config.decoration,
        textStyle: _config.textStyle,
        animation: CurvedAnimation(
          parent: _controller,
          curve: Curves.fastOutSlowIn,
        ),
        target: target,
        horizontalOffset: _config.horizontalOffset,
        preferRight: _config.preferRight,
      ),
    );
    _entry = OverlayEntry(builder: (BuildContext context) => overlay);
    overlayState.insert(_entry!);
    SemanticsService.tooltip(widget.message);
  }

  void _removeEntry() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _showTimer?.cancel();
    _showTimer = null;
    _entry?.remove();
    _entry = null;
  }

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

  void _handleLongPress() {
    _longPressActivated = true;
    final bool tooltipCreated = ensureTooltipVisible();
    if (tooltipCreated) {
      Feedback.forLongPress(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    _config = _TooltipConfig.resolve(
      context: context,
      widget: widget,
      defaultTooltipWidth: _defaultTooltipWidthForPlatform(),
      defaultPadding: _defaultPaddingForPlatform(),
      defaultFontSize: _defaultFontSizeForPlatform(),
      defaultHorizontalOffset: _defaultHorizontalOffset,
      defaultPreferRight: _defaultPreferRight,
      defaultMargin: _defaultMargin,
      defaultExcludeFromSemantics: _defaultExcludeFromSemantics,
      defaultWaitDuration: _defaultWaitDuration,
      defaultShowDuration: _defaultShowDuration,
    );

    Widget content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: _handleLongPress,
      excludeFromSemantics: true,
      child: Semantics(
        label: _config.excludeFromSemantics ? null : widget.message,
        child: widget.child,
      ),
    );

    if (_mouseIsConnected) {
      content = MouseRegion(
        onEnter: (PointerEnterEvent event) => _showTooltip(),
        onExit: (PointerExitEvent event) => _hideTooltip(),
        child: content,
      );
    }

    return content;
  }
}

class _TooltipConfig {
  const _TooltipConfig({
    required this.width,
    required this.padding,
    required this.margin,
    required this.decoration,
    required this.textStyle,
    required this.horizontalOffset,
    required this.preferRight,
    required this.excludeFromSemantics,
    required this.waitDuration,
    required this.showDuration,
  });

  final double width;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Decoration decoration;
  final TextStyle textStyle;
  final double horizontalOffset;
  final bool preferRight;
  final bool excludeFromSemantics;
  final Duration waitDuration;
  final Duration showDuration;

  static _TooltipConfig resolve({
    required BuildContext context,
    required MongolTooltip widget,
    required double defaultTooltipWidth,
    required EdgeInsets defaultPadding,
    required double defaultFontSize,
    required double defaultHorizontalOffset,
    required bool defaultPreferRight,
    required EdgeInsetsGeometry defaultMargin,
    required bool defaultExcludeFromSemantics,
    required Duration defaultWaitDuration,
    required Duration defaultShowDuration,
  }) {
    final ThemeData theme = Theme.of(context);
    final TooltipThemeData tooltipTheme = TooltipTheme.of(context);
    final TextStyle defaultTextStyle;
    final BoxDecoration defaultDecoration;
    if (theme.brightness == Brightness.dark) {
      defaultTextStyle = theme.textTheme.bodyMedium!.copyWith(
        color: Colors.black,
        fontSize: defaultFontSize,
      );
      defaultDecoration = BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      );
    } else {
      defaultTextStyle = theme.textTheme.bodyMedium!.copyWith(
        color: Colors.white,
        fontSize: defaultFontSize,
      );
      defaultDecoration = BoxDecoration(
        color: Colors.grey[700]!.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      );
    }

    return _TooltipConfig(
      width: widget.width ??
          tooltipTheme.constraints?.minHeight ??
          defaultTooltipWidth,
      padding: widget.padding ?? tooltipTheme.padding ?? defaultPadding,
      margin: widget.margin ?? tooltipTheme.margin ?? defaultMargin,
      decoration:
          widget.decoration ?? tooltipTheme.decoration ?? defaultDecoration,
      textStyle: widget.textStyle ?? tooltipTheme.textStyle ?? defaultTextStyle,
      horizontalOffset: widget.horizontalOffset ??
          tooltipTheme.verticalOffset ??
          defaultHorizontalOffset,
      preferRight:
          widget.preferRight ?? tooltipTheme.preferBelow ?? defaultPreferRight,
      excludeFromSemantics: widget.excludeFromSemantics ??
          tooltipTheme.excludeFromSemantics ??
          defaultExcludeFromSemantics,
      waitDuration: widget.waitDuration ??
          tooltipTheme.waitDuration ??
          defaultWaitDuration,
      showDuration: widget.showDuration ??
          tooltipTheme.showDuration ??
          defaultShowDuration,
    );
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

  final String message;
  final double width;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Decoration? decoration;
  final TextStyle? textStyle;
  final Animation<double> animation;
  final Offset target;
  final double horizontalOffset;
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
