// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: omit_local_variable_types

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show
        InputBorder,
        Colors,
        VisualDensity,
        kMinInteractiveDimension,
        FloatingLabelBehavior,
        WidgetStateProperty,
        WidgetState,
        WidgetStateTextStyle,
        WidgetStateColor,
        WidgetStateBorderSide,
        InputDecoration,
        InputDecorationTheme,
        FloatingLabelAlignment,
        IconButtonTheme,
        IconButtonThemeData,
        IconButton,
        Theme,
        ColorScheme,
        ThemeData,
        TextTheme,
        Brightness;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' hide Text;

import '../base/mongol_text_align.dart';
import '../text/mongol_text.dart';
import 'alignment.dart';
import 'input_border.dart';

// 过渡动画持续时间
const Duration _kTransitionDuration = Duration(milliseconds: 200);
// 过渡动画曲线
const Curve _kTransitionCurve = Curves.fastOutSlowIn;
// 浮动标签的最终缩放比例
const double _kFinalLabelScale = 0.75;

// 提示文本淡入淡出过渡的默认持续时间
//
// 动画提示在 Material 规范中未提及。
// 该动画保留用于向后兼容，并使用较短的持续时间
// 以减轻用户体验的影响。
const Duration _kHintFadeTransitionDuration = Duration(milliseconds: 20);

/// 定义 MongolInputDecorator 轮廓边框中浮动标签出现的间隙
class _InputBorderGap extends ChangeNotifier {
  double? _start; // 间隙的起始位置

  /// 获取间隙的起始位置
  double? get start => _start;

  /// 设置间隙的起始位置，并通知监听器
  set start(double? value) {
    if (value != _start) {
      _start = value;
      notifyListeners();
    }
  }

  double _extent = 0.0; // 间隙的长度

  /// 获取间隙的长度
  double get extent => _extent;

  /// 设置间隙的长度，并通知监听器
  set extent(double value) {
    if (value != _extent) {
      _extent = value;
      notifyListeners();
    }
  }

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes, this class is not used in collection
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _InputBorderGap &&
        other.start == start &&
        other.extent == extent;
  }

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes, this class is not used in collection
  int get hashCode => Object.hash(start, extent);
}

/// 用于在两个 InputBorder 之间进行插值
class _InputBorderTween extends Tween<InputBorder> {
  /// 创建一个 _InputBorderTween，指定起始和结束边框
  _InputBorderTween({super.begin, super.end});

  @override
  /// 在指定的进度值 t 处插值两个边框
  InputBorder lerp(double t) => ShapeBorder.lerp(begin, end, t)! as InputBorder;
}

/// 将 _InputBorderGap 参数传递给 InputBorder 的 paint 方法
class _InputBorderPainter extends CustomPainter {
  /// 创建一个 _InputBorderPainter
  /// [repaint] - 用于触发重绘的可听对象
  /// [borderAnimation] - 边框动画
  /// [border] - 边框插值器
  /// [gapAnimation] - 间隙动画
  /// [gap] - 边框间隙信息
  /// [fillColor] - 填充颜色
  /// [hoverAnimation] - 悬停动画
  /// [hoverColorTween] - 悬停颜色插值器
  _InputBorderPainter({
    required Listenable repaint,
    required this.borderAnimation,
    required this.border,
    required this.gapAnimation,
    required this.gap,
    required this.fillColor,
    required this.hoverAnimation,
    required this.hoverColorTween,
  }) : super(repaint: repaint);

  final Animation<double> borderAnimation; // 边框动画
  final _InputBorderTween border; // 边框插值器
  final Animation<double> gapAnimation; // 间隙动画
  final _InputBorderGap gap; // 边框间隙信息
  final Color fillColor; // 填充颜色
  final ColorTween hoverColorTween; // 悬停颜色插值器
  final Animation<double> hoverAnimation; // 悬停动画

  /// 获取混合后的颜色（填充颜色与悬停颜色的混合）
  Color get blendedColor =>
      Color.alphaBlend(hoverColorTween.evaluate(hoverAnimation)!, fillColor);

  @override
  /// 绘制边框
  void paint(Canvas canvas, Size size) {
    final borderValue = border.evaluate(borderAnimation);
    final canvasRect = Offset.zero & size;
    final blendedFillColor = blendedColor;
    if (blendedFillColor.a > 0) {
      canvas.drawPath(
        borderValue.getOuterPath(canvasRect, textDirection: TextDirection.ltr),
        Paint()
          ..color = blendedFillColor
          ..style = PaintingStyle.fill,
      );
    }

    borderValue.paint(
      canvas,
      canvasRect,
      gapStart: gap.start,
      gapExtent: gap.extent,
      gapPercentage: gapAnimation.value,
      textDirection: TextDirection.ltr,
    );
  }

  @override
  /// 确定是否需要重绘
  bool shouldRepaint(_InputBorderPainter oldPainter) {
    return borderAnimation != oldPainter.borderAnimation ||
        hoverAnimation != oldPainter.hoverAnimation ||
        gapAnimation != oldPainter.gapAnimation ||
        border != oldPainter.border ||
        gap != oldPainter.gap;
  }
}

/// 类似于 AnimatedContainer 的组件，用于为 _InputBorder 动画化其形状边框
/// 这个专门的动画容器是必需的，因为在布局时计算的 _InputBorderGap
/// 是 _InputBorder 的 paint 方法所必需的
class _BorderContainer extends StatefulWidget {
  /// 创建一个 _BorderContainer
  /// [border] - 输入边框
  /// [gap] - 边框间隙信息
  /// [gapAnimation] - 间隙动画
  /// [fillColor] - 填充颜色
  /// [hoverColor] - 悬停颜色
  /// [isHovering] - 是否处于悬停状态
  /// [child] - 子组件
  const _BorderContainer({
    required this.border,
    required this.gap,
    required this.gapAnimation,
    required this.fillColor,
    required this.hoverColor,
    required this.isHovering,
    // ignore: unused_element_parameter
    this.child,
  });

  final InputBorder border; // 输入边框
  final _InputBorderGap gap; // 边框间隙信息
  final Animation<double> gapAnimation; // 间隙动画
  final Color fillColor; // 填充颜色
  final Color hoverColor; // 悬停颜色
  final bool isHovering; // 是否处于悬停状态
  final Widget? child; // 子组件

  @override
  _BorderContainerState createState() => _BorderContainerState();
}

