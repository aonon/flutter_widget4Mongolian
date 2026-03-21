// Copyright 2014 The Flutter Authors.
// Copyright 2021 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:characters/characters.dart';
import 'package:flutter/painting.dart';

import 'mongol_text_align.dart';

/// 段落单行测量和统计信息
///
/// 存储整行文本的度量信息，通过 [MongolParagraph.computeLineMetrics] 获取
class MongolLineMetrics {
  /// 创建段落行度量信息
  MongolLineMetrics({
    required this.hardBreak,
    required this.ascent,
    required this.descent,
    required this.unscaledAscent,
    required this.height,
    required this.width,
    required this.top,
    required this.baseline,
    required this.lineNumber,
  });

  /// 行是否以显式换行符结束
  final bool hardBreak;

  /// 从基线开始的上升高度
  final double ascent;

  /// 从基线开始的下降高度
  final double descent;

  /// 忽略行高的上升高度
  final double unscaledAscent;

  /// 行的总高度
  final double height;

  /// 行的总宽度
  final double width;

  /// 行的顶部 y 坐标
  final double top;

  /// 行的基线 x 坐标
  final double baseline;

  /// 行号，从 0 开始
  final int lineNumber;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is MongolLineMetrics &&
        other.hardBreak == hardBreak &&
        other.ascent == ascent &&
        other.descent == descent &&
        other.unscaledAscent == unscaledAscent &&
        other.height == height &&
        other.width == width &&
        other.top == top &&
        other.baseline == baseline &&
        other.lineNumber == lineNumber;
  }

  @override
  int get hashCode => Object.hash(hardBreak, ascent, descent, unscaledAscent,
      height, width, top, baseline, lineNumber);

  @override
  String toString() {
    return 'LineMetrics(hardBreak: $hardBreak, '
        'ascent: $ascent, '
        'descent: $descent, '
        'unscaledAscent: $unscaledAscent, '
        'height: $height, '
        'width: $width, '
        'top: $top, '
        'baseline: $baseline, '
        'lineNumber: $lineNumber)';
  }
}

/// 蒙古文垂直排版段落类
///
/// 蒙古文具有独特的书写特点：
/// 1. 文字书写方向：从上到下
/// 2. 行移动方向：从左到右
/// 3. 字体朝向：蒙古文字体头朝左，因此在垂直排版时需要将文字旋转90度
///
/// 本类负责实现蒙古文的垂直排版、换行和布局，核心实现包括：
/// - 将整个画布旋转90度，实现垂直排版基础
/// - 按从上到下方向排列文字，从左到右换行
/// - 对蒙古文字符进行90度旋转，确保正确的显示朝向
/// - 处理行内对齐、间距和溢出等布局问题
///
/// 变量命名说明：
/// - 内部横向（internal horizontal）：指代码内部使用的水平方向，对应外部显示的垂直方向
/// - 外部纵向（external vertical）：指最终显示给用户的垂直方向，对应内部计算的水平方向
/// 例如：
/// - 内部的width实际对应外部的height
/// - 内部的height实际对应外部的width
class MongolParagraph {
  /// 由 [MongolParagraphBuilder] 创建，不应直接实例化
  MongolParagraph._(
    this._runs,
    this._text,
    this._maxLines,
    this._ellipsis,
    this._textAlign,
  );
  
  // Initialize source signatures after object construction.
  // We can't use initializer list because the runs may be large; do it lazily
  // when first needed.
  void _ensureSourceSignatureInitialized() {
    if (_sourceTextHash != 0 && _sourceRunsSignatureHash != 0) return;
    _sourceTextHash = _text.hashCode;
    _sourceRunsSignatureHash = _computeRunsSignature(_runs);
  }

  int _computeRunsSignature(List<_TextRun> runs) {
    final List<int> parts = <int>[];
    for (final r in runs) {
      parts.add(r.start);
      parts.add(r.end);
      parts.add(r.isRotated ? 1 : 0);
      parts.add(r.textStyle?.hashCode ?? 0);
      parts.add(r.paragraphStyle?.hashCode ?? 0);
    }
    return Object.hashAll(parts);
  }

  final String _text;
  final List<_TextRun> _runs;
  final int? _maxLines;
  final _TextRun? _ellipsis;
  final MongolTextAlign _textAlign;

  // Signature/hash of the source text and runs at construction time. Used
  // to detect external changes and to invalidate caches.
  int _sourceTextHash = 0;
  int _sourceRunsSignatureHash = 0;

  // Signature of the inputs used by the last completed layout. If the
  // current layout request produces the same signature, layout is skipped.
  int? _lastLayoutSignatureHash;

  double? _width;
  double? _height;
  double? _longestLine;
  double? _minIntrinsicHeight;
  double? _maxIntrinsicHeight;

  /// 段落占用的水平空间
  /// 仅在调用 [layout] 后有效
  double get width => _width ?? 0;

  /// 段落占用的垂直空间
  /// 仅在调用 [layout] 后有效
  double get height => _height ?? 0;

  /// 段落中最长行的高度
  /// 仅在调用 [layout] 后有效
  double get longestLine => _longestLine ?? 0;

  /// 段落的最小固有高度
  /// 仅在调用 [layout] 后有效
  double get minIntrinsicHeight => _minIntrinsicHeight ?? 0;

  /// 段落的最大固有高度
  /// 仅在调用 [layout] 后有效
  double get maxIntrinsicHeight => _maxIntrinsicHeight ?? double.infinity;

  /// 字母基线距离
  double get alphabeticBaseline {
    if (_runs.isEmpty) {
      return 0.0;
    }
    return _runs.first.paragraph.alphabeticBaseline;
  }

  /// 表意基线距离
  double get ideographicBaseline {
    if (_runs.isEmpty) {
      return 0.0;
    }
    return _runs.first.paragraph.ideographicBaseline;
  }

  /// 文本是否超过最大行数
  bool get didExceedMaxLines {
    return _didExceedMaxLines;
  }

  bool _didExceedMaxLines = false;

  /// 计算段落中每个字形的大小和位置
  void layout(MongolParagraphConstraints constraints) =>
      _layout(constraints.height);

