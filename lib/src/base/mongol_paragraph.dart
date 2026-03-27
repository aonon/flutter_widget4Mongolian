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

/// ---------------------------------------------------------------------------
/// MongolLineMetrics：每一行文字的“体检报告”
///
/// 当文字排版完成后，我们需要知道每一行到底占了多大地方、基线在哪里。
/// 这个类就像一把尺子，记录了这一竖行文字的各项物理数据。
/// ---------------------------------------------------------------------------
class MongolLineMetrics {
  /// 创建行度量信息
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

  /// 这一行是不是因为你敲了回车键才换行的？
  final bool hardBreak;

  /// 基线以上的距离（文字的“额头”高度）
  final double ascent;

  /// 基线以下的距离（文字的“下巴”深度）
  final double descent;

  /// 忽略行高的原始上升高度（未缩放）
  final double unscaledAscent;

  /// 这一行的总高度（在竖排逻辑中，它代表这一列的“厚度”/宽度）
  final double height;

  /// 这一行的总宽度（在竖排逻辑中，它代表这一列从上到下的“长度”）
  final double width;

  /// 这一行顶部的坐标
  final double top;

  /// 这一行基线的位置
  final double baseline;

  /// 这是第几行？（从 0 开始算）
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

/// ---------------------------------------------------------------------------
/// MongolParagraph：蒙古文垂直排版的“总指挥”
///
/// 蒙古文非常特殊：它是从上往下写，然后一列一列从左往右排。
///
/// 【核心设计思想】：
/// 为了复用 Flutter 强大的排版引擎，我们采用了一个“旋转”策略：
/// 1. 计算时：假装文字是普通的横排（Internal），计算好每一行多长、哪里该换行。
/// 2. 显示时：通过 Canvas 旋转 90 度，把横排瞬间变成竖排（External）。
///
/// 【坐标转换口诀】：
/// - 代码里的 width（宽） = 屏幕上看到的文字高度（列的长度）
/// - 代码里的 height（高） = 屏幕上看到的文字行宽（列的厚度）
/// ---------------------------------------------------------------------------
class MongolParagraph {
  /// 由 [MongolParagraphBuilder] 创建，不应直接实例化
  MongolParagraph._(
    this._runs,
    this._text,
    this._maxLines,
    this._ellipsis,
    this._textAlign,
  );
  
  // 初始化原始文本和片段的特征哈希，用于检测内容是否变化
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

  int _sourceTextHash = 0;
  int _sourceRunsSignatureHash = 0;

  // 上一次布局时的特征值，用于避免重复计算
  int? _lastLayoutSignatureHash;

  double? _width;
  double? _height;
  double? _longestLine;
  double? _minIntrinsicHeight;
  double? _maxIntrinsicHeight;

  /// 段落占用的水平总宽度（所有列厚度的总和）
  double get width => _width ?? 0;

  /// 段落占用的垂直总高度（通常等于 constraints 限制的高度）
  double get height => _height ?? 0;

  /// 段落中最长那一列的长度
  double get longestLine => _longestLine ?? 0;

  /// 段落的最小固有高度（排版时至少需要这么长才能塞下最长的那个词）
  double get minIntrinsicHeight => _minIntrinsicHeight ?? 0;

  /// 段落的最大固有高度（如果不限制高度，这段文字最长能排多长）
  double get maxIntrinsicHeight => _maxIntrinsicHeight ?? double.infinity;

  /// 字母基线位置
  double get alphabeticBaseline {
    if (_runs.isEmpty) {
      return 0.0;
    }
    return _runs.first.paragraph.alphabeticBaseline;
  }

  /// 表意文字基线位置
  double get ideographicBaseline {
    if (_runs.isEmpty) {
      return 0.0;
    }
    return _runs.first.paragraph.ideographicBaseline;
  }

  /// 文本是否因为超过了最大行数限制而被截断
  bool get didExceedMaxLines {
    return _didExceedMaxLines;
  }

  bool _didExceedMaxLines = false;

  /// 【布局总动员】
  /// 根据给定的高度限制，决定文字如何摆放
  void layout(MongolParagraphConstraints constraints) =>
      _layout(constraints.height);