class _BorderContainerState extends State<_BorderContainer>
    with TickerProviderStateMixin {
  static const Duration _kHoverDuration = Duration(milliseconds: 15); // 悬停动画持续时间

  late AnimationController _controller; // 边框动画控制器
  late AnimationController _hoverColorController; // 悬停颜色动画控制器
  late Animation<double> _borderAnimation; // 边框动画
  late _InputBorderTween _border; // 边框插值器
  late Animation<double> _hoverAnimation; // 悬停动画
  late ColorTween _hoverColorTween; // 悬停颜色插值器

  @override
  void initState() {
    super.initState();
    // 初始化悬停颜色动画控制器
    _hoverColorController = AnimationController(
      duration: _kHoverDuration,
      value: widget.isHovering ? 1.0 : 0.0,
      vsync: this,
    );
    // 初始化边框动画控制器
    _controller = AnimationController(
      duration: _kTransitionDuration,
      vsync: this,
    );
    // 创建边框动画
    _borderAnimation = CurvedAnimation(
      parent: _controller,
      curve: _kTransitionCurve,
    );
    // 创建边框插值器
    _border = _InputBorderTween(
      begin: widget.border,
      end: widget.border,
    );
    // 创建悬停动画
    _hoverAnimation = CurvedAnimation(
      parent: _hoverColorController,
      curve: Curves.linear,
    );
    // 创建悬停颜色插值器
    _hoverColorTween =
        ColorTween(begin: Colors.transparent, end: widget.hoverColor);
  }

  @override
  void dispose() {
    _controller.dispose();
    _hoverColorController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_BorderContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 处理边框变化
    if (widget.border != oldWidget.border) {
      _border = _InputBorderTween(
        begin: oldWidget.border,
        end: widget.border,
      );
      _controller
        ..value = 0.0
        ..forward();
    }
    // 处理悬停颜色变化
    if (widget.hoverColor != oldWidget.hoverColor) {
      _hoverColorTween =
          ColorTween(begin: Colors.transparent, end: widget.hoverColor);
    }
    // 处理悬停状态变化
    if (widget.isHovering != oldWidget.isHovering) {
      if (widget.isHovering) {
        _hoverColorController.forward();
      } else {
        _hoverColorController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _InputBorderPainter(
        repaint: Listenable.merge(<Listenable>[
          _borderAnimation,
          widget.gap,
          _hoverColorController,
        ]),
        borderAnimation: _borderAnimation,
        border: _border,
        gapAnimation: widget.gapAnimation,
        gap: widget.gap,
        fillColor: widget.fillColor,
        hoverColorTween: _hoverColorTween,
        hoverAnimation: _hoverAnimation,
      ),
      child: widget.child,
    );
  }
}

/// 用于当 errorText 首次出现时，使浮动标签上下“摇晃”
class _Shaker extends AnimatedWidget {
  /// 创建一个 _Shaker
  /// [animation] - 动画控制器
  /// [child] - 要摇晃的子组件
  const _Shaker({
    required Animation<double> animation,
    this.child,
  }) : super(listenable: animation);

  final Widget? child; // 要摇晃的子组件

  /// 获取动画对象
  Animation<double> get animation => listenable as Animation<double>;

  /// 计算 Y 轴方向的偏移量，实现摇晃效果
  double get translateY {
    const shakeDelta = 4.0; // 摇晃幅度
    final t = animation.value; // 动画进度
    if (t <= 0.25) {
      return -t * shakeDelta; // 向上移动
    } else if (t < 0.75) {
      return (t - 0.5) * shakeDelta; // 向下移动
    } else {
      return (1.0 - t) * 4.0 * shakeDelta; // 快速回到原位
    }
  }

  @override
  /// 构建摇晃效果的组件
  Widget build(BuildContext context) {
    return Transform(
      transform: Matrix4.translationValues(0.0, translateY, 0.0),
      child: child,
    );
  }
}

/// 显示辅助文本和错误文本。当错误文本出现时
/// 它会淡入，而辅助文本会淡出。错误文本首次出现时还会
/// 向左滑动一点
class _HelperError extends StatefulWidget {
  /// 创建一个 _HelperError
  /// [textAlign] - 文本对齐方式
  /// [helperText] - 辅助文本
  /// [helperStyle] - 辅助文本样式
  /// [helperMaxLines] - 辅助文本最大行数
  /// [error] - 错误组件
  /// [errorText] - 错误文本
  /// [errorStyle] - 错误文本样式
  /// [errorMaxLines] - 错误文本最大行数
  const _HelperError({
    this.textAlign,
    this.helperText,
    this.helperStyle,
    this.helperMaxLines,
    this.error,
    this.errorText,
    this.errorStyle,
    this.errorMaxLines,
  });

  final MongolTextAlign? textAlign; // 文本对齐方式
  final String? helperText; // 辅助文本
  final TextStyle? helperStyle; // 辅助文本样式
  final int? helperMaxLines; // 辅助文本最大行数
  final Widget? error; // 错误组件
  final String? errorText; // 错误文本
  final TextStyle? errorStyle; // 错误文本样式
  final int? errorMaxLines; // 错误文本最大行数

  @override
  _HelperErrorState createState() => _HelperErrorState();
}

class _HelperErrorState extends State<_HelperError>
    with SingleTickerProviderStateMixin {
  // 如果在布局时此 widget 和计数器的宽度为零（"空"），则不为子文本分配空间
  static const Widget empty = SizedBox();

  late AnimationController _controller; // 动画控制器
  Widget? _helper; // 辅助文本组件
  Widget? _error; // 错误文本组件

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: _kTransitionDuration,
      vsync: this,
    );
    // 初始化显示错误文本或辅助文本
    if (widget.errorText != null) {
      _error = _buildError();
      _controller.value = 1.0;
    } else if (widget.helperText != null) {
      _helper = _buildHelper();
    }
    _controller.addListener(_handleChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 处理动画值变化
  void _handleChange() {
    setState(() {
      // _controller 的值已更改
    });
  }

  @override
  void didUpdateWidget(_HelperError old) {
    super.didUpdateWidget(old);

    final newErrorText = widget.errorText;
    final newHelperText = widget.helperText;
    final oldErrorText = old.errorText;
    final oldHelperText = old.helperText;

    // 检查错误文本状态是否变化
    final errorTextStateChanged =
        (newErrorText != null) != (oldErrorText != null);
    // 检查辅助文本状态是否变化（仅当没有错误文本时）
    final helperTextStateChanged = newErrorText == null &&
        (newHelperText != null) != (oldHelperText != null);

    // 根据状态变化处理动画
    if (errorTextStateChanged || helperTextStateChanged) {
      if (newErrorText != null) {
        _error = _buildError();
        _controller.forward(); // 显示错误文本
      } else if (newHelperText != null) {
        _helper = _buildHelper();
        _controller.reverse(); // 显示辅助文本
      } else {
        _controller.reverse(); // 隐藏所有文本
      }
    }
  }

  /// 构建辅助文本组件
  Widget _buildHelper() {
    assert(widget.helperText != null);
    return Semantics(
      container: true,
      child: Opacity(
        opacity: 1.0 - _controller.value, // 随动画逐渐显示/隐藏
        child: MongolText(
          widget.helperText!,
          style: widget.helperStyle,
          textAlign: widget.textAlign,
          overflow: TextOverflow.ellipsis,
          maxLines: widget.helperMaxLines,
        ),
      ),
    );
  }

  /// 构建错误文本组件
  Widget _buildError() {
    assert(widget.errorText != null);
    return Semantics(
      container: true,
      liveRegion: true, // 使屏幕阅读器能够读取错误信息
      child: Opacity(
        opacity: _controller.value, // 随动画逐渐显示/隐藏
        child: FractionalTranslation(
          translation: Tween<Offset>(
            begin: const Offset(-0.25, 0.0), // 起始位置（向左偏移）
            end: const Offset(0.0, 0.0), // 结束位置（正常位置）
          ).evaluate(_controller.view),
          child: MongolText(
            widget.errorText!,
            style: widget.errorStyle,
            textAlign: widget.textAlign,
            overflow: TextOverflow.ellipsis,
            maxLines: widget.errorMaxLines,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isDismissed) {
      _error = null;
      if (widget.helperText != null) {
        return _helper = _buildHelper();
      } else {
        _helper = null;
        return empty;
      }
    }

    if (_controller.isCompleted) {
      _helper = null;
      if (widget.errorText != null) {
        return _error = _buildError();
      } else {
        _error = null;
        return empty;
      }
    }

    if (_helper == null && widget.errorText != null) return _buildError();

    if (_error == null && widget.helperText != null) return _buildHelper();

    if (widget.errorText != null) {
      return Stack(
        children: <Widget>[
          Opacity(
            opacity: 1.0 - _controller.value,
            child: _helper,
          ),
          _buildError(),
        ],
      );
    }

    if (widget.helperText != null) {
      return Stack(
        children: <Widget>[
          _buildHelper(),
          Opacity(
            opacity: _controller.value,
            child: _error,
          ),
        ],
      );
    }

    return empty;
  }
}

/// 为 FloatingLabelAlignment 添加垂直方向的对齐值
/// 类似于 FloatingLabelAlignment 源码中的 _x 属性
/// 用于控制浮动标签的垂直位置
extension MongolFloatingLabelAlignment on FloatingLabelAlignment {
  /// 获取垂直方向的对齐值
  /// start: -1.0（顶部）
  /// center: 0.0（居中）
  double get _y => (this == FloatingLabelAlignment.start) ? -1.0 : 0.0;
}

/// 标识 _RenderDecorationElement 的子组件
/// 用于在布局和绘制过程中引用不同的子组件
enum _DecorationSlot {
  icon, // 图标
  input, // 输入框
  label, // 标签
  hint, // 提示文本
  prefix, // 前缀
  suffix, // 后缀
  prefixIcon, // 前缀图标
  suffixIcon, // 后缀图标
  helperError, // 辅助/错误文本
  counter, // 计数器
  container, // 容器
}

/// _Decorator 组件的 InputDecoration 类似物
/// 用于存储输入框装饰相关的所有属性
@immutable
class _Decoration {
  /// 创建一个 _Decoration
  /// [contentPadding] - 内容内边距
  /// [isCollapsed] - 是否折叠
  /// [floatingLabelWidth] - 浮动标签宽度
  /// [floatingLabelProgress] - 浮动标签动画进度
  /// [floatingLabelAlignment] - 浮动标签对齐方式
  /// [border] - 边框
  /// [borderGap] - 边框间隙
  /// [alignLabelWithHint] - 是否将标签与提示文本对齐
  /// [isDense] - 是否使用紧凑布局
  /// [visualDensity] - 视觉密度
  /// [icon] - 图标
  /// [input] - 输入框
  /// [label] - 标签
  /// [hint] - 提示文本
  /// [prefix] - 前缀
  /// [suffix] - 后缀
  /// [prefixIcon] - 前缀图标
  /// [suffixIcon] - 后缀图标
  /// [helperError] - 辅助/错误文本
  /// [counter] - 计数器
  /// [container] - 容器
  const _Decoration({
    required this.contentPadding,
    required this.isCollapsed,
    required this.floatingLabelWidth,
    required this.floatingLabelProgress,
    required this.floatingLabelAlignment,
    this.border,
    this.borderGap,
    required this.alignLabelWithHint,
    required this.isDense,
    this.visualDensity,
    this.icon,
    this.input,
    this.label,
    this.hint,
    this.prefix,
    this.suffix,
    this.prefixIcon,
    this.suffixIcon,
    this.helperError,
    this.counter,
    this.container,
  });

  final EdgeInsetsGeometry contentPadding; // 内容内边距
  final bool isCollapsed; // 是否折叠
  final double floatingLabelWidth; // 浮动标签宽度
  final double floatingLabelProgress; // 浮动标签动画进度
  final FloatingLabelAlignment floatingLabelAlignment; // 浮动标签对齐方式
  final InputBorder? border; // 边框
  final _InputBorderGap? borderGap; // 边框间隙
  final bool alignLabelWithHint; // 是否将标签与提示文本对齐
  final bool? isDense; // 是否使用紧凑布局
  final VisualDensity? visualDensity; // 视觉密度
  final Widget? icon; // 图标
  final Widget? input; // 输入框
  final Widget? label; // 标签
  final Widget? hint; // 提示文本
  final Widget? prefix; // 前缀
  final Widget? suffix; // 后缀
  final Widget? prefixIcon; // 前缀图标
  final Widget? suffixIcon; // 后缀图标
  final Widget? helperError; // 辅助/错误文本
  final Widget? counter; // 计数器
  final Widget? container; // 容器

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _Decoration &&
        other.contentPadding == contentPadding &&
        other.isCollapsed == isCollapsed &&
        other.floatingLabelWidth == floatingLabelWidth &&
        other.floatingLabelProgress == floatingLabelProgress &&
        other.floatingLabelAlignment == floatingLabelAlignment &&
        other.border == border &&
        other.borderGap == borderGap &&
        other.alignLabelWithHint == alignLabelWithHint &&
        other.isDense == isDense &&
        other.visualDensity == visualDensity &&
        other.icon == icon &&
        other.input == input &&
        other.label == label &&
        other.hint == hint &&
        other.prefix == prefix &&
        other.suffix == suffix &&
        other.prefixIcon == prefixIcon &&
        other.suffixIcon == suffixIcon &&
        other.helperError == helperError &&
        other.counter == counter &&
        other.container == container;
  }

  @override
  int get hashCode => Object.hash(
        contentPadding,
        floatingLabelWidth,
        floatingLabelProgress,
        floatingLabelAlignment,
        border,
        borderGap,
        alignLabelWithHint,
        isDense,
        visualDensity,
        icon,
        input,
        label,
        hint,
        prefix,
        suffix,
        prefixIcon,
        suffixIcon,
        helperError,
        counter,
        container,
      );
}

/// 存储 _RenderDecoration._layout 计算的布局值的容器
/// 这些值被 _RenderDecoration.performLayout 用于定位
/// _RenderDecoration 的所有渲染子项
class _RenderDecorationLayout {
  /// 创建一个 _RenderDecorationLayout
  /// [boxToBaseline] - 存储每个渲染框与其基线偏移的映射
  /// [inputBaseline] - 输入框的基线位置
  /// [outlineBaseline] - 轮廓边框的基线位置
  /// [subtextBaseline] - 子文本（辅助/错误/计数器）的基线位置
  /// [containerWidth] - 容器宽度
  /// [subtextWidth] - 子文本宽度
  const _RenderDecorationLayout({
    required this.boxToBaseline,
    required this.inputBaseline,
    required this.outlineBaseline,
    required this.subtextBaseline,
    required this.containerWidth,
    required this.subtextWidth,
  });

  final Map<RenderBox?, double> boxToBaseline; // 存储每个渲染框与其基线偏移的映射
  final double inputBaseline; // 输入框的基线位置
  final double outlineBaseline; // 轮廓边框的基线位置
  final double subtextBaseline; // 子文本（辅助/错误/计数器）的基线位置
  final double containerWidth; // 容器宽度
  final double subtextWidth; // 子文本宽度
}

/// 核心类：负责布局和绘制 _Decorator 组件的 _Decoration
class _RenderDecoration extends RenderBox
    with SlottedContainerRenderObjectMixin<_DecorationSlot, RenderBox> {
  /// 创建一个 _RenderDecoration
  /// [decoration] - 装饰信息
  /// [textBaseline] - 文本基线
  /// [isFocused] - 是否聚焦
  /// [expands] - 是否展开
  /// [isEmpty] - 是否为空
  /// [textAlignHorizontal] - 水平文本对齐方式
  _RenderDecoration({
    required _Decoration decoration,
    required TextBaseline textBaseline,
    required bool isFocused,
    required bool expands,
    required bool isEmpty,
    TextAlignHorizontal? textAlignHorizontal,
  })  : _decoration = decoration,
        _textBaseline = textBaseline,
        _textAlignHorizontal = textAlignHorizontal,
        _isFocused = isFocused,
        _expands = expands,
        _isEmpty = isEmpty;

  static const double subtextGap = 8.0; // 子文本（辅助/错误/计数器）之间的间隙

  /// 获取图标子组件
  RenderBox? get icon => childForSlot(_DecorationSlot.icon);

  /// 获取输入框子组件
  RenderBox? get input => childForSlot(_DecorationSlot.input);

  /// 获取标签子组件
  RenderBox? get label => childForSlot(_DecorationSlot.label);

  /// 获取提示文本子组件
  RenderBox? get hint => childForSlot(_DecorationSlot.hint);

  /// 获取前缀子组件
  RenderBox? get prefix => childForSlot(_DecorationSlot.prefix);

  /// 获取后缀子组件
  RenderBox? get suffix => childForSlot(_DecorationSlot.suffix);

  /// 获取前缀图标子组件
  RenderBox? get prefixIcon => childForSlot(_DecorationSlot.prefixIcon);

  /// 获取后缀图标子组件
  RenderBox? get suffixIcon => childForSlot(_DecorationSlot.suffixIcon);

  /// 获取辅助/错误文本子组件
  RenderBox? get helperError => childForSlot(_DecorationSlot.helperError);

  /// 获取计数器子组件
  RenderBox? get counter => childForSlot(_DecorationSlot.counter);

  /// 获取容器子组件
  RenderBox? get container => childForSlot(_DecorationSlot.container);

  /// 返回用于命中测试的子组件列表（按顺序）
  @override
  Iterable<RenderBox> get children {
    return <RenderBox>[
      if (icon != null) icon!,
      if (input != null) input!,
      if (prefixIcon != null) prefixIcon!,
      if (suffixIcon != null) suffixIcon!,
      if (prefix != null) prefix!,
      if (suffix != null) suffix!,
      if (label != null) label!,
      if (hint != null) hint!,
      if (helperError != null) helperError!,
      if (counter != null) counter!,
      if (container != null) container!,
    ];
  }

  /// 获取装饰信息
  _Decoration get decoration => _decoration;
  _Decoration _decoration; // 装饰信息

  /// 设置装饰信息
  set decoration(_Decoration value) {
    if (_decoration == value) {
      return;
    }
    _decoration = value;
    markNeedsLayout();
  }

  /// 获取文本基线
  TextBaseline get textBaseline => _textBaseline;
  TextBaseline _textBaseline; // 文本基线

  /// 设置文本基线
  set textBaseline(TextBaseline value) {
    if (_textBaseline == value) {
      return;
    }
    _textBaseline = value;
    markNeedsLayout();
  }

  /// 获取默认的水平文本对齐方式
  /// 当使用轮廓边框时居中对齐，否则左对齐
  TextAlignHorizontal get _defaultTextAlignHorizontal =>
      _isOutlineAligned ? TextAlignHorizontal.center : TextAlignHorizontal.left;

  /// 获取水平文本对齐方式
  TextAlignHorizontal? get textAlignHorizontal =>
      _textAlignHorizontal ?? _defaultTextAlignHorizontal;
  TextAlignHorizontal? _textAlignHorizontal; // 水平文本对齐方式

  /// 设置水平文本对齐方式
  set textAlignHorizontal(TextAlignHorizontal? value) {
    if (_textAlignHorizontal == value) {
      return;
    }
    // 如果有效值仍然相同，则不需要重新布局
    if (textAlignHorizontal!.x == (value?.x ?? _defaultTextAlignHorizontal.x)) {
      _textAlignHorizontal = value;
      return;
    }
    _textAlignHorizontal = value;
    markNeedsLayout();
  }

  /// 获取是否聚焦
  bool get isFocused => _isFocused;
  bool _isFocused; // 是否聚焦

  /// 设置是否聚焦
  set isFocused(bool value) {
    if (_isFocused == value) {
      return;
    }
    _isFocused = value;
    markNeedsSemanticsUpdate();
  }

  /// 获取是否展开
  bool get expands => _expands;
  bool _expands = false; // 是否展开

  /// 设置是否展开
  set expands(bool value) {
    if (_expands == value) {
      return;
    }
    _expands = value;
    markNeedsLayout();
  }

  /// 获取是否为空
  bool get isEmpty => _isEmpty;
  bool _isEmpty = false; // 是否为空

  /// 设置是否为空
  set isEmpty(bool value) {
    if (_isEmpty == value) {
      return;
    }
    _isEmpty = value;
    markNeedsLayout();
  }

  /// 指示装饰是否应对齐以适应轮廓边框
  bool get _isOutlineAligned {
    return !decoration.isCollapsed && decoration.border!.isOutline;
  }

  @override
  /// 访问语义子节点
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (icon != null) {
      visitor(icon!);
    }
    if (prefix != null) {
      visitor(prefix!);
    }
    if (prefixIcon != null) {
      visitor(prefixIcon!);
    }

    if (label != null) {
      visitor(label!);
    }
    if (hint != null) {
      if (isFocused) {
        visitor(hint!);
      } else if (label == null) {
        visitor(hint!);
      }
    }

    if (input != null) {
      visitor(input!);
    }
    if (suffixIcon != null) {
      visitor(suffixIcon!);
    }
    if (suffix != null) {
      visitor(suffix!);
    }
    if (container != null) {
      visitor(container!);
    }
    if (helperError != null) {
      visitor(helperError!);
    }
    if (counter != null) {
      visitor(counter!);
    }
  }

  @override
  /// 布局是否由父节点决定
  bool get sizedByParent => false;

  /// 获取渲染框的最小高度
  static double _minHeight(RenderBox? box, double width) {
    return box == null ? 0.0 : box.getMinIntrinsicHeight(width);
  }

  /// 获取渲染框的最大高度
  static double _maxHeight(RenderBox? box, double width) {
    return box == null ? 0.0 : box.getMaxIntrinsicHeight(width);
  }

  /// 获取渲染框的最小宽度
  static double _minWidth(RenderBox? box, double height) {
    return box == null ? 0.0 : box.getMinIntrinsicWidth(height);
  }

  /// 获取渲染框的大小
  static Size _boxSize(RenderBox? box) => box == null ? Size.zero : box.size;

  /// 获取渲染框的父数据
  static BoxParentData _boxParentData(RenderBox box) =>
      box.parentData! as BoxParentData;

  /// 获取内容内边距
  EdgeInsets get contentPadding => decoration.contentPadding as EdgeInsets;

  /// 布局给定的渲染框（如果需要），并返回其基线
  double _layoutLineBox(RenderBox? box, BoxConstraints constraints) {
    if (box == null) {
      return 0.0;
    }
    box.layout(constraints, parentUsesSize: true);
    // 由于内部所有布局都是相对于字母基线执行的，
    // （例如，上升/下降都相对于字母基线，即使字体是表意文字或悬挂字体），
    // 我们应该始终从字母基线获取参考基线。表意文字基线用于
    // 布局后，是从字母基线结合字体度量派生的。
    final double baseline = box.getDistanceToBaseline(TextBaseline.alphabetic)!;

    assert(() {
      if (baseline >= 0) {
        return true;
      }
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary(
            "MongolInputDecorator 的一个子项报告了负基线偏移。"),
        ErrorDescription(
          '${box.runtimeType}，大小为 ${box.size}，报告了负的 '
          '字母基线 $baseline。',
        ),
      ]);
    }());
    return baseline;
  }

  /// 获取空列的宽度
  /// 这等于一个垂直列的前进量
  double _emptyColumnWidth(RenderBox input) {
    return input.getMaxIntrinsicHeight(double.infinity);
  }

  /// 返回 performLayout 用于定位所有渲染器的值
  /// 此方法对除容器之外的所有渲染器应用布局
  /// 为方便起见，容器在 performLayout() 中布局
  _RenderDecorationLayout _layout(BoxConstraints layoutConstraints) {
    assert(
      layoutConstraints.maxHeight < double.infinity,
      'MongolInputDecorator（通常由 MongolTextField 创建）不能有无限高度。\n'
      '当父组件没有提供有限的高度约束时会发生这种情况。例如，如果 MongolInputDecorator 包含在 Column 中，\n'
      '则其高度必须受到约束。可以使用 Expanded 组件或 SizedBox\n'
      '来约束 MongolInputDecorator 或包含它的 MongolTextField 的高度。',
    );

    // 子文本（计数器和辅助/错误文本）每侧的边距
    final Map<RenderBox?, double> boxToBaseline = <RenderBox?, double>{};
    final BoxConstraints boxConstraints = layoutConstraints.loosen();

    // 布局 MongolInputDecorator 使用的所有组件
    boxToBaseline[icon] = _layoutLineBox(icon, boxConstraints);
    final BoxConstraints containerConstraints = boxConstraints.copyWith(
      maxHeight: boxConstraints.maxHeight - _boxSize(icon).height,
    );
    boxToBaseline[prefixIcon] =
        _layoutLineBox(prefixIcon, containerConstraints);
    boxToBaseline[suffixIcon] =
        _layoutLineBox(suffixIcon, containerConstraints);
    final BoxConstraints contentConstraints = containerConstraints.copyWith(
      maxHeight: containerConstraints.maxHeight - contentPadding.vertical,
    );
    boxToBaseline[prefix] = _layoutLineBox(prefix, contentConstraints);
    boxToBaseline[suffix] = _layoutLineBox(suffix, contentConstraints);

    // 计算输入框高度
    final double inputHeight = math.max(
      0.0,
      constraints.maxHeight -
          (_boxSize(icon).height +
              contentPadding.top +
              _boxSize(prefixIcon).height +
              _boxSize(prefix).height +
              _boxSize(suffix).height +
              _boxSize(suffixIcon).height +
              contentPadding.bottom),
    );
    // 当标签缩小时，增加可用高度
    final double invertedLabelScale = lerpDouble(
        1.00, 1 / _kFinalLabelScale, decoration.floatingLabelProgress)!;
    double suffixIconHeight = _boxSize(suffixIcon).height;
    if (decoration.border!.isOutline) {
      suffixIconHeight =
          lerpDouble(suffixIconHeight, 0.0, decoration.floatingLabelProgress)!;
    }
    // 计算标签高度
    final double labelHeight = math.max(
      0.0,
      constraints.maxHeight -
          (_boxSize(icon).height +
              contentPadding.top +
              _boxSize(prefixIcon).height +
              suffixIconHeight +
              contentPadding.bottom),
    );
    boxToBaseline[label] = _layoutLineBox(
      label,
      boxConstraints.copyWith(maxHeight: labelHeight * invertedLabelScale),
    );
    boxToBaseline[counter] = _layoutLineBox(counter, contentConstraints);

    // 辅助或错误文本可以占据除图标和计数器占用空间之外的全部高度
    boxToBaseline[helperError] = _layoutLineBox(
      helperError,
      contentConstraints.copyWith(
        maxHeight: math.max(
            0.0, contentConstraints.maxHeight - _boxSize(counter).height),
      ),
    );

    // 输入框的宽度需要容纳左侧的标签和右侧的计数器及辅助/错误文本（如果存在）
    final double labelWidth = label == null ? 0 : decoration.floatingLabelWidth;
    final double leftWidth = decoration.border!.isOutline
        ? math.max(labelWidth - boxToBaseline[label]!, 0)
        : labelWidth;
    final double counterWidth =
        counter == null ? 0 : boxToBaseline[counter]! + subtextGap;
    final bool helperErrorExists =
        helperError?.size != null && helperError!.size.width > 0;
    final double helperErrorWidth =
        !helperErrorExists ? 0 : helperError!.size.width + subtextGap;
    final double rightWidth = math.max(
      counterWidth,
      helperErrorWidth,
    );
    final Offset densityOffset = decoration.visualDensity!.baseSizeAdjustment;

    // 布局提示文本
    boxToBaseline[hint] = _layoutLineBox(
      hint,
      boxConstraints
          .deflate(EdgeInsets.only(
            left: contentPadding.left + leftWidth + densityOffset.dx / 2,
            right: contentPadding.right + rightWidth + densityOffset.dx / 2,
          ))
          .copyWith(
            minHeight: inputHeight,
            maxHeight: inputHeight,
          ),
    );

    // 布局输入框
    boxToBaseline[input] = _layoutLineBox(
      input,
      boxConstraints
          .deflate(EdgeInsets.only(
            left: contentPadding.left + leftWidth + densityOffset.dx / 2,
            right: contentPadding.right + rightWidth + densityOffset.dx / 2,
          ))
          .copyWith(
            minHeight: inputHeight,
            maxHeight: inputHeight,
          ),
    );

    // 字段可以被提示文本或输入框本身占用
    final double hintWidth = hint == null ? 0 : hint!.size.width;
    final double inputDirectWidth = input == null ? 0 : input!.size.width;

    final bool isFullyEmpty = inputDirectWidth == 0 && hintWidth == 0;

    final double inputWidth = isFullyEmpty && input != null
        ? _emptyColumnWidth(input!)
        : math.max(hintWidth, inputDirectWidth);

    final double inputInternalBaseline = math.max(
      boxToBaseline[input]!,
      boxToBaseline[hint]!,
    );

    // 计算前缀/后缀对输入框上下高度的影响
    final double prefixWidth = prefix?.size.width ?? 0;
    final double suffixWidth = suffix?.size.width ?? 0;
    final double fixWidth = math.max(
      boxToBaseline[prefix]!,
      boxToBaseline[suffix]!,
    );
    final double fixLeftOfInput = math.max(0, fixWidth - inputInternalBaseline);
    final double fixRightOfBaseline = math.max(
      prefixWidth - boxToBaseline[prefix]!,
      suffixWidth - boxToBaseline[suffix]!,
    );
    final double fixRightOfInput = math.max(
      0,
      fixRightOfBaseline - (inputWidth - inputInternalBaseline),
    );

    // 计算输入文本容器的宽度
    final double prefixIconWidth =
        prefixIcon == null ? 0 : prefixIcon!.size.width;
    final double suffixIconWidth =
        suffixIcon == null ? 0 : suffixIcon!.size.width;
    final double fixIconWidth = math.max(prefixIconWidth, suffixIconWidth);
    final double contentWidth = math.max(
      fixIconWidth,
      leftWidth +
          contentPadding.left +
          fixLeftOfInput +
          inputWidth +
          fixRightOfInput +
          contentPadding.right +
          densityOffset.dx,
    );
    final double minContainerWidth =
        decoration.isDense! || decoration.isCollapsed || expands
            ? 0.0
            : kMinInteractiveDimension;
    final double maxContainerWidth = boxConstraints.maxWidth - rightWidth;
    final double containerWidth = expands
        ? maxContainerWidth
        : math.min(
            math.max(contentWidth, minContainerWidth), maxContainerWidth);

    // 确保在内容短于 kMinInteractiveDimension 的情况下文本水平居中
    final double interactiveAdjustment = minContainerWidth > contentWidth
        ? (minContainerWidth - contentWidth) / 2.0
        : 0.0;

    // 尝试在对齐时将前缀/后缀视为文本的一部分
    // 但是，如果前缀/后缀溢出，允许其延伸到输入框外部，并对齐文本和前缀/后缀的其余部分
    final double overflow = math.max(0, contentWidth - maxContainerWidth);
    // 将 textAlignHorizontal 从 -1:1 映射到 0:1，以便可以用于将基线从最小值缩放到最大值
    final double textAlignHorizontalFactor =
        (textAlignHorizontal!.x + 1.0) / 2.0;
    // 调整以尝试在 textAlignHorizontal 的反向上适应输入框内的左侧溢出，
    // 以便左对齐文本调整最多，右对齐文本完全不调整
    final double baselineAdjustment =
        fixLeftOfInput - overflow * (1 - textAlignHorizontalFactor);

    // 将用于绘制实际输入文本内容的基线
    final double leftInputBaseline = contentPadding.left +
        leftWidth +
        inputInternalBaseline +
        baselineAdjustment +
        interactiveAdjustment;
    final double maxContentWidth =
        containerWidth - contentPadding.left - leftWidth - contentPadding.right;
    final double alignableWidth = fixLeftOfInput + inputWidth + fixRightOfInput;
    final double maxHorizontalOffset = maxContentWidth - alignableWidth;
    final double textAlignHorizontalOffset =
        maxHorizontalOffset * textAlignHorizontalFactor;
    final double inputBaseline =
        leftInputBaseline + textAlignHorizontalOffset + densityOffset.dx / 2.0;

    // 当存在轮廓时，基线的三个主要对齐方式是：
    //
    //  * left (-1.0)：考虑内边距的最左侧点
    //  * center (0.0)：输入框的绝对中心，忽略内边距但适应边框和浮动标签
    //  * right (1.0)：考虑内边距的最右侧点
    //
    // 这意味着如果内边距不均匀，中心不是左右的精确中点
    // 为了解决这个问题，中心左侧和右侧的对齐是独立插值的
    final double outlineCenterBaseline = inputInternalBaseline +
        baselineAdjustment / 2.0 +
        (containerWidth - (2.0 + inputWidth)) / 2.0;
    final double outlineLeftBaseline = leftInputBaseline;
    final double outlineRightBaseline = leftInputBaseline + maxHorizontalOffset;
    final double outlineBaseline = _interpolateThree(
      outlineLeftBaseline,
      outlineCenterBaseline,
      outlineRightBaseline,
      textAlignHorizontal!,
    );

    // 找到输入框下方文本的位置（如果存在）
    double subtextCounterBaseline = 0;
    double subtextHelperBaseline = 0;
    double subtextCounterWidth = 0;
    double subtextHelperWidth = 0;
    if (counter != null) {
      subtextCounterBaseline =
          containerWidth + subtextGap + boxToBaseline[counter]!;
      subtextCounterWidth = counter!.size.width + subtextGap;
    }
    if (helperErrorExists) {
      subtextHelperBaseline =
          containerWidth + subtextGap + boxToBaseline[helperError]!;
      subtextHelperWidth = helperErrorWidth;
    }
    final double subtextBaseline = math.max(
      subtextCounterBaseline,
      subtextHelperBaseline,
    );
    final double subtextWidth = math.max(
      subtextCounterWidth,
      subtextHelperWidth,
    );

    return _RenderDecorationLayout(
      boxToBaseline: boxToBaseline,
      containerWidth: containerWidth,
      inputBaseline: inputBaseline,
      outlineBaseline: outlineBaseline,
      subtextBaseline: subtextBaseline,
      subtextWidth: subtextWidth,
    );
  }

  /// 使用 textAlignHorizontal 在三个停止点之间进行插值
  /// 这用于计算轮廓基线，当对齐方式为中间时忽略内边距
  /// 当对齐方式小于零时，在居中文本框的左侧和内容内边距的左侧之间进行插值
  /// 当对齐方式大于零时，在居中框的左侧和使框的右侧与右侧内边距对齐的位置之间进行插值
  double _interpolateThree(double begin, double middle, double end,
      TextAlignHorizontal textAlignHorizontal) {
    if (textAlignHorizontal.x <= 0) {
      // 由于过度内边距，begin、middle 和 end 可能不按顺序排列
      // 这些情况通过使用 middle 来处理
      if (begin >= middle) {
        return middle;
      }
      // 在第一半（begin 和 middle 之间）进行标准线性插值
      final double t = textAlignHorizontal.x + 1;
      return begin + (middle - begin) * t;
    }

    if (middle >= end) {
      return middle;
    }
    // 在第二半（middle 和 end 之间）进行标准线性插值
    final double t = textAlignHorizontal.x;
    return middle + (end - middle) * t;
  }

  @override
  /// 计算最小内在高度
  double computeMinIntrinsicHeight(double width) {
    return _minHeight(icon, width) +
        contentPadding.top +
        _minHeight(prefixIcon, width) +
        _minHeight(prefix, width) +
        math.max(_minHeight(input, width), _minHeight(hint, width)) +
        _minHeight(suffix, width) +
        _minHeight(suffixIcon, width) +
        contentPadding.bottom;
  }

  @override
  /// 计算最大内在高度
  double computeMaxIntrinsicHeight(double width) {
    return _maxHeight(icon, width) +
        contentPadding.top +
        _maxHeight(prefixIcon, width) +
        _maxHeight(prefix, width) +
        math.max(_maxHeight(input, width), _maxHeight(hint, width)) +
        _maxHeight(suffix, width) +
        _maxHeight(suffixIcon, width) +
        contentPadding.bottom;
  }

  /// 计算给定高度下，多个渲染框的最大宽度
  double _lineWidth(double height, List<RenderBox?> boxes) {
    double width = 0.0;
    for (final RenderBox? box in boxes) {
      if (box == null) {
        continue;
      }
      width = math.max(_minWidth(box, height), width);
    }
    return width;
  }

  @override
  /// 计算最小内在宽度
  double computeMinIntrinsicWidth(double height) {
    final double iconWidth = _minWidth(icon, height);
    final double iconHeight = _minHeight(icon, iconWidth);

    height = math.max(height - iconHeight, 0.0);

    final double prefixIconWidth = _minWidth(prefixIcon, height);
    final double prefixIconHeight = _minHeight(prefixIcon, prefixIconWidth);

    final double suffixIconWidth = _minWidth(suffixIcon, height);
    final double suffixIconHeight = _minHeight(suffixIcon, suffixIconWidth);

    height = math.max(height - contentPadding.vertical, 0.0);

    final double counterWidth = _minWidth(counter, height);
    final double counterHeight = _minHeight(counter, counterWidth);

    final double helperErrorAvailableHeight =
        math.max(height - counterHeight, 0.0);
    final double helperErrorWidth =
        _minWidth(helperError, helperErrorAvailableHeight);
    double subtextWidth = math.max(counterWidth, helperErrorWidth);
    if (subtextWidth > 0.0) {
      subtextWidth += subtextGap;
    }

    final double prefixWidth = _minWidth(prefix, height);
    final double prefixHeight = _minHeight(prefix, prefixWidth);

    final double suffixWidth = _minWidth(suffix, height);
    final double suffixHeight = _minHeight(suffix, suffixWidth);

    final double availableInputHeight = math.max(
        height -
            prefixHeight -
            suffixHeight -
            prefixIconHeight -
            suffixIconHeight,
        0.0);
    final double inputWidth =
        _lineWidth(availableInputHeight, <RenderBox?>[input, hint]);
    final double inputMaxWidth =
        <double>[inputWidth, prefixWidth, suffixWidth].reduce(math.max);

    final Offset densityOffset = decoration.visualDensity!.baseSizeAdjustment;
    final double contentWidth = contentPadding.left +
        (label == null ? 0.0 : decoration.floatingLabelWidth) +
        inputMaxWidth +
        contentPadding.right +
        densityOffset.dx;
    final double containerWidth = <double>[
      iconWidth,
      contentWidth,
      prefixIconWidth,
      suffixIconWidth
    ].reduce(math.max);
    final double minContainerWidth =
        decoration.isDense! || expands ? 0.0 : kMinInteractiveDimension;
    return math.max(containerWidth, minContainerWidth) + subtextWidth;
  }

  @override
  /// 计算最大内在宽度
  /// 对于输入装饰器，最大内在宽度与最小内在宽度相同
  double computeMaxIntrinsicWidth(double height) {
    return computeMinIntrinsicWidth(height);
  }

  @override
  /// 计算到实际基线的距离
  double computeDistanceToActualBaseline(TextBaseline baseline) {
    return _boxParentData(input!).offset.dx +
        input!.computeDistanceToActualBaseline(baseline)!;
  }

  // 记录标签绘制的位置
  Matrix4? _labelTransform;

  @override
  /// 计算干布局大小
  /// 由于布局需要基线度量，而基线度量只有在完整布局后才能获得，
  /// 因此此方法返回 Size.zero
  Size computeDryLayout(BoxConstraints constraints) {
    assert(debugCannotComputeDryLayout(
      reason:
          '布局需要基线度量，而基线度量只有在完整布局后才能获得。',
    ));
    return Size.zero;
  }

  @override
  /// 执行布局
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    _labelTransform = null;
    final _RenderDecorationLayout layout = _layout(constraints);

    final double overallHeight = constraints.maxHeight;
    final double overallWidth = layout.containerWidth + layout.subtextWidth;

    if (container != null) {
      final BoxConstraints containerConstraints = BoxConstraints.tightFor(
        width: layout.containerWidth,
        height: overallHeight - _boxSize(icon).height,
      );
      container!.layout(containerConstraints, parentUsesSize: true);
      final double y = _boxSize(icon).height;
      _boxParentData(container!).offset = Offset(0.0, y);
    }

    double? width;
    // 居中布局函数
    double centerLayout(RenderBox box, double y) {
      _boxParentData(box).offset = Offset((width! - box.size.width) / 2.0, y);
      return box.size.height;
    }

    double? baseline;
    // 基线布局函数
    double baselineLayout(RenderBox box, double y) {
      _boxParentData(box).offset =
          Offset(baseline! - layout.boxToBaseline[box]!, y);
      return box.size.height;
    }

    final double top = contentPadding.top;
    final double bottom = overallHeight - contentPadding.bottom;

    width = layout.containerWidth;
    baseline =
        _isOutlineAligned ? layout.outlineBaseline : layout.inputBaseline;

    if (icon != null) {
      const double y = 0.0;
      centerLayout(icon!, y);
    }

    double start = top + _boxSize(icon).height;
    double end = bottom;
    if (prefixIcon != null) {
      start -= contentPadding.top;
      start += centerLayout(prefixIcon!, start);
    }
    if (label != null) {
      if (decoration.alignLabelWithHint) {
        baselineLayout(label!, start);
      } else {
        centerLayout(label!, start);
      }
    }
    if (prefix != null) {
      start += baselineLayout(prefix!, start);
    }
    // 当显示提示文本（字段为空）时，定位输入框以匹配提示的位置
    // 以便光标与提示文本正确对齐
    if (input != null && hint != null && isEmpty) {
      // 首先定位提示以获取其水平偏移
      final double hintHorizontalOffset =
          baseline - layout.boxToBaseline[hint]!;
      _boxParentData(hint!).offset = Offset(hintHorizontalOffset, start);
      // 将输入框定位在与提示相同的水平偏移处
      _boxParentData(input!).offset = Offset(hintHorizontalOffset, start);
      // 不推进 start，因为两者都在同一位置
    } else {
      if (input != null) {
        baselineLayout(input!, start);
      }
      if (hint != null) {
        baselineLayout(hint!, start);
      }
    }
    if (suffixIcon != null) {
      end += contentPadding.bottom;
      end -= centerLayout(suffixIcon!, end - suffixIcon!.size.height);
    }
    if (suffix != null) {
      end -= baselineLayout(suffix!, end - suffix!.size.height);
    }

    if (helperError != null || counter != null) {
      width = layout.subtextWidth;
      baseline = layout.subtextBaseline;
      if (helperError != null) {
        baselineLayout(helperError!, top + _boxSize(icon).height);
      }
      if (counter != null) {
        baselineLayout(counter!, bottom - counter!.size.height);
      }
    }

    if (label != null) {
      final double labelY = _boxParentData(label!).offset.dy;
      // +1 将 y 的范围从 (-1.0, 1.0) 移到 (0.0, 2.0)
      final double floatAlign = decoration.floatingLabelAlignment._y + 1;
      final double floatHeight = _boxSize(label).height * _kFinalLabelScale;
      // 当浮动标签居中时，其 y 相对于 _BorderContainer 的 y，与标签的 y 无关

      // _InputBorderGap.start 的值相对于 _BorderContainer 的原点，该原点由图标的高度偏移
      // 虽然，当浮动标签居中时，它已经相对于 _BorderContainer
      decoration.borderGap!.start = lerpDouble(labelY - _boxSize(icon).height,
          _boxSize(container).height / 2.0 - floatHeight / 2.0, floatAlign);

      decoration.borderGap!.extent = label!.size.height * _kFinalLabelScale;
    } else {
      decoration.borderGap!.start = null;
      decoration.borderGap!.extent = 0.0;
    }

    size = constraints.constrain(Size(overallWidth, overallHeight));
    assert(size.width == constraints.constrainWidth(overallWidth));
    assert(size.height == constraints.constrainHeight(overallHeight));
  }

  /// 绘制标签
  void _paintLabel(PaintingContext context, Offset offset) {
    context.paintChild(label!, offset);
  }

  @override
  /// 绘制装饰器
  void paint(PaintingContext context, Offset offset) {
    void doPaint(RenderBox? child) {
      if (child != null) {
        context.paintChild(child, _boxParentData(child).offset + offset);
      }
    }

    doPaint(container);

    if (label != null) {
      final Offset labelOffset = _boxParentData(label!).offset;
      final double labelWidth = _boxSize(label).width;
      final double labelHeight = _boxSize(label).height;
      // +1 shifts the range of y from (-1.0, 1.0) to (0.0, 2.0).
      final double floatAlign = decoration.floatingLabelAlignment._y + 1;
      final double floatHeight = labelHeight * _kFinalLabelScale;
      final double borderWeight = decoration.border!.borderSide.width;
      final double t = decoration.floatingLabelProgress;
      // The center of the outline border label ends up a little to the right of the
      // center of the left border line.
      final bool isOutlineBorder =
          decoration.border != null && decoration.border!.isOutline;
      // Center the scaled label relative to the border.
      final double floatingX = isOutlineBorder
          ? (-labelWidth * _kFinalLabelScale) / 2.0 + borderWeight / 2.0
          : contentPadding.left;
      final double scale = lerpDouble(1.0, _kFinalLabelScale, t)!;
      final double centeredFloatY = _boxParentData(container!).offset.dy +
          _boxSize(container).height / 2.0 -
          floatHeight / 2.0;
      final double floatStartY = labelOffset.dy;
      final double floatEndY =
          lerpDouble(floatStartY, centeredFloatY, floatAlign)!;
      final double dy = lerpDouble(floatStartY, floatEndY, t)!;
      final double dx = lerpDouble(0.0, floatingX - labelOffset.dx, t)!;
      _labelTransform = Matrix4.identity()
        ..translate(labelOffset.dx + dx, dy)
        ..scale(scale);
      layer = context.pushTransform(
        needsCompositing,
        offset,
        _labelTransform!,
        _paintLabel,
        oldLayer: layer as TransformLayer?,
      );
    } else {
      layer = null;
    }

    doPaint(icon);
    doPaint(prefix);
    doPaint(suffix);
    doPaint(prefixIcon);
    doPaint(suffixIcon);
    doPaint(hint);
    doPaint(input);
    doPaint(helperError);
    doPaint(counter);
  }

  @override
  /// 自身命中测试
  /// 始终返回 true，表示装饰器区域内的任何位置都被视为命中
  bool hitTestSelf(Offset position) => true;

  @override
  /// 子组件命中测试
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final RenderBox child in children) {
      // 标签必须特殊处理，因为我们已经对其进行了变换
      final Offset offset = _boxParentData(child).offset;
      final bool isHit = result.addWithPaintOffset(
        offset: offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          assert(transformed == position - offset);
          return child.hitTest(result, position: transformed);
        },
      );
      if (isHit) {
        return true;
      }
    }
    return false;
  }

  @override
  /// 应用绘制变换
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    // 对标签应用特殊变换
    if (child == label && _labelTransform != null) {
      final Offset labelOffset = _boxParentData(label!).offset;
      transform
        ..multiply(_labelTransform!)
        ..translate(-labelOffset.dx, -labelOffset.dy);
    }
    super.applyPaintTransform(child, transform);
  }
}