  /// 执行段落布局计算
  void _layout(double height) {
    _ensureSourceSignatureInitialized();

    // Compute a signature (small int hash) of inputs that affect layout.
    final currentSignatureHash = Object.hash(height, _sourceTextHash, _sourceRunsSignatureHash);
    if (_lastLayoutSignatureHash != null && _lastLayoutSignatureHash == currentSignatureHash) {
      return;
    }
    
    // 1. 计算行断点，确定文本如何换行
    _calculateLineBreaks(height);
    
    // 2. 计算段落总宽度
    _calculateWidth();
    
    // 3. 更新段落高度
    _height = height;
    
    // 4. 计算内在高度（最小和最大）
    _calculateIntrinsicHeight();

    // Update last layout signature after successful layout.
    _lastLayoutSignatureHash = currentSignatureHash;
  }

  final List<_LineInfo> _lines = [];
  // 每行的累积水平偏移量
  // _lineOffsets[i]是第0到第i行高度的总和，用于快速将垂直坐标映射到行索引
  final List<double> _lineOffsets = [];

  /// 计算文本的换行位置
  void _calculateLineBreaks(double maxLineLength) {
    // 如果没有文本 run，直接返回
    if (_runs.isEmpty) {
      return;
    }
    
    // 重置布局状态
    if (_lines.isNotEmpty) {
      _lines.clear();
      _lineOffsets.clear();
      _didExceedMaxLines = false;
    }

    // 初始化行计算变量
    int startRunIndex = 0;          // 当前行的起始 run 索引
    int endRunIndex = 0;            // 当前行的结束 run 索引
    double currentLineWidth = 0.0;  // 当前行的累积宽度
    double currentLineHeight = 0.0; // 当前行的最大高度
    bool lastRunEndsWithNewline = false; // 上一个 run 是否以换行符结束
    
    // 遍历所有文本 run，计算行断点
    for (int runIndex = 0; runIndex < _runs.length; runIndex++) {
      endRunIndex = runIndex;
      final _TextRun currentRun = _runs[runIndex];
      final double runWidth = currentRun.width;
      final double runHeight = currentRun.height;

      // 检查当前 run 加入后是否超过行宽限制
      if (currentLineWidth + runWidth > maxLineLength) {
        // 超过限制，添加当前行为新行
        _addLine(startRunIndex, endRunIndex, currentLineWidth, currentLineHeight);
        
        // 重置行变量，开始新行
        currentLineWidth = runWidth;
        currentLineHeight = runHeight;
        startRunIndex = endRunIndex;
      } else {
        // 未超过限制，继续累积到当前行
        currentLineWidth += runWidth;
        currentLineHeight = math.max(currentLineHeight, runHeight);
      }

      // 检查当前 run 是否以换行符结束
      lastRunEndsWithNewline = _runEndsWithNewLine(currentRun);
      if (lastRunEndsWithNewline) {
        // 以换行符结束，添加当前行为新行
        endRunIndex = runIndex + 1;
        _addLine(startRunIndex, endRunIndex, currentLineWidth, currentLineHeight);
        
        // 重置行变量，开始新行
        currentLineWidth = 0;
        currentLineHeight = 0;
        startRunIndex = endRunIndex;
      }

      // 如果已经超过最大行数限制，停止处理
      if (_didExceedMaxLines) {
        break;
      }
    }

    // 添加最后一行（如果有剩余文本）
    endRunIndex = _runs.length;
    if (startRunIndex < endRunIndex) {
      _addLine(startRunIndex, endRunIndex, currentLineWidth, currentLineHeight);
    }

    // 如果最后一个 run 以换行符结束，添加一个空行
    if (lastRunEndsWithNewline) {
      final double lastLineHeight = _lines.last.bounds.height;
      _addLine(-1, -1, 0, lastLineHeight);
    }
  }

  bool _runEndsWithNewLine(_TextRun? run) {
    if (run == null) return false;
    final int end = run.end;
    if (end <= 0 || end > _text.length || run.start >= run.end) return false;
    final int index = end - 1;
    return _text[index] == '\n';
  }

  /// 添加新行到布局中
  void _addLine(int start, int end, double width, double height) {
    // 检查是否超过最大行数限制
    if (_maxLines != null && _maxLines! <= _lines.length) {
      _didExceedMaxLines = true;
      return;
    }
    
    _didExceedMaxLines = false;
    
    // 创建行边界矩形
    final Rect bounds = Rect.fromLTRB(0, 0, width, height);
    
    // 预计算行内 run 的累积宽度，用于后续快速命中测试
    final List<double> runCumulativeWidths = <double>[];
    if (start >= 0 && end > start) {
      double accumulatedWidth = 0.0;
      for (int i = start; i < end; i++) {
        accumulatedWidth += _runs[i].width;
        runCumulativeWidths.add(accumulatedWidth);
      }
    }
    
    // 创建行信息对象并添加到行列表中
    final _LineInfo lineInfo = _LineInfo(start, end, bounds, runCumulativeWidths);
    _lines.add(lineInfo);
    
    // 更新最长行记录
    _longestLine = math.max(longestLine, lineInfo.bounds.width);

    // 更新行偏移量列表，用于快速映射垂直坐标到行索引
    final double lastOffset = _lineOffsets.isEmpty ? 0.0 : _lineOffsets.last;
    _lineOffsets.add(lastOffset + bounds.height);
  }

  /// 计算段落总宽度
  void _calculateWidth() {
    double totalWidth = 0.0;
    for (final _LineInfo line in _lines) {
      totalWidth += line.bounds.height;
    }
    _width = totalWidth;
  }

