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
class MongolParagraph {
  /// 由 [MongolParagraphBuilder] 创建，不应直接实例化
  MongolParagraph._(
    this._runs,
    this._text,
    this._maxLines,
    this._ellipsis,
    this._textAlign,
  );

  final String _text;
  final List<_TextRun> _runs;
  final int? _maxLines;
  final _TextRun? _ellipsis;
  final MongolTextAlign _textAlign;

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

    /// 计算段落中每个字形的大小和位置。
    ///
    /// 说明（面向 Flutter 初学者）:
    /// - 这个库实现的是垂直排版（蒙古文从上到下）, 但内部使用的是水平文本测量。
    /// - `MongolParagraphConstraints.height` 表示在竖直方向上可用的行长，
    ///   在内部被当作水平的 "max line length" 来计算换行（随后在绘制时旋转画布）。
    /// - 在调用这个方法后，需要调用 `draw` 才能把文本绘制到画布上。
    void layout(MongolParagraphConstraints constraints) =>
      _layout(constraints.height);

  void _layout(double height) {
    if (height == _height) return;
    _calculateLineBreaks(height);
    _calculateWidth();
    _height = height;
    _calculateIntrinsicHeight();
  }

  final List<_LineInfo> _lines = [];
  // Cumulative horizontal offsets (in vertical layout terms) for each line.
  // _lineOffsets[i] is the sum of heights of lines 0..i inclusive and
  // is used to quickly map a vertical coordinate to a line index.
  final List<double> _lineOffsets = [];

  // Internally this method uses "width" and "height" naming with regard
  // to a horizontal line of text. Rotation doesn't happen until drawing.
  void _calculateLineBreaks(double maxLineLength) {
    // 解释：
    // - `maxLineLength` 在外部看起来是段落的高度（因为我们最终是竖直排版），
    //   但在内部我们把一行当作水平的一段文字来计算，所以这里称为 "maxLineLength"。
    // - `_runs` 是已经按样式拆分并测量好的段落片段，一个 run 通常是一个可绘制的最小单位（字、词或 emoji）。
    // - 本函数把这些 run 累加到一行（horizontal）中，超过 `maxLineLength` 时换到下一行。
    if (_runs.isEmpty) {
      return;
    }
    if (_lines.isNotEmpty) {
      _lines.clear();
      _lineOffsets.clear();
      _didExceedMaxLines = false;
    }

    // add run lengths until exceeds length
    var start = 0;
    var end = 0;
    var lineWidth = 0.0;
    var lineHeight = 0.0;
    var runEndsWithNewLine = false;
    for (var i = 0; i < _runs.length; i++) {
      end = i;
      final run = _runs[i];
      final runWidth = run.width;
      final runHeight = run.height;

      if (lineWidth + runWidth > maxLineLength) {
        _addLine(start, end, lineWidth, lineHeight);
        lineWidth = runWidth;
        lineHeight = runHeight;
        start = end;
      } else {
        lineWidth += runWidth;
        lineHeight = math.max(lineHeight, run.height);
      }

      runEndsWithNewLine = _runEndsWithNewLine(run);
      if (runEndsWithNewLine) {
        end = i + 1;
        _addLine(start, end, lineWidth, lineHeight);
        lineWidth = 0;
        lineHeight = 0;
        start = end;
      }

      if (_didExceedMaxLines) {
        break;
      }
    }

    end = _runs.length;
    if (start < end) {
      _addLine(start, end, lineWidth, lineHeight);
    }

    // add empty line with invalid run indexes for final newline char
    if (runEndsWithNewLine) {
      final height = _lines.last.bounds.height;
      _addLine(-1, -1, 0, height);
    }
  }

  bool _runEndsWithNewLine(_TextRun run) {
    final index = run.end - 1;
    return _text[index] == '\n';
  }

  void _addLine(int start, int end, double width, double height) {
    if (_maxLines != null && _maxLines! <= _lines.length) {
      _didExceedMaxLines = true;
      return;
    }
    _didExceedMaxLines = false;
    final bounds = Rect.fromLTRB(0, 0, width, height);
    // precompute cumulative run widths for faster hit testing later
    final runCumWidths = <double>[];
    if (start >= 0 && end > start) {
      var acc = 0.0;
      for (var i = start; i < end; i++) {
        acc += _runs[i].width;
        runCumWidths.add(acc);
      }
    }
    final lineInfo = _LineInfo(start, end, bounds, runCumWidths);
    _lines.add(lineInfo);
    _longestLine = math.max(longestLine, lineInfo.bounds.width);

    // update line offsets
    final lastOffset = _lineOffsets.isEmpty ? 0.0 : _lineOffsets.last;
    _lineOffsets.add(lastOffset + bounds.height);
  }

  void _calculateWidth() {
    var sum = 0.0;
    for (final line in _lines) {
      sum += line.bounds.height;
    }
    _width = sum;
  }