/// 装饰器组件，用于创建和管理 _RenderDecoration
class _Decorator
    extends SlottedMultiChildRenderObjectWidget<_DecorationSlot, RenderBox> {
  /// 创建一个 _Decorator
  /// [textAlignHorizontal] - 水平文本对齐方式
  /// [decoration] - 装饰信息
  /// [textBaseline] - 文本基线
  /// [isFocused] - 是否聚焦
  /// [expands] - 是否展开
  /// [isEmpty] - 是否为空
  const _Decorator({
    required this.textAlignHorizontal,
    required this.decoration,
    required this.textBaseline,
    required this.isFocused,
    required this.expands,
    required this.isEmpty,
  });

  final _Decoration decoration; // 装饰信息
  final TextBaseline textBaseline; // 文本基线
  final TextAlignHorizontal? textAlignHorizontal; // 水平文本对齐方式
  final bool isFocused; // 是否聚焦
  final bool expands; // 是否展开
  final bool isEmpty; // 是否为空

  @override
  /// 获取所有插槽
  Iterable<_DecorationSlot> get slots => _DecorationSlot.values;

  @override
  /// 根据插槽获取子组件
  Widget? childForSlot(_DecorationSlot slot) {
    switch (slot) {
      case _DecorationSlot.icon:
        return decoration.icon;
      case _DecorationSlot.input:
        return decoration.input;
      case _DecorationSlot.label:
        return decoration.label;
      case _DecorationSlot.hint:
        return decoration.hint;
      case _DecorationSlot.prefix:
        return decoration.prefix;
      case _DecorationSlot.suffix:
        return decoration.suffix;
      case _DecorationSlot.prefixIcon:
        return decoration.prefixIcon;
      case _DecorationSlot.suffixIcon:
        return decoration.suffixIcon;
      case _DecorationSlot.helperError:
        return decoration.helperError;
      case _DecorationSlot.counter:
        return decoration.counter;
      case _DecorationSlot.container:
        return decoration.container;
    }
  }

  @override
  /// 创建渲染对象
  _RenderDecoration createRenderObject(BuildContext context) {
    return _RenderDecoration(
      decoration: decoration,
      textBaseline: textBaseline,
      textAlignHorizontal: textAlignHorizontal,
      isFocused: isFocused,
      expands: expands,
      isEmpty: isEmpty,
    );
  }

  @override
  /// 更新渲染对象
  void updateRenderObject(
      BuildContext context, _RenderDecoration renderObject) {
    renderObject
      ..decoration = decoration
      ..expands = expands
      ..isFocused = isFocused
      ..isEmpty = isEmpty
      ..textAlignHorizontal = textAlignHorizontal
      ..textBaseline = textBaseline;
  }
}