  /// 计算段落的内在高度
  void _calculateIntrinsicHeight() {
    double currentLineSum = 0.0;
    double maxIndividualRunWidth = 0.0;
    double maxHeightForLineWithNewLine = 0.0;
    double minHeightForLineWithoutNewLine = double.infinity;
    
    // 遍历所有行，计算内在高度
    for (int lineIndex = 0; lineIndex < _lines.length; lineIndex++) {
      final _LineInfo line = _lines[lineIndex];
      _TextRun? lastRunInLine;
      
      // 遍历行内所有 run
      for (int runIndex = line.textRunStart; runIndex < line.textRunEnd; runIndex++) {
        lastRunInLine = _runs[runIndex];
        final double runWidth = lastRunInLine.width;
        
        // 更新最大单个 run 宽度
        maxIndividualRunWidth = math.max(runWidth, maxIndividualRunWidth);
        
        // 累积当前行的宽度
        currentLineSum += runWidth;
      }
      
      // 检查当前行是否以换行符结束
      final bool endsWithNewLine = lastRunInLine != null && _runEndsWithNewLine(lastRunInLine);
      final bool hasNextLine = lineIndex < _lines.length - 1;
      
      if (hasNextLine && !endsWithNewLine) {
        // 当前行不是最后一行且不以换行符结束，考虑与下一行合并的情况
        final _LineInfo nextLine = _lines[lineIndex + 1];
        currentLineSum += _runs[nextLine.textRunStart].width;
        minHeightForLineWithoutNewLine = math.min(minHeightForLineWithoutNewLine, currentLineSum);
      } else {
        // 当前行是最后一行或以换行符结束
        maxHeightForLineWithNewLine = math.max(maxHeightForLineWithNewLine, currentLineSum);
      }
      
      // 重置当前行宽度累积
      currentLineSum = 0;
    }
    
    // 处理没有找到不带换行符行的情况
    if (minHeightForLineWithoutNewLine == double.infinity) {
      minHeightForLineWithoutNewLine = 0;
    }
    
    // 更新内在高度属性
    _minIntrinsicHeight = maxIndividualRunWidth;
    _maxIntrinsicHeight =
        math.max(minHeightForLineWithoutNewLine, maxHeightForLineWithNewLine);
  }

  /// 获取最接近给定偏移量的文本位置
  TextPosition getPositionForOffset(Offset offset) {
    final encoded = _getPositionForOffset(offset.dx, offset.dy);
    return TextPosition(
        offset: encoded[0], affinity: TextAffinity.values[encoded[1]]);
  }

  // 行信息和文本 run 是水平方向的，但 [dx] 和 [dy] 偏移量是垂直方向的
  List<int> _getPositionForOffset(double dx, double dy) {
    const int upstream = 0;
    const int downstream = 1;

    // 说明：外部的 `dx`/`dy` 是在竖直布局坐标系中的坐标（段落的左上原点）。
    // 我们内部把行和 run 都当作水平（未旋转）来存储，所以这里需要把竖直坐标
    // 映射回内部的行/run 索引。
    if (_lines.isEmpty) {
      return [0, downstream];
    }

      // 使用二分查找找到对应的行
    _LineInfo matchedLine;
    if (_lineOffsets.isEmpty) {
      matchedLine = _lines.last;
    } else {
      int low = 0;
      int high = _lineOffsets.length - 1;
      // 二分查找确保low和high的有效性
      assert(low >= 0 && high >= 0 && high < _lineOffsets.length, 
          'Invalid binary search bounds: low=$low, high=$high, length=${_lineOffsets.length}');
      
      while (low <= high) {
        final int mid = (low + high) >> 1;
        assert(mid >= 0 && mid < _lineOffsets.length, 
            'Invalid binary search mid: $mid, length=${_lineOffsets.length}');
            
        if (dx <= _lineOffsets[mid]) {
          high = mid - 1;
        } else {
          low = mid + 1;
        }
      }
      final int lineIndex = math.min(low, _lines.length - 1);
      assert(lineIndex >= 0 && lineIndex < _lines.length, 
          'Invalid line index: $lineIndex, length=${_lines.length}');
      matchedLine = _lines[lineIndex];
    }

    // 使用二分查找找到行中的对应 run
    _TextRun matchedRun;
    double runStartOffset = 0.0;
    final double lineTopOffset = matchedLine.bounds.top;
    
    if (matchedLine.runCumWidths.isEmpty) {
      // 回退：选择最后一个 run
      final int runIndex = matchedLine.textRunEnd - 1;
      if (runIndex.isNegative) {
        matchedRun = _runs.last;
      } else {
        assert(runIndex >= 0 && runIndex < _runs.length, 
            'Invalid run index: $runIndex, length=${_runs.length}');
        matchedRun = _runs[runIndex];
      }
    } else {
      int low = 0;
      int high = matchedLine.runCumWidths.length - 1;
      // 二分查找确保low和high的有效性
      assert(low >= 0 && high >= 0 && high < matchedLine.runCumWidths.length, 
          'Invalid binary search bounds: low=$low, high=$high, length=${matchedLine.runCumWidths.length}');
      
      while (low <= high) {
        final int mid = (low + high) >> 1;
        assert(mid >= 0 && mid < matchedLine.runCumWidths.length, 
            'Invalid binary search mid: $mid, length=${matchedLine.runCumWidths.length}');
            
        if (dy <= matchedLine.runCumWidths[mid]) {
          high = mid - 1;
        } else {
          low = mid + 1;
        }
      }
      final int runIndexInLine = math.min(low, matchedLine.runCumWidths.length - 1);
      final int runIndex = matchedLine.textRunStart + runIndexInLine;
      assert(runIndex >= 0 && runIndex < _runs.length, 
          'Invalid run index: $runIndex, length=${_runs.length}');
      matchedRun = _runs[math.min(runIndex, _runs.length - 1)];
      runStartOffset = runIndexInLine == 0 ? 0.0 : matchedLine.runCumWidths[runIndexInLine - 1];
    }

    // 计算在 run 内的偏移量
    final double runLocalX = dy - runStartOffset;
    final double runLocalY = dx - lineTopOffset;
    final Offset runOffset = Offset(runLocalX, runLocalY);
    final TextPosition runPosition = matchedRun.paragraph.getPositionForOffset(runOffset);
    final int textOffset = matchedRun.start + runPosition.offset;

    // 确定文本亲和性
    final int lineEndOffset = matchedRun.end;
    final int textAffinity = (textOffset == lineEndOffset) ? upstream : downstream;
    
    return [textOffset, textAffinity];
  }