  // Internally this translates a horizontal run width to the vertical name
  // that it is known as externally.
  void _calculateIntrinsicHeight() {
    var sum = 0.0;
    var maxRunWidth = 0.0;
    var maxLineEndsWithNewLine = 0.0;
    var minLineEndsWithoutNewLine = double.infinity;
    for (var index = 0; index < _lines.length; index++) {
      final line = _lines[index];
      _TextRun? lastRun;
      for (var i = line.textRunStart; i < line.textRunEnd; i++) {
        lastRun = _runs[i];
        final width = lastRun.width;
        maxRunWidth = math.max(width, maxRunWidth);
        sum += width;
      }
      final bool endsWithNewLine;
      if (lastRun != null) {
        endsWithNewLine = _runEndsWithNewLine(lastRun);
      } else {
        endsWithNewLine = false;
      }
      final hasNextLine = index < _lines.length - 1;
      if (hasNextLine && !endsWithNewLine) {
        final nextLine = _lines[index + 1];
        sum += _runs[nextLine.textRunStart].width;
        minLineEndsWithoutNewLine = math.min(minLineEndsWithoutNewLine, sum);
      } else {
        maxLineEndsWithNewLine = math.max(maxLineEndsWithNewLine, sum);
      }
      sum = 0;
    }
    if (minLineEndsWithoutNewLine == double.infinity) {
      minLineEndsWithoutNewLine = 0;
    }
    _minIntrinsicHeight = maxRunWidth;
    _maxIntrinsicHeight =
        math.max(minLineEndsWithoutNewLine, maxLineEndsWithNewLine);
  }

  /// 获取最接近给定偏移量的文本位置
  TextPosition getPositionForOffset(Offset offset) {
    final encoded = _getPositionForOffset(offset.dx, offset.dy);
    return TextPosition(
        offset: encoded[0], affinity: TextAffinity.values[encoded[1]]);
  }

  // Both the line info and the text run are in horizontal orientation,
  // but the [dx] and [dy] offsets are in vertical orientation.
  List<int> _getPositionForOffset(double dx, double dy) {
    const upstream = 0;
    const downstream = 1;

    // 说明：外部的 `dx`/`dy` 是在竖直布局坐标系中的坐标（段落的左上原点）。
    // 我们内部把行和 run 都当作水平（未旋转）来存储，所以这里需要把竖直坐标
    // 映射回内部的行/run 索引。
    if (_lines.isEmpty) {
      return [0, downstream];
    }

    // find the line using binary search on _lineOffsets
    _LineInfo matchedLine;
    if (_lineOffsets.isEmpty) {
      matchedLine = _lines.last;
    } else {
      var low = 0;
      var high = _lineOffsets.length - 1;
      while (low <= high) {
        final mid = (low + high) >> 1;
        if (dx <= _lineOffsets[mid]) {
          high = mid - 1;
        } else {
          low = mid + 1;
        }
      }
      final lineIndex = math.min(low, _lines.length - 1);
      matchedLine = _lines[lineIndex];
    }

    // find the run in the line using cumulative run widths (binary search)
    _TextRun? matchedRun;
    double rotatedRunDy = 0.0;
    final rotatedRunDx = matchedLine.bounds.top;
    if (matchedLine.runCumWidths.isEmpty) {
      // fallback: select last run
      final matchedRunIndex = matchedLine.textRunEnd - 1;
      if (matchedRunIndex.isNegative) {
        matchedRun = _runs.last;
      } else {
        matchedRun = _runs[matchedRunIndex];
      }
    } else {
      var low = 0;
      var high = matchedLine.runCumWidths.length - 1;
      while (low <= high) {
        final mid = (low + high) >> 1;
        if (dy <= matchedLine.runCumWidths[mid]) {
          high = mid - 1;
        } else {
          low = mid + 1;
        }
      }
      final runIndexInLine = math.min(low, matchedLine.runCumWidths.length - 1);
      final matchedRunIndex = matchedLine.textRunStart + runIndexInLine;
      matchedRun = _runs[math.min(matchedRunIndex, _runs.length - 1)];
      rotatedRunDy = runIndexInLine == 0 ? 0.0 : matchedLine.runCumWidths[runIndexInLine - 1];
    }
    // matchedRun is guaranteed to be non-null here because both branches
    // above assign a value.

    // find the offset
    final paragraphDx = dy - rotatedRunDy;
    final paragraphDy = dx - rotatedRunDx;
    // `offset` 是将外部的 (dx,dy) 转换为内部 paragraph 使用的坐标
    final offset = Offset(paragraphDx, paragraphDy);
    final runPosition = matchedRun.paragraph.getPositionForOffset(offset);
    final textOffset = matchedRun.start + runPosition.offset;

    // find the affinity
    final lineEndCharOffset = matchedRun.end;
    final textAffinity =
        (textOffset == lineEndCharOffset) ? upstream : downstream;
    return [textOffset, textAffinity];
  }