/// 用于显示前缀和后缀文本的 widget。
class _AffixText extends StatelessWidget {
  const _AffixText({
    required this.labelIsFloating,
    this.text,
    this.style,
    this.child,
    this.semanticsSortKey,
    required this.semanticsTag,
  });

  final bool labelIsFloating; // 标签是否浮动
  final String? text; // 显示的文本
  final TextStyle? style; // 文本样式
  final Widget? child; // 子 widget
  final SemanticsSortKey? semanticsSortKey; // 语义排序键
  final SemanticsTag semanticsTag; // 语义标签

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: style,
      child: AnimatedOpacity(
        duration: _kTransitionDuration,
        curve: _kTransitionCurve,
        opacity: labelIsFloating ? 1.0 : 0.0,
        child: Semantics(
          sortKey: semanticsSortKey,
          tagForChildren: semanticsTag,
          child:
              child ?? (text == null ? null : MongolText(text!, style: style)),
        ),
      ),
    );
  }
}

/// Defines the appearance of a Material Design Mongol text field.
///
/// [MongolInputDecorator] displays the visual elements of a Material Design text
/// Mongol field around its input [child]. The visual elements themselves are defined
/// by an [InputDecoration] object and their layout and appearance depend
/// on the `baseStyle`, `textAlign`, `isFocused`, and `isEmpty` parameters.
///
/// [MongolTextField] uses this widget to decorate its [MongolEditableText] child.
///
/// [MongolInputDecorator] can be used to create widgets that look and behave like a
/// [MongolTextField] but support other kinds of input.
///
/// Requires one of its ancestors to be a [Material] widget.
///
/// See also:
///
///  * [MongolTextField], which uses a [MongolInputDecorator] to display a border,
///    labels, and icons, around its [MongolEditableText] child.
///  * [Decoration] and [DecoratedBox], for drawing arbitrary decorations
///    around other widgets.
class MongolInputDecorator extends StatefulWidget {
  /// Creates a widget that displays a border, labels, and icons,
  /// for a [MongolTextField].
  ///
  /// The [isFocused], [isHovering], [expands], and [isEmpty] arguments must not
  /// be null.
  const MongolInputDecorator({
    super.key,
    required this.decoration,
    this.baseStyle,
    this.textAlign,
    this.textAlignHorizontal,
    this.isFocused = false,
    this.isHovering = false,
    this.expands = false,
    this.isEmpty = false,
    this.child,
  });