  /// 在画布上绘制垂直蒙古文
  void draw(Canvas canvas, Offset offset) {
    final shouldDrawEllipsis = _didExceedMaxLines && _ellipsis != null;

    // translate for the offset
    // 保存并移动画布到段落的左上角 (外部坐标系)
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    // rotate the canvas 90 degrees clockwise so that horizontal text
    // (how we measured it) appears vertical on the screen.
    // 简单理解：我们把内部的 "水平行" 顺时针旋转 90°，变成垂直的视觉效果。
    canvas.rotate(math.pi / 2);

    // loop through every line
    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];

      // translate for the line height
      final dy = -line.bounds.height;
      canvas.translate(0, dy);

      // draw line
      final isLastLine = i == _lines.length - 1;
      _drawEachRunInCurrentLine(canvas, line, shouldDrawEllipsis, isLastLine);
    }

    canvas.restore();
  }

  void _drawEachRunInCurrentLine(
      Canvas canvas, _LineInfo line, bool shouldDrawEllipsis, bool isLastLine) {
    // 每行绘制前保存画布状态，便于恢复
    canvas.save();

    // runSpacing 是行内额外的间距（用于两端对齐时分配空白）
    var runSpacing = 0.0;
    switch (_textAlign) {
      case MongolTextAlign.top:
        break;
      case MongolTextAlign.center:
        final offset = (_height! - line.bounds.width) / 2;
        canvas.translate(offset, 0);
        break;
      case MongolTextAlign.bottom:
        final offset = _height! - line.bounds.width;
        canvas.translate(offset, 0);
        break;
      case MongolTextAlign.justify:
        if (isLastLine) break;
        final extraSpace = _height! - line.bounds.width;
        final runsInLine = line.textRunEnd - line.textRunStart;
        if (runsInLine <= 1) break;
        runSpacing = extraSpace / (runsInLine - 1);
        break;
    }

    final startIndex = line.textRunStart;
    final endIndex = line.textRunEnd - 1;
    for (var j = startIndex; j <= endIndex; j++) {
      final run = _runs[j];

      // alignmentOffset: 在 run 宽度小于行高度时，垂直居中该 run
      var alignmentOffset = 0.0;
      if (run.isRotated) {
        alignmentOffset = (line.bounds.height - run.width) / 2;
      }
      // verticalShift: 根据字体基线做细微的垂直偏移，以便视觉上更居中
      var verticalShift = 0.0;
      if (run.isRotated) {
        final descent = run.paragraph.height - run.paragraph.alphabeticBaseline;
        verticalShift = -descent / 2;
      }
      final offset = Offset(verticalShift, alignmentOffset);

      // 如果需要绘制省略号且当前是最后一行的最后一个 run，则处理省略号逻辑
      if (shouldDrawEllipsis && isLastLine && j == endIndex) {
        if (maxIntrinsicHeight + _ellipsis!.height < height) {
          run.draw(canvas, offset);
          canvas.translate(run.width, 0);
        }
        _ellipsis!.draw(canvas, const Offset(0, 0));
      } else {
        run.draw(canvas, offset);
        canvas.translate(run.width, 0);
      }
      canvas.translate(runSpacing, 0);
    }

    canvas.restore();
  }

  /// 获取给定文本范围的包围矩形列表
  ///
  /// 矩形坐标相对于段落左上角，正y值向下。
  /// 方向为垂直蒙古文，从左到右换行。
  List<Rect> getBoxesForRange(int start, int end) {
    final boxes = <Rect>[];

    // The [start] index must be within the text range
    final textLength = _text.length;
    if (start < 0 || start > _text.length) {
      return boxes;
    }

    // Allow the [end] index to be larger than the text length but don't use it
    final effectiveEnd = math.min(textLength, end);

    // Horizontal offset (`dx`) 表示在竖直排版下，当前列（line）在水平方向上的起点。
    // 因为我们把每一行的高度作为列宽来累加，所以这里使用 line.bounds.height。
    var dx = 0.0;

    // loop through each line
    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      final lastRunIndex = line.textRunEnd - 1;

      // return empty line for invalid run indexes
      // (This happens when text ends with newline char.)
      if (lastRunIndex < 0) {
        if (end > textLength) {
          boxes.add(_lineBoundsAsBox(line, dx));
        }
        continue;
      }

      final lineLastCharIndex = _runs[lastRunIndex].end - 1;

      // skip empty lines before the selected range
      if (lineLastCharIndex < start) {
        // The line is horizontal but dx is for vertical orientation
        dx += line.bounds.height;
        continue;
      }

      final firstRunIndex = line.textRunStart;
      final lineFirstCharIndex = _runs[firstRunIndex].start;

      // If this is a full line then skip looping over the runs
      // because the line size has already been cached.
      if (lineFirstCharIndex >= start && lineLastCharIndex < effectiveEnd) {
        boxes.add(_lineBoundsAsBox(line, dx));
      } else {
        // check the runs one at a time
        final lineBox = _getBoxFromLine(line, start, effectiveEnd, dx);

        // partial selections of grapheme clusters should return no boxes
        if (lineBox != Rect.zero) {
          boxes.add(lineBox);
        }

        // If this is the last line there we're finished
        if (lineLastCharIndex >= effectiveEnd - 1) {
          return boxes;
        }
      }
      dx += line.bounds.height;
    }
    return boxes;
  }

  Rect _lineBoundsAsBox(_LineInfo line, double dx) {
    final lineBounds = line.bounds;
    return Rect.fromLTWH(dx, 0, lineBounds.height, lineBounds.width);
  }

  // Takes a single line and finds the box that includes the selected range
  Rect _getBoxFromLine(_LineInfo line, int start, int end, double dx) {
    var boxWidth = 0.0;
    var boxHeight = 0.0;

    // `dy` 是在当前竖直行中（即内部水平行的方向）沿着文字增长方向的偏移量。
    // 对于第一段选择，它通常是 0，但如果选择从行中间开始，`dy` 会记录偏移。
    var dy = 0.0;

    // loop though every run in the line
    // If the line has cumulative run widths we can use them to skip runs quickly.
    for (var j = line.textRunStart; j < line.textRunEnd; j++) {
      final run = _runs[j];

      // skips runs that are after selected range
      if (run.start >= end) {
        break;
      }

      // skip runs that are before the selected range
      if (run.end <= start) {
        dy += run.width;
        continue;
      }

      // The size of full intermediate runs has already been cached
      if (run.start >= start && run.end <= end) {
        boxWidth = math.max(boxWidth, run.height);
        boxHeight += run.width;
        if (run.end == end) {
          break;
        }
        continue;
      }

      // The range selection is in middle of a run
      final localStart = math.max(start, run.start) - run.start;
      final localEnd = math.min(end, run.end) - run.start;
      final textBoxes = run.paragraph.getBoxesForRange(localStart, localEnd);

      // empty boxes occur for partial selections of a grapheme cluster
      if (textBoxes.isEmpty) {
        if (end <= run.end) {
          break;
        } else {
          dy += run.width;
          continue;
        }
      }

      // handle orientation differences for emoji and CJK characters
      final box = textBoxes.first;
      dy += box.left;
      double verticalWidth = box.bottom;
      double verticalHeight = box.right - box.left;
      boxWidth = math.max(boxWidth, verticalWidth);
      boxHeight += verticalHeight;

      // if this is the last run then we're finished
      if (end <= run.end) {
        break;
      }
    }

    if (boxWidth == 0.0 || boxHeight == 0.0) {
      return Rect.zero;
    }
    return Rect.fromLTWH(dx, dy, boxWidth, boxHeight);
  }

  /// 获取给定文本位置处的单词边界
  ///
  /// 当前实现返回正确的文本片段，通常是一个单词
  TextRange getWordBoundary(TextPosition position) {
    final offset = position.offset;
    if (offset >= _text.length) {
      return TextRange(start: _text.length, end: offset);
    }
    // 先找到包含该偏移的 run，然后在 run 内使用分词/换行规则找到单词边界。
    final run = _getRunFromOffset(offset);
    if (run == null) {
      return TextRange.empty;
    }
    return _splitBreakCharactersFromRun(run, offset);
  }

  // runs can include break characters currently so split them from the returned
  // range
  TextRange _splitBreakCharactersFromRun(_TextRun run, int offset) {
    var start = run.start;
    var end = run.end;
    final finalChar = _text[end - 1];
    if (LineBreaker.isBreakChar(finalChar)) {
      if (offset == end - 1) {
        start = end - 1;
      } else {
        end = end - 1;
      }
    }
    return TextRange(start: start, end: end);
  }

  _TextRun? _getRunFromOffset(int offset) {
    if (_runs.isEmpty || offset < 0 || offset >= _text.length) {
      return null;
    }
    int min = 0;
    int max = _runs.length - 1;
    // 使用二分查找在已测量的 runs 中定位包含 `offset` 的 run，
    // 这样比线性查找要快，尤其是在长文本时。
    while (min <= max) {
      final int guess = (max + min) ~/ 2;
      final _TextRun currentRun = _runs[guess];
      
      // 确保 run 的边界是有效的
      assert(currentRun.start >= 0 && currentRun.end >= currentRun.start, 
          'Invalid run bounds: start=${currentRun.start}, end=${currentRun.end}');
      
      if (offset >= currentRun.end) {
        min = guess + 1;
      } else if (offset < currentRun.start) {
        max = guess - 1;
      } else {
        return currentRun;
      }
    }
    return null;
  }

  /// 获取给定文本位置处的行边界
  ///
  /// 换行符不包含在返回的范围内
  /// 仅在调用 layout 后有效
  /// 此方法可能较昂贵，建议谨慎使用
  TextRange getLineBoundary(TextPosition position) {
    final offset = position.offset;
    if (offset > _text.length) {
      return TextRange.empty;
    }
    var min = 0;
    var max = _lines.length - 1;
    var start = -1;
    var end = -1;
    // do a binary search
    while (min <= max) {
      final guess = (max + min) ~/ 2;
      final line = _lines[guess];
      start = _runs[line.textRunStart].start;
      end = _runs[line.textRunEnd - 1].end;
      if (offset >= end) {
        min = guess + 1;
        continue;
      } else if (offset < start) {
        max = guess - 1;
        continue;
      } else {
        break;
      }
    }
    // exclude newline character
    if (end > start && _text[end - 1] == '\n') {
      end--;
    }
    return TextRange(start: start, end: end);
  }

  /// 获取每一行的详细度量信息列表
  ///
  /// 仅在调用 layout 后有效
  /// 可能返回大量数据，建议缓存结果而非重复调用
  List<MongolLineMetrics> computeLineMetrics() {
    final List<MongolLineMetrics> lineMetricsList = <MongolLineMetrics>[];
    
    for (int lineIndex = 0; lineIndex < _lines.length; lineIndex++) {
      final _LineInfo line = _lines[lineIndex];
      
      bool isHardBreak = false;
      double maxAscent = 0;
      double maxDescent = 0;
      double maxUnscaledAscent = 0;
      double totalHeight = 0;
      double maxLineWidth = 0;
      double lineBaseline = 0;
      
          // 遍历当前行的所有文本 run，跳过无效的行（textRunStart 和 textRunEnd 都为 -1 的空行）
      if (line.textRunStart != -1 && line.textRunEnd != -1) {
        for (int runIndex = line.textRunStart; runIndex < line.textRunEnd; runIndex++) {
          // 确保 runIndex 在有效范围内
          if (runIndex < 0 || runIndex >= _runs.length) continue;
          
          final _TextRun textRun = _runs[runIndex];
          final List<LineMetrics> runLineMetrics = textRun.paragraph.computeLineMetrics();
          final LineMetrics? runMetrics = runLineMetrics.isNotEmpty ? runLineMetrics.first : null;

          // 检查是否为行末换行符
          if (runIndex == line.textRunEnd - 1) {
            isHardBreak = _runEndsWithNewLine(textRun);
          }
          
          // 计算行的最大上升高度、下降高度等
          final double runAscent = runMetrics?.ascent ?? 0;
          final double runDescent = runMetrics?.descent ?? 0;
          final double runUnscaledAscent = runMetrics?.unscaledAscent ?? 0;
          final double runHeight = runMetrics?.height ?? 0;
          final double runWidth = runMetrics?.width ?? textRun.width;
          
          maxAscent = math.max(runAscent, maxAscent);
          maxDescent = math.max(runDescent, maxDescent);
          maxUnscaledAscent = math.max(runUnscaledAscent, maxUnscaledAscent);
          maxLineWidth = math.max(runHeight, maxLineWidth);
          totalHeight += runWidth;
          
          // 基线位置将在处理完本行所有 run 后，根据上一行的度量计算。
        }
      }

      MongolLineMetrics? previousLineMetrics =
          (lineIndex > 0 && lineMetricsList.isNotEmpty) ? lineMetricsList[lineIndex - 1] : null;
      if (previousLineMetrics != null) {
        lineBaseline = previousLineMetrics.baseline + previousLineMetrics.ascent + maxDescent;
      }

      // 处理空行（由换行符创建的行）
      if (line.textRunStart == -1 && line.textRunEnd == -1) {
        // 空行：如果存在上一行，则借用上一行度量作为参考；否则保留默认 0。
        isHardBreak = true;
        if (previousLineMetrics != null) {
          maxAscent = previousLineMetrics.ascent;
          maxDescent = previousLineMetrics.descent;
          maxUnscaledAscent = previousLineMetrics.unscaledAscent;
          totalHeight = previousLineMetrics.height;
          maxLineWidth = previousLineMetrics.width;
          lineBaseline = previousLineMetrics.baseline + previousLineMetrics.ascent + maxDescent;
        }
      }

      // 计算行的顶部偏移量，根据对齐方式调整
      double lineTopOffset = 0;
      if (_textAlign == MongolTextAlign.center) {
        lineTopOffset = (height - totalHeight) / 2;
      } else if (_textAlign == MongolTextAlign.bottom) {
        lineTopOffset = height - totalHeight;
      }

      // 创建行度量信息对象
      final MongolLineMetrics lineMetrics = MongolLineMetrics(
        hardBreak: isHardBreak,
        ascent: maxAscent,
        descent: maxDescent,
        unscaledAscent: maxUnscaledAscent,
        height: totalHeight,
        width: maxLineWidth,
        top: lineTopOffset,
        baseline: lineBaseline,
        lineNumber: lineIndex,
      );
      
      lineMetricsList.add(lineMetrics);
    }
    
    return lineMetricsList;
  }

  /// 释放对象使用的资源
  /// 调用后对象不再可用
  void dispose() {
    assert(!_disposed);
    _disposed = true;

    for (final run in _runs) {
      try {
        run.paragraph.dispose();
      } catch (_) {
        // Ignore errors during dispose to be defensive.
      }
    }
    _runs.clear();
  }

  bool _disposed = false;

  /// Whether this reference to the underlying picture is [dispose]d.
  ///
  /// This only returns a valid value if asserts are enabled, and must not be
  /// used otherwise.
  bool get debugDisposed {
    bool? disposed;
    assert(() {
      disposed = _disposed;
      return true;
    }());
    return disposed ??
        (throw StateError(
            '$runtimeType.debugDisposed is only available when asserts are enabled.'));
  }
}

