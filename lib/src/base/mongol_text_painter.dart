// Copyright 2014 The Flutter Authors.
// Copyright 2020 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' show max, min;
import 'dart:ui' as ui show ParagraphStyle;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show TextBoundary, UntilPredicate;
import 'package:flutter/widgets.dart'
    show
        TextAlign,
        TextSpan,
        Canvas,
        RenderComparison,
        Size,
        Rect,
        DiagnosticsNode,
        TextPosition,
        Offset,
        TextRange,
        TextOverflow,
        TextSelection,
        InlineSpan,
        FlutterError,
        ErrorSummary,
        TextDirection,
        TextBaseline,
        TextScaler,
        TextAffinity;
import 'package:mongol/src/base/mongol_paragraph.dart';

import 'mongol_text_align.dart';

// 默认字体大小，与 Flutter 引擎和 text_style.dart 保持一致
const double _kDefaultFontSize = 14.0;

/// 文本高度计算方式枚举
/// 用于确定多行或单行文本的高度测量方式
enum TextHeightBasis {
  /// 多行文本占满父容器高度，单行文本使用最小高度
  /// 适用于标准段落
  parent,

  /// 高度仅足以容纳最长行
  /// 适用于聊天气泡等场景
  longestLine,
}

/// 用于定位蒙古文单词边界的 TextBoundary 实现
/// 基于 UAX #29  Unicode 单词边界规则
class MongolWordBoundary extends TextBoundary {
  /// 使用文本和布局信息创建 [MongolWordBoundary]
  MongolWordBoundary._(this._text, this._paragraph);

  final InlineSpan _text;
  final MongolParagraph _paragraph;

  @override
  TextRange getTextBoundaryAt(int position) =>
      _paragraph.getWordBoundary(TextPosition(offset: max(position, 0)));

  // 将两个 UTF-16 代码单元（高代理 + 低代理）组合成一个表示补充字符的代码点
  static int _codePointFromSurrogates(int highSurrogate, int lowSurrogate) {
    assert(
      MongolTextPainter.isHighSurrogate(highSurrogate),
      'U+${highSurrogate.toRadixString(16).toUpperCase().padLeft(4, "0")}) is not a high surrogate.',
    );
    assert(
      MongolTextPainter.isLowSurrogate(lowSurrogate),
      'U+${lowSurrogate.toRadixString(16).toUpperCase().padLeft(4, "0")}) is not a low surrogate.',
    );
    const int base = 0x010000 - (0xD800 << 10) - 0xDC00;
    return (highSurrogate << 10) + lowSurrogate + base;
  }

  // Runes 类不提供带有代码单元偏移的随机访问
  int? _codePointAt(int index) {
    final int? codeUnitAtIndex = _text.codeUnitAt(index);
    if (codeUnitAtIndex == null) {
      return null;
    }
    return switch (codeUnitAtIndex & 0xFC00) {
      0xD800 =>
        _codePointFromSurrogates(codeUnitAtIndex, _text.codeUnitAt(index + 1)!),
      0xDC00 =>
        _codePointFromSurrogates(_text.codeUnitAt(index - 1)!, codeUnitAtIndex),
      _ => codeUnitAtIndex,
    };
  }

  static bool _isNewline(int codePoint) {
    return switch (codePoint) {
      0x000A || 0x0085 || 0x000B || 0x000C || 0x2028 || 0x2029 => true,
      _ => false,
    };
  }

  bool _skipSpacesAndPunctuations(int offset, bool forward) {
    // 使用代码点，因为一些标点符号是补充字符
    // 这里的 "inner" 指的是搜索方向（`forward`）中断点之前的代码单元
    final int? innerCodePoint = _codePointAt(forward ? offset - 1 : offset);
    final int? outerCodeUnit = _text.codeUnitAt(forward ? offset : offset - 1);

    // 确保 UAX#29 中的硬断点规则优先于我们下面添加的规则
    // 幸运的是，单词断点只有 4 个硬断点规则，基于字典的断点不会引入新的硬断点：
    // https://unicode-org.github.io/icu/userguide/boundaryanalysis/break-rules.html#word-dictionaries
    //
    // WB1 & WB2: 总是在文本的开始或结束处断开
    final bool hardBreakRulesApply = innerCodePoint == null ||
        outerCodeUnit == null
        // WB3a & WB3b: 总是在换行符之前和之后断开
        ||
        _isNewline(innerCodePoint) ||
        _isNewline(outerCodeUnit);
    return hardBreakRulesApply ||
        !RegExp(r'[\p{Space_Separator}\p{Punctuation}]', unicode: true)
            .hasMatch(String.fromCharCode(innerCodePoint));
  }

  /// 返回一个适合处理逐字更改当前选择的键盘导航命令的 [TextBoundary]
  ///
  /// 这个 [TextBoundary] 被 flutter 框架中的文本小部件用于为文本编辑快捷键提供默认实现
  /// 例如，"删除到前一个单词"
  ///
  /// 该实现应用与 [MongolWordBoundary] 相同的规则集
  /// 除了在空格分隔符或标点符号处结束的单词断点会被跳过，以匹配大多数平台的行为
  /// 未来可能会添加其他规则以更好地匹配平台行为
  late final TextBoundary moveByWordBoundary =
      _UntilTextBoundary(this, _skipSpacesAndPunctuations);
}

/// 一个用于处理文本边界的辅助类
///
/// 该类根据给定的谓词函数来确定文本边界
/// 当谓词函数返回 true 时，边界被认为是有效的
class _UntilTextBoundary extends TextBoundary {
  /// 创建一个 _UntilTextBoundary 实例
  ///
  /// [_textBoundary] 是基础文本边界
  /// [_predicate] 是用于判断边界是否有效的谓词函数
  const _UntilTextBoundary(this._textBoundary, this._predicate);

  final UntilPredicate _predicate;
  final TextBoundary _textBoundary;

  @override
  int? getLeadingTextBoundaryAt(int position) {
    if (position < 0) {
      return null;
    }
    final int? offset = _textBoundary.getLeadingTextBoundaryAt(position);
    return offset == null || _predicate(offset, false)
        ? offset
        : getLeadingTextBoundaryAt(offset - 1);
  }

  @override
  int? getTrailingTextBoundaryAt(int position) {
    final int? offset = _textBoundary.getTrailingTextBoundaryAt(max(position, 0));
    return offset == null || _predicate(offset, true)
        ? offset
        : getTrailingTextBoundaryAt(offset);
  }
}

/// 蒙古文文本布局类
///
/// 该类封装了蒙古文段落的布局信息和相关度量
class _MongolTextLayout {
  /// 创建一个 _MongolTextLayout 实例
  ///
  /// [_paragraph] 是用于布局的蒙古文段落
  _MongolTextLayout._(this._paragraph);

  // 这个字段不是 final 的，因为所有者 MongolTextPainter 可能会创建一个具有完全相同文本布局的新 MongolParagraph
  // 例如，当只更改文本颜色时
  //
  // 这个 _MongolTextLayout 的创建者也负责在不再需要时释放这个对象
  MongolParagraph _paragraph;