  /// The text and styles to use when decorating the child.
  ///
  /// Null [InputDecoration] properties are initialized with the corresponding
  /// values from [ThemeData.inputDecorationTheme].
  ///
  /// Must not be null.
  final InputDecoration decoration;

  /// The style on which to base the label, hint, counter, and error styles
  /// if the [decoration] does not provide explicit styles.
  ///
  /// If null, `baseStyle` defaults to the `subtitle1` style from the
  /// current [Theme], see [ThemeData.textTheme].
  ///
  /// The [TextStyle.textBaseline] of the [baseStyle] is used to determine
  /// the baseline used for text alignment.
  final TextStyle? baseStyle;

  /// How the text in the decoration should be aligned vertically.
  final MongolTextAlign? textAlign;

  /// How the text should be aligned horizontally.
  ///
  /// Determines the alignment of the baseline within the available space of
  /// the input (typically a `MongolTextField`). For example,
  /// `TextAlignHorizontal.left` will place the baseline such that the text,
  /// and any attached decoration like prefix and suffix, is as close to the
  /// left side of the input as possible without overflowing. The widths of the
  /// prefix and suffix are similarly included for other alignment values. If
  /// the width is greater than the width available, then the prefix and suffix
  /// will be allowed to overflow first before the text scrolls.
  final TextAlignHorizontal? textAlignHorizontal;