/// [MongolParagraph] 的布局约束
///
/// 通常与 [MongolParagraph.layout] 一起使用
///
/// 唯一可指定的约束是 [height]
class MongolParagraphConstraints {
  const MongolParagraphConstraints({
    required this.height,
  });

  /// The height the paragraph should use when computing the positions of glyphs.
  final double height;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is MongolParagraphConstraints && other.height == height;
  }

  @override
  int get hashCode => height.hashCode;

  @override
  String toString() => '$runtimeType(height: $height)';
}

/// 构建带有样式信息的 [MongolParagraph]
///
/// 通过 [pushStyle]、[addText] 和 [pop] 方法添加样式化文本，
/// 最后调用 [build] 获取构建好的 [MongolParagraph] 对象。
/// 调用 [build] 后，构建器不再可用。
class MongolParagraphBuilder {
  MongolParagraphBuilder(
    ui.ParagraphStyle style, {
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
    bool rotateCJK = true,
  })  : _paragraphStyle = style,
        _textAlign = textAlign,
        _textScaler = textScaler == TextScaler.noScaling
            ? TextScaler.linear(textScaleFactor)
            : textScaler,
        _maxLines = maxLines,
        _ellipsis = ellipsis,
        _rotateCJK = rotateCJK;

  ui.ParagraphStyle? _paragraphStyle;
  final MongolTextAlign _textAlign;
  final TextScaler _textScaler;
  final int? _maxLines;
  final String? _ellipsis;
  final bool _rotateCJK;