  /// 此布局是否已失效和释放
  ///
  /// 仅在启用断言时使用
  bool get debugDisposed => _paragraph.debugDisposed;

  /// 绘制此文本所需的垂直空间
  ///
  /// 如果一行以尾随空格结束，尾随空格可能会延伸到 [height] 定义的水平绘制边界之外
  double get height => _paragraph.height;

  /// 绘制此文本所需的水平空间
  double get width => _paragraph.width;

  /// 减小文本高度会阻止其完全绘制在其边界内的高度
  double get minIntrinsicLineExtent => _paragraph.minIntrinsicHeight;

  /// 增加文本高度不再减少宽度的高度
  ///
  /// 包括任何尾随空格
  double get maxIntrinsicLineExtent => _paragraph.maxIntrinsicHeight;

  /// 从最顶部字形的顶部边缘到段落中最底部字形的底部边缘的距离
  double get longestLine => _paragraph.longestLine;

  /// 返回从文本左侧到给定类型的第一条基线的距离
  double getDistanceToBaseline(TextBaseline baseline) {
    return switch (baseline) {
      TextBaseline.alphabetic => _paragraph.alphabeticBaseline,
      TextBaseline.ideographic => _paragraph.ideographicBaseline,
    };
  }
}

/// 文本绘制器布局缓存类
///
/// 该类存储当前文本布局和相应的 paintOffset/contentHeight，
/// 以及一些依赖于当前文本布局的缓存文本度量值，
/// 这些值会在文本布局失效时立即失效
class _TextPainterLayoutCacheWithOffset {
  /// 创建一个 _TextPainterLayoutCacheWithOffset 实例
  ///
  /// [layout] 是蒙古文文本布局
  /// [textAlignment] 是文本对齐方式（0-1之间的值，0表示顶部对齐，1表示底部对齐）
  /// [minHeight] 是最小高度约束
  /// [maxHeight] 是最大高度约束
  /// [heightBasis] 是高度计算方式
  _TextPainterLayoutCacheWithOffset(this.layout, this.textAlignment,
      double minHeight, double maxHeight, TextHeightBasis heightBasis)
      : contentHeight =
            _contentHeightFor(minHeight, maxHeight, heightBasis, layout),
        assert(textAlignment >= 0.0 && textAlignment <= 1.0);

  final _MongolTextLayout layout;

  // 文本绘制器在 MongolTextPainter.height 中应报告的内容高度
  // 这也用于计算 `paintOffset`
  double contentHeight;

  // MongolTextPainter 画布中的有效文本对齐方式
  // 值在 [0, 1] 区间内：0 表示顶部对齐，1 表示底部对齐
  final double textAlignment;

  // `paragraph` 在 MongolTextPainter 画布中的 paintOffset
  //
  // 其坐标值保证不为 NaN
  Offset get paintOffset {
    if (textAlignment == 0) {
      return Offset.zero;
    }
    if (!paragraph.height.isFinite) {
      return const Offset(0.0, double.infinity);
    }
    final double dy = textAlignment * (contentHeight - paragraph.height);
    assert(!dy.isNaN);
    return Offset(0, dy);
  }

  /// 获取段落实例
  MongolParagraph get paragraph => layout._paragraph;

  /// 根据给定的约束和高度计算方式计算内容高度
  static double _contentHeightFor(double minHeight, double maxHeight,
      TextHeightBasis heightBasis, _MongolTextLayout layout) {
    return switch (heightBasis) {
      TextHeightBasis.longestLine =>
        clampDouble(layout.longestLine, minHeight, maxHeight),
      TextHeightBasis.parent =>
        clampDouble(layout.maxIntrinsicLineExtent, minHeight, maxHeight),
    };
  }

  /// 尝试调整 contentHeight 以适应新的输入约束，只需调整绘制偏移（因此不需要更改换行）
  ///
  /// 如果新约束需要重新计算换行，则返回 false，此时不会发生任何副作用
  bool _resizeToFit(
      double minHeight, double maxHeight, TextHeightBasis heightBasis) {
    assert(layout.maxIntrinsicLineExtent.isFinite);
    // 这里的假设是，如果 MongolParagraph 的高度已经 >= 其 maxIntrinsicHeight，
    // 进一步增加输入高度不会改变其布局（但如果不是顶部对齐，可能会改变绘制偏移）
    // 即使对于 MongolTextAlign.justify 也是如此：当 height >= maxIntrinsicHeight 时，
    // MongolTextAlign.justify 的行为与 MongolTextAlign.start 完全相同
    //
    // 一个例外情况是当文本不是顶部对齐，且输入高度为 double.infinity 时
    // 由于结果 MongolParagraph 的高度将为 double.infinity，
    // 为了使文本可见，paintOffset.dy 必然是 double.negativeInfinity，
    // 这会使所有算术运算无效
    final double newContentHeight =
        _contentHeightFor(minHeight, maxHeight, heightBasis, layout);
    if (newContentHeight == contentHeight) {
      return true;
    }
    assert(minHeight <= maxHeight);
    // 当当前 paintOffset 和段落高度都不是有限值时，始终需要布局
    if (!paintOffset.dy.isFinite &&
        !paragraph.height.isFinite &&
        minHeight.isFinite) {
      assert(paintOffset.dy == double.infinity);
      assert(paragraph.height == double.infinity);
      return false;
    }
    final double maxIntrinsicHeight = paragraph.maxIntrinsicHeight;
    if ((paragraph.height - maxIntrinsicHeight) > -precisionErrorTolerance &&
        (maxHeight - maxIntrinsicHeight) > -precisionErrorTolerance) {
      // 调整 paintOffset 和 contentWidth 以适应新的输入约束
      contentHeight = newContentHeight;
      return true;
    }
    return false;
  }

  // ---- 缓存值 ----

  /// 获取行度量信息列表
  List<MongolLineMetrics> get lineMetrics =>
      _cachedLineMetrics ??= paragraph.computeLineMetrics();
  List<MongolLineMetrics>? _cachedLineMetrics;

  // 保存最后计算插入符度量时的 TextPosition
  // 当传入新值时，我们仅在必要时重新计算插入符度量
  TextPosition? _previousCaretPosition;
}

/// 用于缓存和传递有关插入符大小和位置的计算度量
///
/// 由于计算成本较高，因此首选使用此方法
///
// _CaretMetrics 要么是 _LineCaretMetrics，要么是 _EmptyLineCaretMetrics
@immutable
sealed class _CaretMetrics {}

/// 位于非空行中的插入符的 _CaretMetrics
///
/// 位于非空行中的插入符与同一行中的字形相关联
final class _LineCaretMetrics implements _CaretMetrics {
  /// 创建一个 _LineCaretMetrics 实例
  ///
  /// [offset] 是插入符左上角相对于段落左上角的偏移量
  /// [fullWidth] 是插入符位置处字形的完整宽度
  const _LineCaretMetrics({required this.offset, required this.fullWidth});