  /// Whether the input field has focus.
  ///
  /// Determines the position of the label text and the color and weight of the
  /// border.
  ///
  /// Defaults to false.
  ///
  /// See also:
  ///
  ///  * [InputDecoration.hoverColor], which is also blended into the focus
  ///    color and fill color when the [isHovering] is true to produce the final
  ///    color.
  final bool isFocused;

  /// Whether the input field is being hovered over by a mouse pointer.
  ///
  /// Determines the container fill color, which is a blend of
  /// [InputDecoration.hoverColor] with [InputDecoration.fillColor] when
  /// true, and [InputDecoration.fillColor] when not.
  ///
  /// Defaults to false.
  final bool isHovering;

  /// If true, the width of the input field will be as large as possible.
  ///
  /// If wrapped in a widget that constrains its child's width, like Expanded
  /// or SizedBox, the input field will only be affected if [expands] is set to
  /// true.
  ///
  /// See [MongolTextField.minLines] and [MongolTextField.maxLines] for related
  /// ways to affect the width of an input. When [expands] is true, both must
  /// be null in order to avoid ambiguity in determining the width.
  ///
  /// Defaults to false.
  final bool expands;

  /// Whether the input field is empty.
  ///
  /// Determines the position of the label text and whether to display the hint
  /// text.
  ///
  /// Defaults to false.
  final bool isEmpty;

  /// The widget below this widget in the tree.
  ///
  /// Typically a [MongolEditableText], [DropdownButton], or [InkWell].
  final Widget? child;

  /// Whether the label needs to get out of the way of the input, either by
  /// floating or disappearing.
  ///
  /// Will withdraw when not empty, or when focused while enabled.
  bool get _labelShouldWithdraw =>
      !isEmpty || (isFocused && decoration.enabled);

  @override
  State<MongolInputDecorator> createState() => _InputDecoratorState();