  //_TextRun? _ellipsisRun;
  final _styleStack = _Stack<TextStyle>();
  final _rawStyledTextRuns = <_RawStyledTextRun>[];

  static final _defaultParagraphStyle = ui.ParagraphStyle(
    textAlign: TextAlign.start,
    textDirection: TextDirection.ltr,
  );

  static final _defaultTextStyle = ui.TextStyle(
    color: const Color(0xFFFFFFFF),
    textBaseline: TextBaseline.alphabetic,
  );

  /// Applies the given style to the added text until [pop] is called.
  ///
  /// See [pop] for details.
  void pushStyle(TextStyle style) {
    if (_styleStack.isEmpty) {
      _styleStack.push(style);
      return;
    }
    final lastStyle = _styleStack.top;
    _styleStack.push(lastStyle.merge(style));
  }

  /// Ends the effect of the most recent call to [pushStyle].
  ///
  /// Internally, the paragraph builder maintains a stack of text styles. Text
  /// added to the paragraph is affected by all the styles in the stack. Calling
  /// [pop] removes the topmost style in the stack, leaving the remaining styles
  /// in effect.
  void pop() {
    _styleStack.pop();
  }

  final _plainText = StringBuffer();

  /// Adds the given text to the paragraph.
  ///
  /// The text will be styled according to the current stack of text styles.
  void addText(String text) {
    _plainText.write(text);
    final style = _styleStack.isEmpty ? null : _styleStack.top;
    final breakSegments = BreakSegments(text);
    for (final segment in breakSegments) {
      _rawStyledTextRuns.add(_RawStyledTextRun(style, segment));
    }
  }