  /// 执行核心布局计算
  void _layout(double height) {
    _ensureSourceSignatureInitialized();

    // 1. 看看内容和限制变了没？没变就直接收工。
    final currentSignatureHash = Object.hash(height, _sourceTextHash, _sourceRunsSignatureHash);
    if (_lastLayoutSignatureHash != null && _lastLayoutSignatureHash == currentSignatureHash) {
      return;
    }
    
    // 2. 算断点：根据高度限制，决定在哪里把文字切断，换到下一列。
    _calculateLineBreaks(height);
    
    // 3. 算总宽：把所有列的“厚度”加起来。
    _calculateWidth();
    
    // 4. 记录高度并计算内在高度限制。
    _height = height;
    _calculateIntrinsicHeight();

    _lastLayoutSignatureHash = currentSignatureHash;
  }

  final List<_LineInfo> _lines = [];
  // 每一列在水平方向上的累积偏移量
  final List<double> _lineOffsets = [];

  /// 【换行计算器】
  /// 遍历文字片段，看看当前这一列还能不能塞下。塞不下了就另起一列。
  void _calculateLineBreaks(double maxLineLength) {
    if (_runs.isEmpty) {
      return;
    }
    
    if (_lines.isNotEmpty) {
      _lines.clear();
      _lineOffsets.clear();
      _didExceedMaxLines = false;
    }

    int startRunIndex = 0;
    int endRunIndex = 0;
    double currentLineWidth = 0.0;
    double currentLineHeight = 0.0;
    bool lastRunEndsWithNewline = false;
    
    for (int runIndex = 0; runIndex < _runs.length; runIndex++) {
      endRunIndex = runIndex;
      final _TextRun currentRun = _runs[runIndex];
      final double runWidth = currentRun.width;
      final double runHeight = currentRun.height;

      // 如果当前列塞不下了...
      if (currentLineWidth + runWidth > maxLineLength) {
        _addLine(startRunIndex, endRunIndex, currentLineWidth, currentLineHeight);
        currentLineWidth = runWidth;
        currentLineHeight = runHeight;
        startRunIndex = endRunIndex;
      } else {
        currentLineWidth += runWidth;
        currentLineHeight = math.max(currentLineHeight, runHeight);
      }

      // 碰到 '\n' 强制换到下一列
      lastRunEndsWithNewline = _runEndsWithNewLine(currentRun);
      if (lastRunEndsWithNewline) {
        endRunIndex = runIndex + 1;
        _addLine(startRunIndex, endRunIndex, currentLineWidth, currentLineHeight);
        currentLineWidth = 0;
        currentLineHeight = 0;
        startRunIndex = endRunIndex;
      }

      if (_didExceedMaxLines) {
        break;
      }
    }

    // 收尾：把剩下的文字放进最后一列
    endRunIndex = _runs.length;
    if (startRunIndex < endRunIndex) {
      _addLine(startRunIndex, endRunIndex, currentLineWidth, currentLineHeight);
    }

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

  /// 将计算好的一列文字信息存入列表
  void _addLine(int start, int end, double width, double height) {
    if (_maxLines != null && _maxLines! <= _lines.length) {
      _didExceedMaxLines = true;
      return;
    }
    
    _didExceedMaxLines = false;
    final Rect bounds = Rect.fromLTRB(0, 0, width, height);
    
    final List<double> runCumulativeWidths = <double>[];
    if (start >= 0 && end > start) {
      double accumulatedWidth = 0.0;
      for (int i = start; i < end; i++) {
        accumulatedWidth += _runs[i].width;
        runCumulativeWidths.add(accumulatedWidth);
      }
    }
    
    final _LineInfo lineInfo = _LineInfo(start, end, bounds, runCumulativeWidths);
    _lines.add(lineInfo);
    _longestLine = math.max(longestLine, lineInfo.bounds.width);

    final double lastOffset = _lineOffsets.isEmpty ? 0.0 : _lineOffsets.last;
    _lineOffsets.add(lastOffset + bounds.height);
  }

  /// 累加所有列的厚度，得到段落总宽度
  void _calculateWidth() {
    double totalWidth = 0.0;
    for (final _LineInfo line in _lines) {
      totalWidth += line.bounds.height;
    }
    _width = totalWidth;
  }

  /// 计算如果不受高度限制，段落最小和最大可能的高度
  void _calculateIntrinsicHeight() {
    double currentLineSum = 0.0;
    double maxIndividualRunWidth = 0.0;
    double maxHeightForLineWithNewLine = 0.0;
    double minHeightForLineWithoutNewLine = double.infinity;
    
    for (int lineIndex = 0; lineIndex < _lines.length; lineIndex++) {
      final _LineInfo line = _lines[lineIndex];
      _TextRun? lastRunInLine;
      
      for (int runIndex = line.textRunStart; runIndex < line.textRunEnd; runIndex++) {
        lastRunInLine = _runs[runIndex];
        final double runWidth = lastRunInLine.width;
        maxIndividualRunWidth = math.max(runWidth, maxIndividualRunWidth);
        currentLineSum += runWidth;
      }
      
      final bool endsWithNewLine = lastRunInLine != null && _runEndsWithNewLine(lastRunInLine);
      final bool hasNextLine = lineIndex < _lines.length - 1;
      
      if (hasNextLine && !endsWithNewLine) {
        final _LineInfo nextLine = _lines[lineIndex + 1];
        currentLineSum += _runs[nextLine.textRunStart].width;
        minHeightForLineWithoutNewLine = math.min(minHeightForLineWithoutNewLine, currentLineSum);
      } else {
        maxHeightForLineWithNewLine = math.max(maxHeightForLineWithNewLine, currentLineSum);
      }
      
      currentLineSum = 0;
    }
    
    if (minHeightForLineWithoutNewLine == double.infinity) {
      minHeightForLineWithoutNewLine = 0;
    }
    
    _minIntrinsicHeight = maxIndividualRunWidth;
    _maxIntrinsicHeight =
        math.max(minHeightForLineWithoutNewLine, maxHeightForLineWithNewLine);
  }

  /// 【点击位置检测】
  /// 当用户点了一下屏幕，我们需要知道他点在哪个字上。
  /// 因为有旋转，我们需要把屏幕坐标 (dx, dy) 逆向转回内部坐标。
  TextPosition getPositionForOffset(Offset offset) {
    final encoded = _getPositionForOffset(offset.dx, offset.dy);
    return TextPosition(
        offset: encoded[0], affinity: TextAffinity.values[encoded[1]]);
  }

  List<int> _getPositionForOffset(double dx, double dy) {
    const int upstream = 0;
    const int downstream = 1;

    if (_lines.isEmpty) {
      return [0, downstream];
    }

    // 1. 用二分查找法，快速定位点在了第几列。
    _LineInfo matchedLine;
    if (_lineOffsets.isEmpty) {
      matchedLine = _lines.last;
    } else {
      int low = 0;
      int high = _lineOffsets.length - 1;
      while (low <= high) {
        final int mid = (low + high) >> 1;
        if (dx <= _lineOffsets[mid]) {
          high = mid - 1;
        } else {
          low = mid + 1;
        }
      }
      final int lineIndex = math.min(low, _lines.length - 1);
      matchedLine = _lines[lineIndex];
    }

    // 2. 在那一列里，再次用二分查找定位点在哪个文字片段上。
    _TextRun matchedRun;
    double runStartOffset = 0.0;
    final double lineTopOffset = matchedLine.bounds.top;
    
    if (matchedLine.runCumWidths.isEmpty) {
      final int runIndex = matchedLine.textRunEnd - 1;
      if (runIndex.isNegative) {
        matchedRun = _runs.last;
      } else {
        matchedRun = _runs[runIndex];
      }
    } else {
      int low = 0;
      int high = matchedLine.runCumWidths.length - 1;
      while (low <= high) {
        final int mid = (low + high) >> 1;
        if (dy <= matchedLine.runCumWidths[mid]) {
          high = mid - 1;
        } else {
          low = mid + 1;
        }
      }
      final int runIndexInLine = math.min(low, matchedLine.runCumWidths.length - 1);
      final int runIndex = matchedLine.textRunStart + runIndexInLine;
      matchedRun = _runs[math.min(runIndex, _runs.length - 1)];
      runStartOffset = runIndexInLine == 0 ? 0.0 : matchedLine.runCumWidths[runIndexInLine - 1];
    }

    // 3. 计算在片段内的具体偏移，返回文字索引。
    final double runLocalX = dy - runStartOffset;
    final double runLocalY = dx - lineTopOffset;
    final Offset runOffset = Offset(runLocalX, runLocalY);
    final TextPosition runPosition = matchedRun.paragraph.getPositionForOffset(runOffset);
    final int textOffset = matchedRun.start + runPosition.offset;

    final int lineEndOffset = matchedRun.end;
    final int textAffinity = (textOffset == lineEndOffset) ? upstream : downstream;
    
    return [textOffset, textAffinity];
  }

  /// 【最终绘制】
  /// 把文字真正画到屏幕上。
  void draw(Canvas canvas, Offset offset) {
    final shouldDrawEllipsis = _didExceedMaxLines && _ellipsis != null;

    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    // 【核心变换】：顺时针旋转画布 90 度，让横向排版的“列”变成纵向显示。
    canvas.rotate(math.pi / 2);

    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];

      // 移动到下一列的位置（因为旋转了，所以是往负 y 方向移）
      final dy = -line.bounds.height;
      canvas.translate(0, dy);

      final isLastLine = i == _lines.length - 1;
      _drawEachRunInCurrentLine(canvas, line, shouldDrawEllipsis, isLastLine);
    }

