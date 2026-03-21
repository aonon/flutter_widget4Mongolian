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

  /// 计算指定配置下文本绘制器的实际高度
  ///
  /// 实际高度是指文本在指定约束条件下布局后的实际占用高度，
  /// 它会根据 [textHeightBasis] 参数的不同而有所变化：
  /// - [TextHeightBasis.parent]：多行文本占满父容器高度，单行文本使用最小高度
  /// - [TextHeightBasis.longestLine]：高度仅足以容纳最长行
  ///
  /// 这是一个静态便捷方法，其工作流程：
  /// 1. 使用提供的参数创建一个临时 [MongolTextPainter] 实例
  /// 2. 使用指定的 [minHeight] 和 [maxHeight] 调用 [layout] 方法进行布局
  /// 3. 获取并返回 [height] 属性值
  /// 4. 无论计算成功与否，都会释放临时绘制器的资源
  ///
  /// 性能注意事项：
  /// - 此操作成本较高，因为它需要创建、布局和销毁一个完整的文本绘制器实例
  /// - 当需要多次获取文本度量信息时，建议创建并重用一个 [MongolTextPainter] 实例
  /// - 仅在单次使用场景下或无法重用绘制器时使用此静态方法
  ///
  /// 参数说明：
  /// - [text]：要计算的文本内容，必须提供
  /// - [textAlign]：文本对齐方式，默认为顶部对齐
  /// - [textScaleFactor]：已弃用，请使用 [textScaler] 替代
  /// - [textScaler]：字体缩放策略，用于调整文本大小
  /// - [maxLines]：最大行数限制，null 表示无限制
  /// - [ellipsis]：溢出时显示的省略符号
  /// - [textHeightBasis]：高度计算方式，默认为基于父容器
  /// - [minHeight]：最小高度约束，默认为 0.0
  /// - [maxHeight]：最大高度约束，默认为无限大
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

  /// 计算指定配置下文本绘制器的最大内在高度
  ///
  /// 最大内在高度是指文本在垂直方向上能够达到的最大高度，
  /// 当文本高度增加到这个值后，继续增加高度不会再减少宽度
  ///
  /// 这是一个静态便捷方法，其工作流程：
  /// 1. 使用提供的参数创建一个临时 [MongolTextPainter] 实例
  /// 2. 使用指定的 [minHeight] 和 [maxHeight] 调用 [layout] 方法进行布局
  /// 3. 获取并返回 [maxIntrinsicHeight] 属性值
  /// 4. 无论计算成功与否，都会释放临时绘制器的资源
  ///
  /// 性能注意事项：
  /// - 此操作成本较高，因为它需要创建、布局和销毁一个完整的文本绘制器实例
  /// - 当需要多次获取文本度量信息时，建议创建并重用一个 [MongolTextPainter] 实例
  /// - 仅在单次使用场景下或无法重用绘制器时使用此静态方法
  ///
  /// 参数说明：
  /// - [text]：要计算的文本内容，必须提供
  /// - [textAlign]：文本对齐方式，默认为顶部对齐
  /// - [textScaleFactor]：已弃用，请使用 [textScaler] 替代
  /// - [textScaler]：字体缩放策略，用于调整文本大小
  /// - [maxLines]：最大行数限制，null 表示无限制
  /// - [ellipsis]：溢出时显示的省略符号
  /// - [textHeightBasis]：高度计算方式，默认为基于父容器
  /// - [minHeight]：最小高度约束，默认为 0.0
  /// - [maxHeight]：最大高度约束，默认为无限大
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

  /// 标记文本绘制器的布局信息为脏状态并清除布局缓存
  ///
  /// 当文本绘制器的属性（如文本内容、样式、对齐方式等）发生变化时，
  /// 需要调用此方法通知绘制器在下一次绘制前重新计算布局
  ///
  /// 内部实现：
  /// 1. 如果启用断言，记录导致布局失效的调用栈，便于调试
  /// 2. 释放当前布局缓存中可能持有的 [MongolParagraph] 资源
  /// 3. 清除布局缓存引用，触发下一次布局计算
  ///
  /// 注意：在大多数情况下，更新绘制器属性后会自动调用此方法，无需手动调用
  /// 只有在特殊情况下（如引擎层面的布局变化）才需要手动调用
  void markNeedsLayout() {
    assert(() {
      if (_layoutCache != null) {
        _debugMarkNeedsLayoutCallStack ??= StackTrace.current; // 记录调用栈，用于调试布局失效问题
      }
      return true;
    }());
    _layoutCache?.paragraph.dispose(); // 释放当前段落资源
    _layoutCache = null; // 清除布局缓存，标记为需要重新布局
  }

  /// 要绘制的文本内容，可以是带样式的文本树
  ///
  /// 此属性接受 [TextSpan] 对象，用于表示复杂的富文本内容
  /// - 单个 [TextSpan] 可表示简单的带样式文本
  /// - 嵌套的 [TextSpan] 可表示复杂的富文本树结构
  ///
  /// 关键特性：
  /// - 设置为 null 时，表示没有文本内容
  /// - 在调用 [layout] 方法之前，此属性必须非空，否则会抛出异常
  /// - 更改此属性后，需要根据文本变化的类型决定是否重新布局或仅重新绘制
  ///
  /// 文本变化处理逻辑：
  /// 1. 比较新旧文本的样式，如果样式变化则释放并重置布局模板
  /// 2. 使用 [RenderComparison] 评估文本变化程度
  /// 3. 如果是布局级别的变化（如文本内容、字体大小等），标记需要重新布局
  /// 4. 如果仅是绘制级别的变化（如文本颜色），标记需要重建段落但不需要重新布局
  /// 5. 清除纯文本缓存，因为文本内容已变化
  ///
  /// 获取纯文本内容：使用 [plainText] 属性获取此文本的纯文本表示
  TextSpan? get text => _text;
  TextSpan? _text;
  set text(TextSpan? value) {
    assert(value == null || value.debugAssertIsValid()); // 确保文本树结构有效
    
    if (_text == value) {
      return; // 文本未变化，无需操作
    }
    
    // 检查样式是否变化，变化则重置布局模板
    if (_text?.style != value?.style) {
      _layoutTemplate?.dispose();
      _layoutTemplate = null;
    }

    // 评估文本变化程度
    final RenderComparison comparison = value == null
        ? RenderComparison.layout // 从有文本变为无文本，属于布局变化
        : _text?.compareTo(value) ?? RenderComparison.layout; // 比较新旧文本

    _text = value;
    _cachedPlainText = null; // 清除纯文本缓存

    if (comparison.index >= RenderComparison.layout.index) {
      markNeedsLayout(); // 布局级变化，标记需要重新布局
    } else if (comparison.index >= RenderComparison.paint.index) {
      // 仅绘制级变化，无需重新布局，但需要重建段落
      _rebuildParagraphForPaint = true;
    }
    // 否则：既不需要重布局也不需要重绘
  }

  /// 获取文本内容的纯文本表示，忽略所有样式信息
  ///
  /// 此属性提供了一种便捷方式获取 [text] 属性中 [TextSpan] 树的纯文本内容
  /// 内部实现：
  /// 1. 使用 [TextSpan.toPlainText] 方法递归遍历文本树，提取所有文本内容
  /// 2. 缓存结果以提高性能，避免重复计算
  /// 3. 当 [text] 属性变化时，缓存会自动失效
  ///
  /// 重要特性：
  /// - 忽略所有样式信息（如颜色、字体、大小等），仅返回文本字符
  /// - 不包含语义标签（includeSemanticsLabels: false）
  /// - 当 [text] 为 null 时，返回空字符串 ''
  /// - 当文本树结构复杂时，首次访问可能有轻微性能开销，但后续访问会使用缓存
  ///
  /// 使用场景：
  /// - 需要获取文本长度或进行文本搜索时
  /// - 需要将富文本转换为纯文本进行处理时
  /// - 需要在调试时查看实际文本内容时
  String get plainText {
    _cachedPlainText ??= _text?.toPlainText(includeSemanticsLabels: false); // 懒加载并缓存结果
    return _cachedPlainText ?? ''; // 确保始终返回非空字符串
  }

  String? _cachedPlainText;

  /// 文本在垂直方向上的对齐方式
  ///
  /// 由于蒙古文是垂直排版的，此属性控制文本在垂直方向上的对齐
  /// - [MongolTextAlign.top]：文本顶部对齐（默认值）
  /// - [MongolTextAlign.center]：文本垂直居中对齐
  /// - [MongolTextAlign.bottom]：文本底部对齐
  /// - [MongolTextAlign.justify]：文本两端对齐
  ///
  /// 更改此属性后，必须调用 [layout] 方法重新布局文本，然后才能调用 [paint] 进行绘制
  /// 这是因为对齐方式会影响文本的布局计算
  MongolTextAlign get textAlign => _textAlign;
  MongolTextAlign _textAlign;
  set textAlign(MongolTextAlign value) {
    if (_textAlign == value) {
      return; // 对齐方式未改变，无需操作
    }
    _textAlign = value;
    markNeedsLayout(); // 对齐方式改变，标记需要重新布局
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
    // textAlign 应该始终为 `left`，因为这是单个文本 run 的样式。
    // MongolTextAlign 在其他地方处理。
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
          // 使用默认字体大小进行乘法，因为 MongolRichText 不执行
          // 继承 [TextStyle]，否则将无法应用 textScaleFactor。
          fontSize: textScaler.scale(_kDefaultFontSize),
          maxLines: maxLines,
          ellipsis: ellipsis,
          locale: null,
        );
  }

  MongolParagraph? _layoutTemplate;
  MongolParagraph _createLayoutTemplate() {
    final builder = MongolParagraphBuilder(_createParagraphStyle());
    // MongolParagraphBuilder 将处理将绘制器 TextStyle 转换为
    // ui.TextStyle 以及应用文本缩放器。
    final textStyle = text?.style;
    if (textStyle != null) {
      builder.pushStyle(textStyle);
    }
    builder.addText(' ');
    return builder.build()
      ..layout(const MongolParagraphConstraints(height: double.infinity));
  }

  /// [text] 中一个空格的逻辑像素宽度。
  ///
  /// （这是在垂直方向上。换句话说，它是水平方向上一个空格的高度。）
  ///
  /// 并非 [text] 中的每一行文本都会有此宽度，但此宽度对于 [text] 中的文本来说是 "典型的"，
  /// 可用于相对于典型文本行调整其他对象的大小。
  ///
  /// 获取此值不需要调用 [layout]。
  ///
  /// [text] 属性的样式用于确定影响 [preferredLineWidth] 的字体设置。
  /// 如果 [text] 为 null 或未指定任何样式，则使用默认的 [TextStyle] 值（10 像素的无衬线字体）。
  double get preferredLineWidth =>
      (_layoutTemplate ??= _createLayoutTemplate()).width;

  /// 减小文本高度会阻止其完全绘制在其边界内的高度。
  ///
  /// 仅在调用 [layout] 后有效。
  double get minIntrinsicHeight {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.layout.minIntrinsicLineExtent;
  }

  /// 增加文本高度不再减少宽度的高度。
  ///
  /// 仅在调用 [layout] 后有效。
  double get maxIntrinsicHeight {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.layout.maxIntrinsicLineExtent;
  }

  /// 绘制此文本所需的垂直空间。
  ///
  /// 仅在调用 [layout] 后有效。
  double get height {
    assert(_debugAssertTextLayoutIsValid);
    assert(!_debugNeedsRelayout);
    return _layoutCache!.contentHeight;
  }

  /// 绘制此文本所需的水平空间。
  ///
  /// 仅在调用 [layout] 后有效。
  double get width {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.layout.width;
  }

  /// 绘制此文本所需的空间大小。
  ///
  /// 仅在调用 [layout] 后有效。
  Size get size {
    assert(_debugAssertTextLayoutIsValid);
    assert(!_debugNeedsRelayout);
    return Size(width, height);
  }

  /// 尽管文本被旋转，但沿基线布局对象仍然很有用。（例如在 MongolInputDecorator 中。）
  ///
  /// 仅在调用 [layout] 后有效。
  double computeDistanceToActualBaseline(TextBaseline baseline) {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.layout.getDistanceToBaseline(baseline);
  }

  /// 是否有任何文本被截断或省略。
  ///
  /// 如果 [maxLines] 不为 null，当要绘制的行数超过给定的 [maxLines]，
  /// 因此输出中至少省略了一行时，返回 true；否则返回 false。
  ///
  /// 如果 [maxLines] 为 null，当 [ellipsis] 不是空字符串且有一行溢出了传递给
  /// [layout] 的 `maxHeight` 参数时，返回 true；否则返回 false。
  ///
  /// 仅在调用 [layout] 后有效。
  bool get didExceedMaxLines {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.paragraph.didExceedMaxLines;
  }

  // 使用此类中的当前配置创建 MongolParagraph 并将其分配给 _paragraph。
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

  /// 计算用于绘制文本的字形的视觉位置。
  ///
  /// 文本将以尽可能接近其最大内在高度（如果 [textHeightBasis] 设置为
  /// [TextHeightBasis.parent]，则为其最长行）的高度进行布局，
  /// 同时仍大于或等于 `minHeight` 且小于或等于 `maxHeight`。
  ///
  /// 在调用此方法之前，[text] 属性必须非空。
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
    // 尽量避免在文本非顶部对齐时使用 maxHeight=double.infinity 布局段落，
    // 这样我们就不需要处理无限的绘制偏移量。
    final bool adjustMaxHeight =
        !maxHeight.isFinite && paintOffsetAlignment != 0;
    final double? adjustedMaxHeight = !adjustMaxHeight
        ? maxHeight
        : cachedLayout?.layout.maxIntrinsicLineExtent;
    _inputHeight = adjustedMaxHeight ?? maxHeight;

    // 只有在布局变化时才重建段落，即使 `_rebuildParagraphForPaint` 为 true。
    // 最好不要急于重建段落以避免额外工作，因为：
    // 1. 在调用 `paint` 之前，文本颜色可能会再次更改（因此其中一次段落重建是不必要的）
    // 2. 用户可能正在测量文本布局，因此永远不会调用 `paint`。
    final paragraph = (cachedLayout?.paragraph ?? _createParagraph(text))
      ..layout(MongolParagraphConstraints(height: _inputHeight));
    final newLayoutCache = _TextPainterLayoutCacheWithOffset(
      _MongolTextLayout._(paragraph),
      paintOffsetAlignment,
      minHeight,
      maxHeight,
      textHeightBasis,
    );
    // 如果 newLayoutCache 有无限的绘制偏移量，则再次调用 layout。
    // 这并不像看起来那么昂贵，与字形绘制相比，换行相对便宜。
    if (adjustedMaxHeight == null && minHeight.isFinite) {
      assert(maxHeight.isInfinite);
      final double newInputHeight =
          newLayoutCache.layout.maxIntrinsicLineExtent;
      paragraph.layout(MongolParagraphConstraints(height: newInputHeight));
      _inputHeight = newInputHeight;
    }
    _layoutCache = newLayoutCache;
  }

  /// 将文本绘制到给定偏移量的给定画布上。
  ///
  /// 仅在调用 [layout] 后有效。
  ///
  /// 如果看不到正在绘制的文本，请检查文本颜色是否与您绘制的背景冲突。
  /// 默认文本颜色为白色（与默认黑色背景颜色形成对比），
  /// 因此如果您正在编写具有白色背景的应用程序，文本默认将不可见。
  ///
  /// 要设置文本样式，请在创建传递给 [MongolTextPainter] 构造函数或 [text]
  /// 属性的 [TextSpan] 时指定 [TextStyle]。
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
      // 不幸的是，即使我们知道只有绘制更改，也没有 API 只更新这些更改，
      // 因此必须重新创建并重新布局段落。
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

  // 如果值在 UTF16 编码的有效范围内，则返回 true。
  static bool _isUTF16(int value) {
    return value >= 0x0 && value <= 0xFFFFF;
  }

  /// 当且仅当给定值是有效的 UTF-16 高（第一个）代理项时返回 true。
  /// 该值必须是 UTF-16 代码单元，这意味着它必须在 0x0000-0xFFFF 范围内。
  ///
  /// 另请参阅：
  ///   * https://en.wikipedia.org/wiki/UTF-16#Code_points_from_U+010000_to_U+10FFFF
  ///   * [isLowSurrogate]，它对低（第二个）代理项执行相同的检查。
  static bool isHighSurrogate(int value) {
    assert(_isUTF16(value));
    return value & 0xFC00 == 0xD800;
  }

  /// 当且仅当给定值是有效的 UTF-16 低（第二个）代理项时返回 true。
  /// 该值必须是 UTF-16 代码单元，这意味着它必须在 0x0000-0xFFFF 范围内。
  ///
  /// 另请参阅：
  ///   * https://en.wikipedia.org/wiki/UTF-16#Code_points_from_U+010000_to_U+10FFFF
  ///   * [isHighSurrogate]，它对高（第一个）代理项执行相同的检查。
  static bool isLowSurrogate(int value) {
    assert(_isUTF16(value));
    return value & 0xFC00 == 0xDC00;
  }

  // 检查字形是否为 [Unicode.RLM] 或 [Unicode.LRM]。这些值占用零空间且周围没有有效的边界框。
  //
  // 我们不直接使用 [Unicode] 常量，因为它们是字符串。
  static bool _isUnicodeDirectionality(int value) {
    return value == 0x200F || value == 0x200E;
  }

  /// 返回输入光标可以定位的 `offset` 之后最近的偏移量。
  int? getOffsetAfter(int offset) {
    final int? nextCodeUnit = _text!.codeUnitAt(offset);
    if (nextCodeUnit == null) {
      return null;
    }
    return isHighSurrogate(nextCodeUnit) ? offset + 2 : offset + 1;
  }

  /// 返回输入光标可以定位的 `offset` 之前最近的偏移量。
  int? getOffsetBefore(int offset) {
    final int? prevCodeUnit = _text!.codeUnitAt(offset - 1);
    if (prevCodeUnit == null) {
      return null;
    }
    return isLowSurrogate(prevCodeUnit) ? offset - 2 : offset - 1;
  }

  // 零宽度连接符字符的 Unicode 值。
  static const int _zwjUtf16 = 0x200d;

  // 基于给定字符串偏移量上游字符的近边缘获取插入符度量（以逻辑像素为单位）。
  _CaretMetrics? _getMetricsFromUpstream(int offset) {
    assert(offset >= 0);
    final int plainTextLength = plainText.length;
    if (plainTextLength == 0 || offset > plainTextLength) {
      return null;
    }
    final int prevCodeUnit = plainText.codeUnitAt(max(0, offset - 1));

    // 如果上游字符是换行符，则光标位于下一行的开始
    const int newlineCodeUnit = 10;

    // 检查多代码单元字形，如表情符号或零宽度连接符.
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
      // 当范围不包含完整的集群时，不会返回任何框。
      if (boxes.isEmpty) {
        // 当我们在行的开头时，非代理位置将返回空框。我们中断并尝试从下游开始。
        if (!needsSearch && prevCodeUnit == newlineCodeUnit) {
          break; // 如果不需要搜索，只执行一次迭代。
        }
        if (prevRuneOffset < -plainTextLength) {
          break; // 当超出文本的最大长度时停止迭代。
        }
        // 乘以2以 log(n) 时间覆盖整个文本范围。这允许更快地发现非常长的集群，
        // 并减少某些大型集群比其他集群花费更长时间的可能性，这可能导致卡顿。
        graphemeClusterLength *= 2;
        continue;
      }

      // 尝试识别最接近偏移量的框。当只有一个框且所有框具有相同方向时，此逻辑有效。
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

  // 基于给定字符串偏移量下游字符的近边缘获取插入符度量（以逻辑像素为单位）。
  _CaretMetrics? _getMetricsFromDownstream(int offset) {
    assert(offset >= 0);
    final int plainTextLength = plainText.length;
    if (plainTextLength == 0) {
      return null;
    }
    // 我们将偏移量限制在纯文本的最终索引处。
    final int nextCodeUnit =
        plainText.codeUnitAt(min(offset, plainTextLength - 1));

    // 检查多代码单元字形，如表情符号或零宽度连接符
    final bool needsSearch = isHighSurrogate(nextCodeUnit) ||
        isLowSurrogate(nextCodeUnit) ||
        nextCodeUnit == _zwjUtf16 ||
        _isUnicodeDirectionality(nextCodeUnit);
    int graphemeClusterLength = needsSearch ? 2 : 1;
    List<Rect> boxes = <Rect>[];
    while (boxes.isEmpty) {
      final int nextRuneOffset = offset + graphemeClusterLength;
      boxes = _layoutCache!.paragraph.getBoxesForRange(offset, nextRuneOffset);
      // 当范围不包含完整的集群时，不会返回任何框。
      if (boxes.isEmpty) {
        // 当我们在行的末尾时，非代理位置将返回空框。我们中断并尝试从上游开始。
        if (!needsSearch) {
          break; // 如果不需要搜索，只执行一次迭代。
        }
        if (nextRuneOffset >= plainTextLength << 1) {
          break; // 当超出文本的最大长度时停止迭代。
        }
        // 乘以2以 log(n) 时间覆盖整个文本范围。这允许更快地发现非常长的集群，
        // 并减少某些大型集群比其他集群花费更长时间的可能性，这可能导致卡顿。
        graphemeClusterLength *= 2;
        continue;
      }

      // 尝试识别最接近偏移量的框。当只有一个框且所有框具有相同方向时，此逻辑有效。
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

  /// 返回绘制插入符的偏移量。
  ///
  /// 仅在调用 [layout] 后有效。
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
        // 完整高度不是 (height - caretPrototype.height)
        // 因为 MongolRenderEditable 在底部预留了光标高度。理想情况下，这
        // 应该由 MongolRenderEditable 来处理。
        final double dy = paintOffsetAlignment == 0
            ? 0
            : paintOffsetAlignment * layoutCache.contentHeight;
        return Offset(lineHorizontalOffset, dy);
      case _LineCaretMetrics(:final Offset offset):
        rawOffset = offset;
    }
    // 如果 offset.dy 超出了公布的内容区域，那么相关的字形集群属于尾随换行符。
    // 理想情况下，这种行为应该由更高层的实现来处理（例如，
    // MongolRenderEditable 为显示插入符预留了高度，最好在那里处理
    // 截断）。
    final double adjustedDy = clampDouble(
        rawOffset.dy + layoutCache.paintOffset.dy,
        0,
        layoutCache.contentHeight);
    return Offset(rawOffset.dx + layoutCache.paintOffset.dx, adjustedDy);
  }

  /// 返回给定 `position` 处字形的支柱边界宽度。
  ///
  /// 仅在调用 [layout] 后有效。
  double? getFullWidthForCaret(TextPosition position, Rect caretPrototype) {
    if (position.offset < 0) {
      return null;
    }
    return switch (_computeCaretMetrics(position)) {
      _LineCaretMetrics(:final double fullWidth) => fullWidth,
      _EmptyLineCaretMetrics() => null,
    };
  }

  // 缓存的插入符度量。这允许连续多次调用 [getOffsetForCaret] 和
  // [getFullWidthForCaret]，而无需对段落执行冗余且昂贵的获取矩形调用。
  late _CaretMetrics _caretMetrics;

  // 检查 [position] 和 [caretPrototype] 是否已从缓存版本更改，并重新计算定位插入符所需的度量。
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
    // 缓存输入参数以防止以后重复工作。
    cachedLayout._previousCaretPosition = position;
    return _caretMetrics =
        metrics ?? const _EmptyLineCaretMetrics(lineHorizontalOffset: 0);
  }

  /// 返回界定给定选择范围的矩形列表。
  ///
  /// [selection] 必须是有效的范围（[TextSelection.isValid] 为 true）。
  ///
  /// 前导或尾随换行符将由零高度的 `Rect` 表示。
  ///
  /// 该方法仅返回完全包含在给定 `selection` 中的字形的 `Rect`：
  /// 如果仅部分代码单元在 `selection` 中，则多代码单元字形将被排除。
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

  /// 返回给定像素偏移量在文本中的位置。
  TextPosition getPositionForOffset(Offset offset) {
    assert(_debugAssertTextLayoutIsValid);
    assert(!_debugNeedsRelayout);
    final _TextPainterLayoutCacheWithOffset cachedLayout = _layoutCache!;
    return cachedLayout.paragraph
        .getPositionForOffset(offset - cachedLayout.paintOffset);
  }

  /// 返回给定偏移量处单词的文本范围。不属于单词的字符（如空格、符号和标点符号）
  /// 两侧都有单词分隔符。在这种情况下，此方法将返回包含给定文本位置的文本范围。
  ///
  /// 单词边界在 Unicode 标准附件 #29 中有更精确的定义
  /// <http://www.unicode.org/reports/tr29/#Word_Boundaries>。
  TextRange getWordBoundary(TextPosition position) {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.paragraph.getWordBoundary(position);
  }

  /// 返回一个 [TextBoundary]，可用于对当前 [text] 执行单词边界分析。
  ///
  /// 此 [TextBoundary] 使用 [Unicode 标准附件 #29]
  /// (http://www.unicode.org/reports/tr29/#Word_Boundaries) 中定义的单词边界规则。
  ///
  /// 目前，单词边界分析只能在调用 [layout] 后执行。
  MongolWordBoundary get wordBoundaries =>
      MongolWordBoundary._(text!, _layoutCache!.paragraph);

  /// 返回给定偏移量处行的文本范围。
  ///
  /// 换行符（如果有）不会作为范围的一部分返回。
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

  /// 返回详细描述每行布局的各种度量的完整 [MongolLineMetrics] 列表。
  ///
  /// [MongolLineMetrics] 列表按它们表示的行顺序呈现。
  /// 例如，第一行在索引 0 处。
  ///
  /// [MongolLineMetrics] 包含整行的上升、下降、基线和高度等测量值，
  /// 可能有助于将其他小部件与特定行对齐。
  ///
  /// 仅在调用 [layout] 后有效。
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

  /// 此对象是否已被释放。
  ///
  /// 仅在启用断言时使用。
  bool get debugDisposed {
    bool? disposed;
    assert(() {
      disposed = _disposed;
      return true;
    }());
    return disposed ??
        (throw StateError('debugDisposed only available when asserts are on.'));
  }

  /// 释放与此绘制器关联的资源。
  ///
  /// 释放后，此绘制器将无法使用。
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