  /// 插入符左上角相对于段落左上角的偏移量
  final Offset offset;

  /// 插入符位置处字形的完整宽度
  final double fullWidth;
}

/// 位于空行中的插入符的 _CaretMetrics
///
/// 当文本为空，或插入符位于两个换行符之间时
final class _EmptyLineCaretMetrics implements _CaretMetrics {
  /// 创建一个 _EmptyLineCaretMetrics 实例
  ///
  /// [lineHorizontalOffset] 是未占用行的 x 偏移量
  const _EmptyLineCaretMetrics({required this.lineHorizontalOffset});

  /// 未占用行的 x 偏移量
  final double lineHorizontalOffset;
}

/// 将水平 TextAlign 转换为蒙古文垂直 MongolTextAlign 的便捷方法
///
/// 由于蒙古文是垂直排版的，需要将水平对齐方式映射到垂直方向
/// - TextAlign.left 和 TextAlign.start 映射到 MongolTextAlign.top（顶部对齐）
/// - TextAlign.right 和 TextAlign.end 映射到 MongolTextAlign.bottom（底部对齐）
/// - TextAlign.center 映射到 MongolTextAlign.center（居中对齐）
/// - TextAlign.justify 映射到 MongolTextAlign.justify（两端对齐）
MongolTextAlign? mapHorizontalToMongolTextAlign(TextAlign? textAlign) {
  if (textAlign == null) return null;
  switch (textAlign) {
    case TextAlign.left:
    case TextAlign.start:
      return MongolTextAlign.top;
    case TextAlign.right:
    case TextAlign.end:
      return MongolTextAlign.bottom;
    case TextAlign.center:
      return MongolTextAlign.center;
    case TextAlign.justify:
      return MongolTextAlign.justify;
  }
}

/// 将蒙古文 [TextSpan] 树绘制到 [Canvas] 上的对象
///
/// 使用 [MongolTextPainter] 的步骤：
///
/// 1. 创建一个 [TextSpan] 树并将其传递给 [MongolTextPainter] 构造函数
///
/// 2. 调用 [layout] 来准备段落
///
/// 3. 按需多次调用 [paint] 来绘制段落
///
/// 4. 当对象不再被访问时，调用 [dispose] 来释放本地资源
///    对于重复使用并存储在 [State] 或 [RenderObject] 上的 [MongolTextPainter] 对象，
///    从 [State.dispose] 或 [RenderObject.dispose] 等方法中调用 [dispose]
///    对于仅临时使用的 [MongolTextPainter] 对象，在对该对象的方法或属性的最后一次调用后立即释放它们是安全的
///
/// 如果文本被绘制到的区域的高度发生变化，返回步骤 2
/// 如果要绘制的文本发生变化，返回步骤 1
///
/// 默认文本样式是白色。要更改文本颜色，请在 `text` 中的 [TextSpan] 中传递 [TextStyle] 对象
class MongolTextPainter {
  /// 创建一个绘制给定文本的文本绘制器
  ///
  /// `text` 参数是可选的，但在调用 [layout] 之前 [text] 必须非空
  ///
  /// [maxLines] 属性如果非空，必须大于零
  ///
  /// [textAlign] 是文本的垂直对齐方式，默认为顶部对齐
  /// [textScaler] 是字体缩放策略，默认为无缩放
  /// [maxLines] 是文本的最大行数，默认为无限制
  /// [ellipsis] 是用于省略溢出文本的字符串，默认为 null
  /// [textHeightBasis] 定义如何测量渲染文本的高度，默认为 parent
  /// [rotateCJK] 是否旋转 CJK 字符 90 度以在垂直列中显示为 upright，默认为 true
  MongolTextPainter({
    TextSpan? text,
    MongolTextAlign textAlign = MongolTextAlign.top,
    @Deprecated(
      'Use textScaler instead. '
      'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
      'This feature was deprecated after v3.12.0-2.0.pre.',
    )
    double textScaleFactor = 1.0,
    TextScaler textScaler = TextScaler.noScaling,
    int? maxLines,
    String? ellipsis,
    TextHeightBasis textHeightBasis = TextHeightBasis.parent,
    bool rotateCJK = true,
  })  : assert(text == null || text.debugAssertIsValid()),
        assert(maxLines == null || maxLines > 0),
        assert(
            textScaleFactor == 1.0 ||
                identical(textScaler, TextScaler.noScaling),
            'Use textScaler instead.'),
        _text = text,
        _textAlign = textAlign,
        _textScaler = textScaler == TextScaler.noScaling
            ? TextScaler.linear(textScaleFactor)
            : textScaler,
        _maxLines = maxLines,
        _ellipsis = ellipsis,
        _textHeightBasis = textHeightBasis,
        _rotateCJK = rotateCJK;

  /// 计算配置的 [MongolTextPainter] 的高度
  ///
  /// 这是一个便捷方法，使用提供的参数创建一个文本绘制器，
  /// 使用提供的 [minHeight] 和 [maxHeight] 进行布局，
  /// 并返回其 [MongolTextPainter.height]，同时确保释放底层资源
  /// 此操作成本较高，应尽可能避免，
  /// 只要有可能保留 [MongolTextPainter] 来绘制文本或获取其他信息
  static double computeHeight({
    required TextSpan text,
    MongolTextAlign textAlign = MongolTextAlign.top,
    @Deprecated(
      'Use textScaler instead. '
      'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
      'This feature was deprecated after v3.12.0-2.0.pre.',
    )
    double textScaleFactor = 1.0,
    TextScaler textScaler = TextScaler.noScaling,
    int? maxLines,
    String? ellipsis,
    TextHeightBasis textHeightBasis = TextHeightBasis.parent,
    double minHeight = 0.0,
    double maxHeight = double.infinity,
  }) {
    assert(
      textScaleFactor == 1.0 || identical(textScaler, TextScaler.noScaling),
      'Use textScaler instead.',
    );
    final MongolTextPainter painter = MongolTextPainter(
      text: text,
      textAlign: textAlign,
      textScaler: textScaler == TextScaler.noScaling
          ? TextScaler.linear(textScaleFactor)
          : textScaler,
      maxLines: maxLines,
      ellipsis: ellipsis,
      textHeightBasis: textHeightBasis,
    )..layout(minHeight: minHeight, maxHeight: maxHeight);

    try {
      return painter.height;
    } finally {
      painter.dispose();
    }
  }