  /// The RenderBox that defines this decorator's "container". That's the
  /// area which is filled if [InputDecoration.filled] is true. It's the area
  /// adjacent to [InputDecoration.icon] and to the left of the widgets that contain
  /// [InputDecoration.helperText], [InputDecoration.errorText], and
  /// [InputDecoration.counterText].
  ///
  /// [MongolTextField] renders ink splashes within the container.
  static RenderBox? containerOf(BuildContext context) {
    final result = context.findAncestorRenderObjectOfType<_RenderDecoration>();
    return result?.container;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
        .add(DiagnosticsProperty<InputDecoration>('decoration', decoration));
    properties.add(DiagnosticsProperty<TextStyle>('baseStyle', baseStyle,
        defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('isFocused', isFocused));
    properties.add(
        DiagnosticsProperty<bool>('expands', expands, defaultValue: false));
    properties.add(DiagnosticsProperty<bool>('isEmpty', isEmpty));
  }
}

class _InputDecoratorState extends State<MongolInputDecorator>
    with TickerProviderStateMixin {
  late final AnimationController _floatingLabelController;
  late final Animation<double> _floatingLabelAnimation;
  late final AnimationController _shakingLabelController;
  final _InputBorderGap _borderGap = _InputBorderGap();
  static const OrdinalSortKey _kPrefixSemanticsSortOrder = OrdinalSortKey(0);
  static const OrdinalSortKey _kInputSemanticsSortOrder = OrdinalSortKey(1);
  static const OrdinalSortKey _kSuffixSemanticsSortOrder = OrdinalSortKey(2);
  static const SemanticsTag _kPrefixSemanticsTag =
      SemanticsTag('_InputDecoratorState.prefix');
  static const SemanticsTag _kSuffixSemanticsTag =
      SemanticsTag('_InputDecoratorState.suffix');

  @override
  void initState() {
    super.initState();

    final labelIsInitiallyFloating = widget.decoration.floatingLabelBehavior ==
            FloatingLabelBehavior.always ||
        (widget.decoration.floatingLabelBehavior !=
                FloatingLabelBehavior.never &&
            widget._labelShouldWithdraw);

    _floatingLabelController = AnimationController(
        duration: _kTransitionDuration,
        vsync: this,
        value: labelIsInitiallyFloating ? 1.0 : 0.0);
    _floatingLabelController.addListener(_handleChange);
    _floatingLabelAnimation = CurvedAnimation(
      parent: _floatingLabelController,
      curve: _kTransitionCurve,
      reverseCurve: _kTransitionCurve.flipped,
    );

    _shakingLabelController = AnimationController(
      duration: _kTransitionDuration,
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _effectiveDecoration = null;
  }

  @override
  void dispose() {
    _floatingLabelController.dispose();
    _shakingLabelController.dispose();
    super.dispose();
  }

  void _handleChange() {
    setState(() {
      // The _floatingLabelController's value has changed.
    });
  }

  InputDecoration? _effectiveDecoration;

  InputDecoration get decoration => _effectiveDecoration ??=
      widget.decoration.applyDefaults(Theme.of(context).inputDecorationTheme);

  MongolTextAlign? get textAlign => widget.textAlign;

  bool get isFocused => widget.isFocused;

  bool get _hasError =>
      decoration.errorText != null || decoration.error != null;

  bool get isHovering => widget.isHovering && decoration.enabled;

  bool get isEmpty => widget.isEmpty;

  bool get _floatingLabelEnabled {
    return decoration.floatingLabelBehavior != FloatingLabelBehavior.never;
  }

  @override
  void didUpdateWidget(MongolInputDecorator old) {
    super.didUpdateWidget(old);
    if (widget.decoration != old.decoration) {
      _effectiveDecoration = null;
    }

    final floatBehaviorChanged = widget.decoration.floatingLabelBehavior !=
        old.decoration.floatingLabelBehavior;

    if (widget._labelShouldWithdraw != old._labelShouldWithdraw ||
        floatBehaviorChanged) {
      if (_floatingLabelEnabled &&
          (widget._labelShouldWithdraw ||
              widget.decoration.floatingLabelBehavior ==
                  FloatingLabelBehavior.always)) {
        _floatingLabelController.forward();
      } else {
        _floatingLabelController.reverse();
      }
    }

    final String? errorText = decoration.errorText;
    final String? oldErrorText = old.decoration.errorText;

    if (_floatingLabelController.isCompleted &&
        errorText != null &&
        errorText != oldErrorText) {
      _shakingLabelController
        ..value = 0.0
        ..forward();
    }
  }

  Color _getDefaultM2BorderColor(ThemeData themeData) {
    if (!decoration.enabled && !isFocused) {
      return ((decoration.filled ?? false) &&
              !(decoration.border?.isOutline ?? false))
          ? Colors.transparent
          : themeData.disabledColor;
    }
    if (_hasError) {
      return themeData.colorScheme.error;
    }
    if (isFocused) {
      return themeData.colorScheme.primary;
    }
    if (decoration.filled!) {
      return themeData.hintColor;
    }
    final Color enabledColor = themeData.colorScheme.onSurface.withAlpha(0x61);
    if (isHovering) {
      final Color hoverColor = decoration.hoverColor ??
          themeData.inputDecorationTheme.hoverColor ??
          themeData.hoverColor;
      return Color.alphaBlend(hoverColor.withAlpha(0x1f), enabledColor);
    }
    return enabledColor;
  }

  Color _getFillColor(ThemeData themeData, InputDecorationTheme defaults) {
    if (decoration.filled != true) {
      // filled == null same as filled == false
      return Colors.transparent;
    }
    if (decoration.fillColor != null) {
      return WidgetStateProperty.resolveAs(
          decoration.fillColor!, materialState);
    }
    return WidgetStateProperty.resolveAs(defaults.fillColor!, materialState);
  }

  Color _getHoverColor(ThemeData themeData) {
    if (decoration.filled == null ||
        !decoration.filled! ||
        isFocused ||
        !decoration.enabled) {
      return Colors.transparent;
    }
    return decoration.hoverColor ??
        themeData.inputDecorationTheme.hoverColor ??
        themeData.hoverColor;
  }

  Color _getIconColor(ThemeData themeData, InputDecorationTheme defaults) {
    return WidgetStateProperty.resolveAs(decoration.iconColor, materialState) ??
        WidgetStateProperty.resolveAs(
            themeData.inputDecorationTheme.iconColor, materialState) ??
        WidgetStateProperty.resolveAs(defaults.iconColor!, materialState);
  }

  Color _getPrefixIconColor(
      ThemeData themeData, InputDecorationTheme defaults) {
    return WidgetStateProperty.resolveAs(
            decoration.prefixIconColor, materialState) ??
        WidgetStateProperty.resolveAs(
            themeData.inputDecorationTheme.prefixIconColor, materialState) ??
        WidgetStateProperty.resolveAs(defaults.prefixIconColor!, materialState);
  }

  Color _getSuffixIconColor(
      ThemeData themeData, InputDecorationTheme defaults) {
    return WidgetStateProperty.resolveAs(
            decoration.suffixIconColor, materialState) ??
        WidgetStateProperty.resolveAs(
            themeData.inputDecorationTheme.suffixIconColor, materialState) ??
        WidgetStateProperty.resolveAs(defaults.suffixIconColor!, materialState);
  }

  // True if the label will be shown and the hint will not.
  // If we're not focused, there's no value, labelText was provided, and
  // floatingLabelBehavior isn't set to always, then the label appears where the
  // hint would.
  bool get _hasInlineLabel {
    return !widget._labelShouldWithdraw &&
        (decoration.labelText != null || decoration.label != null) &&
        decoration.floatingLabelBehavior != FloatingLabelBehavior.always;
  }

  // If the label is a floating placeholder, it's always shown.
  bool get _shouldShowLabel => _hasInlineLabel || _floatingLabelEnabled;

  // The base style for the inline label when they're displayed "inline",
  // i.e. when they appear in place of the empty text field.
  TextStyle _getInlineLabelStyle(
      ThemeData themeData, InputDecorationTheme defaults) {
    final TextStyle defaultStyle =
        WidgetStateProperty.resolveAs(defaults.labelStyle!, materialState);

    final TextStyle? style =
        WidgetStateProperty.resolveAs(decoration.labelStyle, materialState) ??
            WidgetStateProperty.resolveAs(
                themeData.inputDecorationTheme.labelStyle, materialState);

    return themeData.textTheme.titleMedium!
        .merge(widget.baseStyle)
        .merge(defaultStyle)
        .merge(style)
        .copyWith(height: 1);
  }

  // The base style for the inline hint when they're displayed "inline",
  // i.e. when they appear in place of the empty text field.
  TextStyle _getInlineHintStyle(
      ThemeData themeData, InputDecorationTheme defaults) {
    final TextStyle defaultStyle =
        WidgetStateProperty.resolveAs(defaults.hintStyle!, materialState);

    final TextStyle? style =
        WidgetStateProperty.resolveAs(decoration.hintStyle, materialState) ??
            WidgetStateProperty.resolveAs(
                themeData.inputDecorationTheme.hintStyle, materialState);

    return themeData.textTheme.titleMedium!
        .merge(widget.baseStyle)
        .merge(defaultStyle)
        .merge(style);
  }

  TextStyle _getFloatingLabelStyle(
      ThemeData themeData, InputDecorationTheme defaults) {
    TextStyle defaultTextStyle = WidgetStateProperty.resolveAs(
        defaults.floatingLabelStyle!, materialState);
    if (_hasError && decoration.errorStyle?.color != null) {
      defaultTextStyle =
          defaultTextStyle.copyWith(color: decoration.errorStyle?.color);
    }
    defaultTextStyle = defaultTextStyle
        .merge(decoration.floatingLabelStyle ?? decoration.labelStyle);

    final TextStyle? style = WidgetStateProperty.resolveAs(
            decoration.floatingLabelStyle, materialState) ??
        WidgetStateProperty.resolveAs(
            themeData.inputDecorationTheme.floatingLabelStyle, materialState);

    return themeData.textTheme.titleMedium!
        .merge(widget.baseStyle)
        .copyWith(height: 1)
        .merge(defaultTextStyle)
        .merge(style);
  }

  TextStyle _getHelperStyle(
      ThemeData themeData, InputDecorationTheme defaults) {
    return WidgetStateProperty.resolveAs(defaults.helperStyle!, materialState)
        .merge(WidgetStateProperty.resolveAs(
            decoration.helperStyle, materialState));
  }

  TextStyle _getErrorStyle(ThemeData themeData, InputDecorationTheme defaults) {
    return WidgetStateProperty.resolveAs(defaults.errorStyle!, materialState)
        .merge(decoration.errorStyle);
  }

  Set<WidgetState> get materialState {
    return <WidgetState>{
      if (!decoration.enabled) WidgetState.disabled,
      if (isFocused) WidgetState.focused,
      if (isHovering) WidgetState.hovered,
      if (_hasError) WidgetState.error,
    };
  }

  InputBorder _getDefaultBorder(
      ThemeData themeData, InputDecorationTheme defaults) {
    final InputBorder border =
        WidgetStateProperty.resolveAs(decoration.border, materialState) ??
            const SidelineInputBorder();

    if (decoration.border is WidgetStateProperty<InputBorder>) {
      return border;
    }

    if (border.borderSide == BorderSide.none) {
      return border;
    }

    if (themeData.useMaterial3) {
      if (decoration.filled!) {
        return border.copyWith(
          borderSide: WidgetStateProperty.resolveAs(
              defaults.activeIndicatorBorder, materialState),
        );
      } else {
        return border.copyWith(
          borderSide: WidgetStateProperty.resolveAs(
              defaults.outlineBorder, materialState),
        );
      }
    } else {
      return border.copyWith(
        borderSide: BorderSide(
          color: _getDefaultM2BorderColor(themeData),
          width: ((decoration.isCollapsed ??
                      themeData.inputDecorationTheme.isCollapsed) ||
                  decoration.border == InputBorder.none ||
                  !decoration.enabled)
              ? 0.0
              : isFocused
                  ? 2.0
                  : 1.0,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData themeData = Theme.of(context);
    final InputDecorationTheme defaults = Theme.of(context).useMaterial3
        ? _InputDecoratorDefaultsM3(context)
        : _InputDecoratorDefaultsM2(context);

    final TextStyle labelStyle = _getInlineLabelStyle(themeData, defaults);
    final TextBaseline textBaseline = labelStyle.textBaseline!;

    final TextStyle hintStyle = _getInlineHintStyle(themeData, defaults);
    final String? hintText = decoration.hintText;
    final Widget? hint = hintText == null
        ? null
        : AnimatedOpacity(
            opacity: (isEmpty && !_hasInlineLabel) ? 1.0 : 0.0,
            duration:
                decoration.hintFadeDuration ?? _kHintFadeTransitionDuration,
            curve: _kTransitionCurve,
            child: MongolText(
              hintText,
              style: hintStyle,
              overflow: hintStyle.overflow ?? TextOverflow.ellipsis,
              textAlign: textAlign,
              maxLines: decoration.hintMaxLines,
            ),
          );

    InputBorder? border;
    if (!decoration.enabled) {
      border = _hasError ? decoration.errorBorder : decoration.disabledBorder;
    } else if (isFocused) {
      border =
          _hasError ? decoration.focusedErrorBorder : decoration.focusedBorder;
    } else {
      border = _hasError ? decoration.errorBorder : decoration.enabledBorder;
    }
    border ??= _getDefaultBorder(themeData, defaults);

    final Widget container = _BorderContainer(
      border: border,
      gap: _borderGap,
      gapAnimation: _floatingLabelAnimation,
      fillColor: _getFillColor(themeData, defaults),
      hoverColor: _getHoverColor(themeData),
      isHovering: isHovering,
    );

    final Widget? label =
        decoration.labelText == null && decoration.label == null
            ? null
            : _Shaker(
                animation: _shakingLabelController.view,
                child: AnimatedOpacity(
                  duration: _kTransitionDuration,
                  curve: _kTransitionCurve,
                  opacity: _shouldShowLabel ? 1.0 : 0.0,
                  child: AnimatedDefaultTextStyle(
                    duration: _kTransitionDuration,
                    curve: _kTransitionCurve,
                    style: widget._labelShouldWithdraw
                        ? _getFloatingLabelStyle(themeData, defaults)
                        : labelStyle,
                    child: decoration.label ??
                        MongolText(
                          decoration.labelText!,
                          overflow: TextOverflow.ellipsis,
                          textAlign: textAlign,
                        ),
                  ),
                ),
              );

    final bool hasPrefix =
        decoration.prefix != null || decoration.prefixText != null;
    final bool hasSuffix =
        decoration.suffix != null || decoration.suffixText != null;

    Widget? input = widget.child;
    // If at least two out of the three are visible, it needs semantics sort
    // order.
    final bool needsSemanticsSortOrder = widget._labelShouldWithdraw &&
        (input != null ? (hasPrefix || hasSuffix) : (hasPrefix && hasSuffix));

    final Widget? prefix = hasPrefix
        ? _AffixText(
            labelIsFloating: widget._labelShouldWithdraw,
            text: decoration.prefixText,
            style: WidgetStateProperty.resolveAs(
                    decoration.prefixStyle, materialState) ??
                hintStyle,
            semanticsSortKey:
                needsSemanticsSortOrder ? _kPrefixSemanticsSortOrder : null,
            semanticsTag: _kPrefixSemanticsTag,
            child: decoration.prefix,
          )
        : null;

    final Widget? suffix = hasSuffix
        ? _AffixText(
            labelIsFloating: widget._labelShouldWithdraw,
            text: decoration.suffixText,
            style: WidgetStateProperty.resolveAs(
                    decoration.suffixStyle, materialState) ??
                hintStyle,
            semanticsSortKey:
                needsSemanticsSortOrder ? _kSuffixSemanticsSortOrder : null,
            semanticsTag: _kSuffixSemanticsTag,
            child: decoration.suffix,
          )
        : null;

    if (input != null && needsSemanticsSortOrder) {
      input = Semantics(
        sortKey: _kInputSemanticsSortOrder,
        child: input,
      );
    }

    final bool decorationIsDense = decoration.isDense ?? false;
    final double iconSize = decorationIsDense ? 18.0 : 24.0;

    final Widget? icon = decoration.icon == null
        ? null
        : MouseRegion(
            cursor: SystemMouseCursors.basic,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 16.0),
              child: IconTheme.merge(
                data: IconThemeData(
                  color: _getIconColor(themeData, defaults),
                  size: iconSize,
                ),
                child: decoration.icon!,
              ),
            ),
          );

    final Widget? prefixIcon = decoration.prefixIcon == null
        ? null
        : Center(
            widthFactor: 1.0,
            heightFactor: 1.0,
            child: MouseRegion(
              cursor: SystemMouseCursors.basic,
              child: ConstrainedBox(
                constraints: decoration.prefixIconConstraints ??
                    themeData.visualDensity.effectiveConstraints(
                      const BoxConstraints(
                        minWidth: kMinInteractiveDimension,
                        minHeight: kMinInteractiveDimension,
                      ),
                    ),
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: _getPrefixIconColor(themeData, defaults),
                    size: iconSize,
                  ),
                  child: IconButtonTheme(
                    data: IconButtonThemeData(
                      style: IconButton.styleFrom(
                        foregroundColor:
                            _getPrefixIconColor(themeData, defaults),
                        iconSize: iconSize,
                      ),
                    ),
                    child: Semantics(
                      child: decoration.prefixIcon,
                    ),
                  ),
                ),
              ),
            ),
          );

    final Widget? suffixIcon = decoration.suffixIcon == null
        ? null
        : Center(
            widthFactor: 1.0,
            heightFactor: 1.0,
            child: MouseRegion(
              cursor: SystemMouseCursors.basic,
              child: ConstrainedBox(
                constraints: decoration.suffixIconConstraints ??
                    themeData.visualDensity.effectiveConstraints(
                      const BoxConstraints(
                        minWidth: kMinInteractiveDimension,
                        minHeight: kMinInteractiveDimension,
                      ),
                    ),
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: _getSuffixIconColor(themeData, defaults),
                    size: iconSize,
                  ),
                  child: IconButtonTheme(
                    data: IconButtonThemeData(
                      style: IconButton.styleFrom(
                        foregroundColor:
                            _getSuffixIconColor(themeData, defaults),
                        iconSize: iconSize,
                      ),
                    ),
                    child: Semantics(
                      child: decoration.suffixIcon,
                    ),
                  ),
                ),
              ),
            ),
          );

    final Widget helperError = _HelperError(
      textAlign: textAlign,
      helperText: decoration.helperText,
      helperStyle: _getHelperStyle(themeData, defaults),
      helperMaxLines: decoration.helperMaxLines,
      error: decoration.error,
      errorText: decoration.errorText,
      errorStyle: _getErrorStyle(themeData, defaults),
      errorMaxLines: decoration.errorMaxLines,
    );

    Widget? counter;
    if (decoration.counter != null) {
      counter = decoration.counter;
    } else if (decoration.counterText != null && decoration.counterText != '') {
      counter = Semantics(
        container: true,
        liveRegion: isFocused,
        child: MongolText(
          decoration.counterText!,
          style: _getHelperStyle(themeData, defaults).merge(
              WidgetStateProperty.resolveAs(
                  decoration.counterStyle, materialState)),
          overflow: TextOverflow.ellipsis,
          semanticsLabel: decoration.semanticCounterText,
        ),
      );
    }

