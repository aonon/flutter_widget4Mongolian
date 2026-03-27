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

  /// 上一次计算光标度量时的文本位置
  ///
  /// 用于缓存光标度量结果。当查询相同位置时，无需重新计算，
  /// 直接返回缓存的度量结果（即 [MongolTextPainter._caretMetrics]）。
  /// 当位置变化时，缓存自动失效。
  TextPosition? _previousCaretPosition;
}

/// 光标度量信息的基类，使用密封类进行类型安全
///
/// 此密封类有两个子类：
/// - [_LineCaretMetrics]：光标位于非空行中的字形旁
/// - [_EmptyLineCaretMetrics]：光标位于空行中（文本为空或在换行符之间）
///
/// 使用 sealed class 而非 enum 的原因：
/// - 每个子类需要存储不同的数据（不同的字段）
/// - sealed class 比 enum 更适合这种场景
/// - 支持 pattern matching（switch 表达式）来区分不同情况
///
/// 计算和缓存：
/// - 由 [MongolTextPainter._computeCaretMetrics] 计算
/// - 缓存在 [MongolTextPainter._caretMetrics]，避免重复计算
/// - 当光标位置改变时缓存自动失效
@immutable
sealed class _CaretMetrics {}

/// 光标位于非空行的中的度量信息
///
/// 此类表示光标位于文本行中字形旁的情况，存储光标和字形的位置及大小信息。
final class _LineCaretMetrics implements _CaretMetrics {
  /// 创建一个光标度量信息实例
  ///
  /// 参数说明：
  /// - [offset]：光标左上角的坐标（段落内部坐标系）
  ///   * 可能是字形的左侧（上游亲和力）或右侧（下游亲和力）
  /// - [fullWidth]：光标位置处字形的完整宽度（用于渲染光标的宽度）
  const _LineCaretMetrics({required this.offset, required this.fullWidth});

  /// 光标左上角相对于段落左上角的位置（段落内部坐标系）
  final Offset offset;

  /// 光标所在位置字形的完整宽度
  /// 这个宽度通常用于绘制光标矩形的高度（在垂直文本中）
  final double fullWidth;
}

/// 光标位于空行或换行符处的度量信息
///
/// 此类表示光标位于空行中的情况（如文本为空、行首、或两个换行符之间），
/// 此时光标不关联任何字形，仅需提供水平位置信息。
final class _EmptyLineCaretMetrics implements _CaretMetrics {
  /// 创建一个空行光标度量信息实例
  ///
  /// 参数说明：
  /// - [lineHorizontalOffset]：未占用行的水平偏移（即行的 x 坐标）
  ///   * 在垂直文本中，这对应于行的列位置
  const _EmptyLineCaretMetrics({required this.lineHorizontalOffset});