    canvas.restore();
  }

  void _drawEachRunInCurrentLine(
      Canvas canvas, _LineInfo line, bool shouldDrawEllipsis, bool isLastLine) {
    canvas.save();

    // 处理对齐方式（靠顶、居中、靠底、两端对齐）
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

      var alignmentOffset = 0.0;
      if (run.isRotated) {
        alignmentOffset = (line.bounds.height - run.width) / 2;
      }
      var verticalShift = 0.0;
      if (run.isRotated) {
        final descent = run.paragraph.height - run.paragraph.alphabeticBaseline;
        verticalShift = -descent / 2;
      }
      final offset = Offset(verticalShift, alignmentOffset);

      // 处理省略号 (...)
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

  /// 获取给定文本范围的包围矩形列表（用于选中文光标或背景）
  List<Rect> getBoxesForRange(int start, int end) {
    final boxes = <Rect>[];
    final textLength = _text.length;
    if (start < 0 || start > _text.length) {
      return boxes;
    }

    final effectiveEnd = math.min(textLength, end);
    var dx = 0.0;

    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      final lastRunIndex = line.textRunEnd - 1;

      if (lastRunIndex < 0) {
        if (end > textLength) {
          boxes.add(_lineBoundsAsBox(line, dx));
        }
        continue;
      }

      final lineLastCharIndex = _runs[lastRunIndex].end - 1;
      if (lineLastCharIndex < start) {
        dx += line.bounds.height;
        continue;
      }

      final firstRunIndex = line.textRunStart;
      final lineFirstCharIndex = _runs[firstRunIndex].start;

      if (lineFirstCharIndex >= start && lineLastCharIndex < effectiveEnd) {
        boxes.add(_lineBoundsAsBox(line, dx));
      } else {
        final lineBox = _getBoxFromLine(line, start, effectiveEnd, dx);
        if (lineBox != Rect.zero) {
          boxes.add(lineBox);
        }
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

  Rect _getBoxFromLine(_LineInfo line, int start, int end, double dx) {
    var boxWidth = 0.0;
    var boxHeight = 0.0;
    var dy = 0.0;

    for (var j = line.textRunStart; j < line.textRunEnd; j++) {
      final run = _runs[j];
      if (run.start >= end) break;
      if (run.end <= start) {
        dy += run.width;
        continue;
      }

      if (run.start >= start && run.end <= end) {
        boxWidth = math.max(boxWidth, run.height);
        boxHeight += run.width;
        if (run.end == end) break;
        continue;
      }

      final localStart = math.max(start, run.start) - run.start;
      final localEnd = math.min(end, run.end) - run.start;
      final textBoxes = run.paragraph.getBoxesForRange(localStart, localEnd);

      if (textBoxes.isEmpty) {
        if (end <= run.end) {
          break;
        } else {
          dy += run.width;
          continue;
        }
      }

      final box = textBoxes.first;
      dy += box.left;
      double verticalWidth = box.bottom;
      double verticalHeight = box.right - box.left;
      boxWidth = math.max(boxWidth, verticalWidth);
      boxHeight += verticalHeight;

      if (end <= run.end) break;
    }

    if (boxWidth == 0.0 || boxHeight == 0.0) {
      return Rect.zero;
    }
    return Rect.fromLTWH(dx, dy, boxWidth, boxHeight);
  }

  /// 获取给定文本位置处的单词边界
  TextRange getWordBoundary(TextPosition position) {
    final offset = position.offset;
    if (offset >= _text.length) {
      return TextRange(start: _text.length, end: offset);
    }
    final run = _getRunFromOffset(offset);
    if (run == null) {
      return TextRange.empty;
    }
    return _splitBreakCharactersFromRun(run, offset);
  }

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
    while (min <= max) {
      final int guess = (max + min) ~/ 2;
      final _TextRun currentRun = _runs[guess];
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

  /// 获取给定文本位置所在的这一列的起始和结束位置
  TextRange getLineBoundary(TextPosition position) {
    final offset = position.offset;
    if (offset > _text.length) {
      return TextRange.empty;
    }
    var min = 0;
    var max = _lines.length - 1;
    var start = -1;
    var end = -1;
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
    if (end > start && _text[end - 1] == '\n') {
      end--;
    }
    return TextRange(start: start, end: end);
  }

  /// 获取所有列的详细度量信息列表
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
      
      if (line.textRunStart != -1 && line.textRunEnd != -1) {
        for (int runIndex = line.textRunStart; runIndex < line.textRunEnd; runIndex++) {
          if (runIndex < 0 || runIndex >= _runs.length) continue;
          
          final _TextRun textRun = _runs[runIndex];
          final List<LineMetrics> runLineMetrics = textRun.paragraph.computeLineMetrics();
          final LineMetrics? runMetrics = runLineMetrics.isNotEmpty ? runLineMetrics.first : null;

          if (runIndex == line.textRunEnd - 1) {
            isHardBreak = _runEndsWithNewLine(textRun);
          }
          
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
        }
      }

      MongolLineMetrics? previousLineMetrics =
          (lineIndex > 0 && lineMetricsList.isNotEmpty) ? lineMetricsList[lineIndex - 1] : null;
      if (previousLineMetrics != null) {
        lineBaseline = previousLineMetrics.baseline + previousLineMetrics.ascent + maxDescent;
      }

      if (line.textRunStart == -1 && line.textRunEnd == -1) {
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

      double lineTopOffset = 0;
      if (_textAlign == MongolTextAlign.center) {
        lineTopOffset = (height - totalHeight) / 2;
      } else if (_textAlign == MongolTextAlign.bottom) {
        lineTopOffset = height - totalHeight;
      }

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

  /// 释放资源
  void dispose() {
    assert(!_disposed);
    _disposed = true;

    for (final run in _runs) {
      try {
        run.paragraph.dispose();
      } catch (_) {}
    }
    _runs.clear();
  }

  bool _disposed = false;

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

/// [MongolParagraph] 的布局约束（目前主要限制高度）
class MongolParagraphConstraints {
  const MongolParagraphConstraints({
    required this.height,
  });

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

/// 蒙古文段落构造器：一步步把文字和样式塞进去，最后 build 出 MongolParagraph
class MongolParagraphBuilder {
  MongolParagraphBuilder(
    ui.ParagraphStyle style, {
    MongolTextAlign textAlign = MongolTextAlign.top,
    @Deprecated('Use textScaler instead.')
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

  /// 给接下来的文字添加某种样式
  void pushStyle(TextStyle style) {
    if (_styleStack.isEmpty) {
      _styleStack.push(style);
      return;
    }
    final lastStyle = _styleStack.top;
    _styleStack.push(lastStyle.merge(style));
  }

  /// 移除最近添加的一个样式
  void pop() {
    _styleStack.pop();
  }

  final _plainText = StringBuffer();

  /// 添加纯文本，会应用当前栈顶的样式
  void addText(String text) {
    _plainText.write(text);
    final style = _styleStack.isEmpty ? null : _styleStack.top;
    final breakSegments = BreakSegments(text);
    for (final segment in breakSegments) {
      _rawStyledTextRuns.add(_RawStyledTextRun(style, segment));
    }
  }

  /// 构建出最终的 MongolParagraph 对象
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

      bool isRotated = segment.isRotatable;
      if (isRotated && !_rotateCJK) {
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

/// 将文本分割成可旋转或不可旋转的片段的迭代器
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

/// 负责将字符串切分成一个个小的“逻辑片段”
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
      throw StateError('Current is undefined.');
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

    if (codePoint >= _mongolQuickCheckStart &&
        codePoint < _mongolQuickCheckEnd) {
      return false;
    }

    if (codePoint < _koreanJamoStart) return false;
    if (codePoint <= _koreanJamoEnd) return true;

    if (codePoint >= _cjkRadicalSupplementStart &&
        codePoint <= _cjkUnifiedIdeographsEnd) {
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

    if (codePoint >= _hangulSyllablesStart &&
        codePoint <= _hangulJamoExtendedBEnd) {
      return true;
    }

    if (codePoint >= _cjkCompatibilityIdeographsStart &&
        codePoint <= _cjkCompatibilityIdeographsEnd) {
      return true;
    }

    if (isEmoji(codePoint)) return true;
    return false;
  }

  static bool isEmoji(int codePoint) {
    return codePoint > _unicodeEmojiStart;
  }
}

class _RawStyledTextRun {
  _RawStyledTextRun(this.style, this.text);
  final TextStyle? style;
  final RotatableString text;
}

/// [_TextRun] 文字片段：文字排版中最小的绘制单元（如一个单词、一个汉字、一个表情）。
class _TextRun {
  _TextRun(this.start, this.end, this.isRotated, this.paragraph,
      {this.textStyle, this.paragraphStyle});

  final int start;
  final int end;

  /// 片段是否需要旋转（蒙古文、CJK 字符、表情通常需要旋转）
  final bool isRotated;

  /// 该片段对应的预计算段落对象（包含尺寸等信息）
  final ui.Paragraph paragraph;

  final ui.TextStyle? textStyle;
  final ui.ParagraphStyle? paragraphStyle;

  double get width => paragraph.maxIntrinsicWidth;
  double get height => paragraph.height;

  /// 绘制片段：如果需要旋转，就在这里施展“逆时针旋转 90 度”的魔法。
  void draw(ui.Canvas canvas, ui.Offset offset) {
    if (isRotated) {
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      // 逆时针旋转 90 度，配合 Canvas 的 90 度顺时针旋转，让蒙古文字体方向转正。
      canvas.rotate(-math.pi / 2);
      canvas.translate(-paragraph.maxIntrinsicWidth, 0);
      canvas.drawParagraph(paragraph, const ui.Offset(0, 0));
      canvas.restore();
    } else {
      canvas.drawParagraph(paragraph, offset);
    }
  }
}

/// 内部数据结构：记录每一列的信息
class _LineInfo {
  _LineInfo(this.textRunStart, this.textRunEnd, this.bounds, this.runCumWidths);
  final int textRunStart;
  final int textRunEnd;
  final Rect bounds;
  final List<double> runCumWidths;
}

class _Stack<T> {
  final _stack = Queue<T>();
  void push(T element) => _stack.addLast(element);
  void pop() => _stack.removeLast();
  bool get isEmpty => _stack.isEmpty;
  T get top => _stack.last;
}
