// Copyright 2014 The Flutter Authors.
// Copyright 2020 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' show max;
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
        TextStyle;
import 'package:mongol/src/base/mongol_paragraph.dart';

import 'mongol_text_align.dart';
import 'mongol_text_metrics.dart';
import 'mongol_text_tools.dart';

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
///
/// 此类实现了 [TextBoundary] 接口，用于在蒙古文文本中找到单词的边界位置。
/// 实现遵循 Unicode 标准附录 #29 (UAX #29) 中定义的单词分割规则。
///
/// 核心功能：
/// 1. [getTextBoundaryAt]：获取给定位置处单词的绝对边界（开始和结束）
/// 2. [moveByWordBoundary]：提供的 TextBoundary，用于更好地支持键盘导航
///
/// 特殊处理：
/// - 处理 UTF-16 代理对（补充平面字符，如表情符号）
/// - 跳过空格和标点符号以提供更自然的单词导航体验
/// - 支持零宽度字符和双向文本标记
///
/// 与标准 TextBoundary 的差异：
/// - [moveByWordBoundary] 会跳过单词末尾的空格/标点，与大多数平台保持一致
/// - 这种行为更适合文本编辑中的"单词移动"快捷键
///
/// 使用场景：
/// - 获取双击选择的单词范围
/// - 文本编辑中的单词级导航
/// - 实现快捷键（如 Ctrl+右箭头）的单词移动功能
class MongolWordBoundary extends TextBoundary {
  /// 使用文本和布局信息创建 [MongolWordBoundary]
  ///
  /// 参数说明：
  /// - [_text]：文本树的根节点，包含所有文本和样式信息
  /// - [_paragraph]：已布局的段落，用于获取单词边界信息
  MongolWordBoundary._(this._text, this._paragraph);

  final InlineSpan _text;
  final MongolParagraph _paragraph;

  @override
  TextRange getTextBoundaryAt(int position) =>
      _paragraph.getWordBoundary(TextPosition(offset: max(position, 0)));