  /// 空行的水平位置（该行的 x 坐标）
  /// 在垂直文本渲染中，这是光标应该绘制的列位置
  final double lineHorizontalOffset;
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
  ///
  /// 此方法将当前 MongolTextPainter 的所有配置应用于段落创建过程：
  /// 1. 创建段落样式（[_createParagraphStyle]）
  /// 2. 将文本树中的样式递推应用到构建器
  /// 3. 清除调试信息
  /// 4. 清除绘制重建标志
  ///
  /// 创建的段落尚未进行布局，需要外部调用其 layout 方法
  ///
  /// 参数 [text] 必须非空
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
  ///
  /// 此方法将 InlineSpan 树序列化为段落构建器的样式和文本操作。
  /// 实现了 TextSpan 树的深度遍历，按序应用样式和文本。
  ///
  /// 处理流程：
  /// 1. 检查是否为 TextSpan（目前仅支持 TextSpan，不支持其他 InlineSpan）
  /// 2. 若有样式，推送样式到构建器
  /// 3. 若有文本内容，添加文本到构建器
  /// 4. 若有子节点，递推处理每个子节点
  /// 5. 若有样式，从构建器弹出样式
  ///
  /// 参数说明：
  /// - [builder] 是目标段落构建器
  /// - [inlineSpan] 是要处理的 InlineSpan 树节点
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
  ///
  /// 此方法是文本绘制的核心计算步骤，必须在调用 [paint] 之前调用。
  /// 该方法执行以下过程：
  /// 
  /// 1. 验证输入约束（minHeight 和 maxHeight 必须是有效数字）
  /// 2. 检查是否可以复用现有缓存（通过 [_resizeToFit]）
  /// 3. 如果需要新的布局：
  ///    a. 创建段落对象（基于当前文本和样式配置）
  ///    b. 进行段落布局（使用给定的高度约束）
  ///    c. 计算对齐偏移
  /// 4. 缓存布局结果，包括绘制偏移、内容高度等
  /// 5. 处理特殊情况（无穷大约束下的重新布局）
  ///
  /// 约束条件处理：
  /// - [minHeight]：最小可用高度，文本实际高度不会小于此值
  /// - [maxHeight]：最大可用高度，文本实际高度不会超过此值
  /// - 当 minHeight > maxHeight 时，断言失败
  ///
  /// 高度调整策略（adjustMaxHeight）：
  /// - 为避免无限的 paintOffset.dy（当文本非顶部对齐且 maxHeight=infinity 时）
  /// - 会临时使用 maxIntrinsicHeight 代替无穷大的 maxHeight
  /// - 然后在获得合理的布局后，重新使用精确的高度约束重新布局
  ///
  /// 前置条件：[text] 属性必须非空
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
  ///
  /// 此方法执行最终的文本绘制操作，将布局好的段落渲染到画布上。
  ///
  /// 前置条件：
  /// - 必须在调用 [layout] 之后调用此方法
  /// - [layout] 必须至少调用过一次
  ///
  /// 参数说明：
  /// - [canvas] 目标绘制画布
  /// - [offset] 在画布上的绘制起点（左上角基准点）
  ///
  /// 绘制流程：
  /// 1. 检查缓存有效性：如果未进行过布局则抛异常
  /// 2. 检查纠正的绘制偏移是否有限：无穷大的偏移表示对齐计算失败
  /// 3. 如果需要重建段落（[_rebuildParagraphForPaint]）：
  ///    a. 重新创建段落（处理仅绘制级的改动，如颜色变化）
  ///    b. 重新布局新段落（使用保存的 _inputHeight）
  ///    c. 验证高度不变性（布局不应受颜色变化影响）
  ///    d. 释放旧段落对象
  /// 4. 最后调用段落的 draw 方法进行实际绘制
  ///
  /// 特殊处理：
  /// - paintOffset：将段落原始坐标系转换为对齐后的坐标系
  /// - 绝对偏移：offset + paintOffset 是段落在画布上的最终位置
  ///
  /// 调试信息：
  /// - 在段落重建时验证尺寸不变性
  /// - 比较重建前后的大小，确保仅发生了绘制级改变
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

  /// 检查给定值是否为有效的 UTF-16 代码单元
  ///
  /// UTF-16 代码单元的有效范围是 [0x0000, 0xFFFF]
  static bool _isUTF16(int value) {
    return value >= 0x0 && value <= 0xFFFFF;
  }

  /// 检查给定值是否为有效的 UTF-16 高代理（第一个代理代码单元）
  ///
  /// 高代理用于表示补充字符（Unicode 代码点 U+010000 到 U+10FFFF）的第一部分。
  /// 有效范围：0xD800 到 0xDBFF
  ///
  /// 参数 [value] 必须是有效的 UTF-16 代码单元（[0x0000, 0xFFFF]），否则断言失败
  ///
  /// 相关链接：
  ///   * https://en.wikipedia.org/wiki/UTF-16#Code_points_from_U+010000_to_U+10FFFF
  ///   * [isLowSurrogate]
  static bool isHighSurrogate(int value) {
    assert(_isUTF16(value));
    return value & 0xFC00 == 0xD800;
  }