  /// Applies the given paragraph style and returns a [MongolParagraph]
  /// containing the added text and associated styling.
  ///
  /// After calling this function, the paragraph builder object is invalid and
  /// cannot be used further.
  MongolParagraph build() {
    _paragraphStyle ??= _defaultParagraphStyle;
    final runs = <_TextRun>[];

    final length = _rawStyledTextRuns.length;
    var startIndex = 0;
    var endIndex = 0;
    ui.ParagraphBuilder? builder;
    ui.TextStyle? style;
    for (var i = 0; i < length; i++) {
      style = _uiStyleForRun(i);
      final segment = _rawStyledTextRuns[i].text;
      endIndex += segment.text.length;
      builder ??= ui.ParagraphBuilder(_paragraphStyle!);
      builder.pushStyle(style);
      final text = _stripNewLineChar(segment.text);
      builder.addText(text);
      builder.pop();

      if (_isNonBreakingSegment(i)) {
        continue;
      }

      final paragraph = builder.build();
      paragraph.layout(const ui.ParagraphConstraints(width: double.infinity));

      // Determine final rotation logic here
      bool isRotated = segment.isRotatable;
      if (isRotated && !_rotateCJK) {
        // If config says don't rotate, we un-flag it, BUT...
        // ...we must ensure Emojis stay rotated.
        if (!LineBreaker.isEmoji(segment.text.runes.first)) {
          isRotated = false;
        }
      }

        final run = _TextRun(startIndex, endIndex, isRotated, paragraph,
          textStyle: style, paragraphStyle: _paragraphStyle);
      runs.add(run);
      builder = null;
      startIndex = endIndex;
    }

    return MongolParagraph._(
      runs,
      _plainText.toString(),
      _maxLines,
      _ellipsisRun(style),
      _textAlign,
    );
  }

  bool _isNonBreakingSegment(int i) {
    final segment = _rawStyledTextRuns[i].text;
    if (segment.isRotatable) return false;
    if (_endsWithBreak(segment.text)) return false;

    if (i >= _rawStyledTextRuns.length - 1) return false;
    final nextSegment = _rawStyledTextRuns[i + 1].text;
    if (nextSegment.isRotatable) return false;
    if (_startsWithBreak(nextSegment.text)) return false;
    return true;
  }

  bool _startsWithBreak(String run) {
    if (run.isEmpty) return false;
    return LineBreaker.isBreakChar(run[0]);
  }

  bool _endsWithBreak(String run) {
    if (run.isEmpty) return false;
    return LineBreaker.isBreakChar(run[run.length - 1]);
  }

  ui.TextStyle _uiStyleForRun(int index) {
    final style = _rawStyledTextRuns[index].style;
    return style?.getTextStyle(textScaler: _textScaler) ?? _defaultTextStyle;
  }

  String _stripNewLineChar(String text) {
    if (!text.endsWith('\n')) return text;
    return text.replaceAll('\n', '');
  }

  _TextRun? _ellipsisRun(ui.TextStyle? style) {
    if (_ellipsis == null) {
      return null;
    }
    final builder = ui.ParagraphBuilder(_paragraphStyle!);
    if (style != null) {
      builder.pushStyle(style);
    }
    builder.addText(_ellipsis!);
    final paragraph = builder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: double.infinity));
    return _TextRun(-1, -1, false, paragraph,
      textStyle: style, paragraphStyle: _paragraphStyle);
  }
}

/// An iterable that iterates over the substrings of [text] between locations
/// that line breaks are allowed.
class BreakSegments extends Iterable<RotatableString> {
  BreakSegments(this.text);

  final String text;

  @override
  Iterator<RotatableString> get iterator => LineBreaker(text);
}

class RotatableString {
  const RotatableString(this.text, this.isRotatable);

  final String text;
  final bool isRotatable;
}

/// Finds all the locations in a string of text where line breaks are allowed.
///
/// LineBreaker gives the strings between the breaks upon iteration.
class LineBreaker implements Iterator<RotatableString> {
  LineBreaker(this.text) {
    _characterIterator = text.characters.iterator;
  }

  final String text;

  late CharacterRange _characterIterator;

  RotatableString? _currentTextRun;

  @override
  RotatableString get current {
    if (_currentTextRun == null) {
      throw StateError(
          'Current is undefined before moveNext is called or after last element.');
    }
    return _currentTextRun!;
  }

  bool _atEndOfCharacterRange = false;
  RotatableString? _rotatedCharacterBuffer;

  @override
  bool moveNext() {
    if (_atEndOfCharacterRange) {
      _currentTextRun = null;
      return false;
    }
    if (_rotatedCharacterBuffer != null) {
      _currentTextRun = _rotatedCharacterBuffer;
      _rotatedCharacterBuffer = null;
      return true;
    }

    final returnValue = StringBuffer();
    while (_characterIterator.moveNext()) {
      final current = _characterIterator.current;
      if (isBreakChar(current)) {
        returnValue.write(current);
        _currentTextRun = RotatableString(returnValue.toString(), false);
        return true;
      } else if (_isRotatable(current)) {
        if (returnValue.isEmpty) {
          _currentTextRun = RotatableString(current, true);
          return true;
        } else {
          _currentTextRun = RotatableString(returnValue.toString(), false);
          _rotatedCharacterBuffer = RotatableString(current, true);
          return true;
        }
      }
      returnValue.write(current);
    }
    _currentTextRun = RotatableString(returnValue.toString(), false);
    if (_currentTextRun!.text.isEmpty) {
      return false;
    }
    _atEndOfCharacterRange = true;
    return true;
  }

  static bool isBreakChar(String character) {
    return (character == ' ' || character == '\n');
  }