  /// 计算配置的 [MongolTextPainter] 的最大内在高度
  ///
  /// 这是一个便捷方法，使用提供的参数创建一个文本绘制器，
  /// 使用提供的 [minHeight] 和 [maxHeight] 进行布局，
  /// 并返回其 [MongolTextPainter.maxIntrinsicHeight]，同时确保释放底层资源
  /// 此操作成本较高，应尽可能避免，
  /// 只要有可能保留 [MongolTextPainter] 来绘制文本或获取其他信息
  static double computeMaxIntrinsicHeight({
    required TextSpan text,
    MongolTextAlign textAlign = MongolTextAlign.top,
    @Deprecated(
      'Use textScaler instead. '
      'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
      'This feature was deprecated after v3.12.0-2.0.pre.',
    )
    double textScaleFactor = 1.0,
    TextScaler textScaler = TextScaler.noScaling,
    int? maxLines,
    String? ellipsis,
    TextHeightBasis textHeightBasis = TextHeightBasis.parent,
    double minHeight = 0.0,
    double maxHeight = double.infinity,
  }) {
    assert(
      textScaleFactor == 1.0 || identical(textScaler, TextScaler.noScaling),
      'Use textScaler instead.',
    );
    final MongolTextPainter painter = MongolTextPainter(
      text: text,
      textAlign: textAlign,
      textScaler: textScaler == TextScaler.noScaling
          ? TextScaler.linear(textScaleFactor)
          : textScaler,
      maxLines: maxLines,
      ellipsis: ellipsis,
      textHeightBasis: textHeightBasis,
    )..layout(minHeight: minHeight, maxHeight: maxHeight);

    try {
      return painter.maxIntrinsicHeight;
    } finally {
      painter.dispose();
    }
  }

  // textHeightBasis 在最近的 `layout` 调用后是否已更改
  bool _debugNeedsRelayout = true;
  // 最近 `layout` 调用的结果
  _TextPainterLayoutCacheWithOffset? _layoutCache;

  // _layoutCache 是否包含过时的绘制信息，需要在绘制前更新
  //
  // MongolParagraph 是完全不可变的，因此会影响布局的文本样式更改和不会影响布局的更改都需要重新创建 MongolParagraph 对象
  // 调用者可能在更新文本颜色后不再调用 `layout`
  // 参见：https://github.com/flutter/flutter/issues/85108
  bool _rebuildParagraphForPaint = true;
  // `_layoutCache` 的输入高度
  // 这只是因为在 ui.Paragraph 或 ui.ParagraphBuilder 上没有 API 来创建仅更新绘制而不影响文本布局的更新（例如，更改文本颜色）
  double _inputHeight = double.nan;