  // Runes 类不提供带有代码单元偏移的随机访问
  int? _codePointAt(int index) {
    final int? codeUnitAtIndex = _text.codeUnitAt(index);
    if (codeUnitAtIndex == null) {
      return null;
    }
    return switch (codeUnitAtIndex & 0xFC00) {
      0xD800 =>
        MongolTextTools.codePointFromSurrogates(codeUnitAtIndex, _text.codeUnitAt(index + 1)!),
      0xDC00 =>
        MongolTextTools.codePointFromSurrogates(_text.codeUnitAt(index - 1)!, codeUnitAtIndex),
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

/// 条件性文本边界查询包装器
///
/// 该类装饰了另一个 TextBoundary，并通过谓词函数添加了条件检查。
/// 当谓词函数返回 true 时，该位置被视为有效的边界；否则继续搜索。
///
/// 实现了 TextBoundary 接口的两个主要方法：
/// 1. [getLeadingTextBoundaryAt]：向后搜索，找到第一个满足谓词的位置
/// 2. [getTrailingTextBoundaryAt]：向前搜索，找到第一个满足谓词的位置
///
/// 搜索模式：
/// - 首先从基础 TextBoundary 获取候选边界
/// - 然后检查候选位置是否满足谓词条件
/// - 若不满足，继续搜索下一个候选位置
/// - 若满足或无可用候选，返回结果
///
/// 谓词函数签名：
/// ```dart
/// bool predicate(int offset, bool forward)
/// ```
/// - offset：候选边界的位置
/// - forward：搜索方向（true = 向前，false = 向后）
/// - 返回 true 表示该位置是有效的边界
///
/// 使用场景：
/// - [MongolWordBoundary.moveByWordBoundary] 使用此类跳过尾随的空格/标点
/// - 实现自定义的边界搜索逻辑，如跳过某些字符类型
class _UntilTextBoundary extends TextBoundary {
  /// 创建一个条件性文本边界查询对象
  ///
  /// 参数说明：
  /// - [_textBoundary]：基础文本边界提供者
  /// - [_predicate]：用于判断边界是否有效的谓词函数
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

/// 蒙古文文本布局的度量和布局信息包装器
///
/// 此类封装了 [MongolParagraph] 的度量数据，并提供了统一的接口来访问
/// 文本布局的各种属性，如宽度、高度、基线等。
///
/// 这是一个内部包装类，用于在文本绘制流程中携带布局测量数据，
/// 避免直接暴露 [MongolParagraph] 的细节。
class _MongolTextLayout {
  /// 创建一个 _MongolTextLayout 实例
  ///
  /// [_paragraph] 是蒙古文段落对象，包含布局和度量信息
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

/// 文本绘制器布局缓存容器，集成布局信息和绘制对齐
///
/// 该类是核心缓存类，用于整合以下几部分信息：
/// 1. 文本布局信息（[_MongolTextLayout]）：包含段落的度量数据
/// 2. 绘制对齐因子（[textAlignment]）：用于计算垂直方向的绘制偏移
/// 3. 内容高度（[contentHeight]）：在约束条件下的实际显示高度
/// 4. 缓存的行度量数据：用于快速查询行相关信息
/// 5. 缓存的光标度量数据：用于快速查询光标位置和宽度
///
/// 坐标系说明：
/// - 内部坐标系：段落的原始坐标（从左上角 (0,0) 开始）
/// - 绘制坐标系：经过对齐调整后的坐标（通过 [paintOffset] 转换）
/// - [paintOffset] = (0, textAlignment * (contentHeight - paragraph.height))
///
/// 当文本需要垂直对齐（如底部对齐或居中）时，会产生非零的 [paintOffset.dy]，
/// 所有文本相关的绘制和测量结果都需要通过 [paintOffset] 进行坐标转换
class _TextPainterLayoutCacheWithOffset {
  /// 创建一个 _TextPainterLayoutCacheWithOffset 实例
  ///
  /// [layout] 是蒙古文文本的布局信息包装器
  /// [textAlignment] 是文本的垂直对齐因子（范围 [0, 1]）：
  ///   - 0.0 表示顶部对齐（paintOffset.dy = 0）
  ///   - 1.0 表示底部对齐（paintOffset.dy = contentHeight - paragraph.height）
  ///   - 0.5 表示垂直居中
  /// [minHeight] 是应用于文本的最小高度约束
  /// [maxHeight] 是应用于文本的最大高度约束
  /// [heightBasis] 指定如何基于约束条件计算 [contentHeight]
  _TextPainterLayoutCacheWithOffset(this.layout, this.textAlignment,
      double minHeight, double maxHeight, TextHeightBasis heightBasis)
      : contentHeight =
            _contentHeightFor(minHeight, maxHeight, heightBasis, layout),
        assert(textAlignment >= 0.0 && textAlignment <= 1.0);

  final _MongolTextLayout layout;

  /// 文本在 MongolTextPainter 画布中呈现的高度
  ///
  /// 该值根据输入的高度约束和 [TextHeightBasis] 计算，表示文本实际占用的显示高度。
  /// 用于计算 [paintOffset]，以实现不同的垂直对齐效果。
  double contentHeight;

  /// 文本垂直对齐的标准化因子
  ///
  /// 范围在 [0, 1] 之间：
  /// - 0.0：顶部对齐（不产生纵向移动）
  /// - 0.5：垂直居中
  /// - 1.0：底部对齐（最大纵向移动）
  ///
  /// 这个值由外部传入（通过 [_computePaintOffsetFraction]），
  /// 用于计算 [paintOffset] 以实现相应的对齐效果
  final double textAlignment;

  /// 段落在 MongolTextPainter 画布中的绘制偏移量
  ///
  /// 坐标系转换说明：
  /// - 分量 (dx, dy)
  /// - dx：通常为 0（蒙古文垂直排版，不需要水平偏移）
  /// - dy：基于 textAlignment 和高度差值计算，用于实现垂直对齐
  ///
  /// 计算公式：
  /// ```
  /// paintOffset.dy = textAlignment * (contentHeight - paragraph.height)
  /// ```
  ///
  /// 所有段落相关的绘制和测量操作都需要通过此偏移量进行坐标转换。
  /// 当 paintOffset.dy 不是有限值时，表示对齐计算出现问题（通常是高度为无穷大的情况）
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

  /// 获取此缓存持有的段落实例
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

  /// 尝试根据新的高度约束调整缓存，仅改变绘制偏移而不重新布局
  ///
  /// 此方法实现了重要的优化策略：在不需要改变文本换行的情况下，
  /// 通过调整 [contentHeight] 和 [paintOffset] 来适应新的约束条件。
  ///
  /// 返回值说明：
  /// - true：成功仅通过调整绘制偏移来适应新约束，缓存仍然有效
  /// - false：新约束需要重新计算文本换行，原缓存已失效，需要重新布局
  ///
  /// 核心假设（必须满足）：
  /// - 如果段落高度已经 >= 其 maxIntrinsicHeight，增加约束高度不会改变换行
  /// - 即使使用 MongolTextAlign.justify，当 height >= maxIntrinsicHeight 时也无需调整
  /// - 特殊情况：当高度为无穷大且文本非顶部对齐时，paintOffset.dy 会变为无穷大（无效）
  ///
  /// 异常情况处理：
  /// - 当 paintOffset 和 paragraph.height 都是无限值时，需要强制重新布局
  /// - 当新约束可能导致无穷大的 paintOffset 时，返回 false 强制重新布局
  bool _resizeToFit(
      double minHeight, double maxHeight, TextHeightBasis heightBasis) {
    assert(layout.maxIntrinsicLineExtent.isFinite);
    // 核心假设：当段落高度已经足够容纳所有内容（>= maxIntrinsicHeight）时，
    // 进一步增加约束高度不会改变换行，这对所有对齐方式都成立
    final double newContentHeight =
        _contentHeightFor(minHeight, maxHeight, heightBasis, layout);
    if (newContentHeight == contentHeight) {
      return true; // 高度未变，无需调整
    }
    assert(minHeight <= maxHeight);
    // 当两个值都是无限时且无有限约束时，需要重新布局以确定正确的尺寸
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

  // ---- 惰性缓存字段 ----
  // 这些字段在第一次访问时计算，然后存储以供重复使用
  // 当段落布局失效时，这些缓存会同时失效

  /// 获取所有行的详细度量信息列表
  ///
  /// 返回的列表包含 [MongolLineMetrics]，每个条目代表一行文本的详细度量
  /// （如基线、上升、下降、宽度等），按行顺序排列。
  ///
  /// 此属性使用惰性初始化和缓存：首次访问时进行计算，后续访问返回缓存结果。
  /// 当段落布局失效时，此缓存会自动失效。
  List<MongolLineMetrics> get lineMetrics =>
      _cachedLineMetrics ??= paragraph.computeLineMetrics();

  /// 行度量信息的缓存，首次调用时初始化
  List<MongolLineMetrics>? _cachedLineMetrics;

  /// 光标度量计算器
  ///
  /// 按布局缓存作用域管理，当段落重新布局时，新的缓存会创建新的计算器实例，
  /// 自动清除旧的光标度量缓存。
  final CaretMetricsCalculator caretCalculator = CaretMetricsCalculator();
}

/// 将水平排版的 TextAlign 转换为垂直排版的 MongolTextAlign
///
/// 此方法处理坐标系统的转换，从 Flutter 标准的水平对齐方式映射到蒙古文垂直排版的对齐方式。
///
/// 映射规则（水平 -> 垂直）：
/// - [TextAlign.left] 或 [TextAlign.start] -> [MongolTextAlign.top]（顶部对齐）
/// - [TextAlign.right] 或 [TextAlign.end] -> [MongolTextAlign.bottom]（底部对齐）
/// - [TextAlign.center] -> [MongolTextAlign.center]（垂直居中）
/// - [TextAlign.justify] -> [MongolTextAlign.justify]（两端对齐）
///
/// 坐标系统背景：
/// - 蒙古文竖排：文本从上到下书写，所以"top"对应"left"（文本流起点）
/// - 蒙古文竖排：文本从上到下书写，所以"bottom"对应"right"（文本流终点）
///
/// 参数 [textAlign] 为 null 时，返回 null（无对齐方式）
///
/// 使用场景：
/// - 将高层 Widget 的水平对齐设置转换为底层的垂直对齐
/// - [MongolText] 等组件用此方法适配标准 Flutter API
///
/// 返回值：
/// - 对应的 [MongolTextAlign] 值（若输入非 null）
/// - null（若输入为 null）
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

  // 在最近的 `layout` 调用中是否遇到文本高度基准（heightBasis）的变化
  // 当 textHeightBasis 属性改变时标记为 true，用于调试和检查
  bool _debugNeedsRelayout = true;

  /// 最近 `layout` 调用的完整缓存结果
  ///
  /// 该缓存包含：
  /// - 分析后的段落布局（[_MongolTextLayout]）
  /// - 计算得出的绘制偏移（[Offset]）
  /// - 内容高度和对齐信息
  ///
  /// 缓存失效的情况：
  /// - 调用 [markNeedsLayout]：清除整个缓存，下次 layout 需要完全重新计算
  /// - 文本内容改变：[text] setter 会根据变化类型决定是否清空缓存
  /// - 约束条件改变：新的 layout 调用可能导致缓存不适用
  ///
  /// 缓存为 null 表示未进行过布局或缓存已被清空
  _TextPainterLayoutCacheWithOffset? _layoutCache;

  /// 是否需要重建段落以应用仅绘制级别的变化
  ///
  /// 此标志用于处理以下情况：
  /// - 文本颜色改变（仅绘制级变化，不影响布局）
  /// - 段落完全不可变，即使仅改变颜色也需要重新创建
  ///
  /// 处理流程：
  /// 1. 当仅绘制级属性改变时，设置此标志为 true
  /// 2. 保留现有布局缓存（避免重新换行）
  /// 3. 在 paint 时重建段落但不重新布局
  /// 4. 重建后清除此标志
  ///
  /// 此标志为 true 时，布局缓存仍然有效，可以直接用于绘制
  bool _rebuildParagraphForPaint = true;

  /// 最近 `layout` 调用时使用的约束高度（maxHeight）
  ///
  /// 此值存储以用于 paint 时的段落重建。当仅发生绘制级变化且需要重建段落时，
  /// 必须使用相同的高度约束进行段落布局，以确保布局不变。
  ///
  /// NaN 值表示尚未进行过布局
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

  /// 标记文本绘制器的布局信息为脏状态
  ///
  /// 当文本绘制器的任何影响布局的属性改变时，应调用此方法以通知系统
  /// 在下一次绘制前需要重新计算布局。
  ///
  /// 内部操作：
  /// 1. 记录调用栈（用于调试布局失效问题）
  /// 2. 释放当前布局缓存中的段落资源
  /// 3. 清除布局缓存引用，触发下次的完整布局计算
  ///
  /// 何时被调用：
  /// - 当文本内容改变时（text setter 会根据变化类型自动调用）
  /// - 当对齐方式改变时（textAlign setter）
  /// - 当文本缩放改变时（textScaler setter）
  /// - 当其他影响布局的属性改变时
  ///
  /// 注意：
  /// - 大多数情况下不需要手动调用，属性 setter 会自动处理
  /// - 仅在特殊情况下（如引擎层面的布局变化）才需要手动调用
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

  /// 文本缩放策略，用于根据系统或用户设置调整字体大小
  ///
  /// 该值通常来自 [MediaQuery.textScalerOf]，反映平台辅助功能设置中用户指定的文本缩放值。
  /// 文本的 [TextStyle.fontSize] 在布局和渲染之前会由此 [TextScaler] 进行调整。
  ///
  /// 处理过程：
  /// - 构造段落样式时，字体大小被乘以 textScaler 的缩放因子
  /// - 例如：fontSize: 14, textScaler: 1.5 -> 实际字体大小 21
  ///
  /// 更改此属性的影响：
  /// - 会影响文本的布局（字体大小改变），必须调用 [layout] 重新计算
  /// - 会释放布局模板（因为字体大小改变），下次获取 preferredLineWidth 时重新创建
  /// - 标记当前布局缓存失效
  ///
  /// 性能注意：
  /// - 仅在必要时改变此属性，避免频繁改变造成的重新布局开销
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
  ///
  /// 当文本因高度约束或行数限制而无法完全显示时，用此字符串替代被截断的部分。
  ///
  /// 省略行为说明：
  /// - 如果 [maxLines] 非空，则省略符应用于第 maxLines 行之前的最后一行
  /// - 如果 [maxLines] 为 null，则省略符应用于第一个超出 maxHeight 的行
  /// - 高度约束由传递给 [layout] 的 `maxHeight` 指定
  ///
  /// 示例：
  /// - 设置为 "…" (U+2026 HORIZONTAL ELLIPSIS) 用于文本省略
  /// - 对应于 [TextOverflow.ellipsis] 的行为
  ///
  /// 要求：
  /// - 必须为 null 或非空字符串（空字符串会抛异常）
  /// - 更改后需要调用 [layout] 重新计算布局（因为省略符会占用空间）
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

  /// 文本要跨越的最大行数
  ///
  /// 当文本行数超过此值时，超出的行将被截断并丢弃。
  /// 被截断的最后一行可能会添加省略符（由 [ellipsis] 属性控制）。
  ///
  /// 特性：
  /// - 为 null 表示行数不限制
  /// - 若非 null，必须大于 0（不能为 0）
  /// - 更改此属性后需要调用 [layout] 重新计算布局
  ///
  /// 使用场景：
  /// - 限制文本显示高度（通过限制行数）
  /// - 实现"查看更多"等功能
  /// - 在滚动视图中避免过长文本占用过多空间
  int? get maxLines => _maxLines;
  int? _maxLines;
  set maxLines(int? value) {
    assert(value == null || value > 0);
    if (_maxLines == value) {
      return;
    }
    _maxLines = value;
    markNeedsLayout();
  }

  /// 定义如何测量渲染文本的高度
  ///
  /// 此属性在文本调整大小时扮演重要角色：
  /// - [TextHeightBasis.parent]：多行文本占满父容器高度，单行文本使用最小高度
  /// - [TextHeightBasis.longestLine]：高度仅足以容纳最长行（如聊天气泡）
  ///
  /// 更改此属性后：
  /// - 不会直接触发 [markNeedsLayout]（仅在调试模式下标记标志）
  /// - 但会影响下次 [layout] 调用的结果（通过 [contentHeight] 计算）
  ///
  /// 注意：此属性的更改较为轻微，通常不需要立即重新布局
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

  /// CJK 字符是否应在垂直列中旋转 90 度以显示为竖排
  ///
  /// 当设置为 true 时，CJK（中文、日文、韩文）字符会被旋转 90 度，
  /// 使其在垂直文本中显示为竖排（upright），而不是横排（sideways）。
  ///
  /// 更改此属性的影响：
  /// - 影响文本的渲染（字形旋转），必须调用 [layout] 重新布局
  /// - 不影响布局计算本身，但影响最终的视觉呈现
  ///
  /// 使用场景：
  /// - 在垂直文本中正确显示 CJK 字符
  /// - 根据不同的排版规范切换字符显示方式
  ///
  /// 默认值：true（CJK 字符默认旋转显示）
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
    // 段落样式中的 textAlign 总是使用 LEFT，原因：
    // - MongolParagraph 使用内部坐标系（垂直文本视为水平行）
    // - textAlign 在内部坐标系中始终使用 LEFT（这对应于外部的顶部对齐）
    // - 真正的 MongolTextAlign 对齐通过 MongolTextPainter 中的 paintOffset 实现
    // - 这种设计分离了低层文本布局和高层对齐逻辑
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
          // 使用默认字体大小乘以缩放因子
          // MongolRichText 不执行文本样式继承，因此需要显式应用 textScaleFactor
          fontSize: textScaler.scale(_kDefaultFontSize),
          maxLines: maxLines,
          ellipsis: ellipsis,
          locale: null,
        );
  }

  /// 段落布局模板（单个空格）
  ///
  /// 用于计算 [preferredLineWidth]（代表文本的典型行宽）。
  /// 包含一个空格字符，使用当前文本样式，能够快速获取字体度量。
  /// 
  /// 在以下情况会被清除（需要重新创建）：
  /// - 文本样式改变（text.style 变化）
  /// - 文本缩放策略改变（textScaler 变化）
  ///
  /// 懒加载初始化：首次需要时才创建，不需要时不创建
  MongolParagraph? _layoutTemplate;

  /// 创建用于计算字体度量的布局模板
  ///
  /// 模板包含当前样式下的单个空格，用于获取典型字体度量（主要是字符宽度）
  /// 该模板不用于实际文本绘制，仅用于测量目的
  MongolParagraph _createLayoutTemplate() {
    final builder = MongolParagraphBuilder(_createParagraphStyle());
    // MongolParagraphBuilder 负责：
    // 1. 将 TextStyle 转换为底层 ui.TextStyle
    // 2. 应用文本缩放器（textScaler）
    final textStyle = text?.style;
    if (textStyle != null) {
      builder.pushStyle(textStyle);
    }
    builder.addText(' '); // 添加单个空格用于度量
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

  /// 创建一个新的 MongolParagraph 实例，用于实际的文本布局和绘制
  MongolParagraph _createParagraph(InlineSpan text) {
    final builder = MongolParagraphBuilder(
      _createParagraphStyle(),
      textAlign: _textAlign,
      textScaler: _textScaler,
      maxLines: _maxLines,
      ellipsis: _ellipsis,
      rotateCJK: _rotateCJK,
    );
    // 将文本树中的所有样式递推应用到构建器
    _addStyleToText(builder, text);
    assert(() {
      _debugMarkNeedsLayoutCallStack = null; // 清除调试调用栈
      return true;
    }());
    _rebuildParagraphForPaint = false; // 清除重建标志
    return builder.build();
  }

  /// 将文本树中的样式递推应用到段落构建器
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
    if (hasStyle) builder.pushStyle(style); // 推送样式
    if (text != null) builder.addText(text); // 添加文本
    if (children != null) {
      for (final child in children) {
        _addStyleToText(builder, child); // 递推处理子节点
      }
    }
    if (hasStyle) builder.pop(); // 弹出样式
  }

  /// 计算并缓存文本的布局信息
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
      return; // 缓存仍然有效，只需调整对齐偏移
    }

    final TextSpan? text = this.text;
    if (text == null) {
      throw StateError(
          'MongolTextPainter.text must be set to a non-null value before using the MongolTextPainter.');
    }

    final double paintOffsetAlignment = _computePaintOffsetFraction(textAlign);
    
    // 优化策略：避免在非顶部对齐且 maxHeight=infinity 时进行布局
    // 因为会导致无穷大的 paintOffset.dy，丧失绘制意义
    final bool adjustMaxHeight =
        !maxHeight.isFinite && paintOffsetAlignment != 0;
    final double? adjustedMaxHeight = !adjustMaxHeight
        ? maxHeight
        : cachedLayout?.layout.maxIntrinsicLineExtent;
    _inputHeight = adjustedMaxHeight ?? maxHeight;

    // 布局段落时的智能决策：
    // - 仅在布局变化时创建新段落（避免不必要的重建）
    // - 如果布局缓存存在，复用其段落对象（仅需重新布局）
    final paragraph = (cachedLayout?.paragraph ?? _createParagraph(text))
      ..layout(MongolParagraphConstraints(height: _inputHeight));
    
    final newLayoutCache = _TextPainterLayoutCacheWithOffset(
      _MongolTextLayout._(paragraph),
      paintOffsetAlignment,
      minHeight,
      maxHeight,
      textHeightBasis,
    );
    
    // 异常处理：如果使用调整后的 maxHeight 导致布局仍为无穷大，
    // 则需要使用精确的高度约束重新布局以获得可行的 paintOffset
    if (adjustedMaxHeight == null && minHeight.isFinite) {
      assert(maxHeight.isInfinite);
      final double newInputHeight =
          newLayoutCache.layout.maxIntrinsicLineExtent;
      paragraph.layout(MongolParagraphConstraints(height: newInputHeight));
      _inputHeight = newInputHeight;
    }
    _layoutCache = newLayoutCache;
  }

  /// 将文本绘制到指定画布和偏移位置
  void paint(Canvas canvas, Offset offset) {
    final _TextPainterLayoutCacheWithOffset? layoutCache = _layoutCache;
    if (layoutCache == null) {
      throw StateError(
        'MongolTextPainter.paint called when text geometry was not yet calculated.\n'
        'Please call layout() before paint() to position the text before painting it.',
      );
    }

    // 检查绘制偏移是否有效
    if (!layoutCache.paintOffset.dy.isFinite ||
        !layoutCache.paintOffset.dx.isFinite) {
      return; // 无效的偏移，不进行绘制
    }

    // 处理仅绘制级变化的段落重建
    if (_rebuildParagraphForPaint) {
      Size? debugSize;
      assert(() {
        debugSize = size; // 记录重建前的尺寸用于验证
        return true;
      }());

      final paragraph = layoutCache.paragraph;
      // 注意：MongolParagraph 完全不可变，虽然只有颜色改变，也需要重新创建并重新布局
      // 这是 Flutter 引擎的设计限制（参见 https://github.com/flutter/flutter/issues/85108）
      assert(!_inputHeight.isNaN);
      layoutCache.layout._paragraph = _createParagraph(text!)
        ..layout(MongolParagraphConstraints(height: _inputHeight));
      
      // 验证重建后高度不变：由于只改变了颜色，布局应该完全相同
      assert(paragraph.height == layoutCache.layout._paragraph.height);
      paragraph.dispose(); // 释放旧段落资源
      assert(debugSize == size); // 验证尺寸未变
    }
    assert(!_rebuildParagraphForPaint); // 重建标志应已清除
    
    // 最终绘制：将段落绘制到画布
    // offset 是用户指定的基点，layoutCache.paintOffset 是对齐产生的偏移
    layoutCache.paragraph.draw(canvas, offset + layoutCache.paintOffset);
  }

  // UTF-16 编码性检查

  /// 获取在指定偏移量之后最近的可以放置输入光标的位置
  int? getOffsetAfter(int offset) {
    final int? nextCodeUnit = _text!.codeUnitAt(offset);
    if (nextCodeUnit == null) {
      return null;
    }
    return MongolTextTools.isHighSurrogate(nextCodeUnit)
        ? offset + 2
        : offset + 1;
  }

  /// 获取在指定偏移量之前最近的可以放置输入光标的位置
  int? getOffsetBefore(int offset) {
    final int? prevCodeUnit = _text!.codeUnitAt(offset - 1);
    if (prevCodeUnit == null) {
      return null;
    }
    return MongolTextTools.isLowSurrogate(prevCodeUnit) ? offset - 2 : offset - 1;
  }

  /// 将文本对齐方式转换为绘制偏移的标准化因子
  static double _computePaintOffsetFraction(MongolTextAlign textAlign) {
    return switch (textAlign) {
      MongolTextAlign.top => 0.0,
      MongolTextAlign.bottom => 1.0,
      MongolTextAlign.center => 0.5,
      MongolTextAlign.justify => 0.0,
    };
  }

  /// 计算给定光标位置的绘制偏移量
  Offset getOffsetForCaret(TextPosition position, Rect caretPrototype) {
    final CaretMetrics caretMetrics;
    final _TextPainterLayoutCacheWithOffset layoutCache = _layoutCache!;
    
    if (position.offset < 0) {
      // 无效位置，返回空行光标（0 高度光标）
      caretMetrics = const EmptyLineCaretMetrics(lineHorizontalOffset: 0);
    } else {
      // 有效位置，计算光标度量
      caretMetrics = layoutCache.caretCalculator.compute(
        position, plainText, layoutCache.paragraph, _text!);
    }

    final Offset rawOffset;
    switch (caretMetrics) {
      case EmptyLineCaretMetrics(:final double lineHorizontalOffset):
        // 空行情况：光标位于空白行，使用对齐方式计算 y 坐标
        final double paintOffsetAlignment =
            _computePaintOffsetFraction(textAlign);
        // 注释：contentHeight 不总是 height - caretPrototype.height
        // 这是因为 MongolRenderEditable 在底部预留了光标空间
        // 理想情况下这个逻辑应该由 MongolRenderEditable 处理（待改进）
        final double dy = paintOffsetAlignment == 0
            ? 0
            : paintOffsetAlignment * layoutCache.contentHeight;
        return Offset(lineHorizontalOffset, dy);
        
      case LineCaretMetrics(:final Offset offset):
        // 非空行情况：光标关联到字形的边缘
        rawOffset = offset;
    }
    
    // 坐标转换：段落内部坐标 -> 对齐后坐标
    final double adjustedDy = clampDouble(
        rawOffset.dy + layoutCache.paintOffset.dy,
        0,
        layoutCache.contentHeight);
    return Offset(rawOffset.dx + layoutCache.paintOffset.dx, adjustedDy);
  }

  /// 返回给定 `position` 处字形的完整宽度
  double? getFullWidthForCaret(TextPosition position, Rect caretPrototype) {
    if (position.offset < 0) {
      return null;
    }
    final _TextPainterLayoutCacheWithOffset layoutCache = _layoutCache!;
    return switch (layoutCache.caretCalculator.compute(
        position, plainText, layoutCache.paragraph, _text!)) {
      LineCaretMetrics(:final double fullWidth) => fullWidth,
      EmptyLineCaretMetrics() => null,
    };
  }

  /// 返回包围指定选择范围内的所有字形的矩形列表
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
            .map((Rect box) => MongolTextTools.shiftTextBox(box, offset))
            .toList(growable: false);
  }