  static const _mongolQuickCheckStart = 0x1800;
  static const _mongolQuickCheckEnd = 0x2060;
  static const _koreanJamoStart = 0x1100;
  static const _koreanJamoEnd = 0x11FF;
  static const _cjkRadicalSupplementStart = 0x2E80;
  static const _cjkSymbolsAndPunctuationStart = 0x3000;
  static const _cjkSymbolsAndPunctuationMenksoftEnd = 0x301C;
  static const _circleNumber21 = 0x3251;
  static const _circleNumber35 = 0x325F;
  static const _circleNumber36 = 0x32B1;
  static const _circleNumber50 = 0x32BF;
  static const _cjkUnifiedIdeographsEnd = 0x9FFF;
  static const _hangulSyllablesStart = 0xAC00;
  static const _hangulJamoExtendedBEnd = 0xD7FF;
  static const _cjkCompatibilityIdeographsStart = 0xF900;
  static const _cjkCompatibilityIdeographsEnd = 0xFAFF;
  static const _unicodeEmojiStart = 0x1F000;

  bool _isRotatable(String character) {
    final codePoint = character.runes.first;

    // Quick return: most Mongol chars should be in this range
    if (codePoint >= _mongolQuickCheckStart &&
        codePoint < _mongolQuickCheckEnd) {
      return false;
    }

    // Korean Jamo
    if (codePoint < _koreanJamoStart) return false; // latin, etc
    if (codePoint <= _koreanJamoEnd) return true;

    // Chinese and Japanese
    if (codePoint >= _cjkRadicalSupplementStart &&
        codePoint <= _cjkUnifiedIdeographsEnd) {
      // exceptions for font handled punctuation
      if (codePoint >= _cjkSymbolsAndPunctuationStart &&
          codePoint <= _cjkSymbolsAndPunctuationMenksoftEnd) {
        return false;
      }
      if (codePoint >= _circleNumber21 && codePoint <= _circleNumber35) {
        return false;
      }

      if (codePoint >= _circleNumber36 && codePoint <= _circleNumber50) {
        return false;
      }
      return true;
    }

    // Korean Hangul
    if (codePoint >= _hangulSyllablesStart &&
        codePoint <= _hangulJamoExtendedBEnd) {
      return true;
    }

    // More Chinese
    if (codePoint >= _cjkCompatibilityIdeographsStart &&
        codePoint <= _cjkCompatibilityIdeographsEnd) {
      return true;
    }

    // Emoji
    if (isEmoji(codePoint)) return true;

    // all other code points
    return false;
  }

  static bool isEmoji(int codePoint) {
    return codePoint > _unicodeEmojiStart;
  }
}

// A data object to associate a text run with its style
class _RawStyledTextRun {
  _RawStyledTextRun(this.style, this.text);

  final TextStyle? style;
  final RotatableString text;
}

/// A [_TextRun] describes the smallest unit of text that is printed on the
/// canvas. It may be a word, CJK character, emoji or particular style.
///
/// The [start] and [end] values are the indexes of the text range that
/// forms the run. The [paragraph] is the precomputed Paragraph object that
/// contains the text run.
class _TextRun {
  _TextRun(this.start, this.end, this.isRotated, this.paragraph,
      {this.textStyle, this.paragraphStyle});

  /// The UTF-16 code unit index where this run starts within the entire text
  /// range. The value in inclusive (that is, this is the actual start index).
  final int start;

  /// The UTF-16 code unit index where this run ends within the entire text
  /// range. The value is exclusive (that is, one unit beyond the last code
  /// unit).
  final int end;

  /// 文本片段是否需要逆时针旋转90度
  ///
  /// 蒙古文、日文、中文等字符在垂直排版时需要旋转，以保证正确的显示朝向
  /// 蒙古文字体头朝左，因此在垂直排版时必须旋转90度才能正确显示
  final bool isRotated;

  /// The pre-computed text layout for this run.
  ///
  /// It includes the size but should never be more than one line.
  final ui.Paragraph paragraph;

  // Optional style information used to rebuild paragraphs when splitting runs.
  final ui.TextStyle? textStyle;
  final ui.ParagraphStyle? paragraphStyle;

  /// Returns the width of the run (in horizontal orientation).
  double get width {
    return paragraph.maxIntrinsicWidth;
  }

  /// Returns the height of the run (in horizontal orientation).
  double get height {
    return paragraph.height;
  }

  /// 绘制文本片段
  ///
  /// 蒙古文绘制处理：
  /// 1. 对于需要旋转的文本（如蒙古文）：
  ///    - 保存画布状态
  ///    - 应用偏移量
  ///    - 逆时针旋转90度，使蒙古文字体朝向正确
  ///    - 平移调整位置，确保文字居中对齐
  ///    - 绘制段落
  ///    - 恢复画布状态
  /// 2. 对于不需要旋转的文本，直接绘制
  void draw(ui.Canvas canvas, ui.Offset offset) {
    if (isRotated) {
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      // 逆时针旋转90度，使蒙古文字体朝向正确
      canvas.rotate(-math.pi / 2);
      // 平移调整位置
      canvas.translate(-paragraph.maxIntrinsicWidth, 0);
      canvas.drawParagraph(paragraph, const ui.Offset(0, 0));
      canvas.restore();
    } else {
      canvas.drawParagraph(paragraph, offset);
    }
  }
}

/// 存储段落中每行的信息
class _LineInfo {
  _LineInfo(this.textRunStart, this.textRunEnd, this.bounds, this.runCumWidths);

  /// 当前行起始run在[_runs]中的索引
  final int textRunStart;

  /// 当前行结束run在[_runs]中的索引（不包含）
  final int textRunEnd;

  /// 未旋转行的测量大小（水平方向）
  final Rect bounds;

  /// 行内run的累积宽度列表
  /// 例如：[w1, w1+w2, w1+w2+w3]
  final List<double> runCumWidths;
}

// 用于跟踪文本样式栈
class _Stack<T> {
  final _stack = Queue<T>();

  void push(T element) {
    _stack.addLast(element);
  }

  void pop() {
    _stack.removeLast();
  }

  bool get isEmpty => _stack.isEmpty;

  T get top => _stack.last;
}
