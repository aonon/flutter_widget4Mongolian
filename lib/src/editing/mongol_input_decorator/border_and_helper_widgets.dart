part of '../mongol_input_decorator.dart';

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
  static const Duration _kHoverDuration =
      Duration(milliseconds: 15); // 悬停动画持续时间

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