  bool get _debugAssertTextLayoutIsValid {
    assert(!debugDisposed);
    if (_layoutCache == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('Text layout not available'),
        if (_debugMarkNeedsLayoutCallStack != null)
          DiagnosticsStackTrace(
              'The calls that first invalidated the text layout were',
              _debugMarkNeedsLayoutCallStack)
        else
          ErrorDescription('The TextPainter has never been laid out.')
      ]);
    }
    return true;
  }

  StackTrace? _debugMarkNeedsLayoutCallStack;

  /// 将此文本绘制器的布局信息标记为脏并移除缓存信息
  ///
  /// 使用此方法在引擎中布局更改的情况下通知文本绘制器重布局
  /// 在大多数情况下，在框架中更新文本绘制器属性会自动调用此方法
  void markNeedsLayout() {
    assert(() {
      if (_layoutCache != null) {
        _debugMarkNeedsLayoutCallStack ??= StackTrace.current;
      }
      return true;
    }());
    _layoutCache?.paragraph.dispose();
    _layoutCache = null;
  }

  /// 要绘制的（可能带样式的）文本
  ///
  /// 设置后，在下次调用 [paint] 之前必须调用 [layout]
  /// 在调用 [layout] 之前，此属性必须非空
  ///
  /// 此属性提供的 [TextSpan] 是以树的形式，可能包含多个 [TextSpan] 实例
  /// 要获取此 [MongolTextPainter] 内容的纯文本表示，请使用 [plainText]
  TextSpan? get text => _text;
  TextSpan? _text;
  set text(TextSpan? value) {
    assert(value == null || value.debugAssertIsValid());
    if (_text == value) {
      return;
    }
    if (_text?.style != value?.style) {
      _layoutTemplate?.dispose();
      _layoutTemplate = null;
    }

    final RenderComparison comparison = value == null
        ? RenderComparison.layout
        : _text?.compareTo(value) ?? RenderComparison.layout;

    _text = value;
    _cachedPlainText = null;

    if (comparison.index >= RenderComparison.layout.index) {
      markNeedsLayout();
    } else if (comparison.index >= RenderComparison.paint.index) {
      // 暂时不要清除 _paragraph 实例变量，它仍然包含有效的布局信息
      _rebuildParagraphForPaint = true;
    }
    // 既不需要重布局也不需要重绘
  }

  /// 返回要绘制的文本的纯文本版本
  ///
  /// 这使用 [TextSpan.toPlainText] 来获取树中所有节点的完整内容
  String get plainText {
    _cachedPlainText ??= _text?.toPlainText(includeSemanticsLabels: false);
    return _cachedPlainText ?? '';
  }

  String? _cachedPlainText;

  /// 文本应如何垂直对齐
  ///
  /// 设置后，在下次调用 [paint] 之前必须调用 [layout]
  ///
  /// [textAlign] 属性默认为 [MongolTextAlign.top]
  MongolTextAlign get textAlign => _textAlign;
  MongolTextAlign _textAlign;
  set textAlign(MongolTextAlign value) {
    if (_textAlign == value) {
      return;
    }
    _textAlign = value;
    markNeedsLayout();
  }

  /// 已弃用。将在未来的 Flutter 版本中移除。请使用 [textScaler] 代替
  ///
  /// 每个逻辑像素的字体像素数
  ///
  /// 例如，如果文本缩放因子为 1.5，文本将比指定的字体大小大 50%
  ///
  /// 设置后，在下次调用 [paint] 之前必须调用 [layout]
  @Deprecated(
    'Use textScaler instead. '
    'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
    'This feature was deprecated after v3.12.0-2.0.pre.',
  )
  double get textScaleFactor => textScaler.textScaleFactor;
  @Deprecated(
    'Use textScaler instead. '
    'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
    'This feature was deprecated after v3.12.0-2.0.pre.',
  )
  set textScaleFactor(double value) {
    textScaler = TextScaler.linear(value);
  }

  /// 布局和渲染文本时使用的字体缩放策略
  ///
  /// 该值通常来自 [MediaQuery.textScalerOf]，它通常反映平台辅助功能设置中用户指定的文本缩放值
  /// 文本的 [TextStyle.fontSize] 将在文本布局和渲染之前由 [TextScaler] 调整
  ///
  /// [textScaler] 更改后必须调用 [layout] 方法，因为它会影响文本布局
  TextScaler get textScaler => _textScaler;
  TextScaler _textScaler;
  set textScaler(TextScaler value) {
    if (value == _textScaler) {
      return;
    }
    _textScaler = value;
    markNeedsLayout();
    _layoutTemplate?.dispose();
    _layoutTemplate = null;
  }

  /// 用于省略溢出文本的字符串
  /// 设置为非空字符串将导致如果文本无法适应指定的最大高度，则此字符串将替换剩余文本
  ///
  /// 具体来说，如果 [maxLines] 非空且该行溢出高度约束，则省略号应用于 [maxLines] 截断的行之前的最后一行
  /// 或者，如果 [maxLines] 为 null，则应用于比高度约束高的第一行
  /// 高度约束是传递给 [layout] 的 `maxHeight`
  ///
  /// 设置后，在下次调用 [paint] 之前必须调用 [layout]
  ///
  /// 系统的更高层，如 [MongolText] 小部件，使用 [TextOverflow] 枚举表示溢出效果
  /// [TextOverflow.ellipsis] 值对应于将此属性设置为 U+2026 HORIZONTAL ELLIPSIS (…)
  String? get ellipsis => _ellipsis;
  String? _ellipsis;
  set ellipsis(String? value) {
    assert(value == null || value.isNotEmpty);
    if (_ellipsis == value) {
      return;
    }
    _ellipsis = value;
    markNeedsLayout();
  }

  /// 文本要跨越的可选最大行数，必要时换行
  ///
  /// 如果文本超过给定的行数，它会被截断，以便后续行被丢弃
  ///
  /// 设置后，在下次调用 [paint] 之前必须调用 [layout]
  int? get maxLines => _maxLines;
  int? _maxLines;

  /// 该值可以为 null。如果不为 null，则必须大于零
  set maxLines(int? value) {
    assert(value == null || value > 0);
    if (_maxLines == value) {
      return;
    }
    _maxLines = value;
    markNeedsLayout();
  }

  /// 定义如何测量渲染文本的高度
  TextHeightBasis get textHeightBasis => _textHeightBasis;
  TextHeightBasis _textHeightBasis;
  set textHeightBasis(TextHeightBasis value) {
    if (_textHeightBasis == value) {
      return;
    }
    assert(() {
      return _debugNeedsRelayout = true;
    }());
    _textHeightBasis = value;
  }

  /// CJK 字符是否应旋转 90 度以在垂直列中显示为 upright
  bool get rotateCJK => _rotateCJK;
  bool _rotateCJK;
  set rotateCJK(bool value) {
    if (_rotateCJK == value) {
      return;
    }
    _rotateCJK = value;
    markNeedsLayout();
  }

  ui.ParagraphStyle _createParagraphStyle() {
    // textAlign should always be `left` because this is the style for
    // a single text run. MongolTextAlign is handled elsewhere.
    return _text!.style?.getParagraphStyle(
          textAlign: TextAlign.left,
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
          maxLines: maxLines,
          ellipsis: ellipsis,
          locale: null,
          strutStyle: null,
        ) ??
        ui.ParagraphStyle(
          textAlign: TextAlign.left,
          textDirection: TextDirection.ltr,
          // Use the default font size to multiply by as MongolRichText does not
          // perform inheriting [TextStyle]s and would otherwise
          // fail to apply textScaleFactor.
          fontSize: textScaler.scale(_kDefaultFontSize),
          maxLines: maxLines,
          ellipsis: ellipsis,
          locale: null,
        );
  }

  MongolParagraph? _layoutTemplate;
  MongolParagraph _createLayoutTemplate() {
    final builder = MongolParagraphBuilder(_createParagraphStyle());
    // MongolParagraphBuilder will handle converting the painter TextStyle to
    // the ui.TextStyle as well as applying the text scaler.
    final textStyle = text?.style;
    if (textStyle != null) {
      builder.pushStyle(textStyle);
    }
    builder.addText(' ');
    return builder.build()
      ..layout(const MongolParagraphConstraints(height: double.infinity));
  }

  /// The width of a space in [text] in logical pixels.
  ///
  /// (This is in vertical orientation. In other words, it is the height
  /// of a space in horizontal orientation.)
  ///
  /// Not every line of text in [text] will have this width, but this width
  /// is "typical" for text in [text] and useful for sizing other objects
  /// relative a typical line of text.
  ///
  /// Obtaining this value does not require calling [layout].
  ///
  /// The style of the [text] property is used to determine the font settings
  /// that contribute to the [preferredLineWidth]. If [text] is null or if it
  /// specifies no styles, the default [TextStyle] values are used (a 10 pixel
  /// sans-serif font).
  double get preferredLineWidth =>
      (_layoutTemplate ??= _createLayoutTemplate()).width;

  /// The height at which decreasing the height of the text would prevent it from
  /// painting itself completely within its bounds.
  ///
  /// Valid only after [layout] has been called.
  double get minIntrinsicHeight {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.layout.minIntrinsicLineExtent;
  }

  /// The height at which increasing the height of the text no longer decreases
  /// the width.
  ///
  /// Valid only after [layout] has been called.
  double get maxIntrinsicHeight {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.layout.maxIntrinsicLineExtent;
  }

  /// The vertical space required to paint this text.
  ///
  /// Valid only after [layout] has been called.
  double get height {
    assert(_debugAssertTextLayoutIsValid);
    assert(!_debugNeedsRelayout);
    return _layoutCache!.contentHeight;
  }

  /// The horizontal space required to paint this text.
  ///
  /// Valid only after [layout] has been called.
  double get width {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.layout.width;
  }

  /// The amount of space required to paint this text.
  ///
  /// Valid only after [layout] has been called.
  Size get size {
    assert(_debugAssertTextLayoutIsValid);
    assert(!_debugNeedsRelayout);
    return Size(width, height);
  }

  /// Even though the text is rotated, it is still useful to have a baseline
  /// along which to layout objects. (For example in the MongolInputDecorator.)
  ///
  /// Valid only after [layout] has been called.
  double computeDistanceToActualBaseline(TextBaseline baseline) {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.layout.getDistanceToBaseline(baseline);
  }

  /// Whether any text was truncated or ellipsized.
  ///
  /// If [maxLines] is not null, this is true if there were more lines to be
  /// drawn than the given [maxLines], and thus at least one line was omitted in
  /// the output; otherwise it is false.
  ///
  /// If [maxLines] is null, this is true if [ellipsis] is not the empty string
  /// and there was a line that overflowed the `maxHeight` argument passed to
  /// [layout]; otherwise it is false.
  ///
  /// Valid only after [layout] has been called.
  bool get didExceedMaxLines {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.paragraph.didExceedMaxLines;
  }

  // Creates a MongolParagraph using the current configurations in this class and
  // assign it to _paragraph.
  MongolParagraph _createParagraph(InlineSpan text) {
    final builder = MongolParagraphBuilder(
      _createParagraphStyle(),
      textAlign: _textAlign,
      textScaler: _textScaler,
      maxLines: _maxLines,
      ellipsis: _ellipsis,
      rotateCJK: _rotateCJK,
    );
    _addStyleToText(builder, text);
    assert(() {
      _debugMarkNeedsLayoutCallStack = null;
      return true;
    }());
    _rebuildParagraphForPaint = false;
    return builder.build();
  }

  void _addStyleToText(
    MongolParagraphBuilder builder,
    InlineSpan inlineSpan,
  ) {
    if (inlineSpan is! TextSpan) {
      throw UnimplementedError(
          'Inline span support has not yet been implemented for MongolTextPainter');
    }
    final textSpan = inlineSpan;
    final style = textSpan.style;
    final text = textSpan.text;
    final children = textSpan.children;
    final hasStyle = style != null;
    if (hasStyle) builder.pushStyle(style);
    if (text != null) builder.addText(text);
    if (children != null) {
      for (final child in children) {
        _addStyleToText(builder, child);
      }
    }
    if (hasStyle) builder.pop();
  }

  /// Computes the visual position of the glyphs for painting the text.
  ///
  /// The text will layout with a height that's as close to its max intrinsic
  /// height (or its longest line, if [textHeightBasis] is set to
  /// [TextHeightBasis.parent]) as possible while still being greater than or
  /// equal to `minHeight` and less than or equal to `maxHeight`.
  ///
  /// The [text] property must be non-null before this is called.
  void layout({double minHeight = 0.0, double maxHeight = double.infinity}) {
    assert(!maxHeight.isNaN);
    assert(!minHeight.isNaN);
    assert(() {
      _debugNeedsRelayout = false;
      return true;
    }());

    final _TextPainterLayoutCacheWithOffset? cachedLayout = _layoutCache;
    if (cachedLayout != null &&
        cachedLayout._resizeToFit(minHeight, maxHeight, textHeightBasis)) {
      return;
    }

    final TextSpan? text = this.text;
    if (text == null) {
      throw StateError(
          'MongolTextPainter.text must be set to a non-null value before using the MongolTextPainter.');
    }

    final double paintOffsetAlignment = _computePaintOffsetFraction(textAlign);
    // Try to avoid laying out the paragraph with maxHeight=double.infinity
    // when the text is not top-aligned, so we don't have to deal with an
    // infinite paint offset.
    final bool adjustMaxHeight =
        !maxHeight.isFinite && paintOffsetAlignment != 0;
    final double? adjustedMaxHeight = !adjustMaxHeight
        ? maxHeight
        : cachedLayout?.layout.maxIntrinsicLineExtent;
    _inputHeight = adjustedMaxHeight ?? maxHeight;

    // Only rebuild the paragraph when there're layout changes, even when
    // `_rebuildParagraphForPaint` is true. It's best to not eagerly rebuild
    // the paragraph to avoid the extra work, because:
    // 1. the text color could change again before `paint` is called (so one of
    //    the paragraph rebuilds is unnecessary)
    // 2. the user could be measuring the text layout so `paint` will never be
    //    called.
    final paragraph = (cachedLayout?.paragraph ?? _createParagraph(text))
      ..layout(MongolParagraphConstraints(height: _inputHeight));
    final newLayoutCache = _TextPainterLayoutCacheWithOffset(
      _MongolTextLayout._(paragraph),
      paintOffsetAlignment,
      minHeight,
      maxHeight,
      textHeightBasis,
    );
    // Call layout again if newLayoutCache had an infinite paint offset.
    // This is not as expensive as it seems, line breaking is relatively cheap
    // as compared to shaping.
    if (adjustedMaxHeight == null && minHeight.isFinite) {
      assert(maxHeight.isInfinite);
      final double newInputHeight =
          newLayoutCache.layout.maxIntrinsicLineExtent;
      paragraph.layout(MongolParagraphConstraints(height: newInputHeight));
      _inputHeight = newInputHeight;
    }
    _layoutCache = newLayoutCache;
  }

  /// Paints the text onto the given canvas at the given offset.
  ///
  /// Valid only after [layout] has been called.
  ///
  /// If you cannot see the text being painted, check that your text color does
  /// not conflict with the background on which you are drawing. The default
  /// text color is white (to contrast with the default black background color),
  /// so if you are writing an application with a white background, the text
  /// will not be visible by default.
  ///
  /// To set the text style, specify a [TextStyle] when creating the [TextSpan]
  /// that you pass to the [MongolTextPainter] constructor or to the [text]
  /// property.
  void paint(Canvas canvas, Offset offset) {
    final _TextPainterLayoutCacheWithOffset? layoutCache = _layoutCache;
    if (layoutCache == null) {
      throw StateError(
        'MongolTextPainter.paint called when text geometry was not yet calculated.\n'
        'Please call layout() before paint() to position the text before painting it.',
      );
    }

    if (!layoutCache.paintOffset.dy.isFinite ||
        !layoutCache.paintOffset.dx.isFinite) {
      return;
    }

    if (_rebuildParagraphForPaint) {
      Size? debugSize;
      assert(() {
        debugSize = size;
        return true;
      }());

      final paragraph = layoutCache.paragraph;
      // Unfortunately even if we know that there is only paint changes, there's
      // no API to only make those updates so the paragraph has to be recreated
      // and re-laid out.
      assert(!_inputHeight.isNaN);
      layoutCache.layout._paragraph = _createParagraph(text!)
        ..layout(MongolParagraphConstraints(height: _inputHeight));
      assert(paragraph.height == layoutCache.layout._paragraph.height);
      paragraph.dispose();
      assert(debugSize == size);
    }
    assert(!_rebuildParagraphForPaint);
    layoutCache.paragraph.draw(canvas, offset + layoutCache.paintOffset);
  }

  // Returns true if value falls in the valid range of the UTF16 encoding.
  static bool _isUTF16(int value) {
    return value >= 0x0 && value <= 0xFFFFF;
  }

  /// Returns true iff the given value is a valid UTF-16 high (first) surrogate.
  /// The value must be a UTF-16 code unit, meaning it must be in the range
  /// 0x0000-0xFFFF.
  ///
  /// See also:
  ///   * https://en.wikipedia.org/wiki/UTF-16#Code_points_from_U+010000_to_U+10FFFF
  ///   * [isLowSurrogate], which checks the same thing for low (second)
  /// surrogates.
  static bool isHighSurrogate(int value) {
    assert(_isUTF16(value));
    return value & 0xFC00 == 0xD800;
  }

  /// Returns true iff the given value is a valid UTF-16 low (second) surrogate.
  /// The value must be a UTF-16 code unit, meaning it must be in the range
  /// 0x0000-0xFFFF.
  ///
  /// See also:
  ///   * https://en.wikipedia.org/wiki/UTF-16#Code_points_from_U+010000_to_U+10FFFF
  ///   * [isHighSurrogate], which checks the same thing for high (first)
  /// surrogates.
  static bool isLowSurrogate(int value) {
    assert(_isUTF16(value));
    return value & 0xFC00 == 0xDC00;
  }

  // Checks if the glyph is either [Unicode.RLM] or [Unicode.LRM]. These values take
  // up zero space and do not have valid bounding boxes around them.
  //
  // We do not directly use the [Unicode] constants since they are strings.
  static bool _isUnicodeDirectionality(int value) {
    return value == 0x200F || value == 0x200E;
  }

  /// Returns the closest offset after `offset` at which the input cursor can be
  /// positioned.
  int? getOffsetAfter(int offset) {
    final int? nextCodeUnit = _text!.codeUnitAt(offset);
    if (nextCodeUnit == null) {
      return null;
    }
    return isHighSurrogate(nextCodeUnit) ? offset + 2 : offset + 1;
  }

  /// Returns the closest offset before `offset` at which the input cursor can
  /// be positioned.
  int? getOffsetBefore(int offset) {
    final int? prevCodeUnit = _text!.codeUnitAt(offset - 1);
    if (prevCodeUnit == null) {
      return null;
    }
    return isLowSurrogate(prevCodeUnit) ? offset - 2 : offset - 1;
  }

  // Unicode value for a zero width joiner character.
  static const int _zwjUtf16 = 0x200d;

  // Get the caret metrics (in logical pixels) based off the near edge of the
  // character upstream from the given string offset.
  _CaretMetrics? _getMetricsFromUpstream(int offset) {
    assert(offset >= 0);
    final int plainTextLength = plainText.length;
    if (plainTextLength == 0 || offset > plainTextLength) {
      return null;
    }
    final int prevCodeUnit = plainText.codeUnitAt(max(0, offset - 1));

    // If the upstream character is a newline, cursor is at start of next line
    const int newlineCodeUnit = 10;

    // Check for multi-code-unit glyphs such as emojis or zero width joiner.
    final bool needsSearch = isHighSurrogate(prevCodeUnit) ||
        isLowSurrogate(prevCodeUnit) ||
        _text!.codeUnitAt(offset) == _zwjUtf16 ||
        _isUnicodeDirectionality(prevCodeUnit);
    int graphemeClusterLength = needsSearch ? 2 : 1;
    List<Rect> boxes = <Rect>[];
    while (boxes.isEmpty) {
      final int prevRuneOffset = offset - graphemeClusterLength;
      boxes = _layoutCache!.paragraph
          .getBoxesForRange(max(0, prevRuneOffset), offset);
      // When the range does not include a full cluster, no boxes will be returned.
      if (boxes.isEmpty) {
        // When we are at the beginning of the line, a non-surrogate position will
        // return empty boxes. We break and try from downstream instead.
        if (!needsSearch && prevCodeUnit == newlineCodeUnit) {
          break; // Only perform one iteration if no search is required.
        }
        if (prevRuneOffset < -plainTextLength) {
          break; // Stop iterating when beyond the max length of the text.
        }
        // Multiply by two to log(n) time cover the entire text span. This allows
        // faster discovery of very long clusters and reduces the possibility
        // of certain large clusters taking much longer than others, which can
        // cause jank.
        graphemeClusterLength *= 2;
        continue;
      }

      // Try to identify the box nearest the offset.  This logic works when
      // there's just one box, and when all boxes have the same direction.
      final box = boxes.last;
      return prevCodeUnit == newlineCodeUnit
          ? _EmptyLineCaretMetrics(lineHorizontalOffset: box.right)
          : _LineCaretMetrics(
              offset: Offset(box.left, box.bottom),
              fullWidth: box.right - box.left,
            );
    }
    return null;
  }

  // Get the caret metrics (in logical pixels) based off the near edge of the
  // character downstream from the given string offset.
  _CaretMetrics? _getMetricsFromDownstream(int offset) {
    assert(offset >= 0);
    final int plainTextLength = plainText.length;
    if (plainTextLength == 0) {
      return null;
    }
    // We cap the offset at the final index of plain text.
    final int nextCodeUnit =
        plainText.codeUnitAt(min(offset, plainTextLength - 1));

    // Check for multi-code-unit glyphs such as emojis or zero width joiner
    final bool needsSearch = isHighSurrogate(nextCodeUnit) ||
        isLowSurrogate(nextCodeUnit) ||
        nextCodeUnit == _zwjUtf16 ||
        _isUnicodeDirectionality(nextCodeUnit);
    int graphemeClusterLength = needsSearch ? 2 : 1;
    List<Rect> boxes = <Rect>[];
    while (boxes.isEmpty) {
      final int nextRuneOffset = offset + graphemeClusterLength;
      boxes = _layoutCache!.paragraph.getBoxesForRange(offset, nextRuneOffset);
      // When the range does not include a full cluster, no boxes will be returned.
      if (boxes.isEmpty) {
        // When we are at the end of the line, a non-surrogate position will
        // return empty boxes. We break and try from upstream instead.
        if (!needsSearch) {
          break; // Only perform one iteration if no search is required.
        }
        if (nextRuneOffset >= plainTextLength << 1) {
          break; // Stop iterating when beyond the max length of the text.
        }
        // Multiply by two to log(n) time cover the entire text span. This allows
        // faster discovery of very long clusters and reduces the possibility
        // of certain large clusters taking much longer than others, which can
        // cause jank.
        graphemeClusterLength *= 2;
        continue;
      }

      // Try to identify the box nearest the offset.  This logic works when
      // there's just one box, and when all boxes have the same direction.
      final box = boxes.first;
      return _LineCaretMetrics(
        offset: Offset(box.left, box.top),
        fullWidth: box.right - box.left,
      );
    }
    return null;
  }

  static double _computePaintOffsetFraction(MongolTextAlign textAlign) {
    return switch (textAlign) {
      MongolTextAlign.top => 0.0,
      MongolTextAlign.bottom => 1.0,
      MongolTextAlign.center => 0.5,
      MongolTextAlign.justify => 0.0,
    };
  }

  /// Returns the offset at which to paint the caret.
  ///
  /// Valid only after [layout] has been called.
  Offset getOffsetForCaret(TextPosition position, Rect caretPrototype) {
    final _CaretMetrics caretMetrics;
    final _TextPainterLayoutCacheWithOffset layoutCache = _layoutCache!;
    if (position.offset < 0) {
      caretMetrics = const _EmptyLineCaretMetrics(lineHorizontalOffset: 0);
    } else {
      caretMetrics = _computeCaretMetrics(position);
    }

    final Offset rawOffset;
    switch (caretMetrics) {
      case _EmptyLineCaretMetrics(:final double lineHorizontalOffset):
        final double paintOffsetAlignment =
            _computePaintOffsetFraction(textAlign);
        // The full height is not (height - caretPrototype.height)
        // because MongolRenderEditable reserves cursor height on the bottom. Ideally this
        // should be handled by MongolRenderEditable instead.
        final double dy = paintOffsetAlignment == 0
            ? 0
            : paintOffsetAlignment * layoutCache.contentHeight;
        return Offset(lineHorizontalOffset, dy);
      case _LineCaretMetrics(:final Offset offset):
        rawOffset = offset;
    }
    // If offset.dy is outside of the advertised content area, then the associated
    // glyph cluster belongs to a trailing newline character. Ideally the behavior
    // should be handled by higher-level implementations (for instance,
    // MongolRenderEditable reserves height for showing the caret, it's best to handle
    // the clamping there).
    final double adjustedDy = clampDouble(
        rawOffset.dy + layoutCache.paintOffset.dy,
        0,
        layoutCache.contentHeight);
    return Offset(rawOffset.dx + layoutCache.paintOffset.dx, adjustedDy);
  }

  /// Returns the strut bounded width of the glyph at the given `position`.
  ///
  /// Valid only after [layout] has been called.
  double? getFullWidthForCaret(TextPosition position, Rect caretPrototype) {
    if (position.offset < 0) {
      return null;
    }
    return switch (_computeCaretMetrics(position)) {
      _LineCaretMetrics(:final double fullWidth) => fullWidth,
      _EmptyLineCaretMetrics() => null,
    };
  }

  // Cached caret metrics. This allows multiple invokes of [getOffsetForCaret] and
  // [getFullWidthForCaret] in a row without performing redundant and expensive
  // get rect calls to the paragraph.
  late _CaretMetrics _caretMetrics;

  // Checks if the [position] and [caretPrototype] have changed from the cached
  // version and recomputes the metrics required to position the caret.
  _CaretMetrics _computeCaretMetrics(TextPosition position) {
    assert(_debugAssertTextLayoutIsValid);
    assert(!_debugNeedsRelayout);
    final _TextPainterLayoutCacheWithOffset cachedLayout = _layoutCache!;
    if (position == cachedLayout._previousCaretPosition) {
      return _caretMetrics;
    }
    final int offset = position.offset;
    final _CaretMetrics? metrics = switch (position.affinity) {
      TextAffinity.upstream =>
        _getMetricsFromUpstream(offset) ?? _getMetricsFromDownstream(offset),
      TextAffinity.downstream =>
        _getMetricsFromDownstream(offset) ?? _getMetricsFromUpstream(offset),
    };
    // Cache the input parameters to prevent repeat work later.
    cachedLayout._previousCaretPosition = position;
    return _caretMetrics =
        metrics ?? const _EmptyLineCaretMetrics(lineHorizontalOffset: 0);
  }

  /// Returns a list of rects that bound the given selection.
  ///
  /// The [selection] must be a valid range (with [TextSelection.isValid] true).
  ///
  /// Leading or trailing newline characters will be represented by zero-height
  /// `Rect`s.
  ///
  /// The method only returns `Rect`s of glyphs that are entirely enclosed by
  /// the given `selection`: a multi-code-unit glyph will be excluded if only
  /// part of its code units are in `selection`.
  List<Rect> getBoxesForSelection(TextSelection selection) {
    assert(_debugAssertTextLayoutIsValid);
    assert(selection.isValid);
    assert(!_debugNeedsRelayout);
    final _TextPainterLayoutCacheWithOffset cachedLayout = _layoutCache!;
    final Offset offset = cachedLayout.paintOffset;
    if (!offset.dy.isFinite || !offset.dx.isFinite) {
      return <Rect>[];
    }
    final boxes = cachedLayout.paragraph.getBoxesForRange(
      selection.start,
      selection.end,
    );
    return offset == Offset.zero
        ? boxes
        : boxes
            .map((Rect box) => _shiftTextBox(box, offset))
            .toList(growable: false);
  }

  /// Returns the position within the text for the given pixel offset.
  TextPosition getPositionForOffset(Offset offset) {
    assert(_debugAssertTextLayoutIsValid);
    assert(!_debugNeedsRelayout);
    final _TextPainterLayoutCacheWithOffset cachedLayout = _layoutCache!;
    return cachedLayout.paragraph
        .getPositionForOffset(offset - cachedLayout.paintOffset);
  }

  /// Returns the text range of the word at the given offset. Characters not
  /// part of a word, such as spaces, symbols, and punctuation, have word breaks
  /// on both sides. In such cases, this method will return a text range that
  /// contains the given text position.
  ///
  /// Word boundaries are defined more precisely in Unicode Standard Annex #29
  /// <http://www.unicode.org/reports/tr29/#Word_Boundaries>.
  TextRange getWordBoundary(TextPosition position) {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.paragraph.getWordBoundary(position);
  }

  /// Returns a [TextBoundary] that can be used to perform word boundary analysis
  /// on the current [text].
  ///
  /// This [TextBoundary] uses word boundary rules defined in [Unicode Standard
  /// Annex #29](http://www.unicode.org/reports/tr29/#Word_Boundaries).
  ///
  /// Currently word boundary analysis can only be performed after [layout]
  /// has been called.
  MongolWordBoundary get wordBoundaries =>
      MongolWordBoundary._(text!, _layoutCache!.paragraph);

  /// Returns the text range of the line at the given offset.
  ///
  /// The newline (if any) is not returned as part of the range.
  TextRange getLineBoundary(TextPosition position) {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.paragraph.getLineBoundary(position);
  }

  static MongolLineMetrics _shiftLineMetrics(
      MongolLineMetrics metrics, Offset offset) {
    assert(offset.dx.isFinite);
    assert(offset.dy.isFinite);
    return MongolLineMetrics(
      hardBreak: metrics.hardBreak,
      ascent: metrics.ascent,
      descent: metrics.descent,
      unscaledAscent: metrics.unscaledAscent,
      height: metrics.height,
      width: metrics.width,
      top: metrics.top + offset.dy,
      baseline: metrics.baseline + offset.dx,
      lineNumber: metrics.lineNumber,
    );
  }

  static Rect _shiftTextBox(Rect box, Offset offset) {
    assert(offset.dx.isFinite);
    assert(offset.dy.isFinite);
    return Rect.fromLTRB(
      box.left + offset.dx,
      box.top + offset.dy,
      box.right + offset.dx,
      box.bottom + offset.dy,
    );
  }

  /// Returns the full list of [MongolLineMetrics] that describe in detail the various
  /// metrics of each laid out line.
  ///
  /// The [MongolLineMetrics] list is presented in the order of the lines they represent.
  /// For example, the first line is in the zeroth index.
  ///
  /// [MongolLineMetrics] contains measurements such as ascent, descent, baseline, and
  /// height for the line as a whole, and may be useful for aligning additional
  /// widgets to a particular line.
  ///
  /// Valid only after [layout] has been called.
  List<MongolLineMetrics> computeLineMetrics() {
    assert(_debugAssertTextLayoutIsValid);
    assert(!_debugNeedsRelayout);
    final _TextPainterLayoutCacheWithOffset layout = _layoutCache!;
    final Offset offset = layout.paintOffset;
    if (!offset.dy.isFinite || !offset.dx.isFinite) {
      return const <MongolLineMetrics>[];
    }
    final List<MongolLineMetrics> rawMetrics = layout.lineMetrics;
    return offset == Offset.zero
        ? rawMetrics
        : rawMetrics
            .map((MongolLineMetrics metrics) =>
                _shiftLineMetrics(metrics, offset))
            .toList(growable: false);
  }

  bool _disposed = false;

  /// Whether this object has been disposed or not.
  ///
  /// Only for use when asserts are enabled.
  bool get debugDisposed {
    bool? disposed;
    assert(() {
      disposed = _disposed;
      return true;
    }());
    return disposed ??
        (throw StateError('debugDisposed only available when asserts are on.'));
  }

  /// Releases the resources associated with this painter.
  ///
  /// After disposal this painter is unusable.
  void dispose() {
    assert(() {
      _disposed = true;
      return true;
    }());
    _layoutTemplate?.dispose();
    _layoutTemplate = null;
    _layoutCache?.paragraph.dispose();
    _layoutCache = null;
    _text = null;
  }
}