    // The _Decoration widget and _RenderDecoration assume that contentPadding
    // has been resolved to EdgeInsets.
    const textDirection = TextDirection.ltr;
    final EdgeInsets? decorationContentPadding =
        decoration.contentPadding?.resolve(textDirection);

    final EdgeInsets contentPadding;
    final double floatingLabelWidth;
    if (decoration.isCollapsed ?? themeData.inputDecorationTheme.isCollapsed) {
      floatingLabelWidth = 0.0;
      contentPadding = decorationContentPadding ?? EdgeInsets.zero;
    } else if (!border.isOutline) {
      // 4.0: the horizontal gap between the inline elements and the floating label.
      floatingLabelWidth = MediaQuery.textScalerOf(context)
          .scale((4.0 + 0.75 * labelStyle.fontSize!));
      if (decoration.filled ?? false) {
        contentPadding = decorationContentPadding ??
            (decorationIsDense
                ? const EdgeInsets.fromLTRB(8.0, 12.0, 8.0, 12.0)
                : const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0));
      } else {
        // Not top or bottom padding for underline borders that aren't filled
        // is a small concession to backwards compatibility. This eliminates
        // the most noticeable layout change introduced by #13734.
        contentPadding = decorationContentPadding ??
            (decorationIsDense
                ? const EdgeInsets.fromLTRB(8.0, 0.0, 8.0, 0.0)
                : const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0));
      }
    } else {
      floatingLabelWidth = 0.0;
      contentPadding = decorationContentPadding ??
          (decorationIsDense
              ? const EdgeInsets.fromLTRB(20.0, 12.0, 12.0, 12.0)
              : const EdgeInsets.fromLTRB(24.0, 12.0, 16.0, 12.0));
    }

    final _Decorator decorator = _Decorator(
      decoration: _Decoration(
          contentPadding: contentPadding,
          isCollapsed: decoration.isCollapsed ??
              themeData.inputDecorationTheme.isCollapsed,
          floatingLabelWidth: floatingLabelWidth,
          floatingLabelAlignment: decoration.floatingLabelAlignment!,
          floatingLabelProgress: _floatingLabelAnimation.value,
          border: border,
          borderGap: _borderGap,
          alignLabelWithHint: decoration.alignLabelWithHint ?? false,
          isDense: decoration.isDense,
          visualDensity: themeData.visualDensity,
          icon: icon,
          input: input,
          label: label,
          hint: hint,
          prefix: prefix,
          suffix: suffix,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          helperError: helperError,
          counter: counter,
          container: container),
      textBaseline: textBaseline,
      textAlignHorizontal: widget.textAlignHorizontal,
      isFocused: isFocused,
      expands: widget.expands,
      isEmpty: isEmpty,
    );

    final BoxConstraints? constraints =
        decoration.constraints ?? themeData.inputDecorationTheme.constraints;
    if (constraints != null) {
      return ConstrainedBox(
        constraints: constraints,
        child: decorator,
      );
    }
    return decorator;
  }
}

class _InputDecoratorDefaultsM2 extends InputDecorationTheme {
  const _InputDecoratorDefaultsM2(this.context) : super();

  final BuildContext context;

  @override
  TextStyle? get hintStyle =>
      WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return TextStyle(color: Theme.of(context).disabledColor);
        }
        return TextStyle(color: Theme.of(context).hintColor);
      });

  @override
  TextStyle? get labelStyle =>
      WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return TextStyle(color: Theme.of(context).disabledColor);
        }
        return TextStyle(color: Theme.of(context).hintColor);
      });

  @override
  TextStyle? get floatingLabelStyle =>
      WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return TextStyle(color: Theme.of(context).disabledColor);
        }
        if (states.contains(WidgetState.error)) {
          return TextStyle(color: Theme.of(context).colorScheme.error);
        }
        if (states.contains(WidgetState.focused)) {
          return TextStyle(color: Theme.of(context).colorScheme.primary);
        }
        return TextStyle(color: Theme.of(context).hintColor);
      });

  @override
  TextStyle? get helperStyle =>
      WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
        final ThemeData themeData = Theme.of(context);
        if (states.contains(WidgetState.disabled)) {
          return themeData.textTheme.bodySmall!
              .copyWith(color: Colors.transparent);
        }

        return themeData.textTheme.bodySmall!
            .copyWith(color: themeData.hintColor);
      });

  @override
  TextStyle? get errorStyle =>
      WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
        final ThemeData themeData = Theme.of(context);
        if (states.contains(WidgetState.disabled)) {
          return themeData.textTheme.bodySmall!
              .copyWith(color: Colors.transparent);
        }
        return themeData.textTheme.bodySmall!
            .copyWith(color: themeData.colorScheme.error);
      });

  @override
  Color? get fillColor =>
      WidgetStateColor.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          // dark theme: 5% white
          // light theme: 2% black
          switch (Theme.of(context).brightness) {
            case Brightness.dark:
              return const Color(0x0DFFFFFF);
            case Brightness.light:
              return const Color(0x05000000);
          }
        }
        // dark theme: 10% white
        // light theme: 4% black
        switch (Theme.of(context).brightness) {
          case Brightness.dark:
            return const Color(0x1AFFFFFF);
          case Brightness.light:
            return const Color(0x0A000000);
        }
      });

  @override
  Color? get iconColor =>
      WidgetStateColor.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled) &&
            !states.contains(WidgetState.focused)) {
          return Theme.of(context).disabledColor;
        }
        if (states.contains(WidgetState.focused)) {
          return Theme.of(context).colorScheme.primary;
        }
        switch (Theme.of(context).brightness) {
          case Brightness.dark:
            return Colors.white70;
          case Brightness.light:
            return Colors.black45;
        }
      });

  @override
  Color? get prefixIconColor =>
      WidgetStateColor.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled) &&
            !states.contains(WidgetState.focused)) {
          return Theme.of(context).disabledColor;
        }
        if (states.contains(WidgetState.focused)) {
          return Theme.of(context).colorScheme.primary;
        }
        switch (Theme.of(context).brightness) {
          case Brightness.dark:
            return Colors.white70;
          case Brightness.light:
            return Colors.black45;
        }
      });

  @override
  Color? get suffixIconColor =>
      WidgetStateColor.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled) &&
            !states.contains(WidgetState.focused)) {
          return Theme.of(context).disabledColor;
        }
        if (states.contains(WidgetState.focused)) {
          return Theme.of(context).colorScheme.primary;
        }
        switch (Theme.of(context).brightness) {
          case Brightness.dark:
            return Colors.white70;
          case Brightness.light:
            return Colors.black45;
        }
      });
}

class _InputDecoratorDefaultsM3 extends InputDecorationTheme {
  _InputDecoratorDefaultsM3(this.context) : super();

  final BuildContext context;

  late final ColorScheme _colors = Theme.of(context).colorScheme;
  late final TextTheme _textTheme = Theme.of(context).textTheme;

  @override
  TextStyle? get hintStyle =>
      WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return TextStyle(color: Theme.of(context).disabledColor);
        }
        return TextStyle(color: Theme.of(context).hintColor);
      });

  @override
  Color? get fillColor =>
      WidgetStateColor.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return _colors.onSurface.withAlpha(0xa);
        }
        return _colors.surfaceContainerHighest;
      });

  @override
  BorderSide? get activeIndicatorBorder =>
      WidgetStateBorderSide.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(color: _colors.onSurface.withValues(alpha: 0.38));
        }
        if (states.contains(WidgetState.error)) {
          if (states.contains(WidgetState.hovered)) {
            return BorderSide(color: _colors.onErrorContainer);
          }
          if (states.contains(WidgetState.focused)) {
            return BorderSide(color: _colors.error, width: 2.0);
          }
          return BorderSide(color: _colors.error);
        }
        if (states.contains(WidgetState.hovered)) {
          return BorderSide(color: _colors.onSurface);
        }
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: _colors.primary, width: 2.0);
        }
        return BorderSide(color: _colors.onSurfaceVariant);
      });

  @override
  BorderSide? get outlineBorder =>
      WidgetStateBorderSide.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(color: _colors.onSurface.withValues(alpha: 0.12));
        }
        if (states.contains(WidgetState.error)) {
          if (states.contains(WidgetState.hovered)) {
            return BorderSide(color: _colors.onErrorContainer);
          }
          if (states.contains(WidgetState.focused)) {
            return BorderSide(color: _colors.error, width: 2.0);
          }
          return BorderSide(color: _colors.error);
        }
        if (states.contains(WidgetState.hovered)) {
          return BorderSide(color: _colors.onSurface);
        }
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: _colors.primary, width: 2.0);
        }
        return BorderSide(color: _colors.outline);
      });

  @override
  Color? get iconColor => _colors.onSurfaceVariant;

  @override
  Color? get prefixIconColor =>
      WidgetStateColor.resolveWith((Set<WidgetState> states) {
        return _colors.onSurfaceVariant;
      });

  @override
  Color? get suffixIconColor =>
      WidgetStateColor.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return _colors.onSurface.withValues(alpha: 0.38);
        }
        if (states.contains(WidgetState.error)) {
          return _colors.error;
        }
        return _colors.onSurfaceVariant;
      });

  @override
  TextStyle? get labelStyle =>
      WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
        final TextStyle textStyle = _textTheme.bodyLarge ?? const TextStyle();
        if (states.contains(WidgetState.disabled)) {
          return textStyle.copyWith(
              color: _colors.onSurface.withValues(alpha: 0.38));
        }
        if (states.contains(WidgetState.error)) {
          if (states.contains(WidgetState.hovered)) {
            return textStyle.copyWith(color: _colors.onErrorContainer);
          }
          if (states.contains(WidgetState.focused)) {
            return textStyle.copyWith(color: _colors.error);
          }
          return textStyle.copyWith(color: _colors.error);
        }
        if (states.contains(WidgetState.hovered)) {
          return textStyle.copyWith(color: _colors.onSurfaceVariant);
        }
        if (states.contains(WidgetState.focused)) {
          return textStyle.copyWith(color: _colors.primary);
        }
        return textStyle.copyWith(color: _colors.onSurfaceVariant);
      });

  @override
  TextStyle? get floatingLabelStyle =>
      WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
        final TextStyle textStyle = _textTheme.bodyLarge ?? const TextStyle();
        if (states.contains(WidgetState.disabled)) {
          return textStyle.copyWith(
              color: _colors.onSurface.withValues(alpha: 0.38));
        }
        if (states.contains(WidgetState.error)) {
          if (states.contains(WidgetState.hovered)) {
            return textStyle.copyWith(color: _colors.onErrorContainer);
          }
          if (states.contains(WidgetState.focused)) {
            return textStyle.copyWith(color: _colors.error);
          }
          return textStyle.copyWith(color: _colors.error);
        }
        if (states.contains(WidgetState.hovered)) {
          return textStyle.copyWith(color: _colors.onSurfaceVariant);
        }
        if (states.contains(WidgetState.focused)) {
          return textStyle.copyWith(color: _colors.primary);
        }
        return textStyle.copyWith(color: _colors.onSurfaceVariant);
      });

  @override
  TextStyle? get helperStyle =>
      WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
        final TextStyle textStyle = _textTheme.bodySmall ?? const TextStyle();
        if (states.contains(WidgetState.disabled)) {
          return textStyle.copyWith(
              color: _colors.onSurface.withValues(alpha: 0.38));
        }
        return textStyle.copyWith(color: _colors.onSurfaceVariant);
      });

  @override
  TextStyle? get errorStyle =>
      WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
        final TextStyle textStyle = _textTheme.bodySmall ?? const TextStyle();
        return textStyle.copyWith(color: _colors.error);
      });
}