  /// 检查给定值是否为有效的 UTF-16 低代理（第二个代理代码单元）
  ///
  /// 低代理用于表示补充字符的第二部分。有效范围：0xDC00 到 0xDFFF
  ///
  /// 参数 [value] 必须是有效的 UTF-16 代码单元（[0x0000, 0xFFFF]），否则断言失败
  ///
  /// 相关链接：
  ///   * https://en.wikipedia.org/wiki/UTF-16#Code_points_from_U+010000_to_U+10FFFF
  ///   * [isHighSurrogate]
  static bool isLowSurrogate(int value) {
    assert(_isUTF16(value));
    return value & 0xFC00 == 0xDC00;
  }

  /// 检查给定的 UTF-16 代码单元是否为 Unicode 方向性标记
  ///
  /// 方向性标记（Right-to-Left Mark 和 Left-to-Right Mark）是零宽度字符，
  /// 用于控制双向文本的显示方向，不占用可见空间。
  ///
  /// 检查的值：
  /// - 0x200F：RLM (Right-to-Left Mark)
  /// - 0x200E：LRM (Left-to-Right Mark)
  static bool _isUnicodeDirectionality(int value) {
    return value == 0x200F || value == 0x200E;
  }

  /// 获取在指定偏移量之后最近的可以放置输入光标的位置
  ///
  /// 此方法用于文本编辑中的光标导航。它考虑了 UTF-16 代理对，
  /// 确保光标不会放在代理对的中间。
  ///
  /// 处理过程：
  /// 1. 获取当前位置的代码单元
  /// 2. 如果是高代理，下一个位置向前移动 2（跳过完整的代理对）
  /// 3. 否则向前移动 1
  ///
  /// 返回值：
  /// - 如果能够向前移动，返回新位置
  /// - 如果已在文本末尾，返回 null
  int? getOffsetAfter(int offset) {
    final int? nextCodeUnit = _text!.codeUnitAt(offset);
    if (nextCodeUnit == null) {
      return null;
    }
    return isHighSurrogate(nextCodeUnit) ? offset + 2 : offset + 1;
  }

  /// 获取在指定偏移量之前最近的可以放置输入光标的位置
  ///
  /// 此方法用于文本编辑中的光标导航。它考虑了 UTF-16 代理对，
  /// 确保光标不会放在代理对的中间。
  ///
  /// 处理过程：
  /// 1. 获取前一个位置的代码单元
  /// 2. 如果是低代理，向后移动 2（跳过完整的代理对）
  /// 3. 否则向后移动 1
  ///
  /// 返回值：
  /// - 如果能够向后移动，返回新位置
  /// - 如果已在文本开头，返回 null
  int? getOffsetBefore(int offset) {
    final int? prevCodeUnit = _text!.codeUnitAt(offset - 1);
    if (prevCodeUnit == null) {
      return null;
    }
    return isLowSurrogate(prevCodeUnit) ? offset - 2 : offset - 1;
  }

  // 零宽度连接符字符的 Unicode 值。
  static const int _zwjUtf16 = 0x200d;