  /// 返回给定像素偏移量对应的文本位置
  TextPosition getPositionForOffset(Offset offset) {
    assert(_debugAssertTextLayoutIsValid);
    assert(!_debugNeedsRelayout);
    final _TextPainterLayoutCacheWithOffset cachedLayout = _layoutCache!;
    return cachedLayout.paragraph
        .getPositionForOffset(offset - cachedLayout.paintOffset);
  }

  /// 返回给定文本位置处单词的边界范围
  TextRange getWordBoundary(TextPosition position) {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.paragraph.getWordBoundary(position);
  }

  /// 返回一个 TextBoundary 对象，用于对当前文本进行单词边界分析
  MongolWordBoundary get wordBoundaries =>
      MongolWordBoundary._(text!, _layoutCache!.paragraph);

  /// 返回给定文本位置处所在行的边界范围
  TextRange getLineBoundary(TextPosition position) {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.paragraph.getLineBoundary(position);
  }

  /// 计算并返回所有行的详细度量信息列表
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
                MongolTextTools.shiftLineMetrics(metrics, offset))
            .toList(growable: false);
  }

  /// 此对象是否已被释放
  bool get debugDisposed {
    bool? disposed;
    assert(() {
      disposed = _disposed;
      return true;
    }());
    return disposed ??
        (throw StateError('debugDisposed only available when asserts are on.'));
  }

  /// 此对象是否已被释放的内部标志
  bool _disposed = false;

  /// 释放与此绘制器关联的所有资源
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