  /// 在画布上绘制垂直蒙古文
  ///
  /// 蒙古文绘制流程：
  /// 1. 保存画布状态
  /// 2. 应用偏移量
  /// 3. 将整个画布旋转90度，建立垂直排版基础坐标系
  /// 4. 按从上到下的顺序绘制每一行
  /// 5. 对需要旋转的字符（如蒙古文）进行额外的90度旋转处理
  /// 6. 恢复画布状态
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
    if (offset >= _text.length) {
      return null;
    }
    var min = 0;
    var max = _runs.length - 1;
    // 使用二分查找在已测量的 runs 中定位包含 `offset` 的 run，
    // 这样比线性查找要快，尤其是在长文本时。
    while (min <= max) {
      final guess = (max + min) ~/ 2;
      if (offset >= _runs[guess].end) {
        min = guess + 1;
        continue;
      } else if (offset < _runs[guess].start) {
        max = guess - 1;
        continue;
      } else {
        return _runs[guess];
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
    final List<MongolLineMetrics> metrics = <MongolLineMetrics>[];
    for (int index = 0; index < _lines.length; index += 1) {
      final line = _lines[index];
      bool hardBreak = false;
      double ascent = 0;
      double descent = 0;
      double unscaledAscent = 0;
      double height = 0;
      double width = 0;
      double baseline = 0;
      for (int j = line.textRunStart; j < line.textRunEnd; j += 1) {
        final textRun = _runs[j];
        final metricsList = textRun.paragraph.computeLineMetrics();
        final runMetrics = metricsList.isEmpty ? null : metricsList.first;

        // last textRun of this line
        if (j == line.textRunEnd - 1) {
          hardBreak = _runEndsWithNewLine(textRun);
        }
        ascent = math.max(runMetrics?.ascent ?? 0, ascent);
        descent = math.max(runMetrics?.descent ?? 0, descent);
        unscaledAscent =
            math.max(runMetrics?.unscaledAscent ?? 0, unscaledAscent);
        width = math.max(runMetrics?.height ?? 0, width);
        height += runMetrics?.width ?? textRun.width;
        final previousMetrics = index > 0 ? metrics[index - 1] : null;
        final previousLineAscent = previousMetrics?.ascent ?? 0.0;
        final previousLineBaseline = previousMetrics?.baseline ?? 0.0;
        baseline = previousLineBaseline + previousLineAscent + descent;
      }

      // ends with new line
      if (line.textRunStart == -1 && line.textRunEnd == -1) {
        final previousMetrics = metrics[index - 1];
        hardBreak = true;
        ascent = previousMetrics.ascent;
        descent = previousMetrics.descent;
        unscaledAscent = previousMetrics.unscaledAscent;
        height = previousMetrics.height;
        width = previousMetrics.width;
        baseline = previousMetrics.baseline + previousMetrics.ascent + descent;
      }

      double top = 0;
      if (_textAlign == MongolTextAlign.center) {
        top = (this.height - height) / 2;
      } else if (_textAlign == MongolTextAlign.bottom) {
        top = this.height - height;
      }

      final lineMetrics = MongolLineMetrics(
        hardBreak: hardBreak,
        ascent: ascent,
        descent: descent,
        unscaledAscent: unscaledAscent,
        height: height,
        width: width,
        top: top,
        baseline: baseline,
        lineNumber: index,
      );
      metrics.add(lineMetrics);
    }
    return metrics;
  }

  /// 释放对象使用的资源
  /// 调用后对象不再可用
  void dispose() {
    assert(!_disposed);
    assert(() {
      _disposed = true;
      return true;
    }());

    // Is this slow? Is it necessary?
    // Do we need to dispose anything else?
    for (final run in _runs) {
      run.paragraph.dispose();
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

      final run = _TextRun(startIndex, endIndex, isRotated, paragraph);
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
    return _TextRun(-1, -1, false, paragraph);
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
  _TextRun(this.start, this.end, this.isRotated, this.paragraph);

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

/// LineInfo stores information about each line in the paragraph.
///
/// [textRunStart] is the index of the first text run in the line (out of all the
/// text runs in the paragraph). [textRunEnd] is the index of the last run.
///
/// The [bounds] is the size of the unrotated text line.
class _LineInfo {
  _LineInfo(this.textRunStart, this.textRunEnd, this.bounds, this.runCumWidths);

  /// The index of the run in [_runs] where this line starts
  final int textRunStart;

  /// The index (exclusive) of the run in [_runs] where this line end
  final int textRunEnd;

  /// The measured size of this unrotated line (horizontal orientation).
  ///
  /// There is no offset so [left] and [top] are `0`. Just use [width] and
  /// [height].
  final Rect bounds;

  /// Cumulative run widths for runs in this line.
  /// Example: [w1, w1+w2, w1+w2+w3]
  final List<double> runCumWidths;
}

// This is for keeping track of the text style stack.
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