  /// 基于上游字符（当前位置之前的字符）的近边缘获取光标度量
  ///
  /// 用于计算光标位置和宽度，基于文本位置的上游字符。当光标前面有字符时使用此方法。
  ///
  /// 处理的字符类型：
  /// - 换行符：光标位于下一行的开始，此时使用 [_EmptyLineCaretMetrics]
  /// - 多代码单元字形：如表情符号、RTL 标记、零宽度连接符等
  /// - Unicode 方向性标记：零宽度字符，不占用空间
  ///
  /// 查询策略（二分搜索并进行字形集群扩展）：
  /// - 初始化 graphemeClusterLength 为 1（或 2 如果需要搜索）
  /// - 逐次查询边界框，未找到则扩大范围（乘以 2）
  /// - 这一策略在 O(log n) 时间内完成查询，避免 O(n) 的线性扫描
  ///
  /// 返回值：
  /// - 若成功找到字形的边界框，返回光标度量
  /// - 若在光标处多次扩展后仍未找到，返回 null（这属于异常情况）
  ///
  /// 参数 [offset] 应 >= 0，而且通常 <= plainText.length
  _CaretMetrics? _getMetricsFromUpstream(int offset) {
    assert(offset >= 0);
    final int plainTextLength = plainText.length;
    if (plainTextLength == 0 || offset > plainTextLength) {
      return null;
    }
    final int prevCodeUnit = plainText.codeUnitAt(max(0, offset - 1));

    // 换行符标记：如果上游是换行，光标位于下一行
    const int newlineCodeUnit = 10;

    // 确定是否需要扩展搜索范围以找到完整的字形集群
    // 需要搜索的情况：多代码单元字形（代理对）或特殊字符
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
      
      if (boxes.isEmpty) {
        // 若未找到框，检查是否应继续搜索或放弃
        if (!needsSearch && prevCodeUnit == newlineCodeUnit) {
          break; // 非换行符且不需要搜索，仅尝试一次
        }
        if (prevRuneOffset < -plainTextLength) {
          break; // 已超出文本范围
        }
        // 扩大搜索范围（二进制增长以实现 O(log n) 性能）
        graphemeClusterLength *= 2;
        continue;
      }

      // 边界框找到，获取最后一个框作为光标位置
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

  /// 基于下游字符（当前位置之后的字符）的近边缘获取光标度量
  ///
  /// 用于计算光标位置和宽度，基于文本位置的下游字符。当光标后面有字符时使用此方法。
  ///
  /// 处理的字符类型：
  /// - 多代码单元字形：如表情符号、代理对等
  /// - 零宽度连接符 (ZWJ)：用于组合字符和表情符号
  /// - Unicode 方向性标记：零宽度字符
  ///
  /// 查询策略（同 [_getMetricsFromUpstream]）：
  /// - 使用二分搜索策略以 O(log n) 时间复杂度找到字形集群
  /// - 逐次扩大搜索范围直至找到有效的边界框
  ///
  /// 返回值：
  /// - 若成功找到字形的边界框，返回光标度量
  /// - 若文本为空或查询到末尾仍无结果，返回 null
  ///
  /// 参数 [offset] 应 >= 0
  _CaretMetrics? _getMetricsFromDownstream(int offset) {
    assert(offset >= 0);
    final int plainTextLength = plainText.length;
    if (plainTextLength == 0) {
      return null;
    }
    // 将偏移量限制在有效范围内，避免越界
    final int nextCodeUnit =
        plainText.codeUnitAt(min(offset, plainTextLength - 1));

    // 检查是否需要扩展搜索范围以找到完整字形
    final bool needsSearch = isHighSurrogate(nextCodeUnit) ||
        isLowSurrogate(nextCodeUnit) ||
        nextCodeUnit == _zwjUtf16 ||
        _isUnicodeDirectionality(nextCodeUnit);
    int graphemeClusterLength = needsSearch ? 2 : 1;
    List<Rect> boxes = <Rect>[];
    
    while (boxes.isEmpty) {
      final int nextRuneOffset = offset + graphemeClusterLength;
      boxes = _layoutCache!.paragraph.getBoxesForRange(offset, nextRuneOffset);
      
      if (boxes.isEmpty) {
        // 若未找到框，检查是否应继续搜索或放弃
        if (!needsSearch) {
          break; // 非搜索模式下仅尝试一次
        }
        if (nextRuneOffset >= plainTextLength << 1) {
          break; // 已远超文本最大长度
        }
        // 扩大搜索范围（二进制增长策略）
        graphemeClusterLength *= 2;
        continue;
      }

      // 边界框找到，获取第一个框作为光标位置
      final box = boxes.first;
      return _LineCaretMetrics(
        offset: Offset(box.left, box.top),
        fullWidth: box.right - box.left,
      );
    }
    return null;
  }

  /// 将文本对齐方式转换为绘制偏移的标准化因子
  ///
  /// 根据文本对齐方式返回一个因子，用于计算 paintOffset.dy，
  /// 实现蒙古文的垂直对齐。
  ///
  /// 返回值范围在 [0, 1] 之间：
  /// - 0.0：顶部对齐（MongolTextAlign.top, justify）
  /// - 0.5：垂直居中（MongolTextAlign.center）
  /// - 1.0：底部对齐（MongolTextAlign.bottom）
  ///
  /// 应用公式：paintOffset.dy = factor * (contentHeight - paragraph.height)
  static double _computePaintOffsetFraction(MongolTextAlign textAlign) {
    return switch (textAlign) {
      MongolTextAlign.top => 0.0,
      MongolTextAlign.bottom => 1.0,
      MongolTextAlign.center => 0.5,
      MongolTextAlign.justify => 0.0,
    };
  }

  /// 计算给定光标位置的绘制偏移量
  ///
  /// 根据给定的文本位置，计算光标在画布坐标系中应该绘制的位置。
  /// 此方法处理所有对齐和坐标转换逻辑。
  ///
  /// 参数说明：
  /// - [position]：文本中的光标位置
  /// - [caretPrototype]：光标的原型矩形（用于指定光标大小）
  ///
  /// 坐标系转换：
  /// - 段落内部坐标系 -> 对齐后坐标系（通过 paintOffset）-> 最终画布坐标
  ///
  /// 处理的情况：
  /// 1. 无效位置（< 0）：返回空行光标（0, paddingTop）
  /// 2. 空行中的光标：返回该行的 x 坐标，y 坐标基于对齐方式
  /// 3. 非空行中的光标：返回字形的边缘坐标
  ///
  /// 高度夹着策略（Clamping）：
  /// - 某些情况下光标可能落在公布的内容区域之外（如尾随换行符）
  /// - 此时需要将 y 坐标夹着在 [0, contentHeight] 范围内
  /// - 这符合更高层次的期望（如 MongolRenderEditable 的处理）
  ///
  /// 前置条件：必须在调用 [layout] 之后调用
  Offset getOffsetForCaret(TextPosition position, Rect caretPrototype) {
    final _CaretMetrics caretMetrics;
    final _TextPainterLayoutCacheWithOffset layoutCache = _layoutCache!;
    
    if (position.offset < 0) {
      // 无效位置，返回空行光标（0 高度光标）
      caretMetrics = const _EmptyLineCaretMetrics(lineHorizontalOffset: 0);
    } else {
      // 有效位置，计算光标度量
      caretMetrics = _computeCaretMetrics(position);
    }

    final Offset rawOffset;
    switch (caretMetrics) {
      case _EmptyLineCaretMetrics(:final double lineHorizontalOffset):
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
        
      case _LineCaretMetrics(:final Offset offset):
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

  /// 缓存的光标度量信息
  ///
  /// 该字段存储最后一次计算的光标度量结果，避免对相同位置的重复计算。
  /// 在 [_computeCaretMetrics] 中更新。当查询相同的光标位置时，直接返回此缓存，
  /// 无需再次调用高成本的 [_getMetricsFromUpstream] 或 [_getMetricsFromDownstream]。
  late _CaretMetrics _caretMetrics;

  /// 计算指定文本位置处的光标度量信息
  ///
  /// 此方法是光标度量计算的核心，实现了以下逻辑：
  /// 1. 使用位置和亲和力（affinity）确定查询方向
  /// 2. 首选方向查询失败时，回退到另一个方向
  /// 3. 缓存结果，避免重复计算
  ///
  /// 亲和力（Affinity）说明：
  /// - [TextAffinity.upstream]：光标倾向贴靠前一个字符（从下游回退到上游）
  /// - [TextAffinity.downstream]：光标倾向贴靠后一个字符（从上游回退到下游）
  ///
  /// 双向回退策略：
  /// - 如果首选方向无法找到光标，尝试另一个方向
  /// - 如果两个方向都无法找到，返回空行光标（光标位置 0）
  ///
  /// 缓存管理：
  /// - 比较新旧位置：若位置相同，直接返回缓存度量，避免重新计算
  /// - 更新缓存：若位置变化，重新计算并更新缓存
  ///
  /// 前置条件：[_layoutCache] 必须有效
  _CaretMetrics _computeCaretMetrics(TextPosition position) {
    assert(_debugAssertTextLayoutIsValid);
    assert(!_debugNeedsRelayout);
    final _TextPainterLayoutCacheWithOffset cachedLayout = _layoutCache!;
    
    // 缓存检查：若位置未变，直接返回缓存结果
    if (position == cachedLayout._previousCaretPosition) {
      return _caretMetrics;
    }
    
    final int offset = position.offset;
    final _CaretMetrics? metrics = switch (position.affinity) {
      // 上游亲和力：优先从上游查询，失败则从下游查询
      TextAffinity.upstream =>
        _getMetricsFromUpstream(offset) ?? _getMetricsFromDownstream(offset),
      // 下游亲和力：优先从下游查询，失败则从上游查询
      TextAffinity.downstream =>
        _getMetricsFromDownstream(offset) ?? _getMetricsFromUpstream(offset),
    };
    
    // 更新缓存位置和度量
    cachedLayout._previousCaretPosition = position;
    return _caretMetrics =
        metrics ?? const _EmptyLineCaretMetrics(lineHorizontalOffset: 0);
  }

  /// 返回包围指定选择范围内的所有字形的矩形列表
  ///
  /// 选择范围的处理说明：
  /// - [selection] 必须是有效的范围（[TextSelection.isValid] 返回 true）
  /// - 前导和尾随的换行符将由零高度的矩形表示
  /// - 仅返回完全包含在选择范围内的字形矩形
  /// - 若多代码单元字形仅部分在范围内，该字形将被排除
  ///
  /// 坐标系处理：
  /// - 返回的矩形已经通过 [paintOffset] 进行了坐标转换
  /// - 得到的是在 MongolTextPainter 坐标系中（对齐后）的位置
  /// - 如果 paintOffset 无限，返回空列表
  ///
  /// 使用场景：
  /// - 获取文本选择范围的可视化矩形
  /// - 绘制选择高亮背景
  /// - 计算选区的包围盒
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

  /// 返回给定像素偏移量对应的文本位置
  ///
  /// 根据触摸点或指针位置（相对 MongolTextPainter 的坐标），
  /// 计算该点最接近的文本位置（字符偏移量）。
  ///
  /// 坐标系处理：
  /// - [offset] 是在 MongolTextPainter 坐标系中的位置（已对齐）
  /// - 内部自动减去 paintOffset 转换为段落坐标系
  /// - 返回的 TextPosition 的offset 基于纯文本坐标
  ///
  /// 使用场景：
  /// - 响应点击事件获取光标位置
  /// - 实现文本选择交互
  /// - 计算手指指向的字符位置
  TextPosition getPositionForOffset(Offset offset) {
    assert(_debugAssertTextLayoutIsValid);
    assert(!_debugNeedsRelayout);
    final _TextPainterLayoutCacheWithOffset cachedLayout = _layoutCache!;
    return cachedLayout.paragraph
        .getPositionForOffset(offset - cachedLayout.paintOffset);
  }

  /// 返回给定文本位置处单词的边界范围
  ///
  /// 此方法基于 Unicode 标准附录 #29 的单词分割规则识别单词边界。
  /// 
  /// 行为说明：
  /// - 非单词字符（空格、符号、标点）两侧都是单词边界
  /// - 对于这类字符，返回包含该字符的文本范围本身
  /// - 单词边界在 Unicode 标准 #29 中有详细定义
  ///   * http://www.unicode.org/reports/tr29/#Word_Boundaries
  ///
  /// 使用场景：
  /// - 双击选择整个单词
  /// - 实现单词级别的快速选择
  /// - 文本编辑的单词边界检查
  TextRange getWordBoundary(TextPosition position) {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.paragraph.getWordBoundary(position);
  }

  /// 返回一个 TextBoundary 对象，用于对当前文本进行单词边界分析
  ///
  /// 此 TextBoundary 使用 Unicode 标准附录 #29 中定义的规则。
  ///
  /// 前置条件：
  /// - 必须在调用 [layout] 之后使用
  /// - [text] 属性必须非空
  ///
  /// 返回的 TextBoundary：
  /// - 实现了 [MongolWordBoundary] 接口
  /// - 支持单词级别的边界查询
  /// - 包含了针对蒙古文的优化
  MongolWordBoundary get wordBoundaries =>
      MongolWordBoundary._(text!, _layoutCache!.paragraph);

  /// 返回给定文本位置处所在行的边界范围
  ///
  /// 返回范围说明：
  /// - 不包括行末的换行符（如果有的话）
  /// - 范围跨越整个逻辑行
  ///
  /// 使用场景：
  /// - 获取光标所在行的全部文本
  /// - 实现行级别的选择和编辑操作
  TextRange getLineBoundary(TextPosition position) {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.paragraph.getLineBoundary(position);
  }

  /// 对行度量信息应用偏移量变换
  ///
  /// 将指定的列度量信息中的所有坐标通过 [offset] 进行平移。
  /// 这是在坐标系转换中使用的辅助方法，用于将段落坐标转换为绘制坐标。
  ///
  /// 参数：
  /// - [metrics]：原始的行度量信息
  /// - [offset]：要应用的坐标偏移
  ///
  /// 返回值：
  /// - 新的行度量信息，所有坐标值都偏移了指定的量
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

  /// 对文本选择边框应用偏移量变换
  ///
  /// 将指定的矩形通过 [offset] 进行平移。这是在坐标系转换中使用的辅助方法，
  /// 用于将段落坐标中的矩形转换为绘制坐标中的矩形。
  ///
  /// 参数：
  /// - [box]：原始矩形
  /// - [offset]：要应用的坐标偏移
  ///
  /// 返回值：
  /// - 新的矩形，所有坐标值都偏移了指定的量
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

  /// 计算并返回所有行的详细度量信息列表
  ///
  /// 返回值说明：
  /// - 返回一个 [MongolLineMetrics] 列表，按行顺序排列（第一行在索引 0）
  /// - 每个 [MongolLineMetrics] 包含该行的详细度量，如：
  ///   * ascent/descent：上升/下降距离
  ///   * baseline：基线位置
  ///   * height：行高
  ///   * width：行宽（文本占用的垂直距离）
  ///   * hardBreak：是否为硬换行符结尾
  /// - 所有坐标值已通过 [paintOffset] 进行转换，位于绘制坐标系中
  ///
  /// 特殊情况：
  /// - 如果 paintOffset 不是有限值，返回空列表
  ///
  /// 使用场景：
  /// - 获取详细的行布局信息用于精确对齐
  /// - 将其他小部件与特定行对齐
  /// - 实现自定义的行级别渲染逻辑
  ///
  /// 前置条件：必须在调用 [layout] 之后调用
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

  /// 此对象是否已被释放
  ///
  /// 此属性仅在启用断言时可用。在发布模式下访问会抛出 StateError。
  /// 主要用于调试，确保文本绘制器在被释放后不再被使用。
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
  ///
  /// 此方法执行以下清理操作：
  /// 1. 释放布局模板段落（[_layoutTemplate]）
  /// 2. 释放布局缓存中的段落（[_layoutCache] 的 paragraph）
  /// 3. 清除所有缓存和引用
  /// 4. 标记为已释放
  ///
  /// 调用后的行为：
  /// - 调用此对象的任何方法都将失败
  /// - 在调试模式下，[debugDisposed] 会返回 true
  /// - 尽量立即释放，避免资源泄漏
  ///
  /// 何时调用：
  /// - 当不再需要绘制器时（如 Widget 卸载）
  /// - 由 State.dispose or RenderObject.dispose 方法调用
  /// - 对于临时创建的绘制器，应在最后一次使用后立即释放
  ///
  /// 安全性说明：
  /// - 重复调用是安全的（会多次进行清理，但不会报错）
  /// - 释放后访问属性或调用方法通常会失败
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
