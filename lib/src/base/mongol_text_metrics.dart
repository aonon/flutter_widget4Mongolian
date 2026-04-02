// Copyright 2014 The Flutter Authors.
// Copyright 2020 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' show max, min;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/services.dart' show TextAffinity, TextPosition;
import 'package:flutter/widgets.dart' show InlineSpan, Offset, Rect;
import 'mongol_paragraph.dart';
import 'mongol_text_tools.dart';

/// 光标度量信息的基类
/// Base class for caret metrics information.
/// Base class for caret metrics.
@immutable
sealed class CaretMetrics {}

/// 光标位于非空行的中的度量信息
/// Caret metrics for non-empty lines.
final class LineCaretMetrics implements CaretMetrics {
  const LineCaretMetrics({required this.offset, required this.fullWidth});

  final Offset offset;

  final double fullWidth;
}

/// 光标在空行处的度量
/// Caret metrics for empty lines.
final class EmptyLineCaretMetrics implements CaretMetrics {
  const EmptyLineCaretMetrics({required this.lineHorizontalOffset});

  final double lineHorizontalOffset;
}

/// 光标度量计算器
/// Calculates caret metrics for text positions.
class CaretMetricsCalculator {
  static const int _zeroWidthJoinerCodeUnit = 0x200d;
  static const int _newlineCodeUnit = 0x0A;
  static const EmptyLineCaretMetrics _emptyCaretMetrics =
      EmptyLineCaretMetrics(lineHorizontalOffset: 0);

  CaretMetrics _cachedCaretMetrics = _emptyCaretMetrics;

  TextPosition? _lastQueriedCaretPosition;
  String? _lastQueriedPlainText;
  MongolParagraph? _lastQueriedParagraph;
  InlineSpan? _lastQueriedText;

  bool _canUseCached(
    TextPosition position,
    String plainText,
    MongolParagraph paragraph,
    InlineSpan text,
  ) {
    return position == _lastQueriedCaretPosition &&
        identical(plainText, _lastQueriedPlainText) &&
        identical(paragraph, _lastQueriedParagraph) &&
        identical(text, _lastQueriedText);
  }

  CaretMetrics _cacheAndReturn(
    TextPosition position,
    String plainText,
    MongolParagraph paragraph,
    InlineSpan text,
    CaretMetrics metrics,
  ) {
    _lastQueriedCaretPosition = position;
    _lastQueriedPlainText = plainText;
    _lastQueriedParagraph = paragraph;
    _lastQueriedText = text;
    return _cachedCaretMetrics = metrics;
  }

  CaretMetrics compute(
    TextPosition position,
    String plainText,
    MongolParagraph paragraph,
    InlineSpan text,
  ) {
    if (_canUseCached(position, plainText, paragraph, text)) {
      return _cachedCaretMetrics;
    }

    final int offset = position.offset;
    final int plainTextLength = plainText.length;
    if (offset < 0 || offset > plainTextLength || plainTextLength == 0) {
      return _cacheAndReturn(
          position, plainText, paragraph, text, _emptyCaretMetrics);
    }

    final CaretMetrics? metrics = switch (position.affinity) {
      TextAffinity.upstream =>
        _getMetricsFromUpstream(offset, plainText, paragraph, text) ??
            _getMetricsFromDownstream(offset, plainText, paragraph, text),
      TextAffinity.downstream =>
        _getMetricsFromDownstream(offset, plainText, paragraph, text) ??
            _getMetricsFromUpstream(offset, plainText, paragraph, text),
    };

    return _cacheAndReturn(
      position,
      plainText,
      paragraph,
      text,
      metrics ?? _emptyCaretMetrics,
    );
  }

  /// 根据前一个字符获取光标度量
  /// Gets caret metrics from the previous character.
  CaretMetrics? _getMetricsFromUpstream(
    int offset,
    String plainText,
    MongolParagraph paragraph,
    InlineSpan text,
  ) {
    final int plainTextLength = plainText.length;
    if (plainTextLength == 0 || offset < 0 || offset > plainTextLength) {
      return null;
    }

    final int safeOffset = offset.clamp(0, plainTextLength);
    final int prevCodeUnit = plainText.codeUnitAt(max(0, safeOffset - 1));
    final int? nextCodeUnit = text.codeUnitAt(safeOffset);

    final bool needsSearch =
        _needsGraphemeExtendedSearch(prevCodeUnit, nextCodeUnit);

    final List<Rect> boxes = _findBoxesUpstream(
      paragraph,
      safeOffset,
      plainTextLength,
      needsSearch,
      stopAtNewline: prevCodeUnit == _newlineCodeUnit,
    );
    if (boxes.isEmpty) return null;

    final box = boxes.last;
    return prevCodeUnit == _newlineCodeUnit
        ? EmptyLineCaretMetrics(lineHorizontalOffset: box.right)
        : LineCaretMetrics(
            offset: Offset(box.left, box.bottom),
            fullWidth: box.right - box.left,
          );
  }

  CaretMetrics? _getMetricsFromDownstream(
    int offset,
    String plainText,
    MongolParagraph paragraph,
    InlineSpan text,
  ) {
    final int plainTextLength = plainText.length;
    if (plainTextLength == 0 || offset < 0 || offset > plainTextLength) {
      return null;
    }

    final int safeOffset = offset.clamp(0, plainTextLength);
    final int nextCodeUnit =
        plainText.codeUnitAt(min(safeOffset, plainTextLength - 1));

    final bool needsSearch = _needsGraphemeExtendedSearch(nextCodeUnit, null);
    final List<Rect> boxes = _findBoxesDownstream(
        paragraph, safeOffset, plainTextLength, needsSearch);

    if (boxes.isEmpty) return null;
    final box = boxes.first;
    return LineCaretMetrics(
      offset: Offset(box.left, box.top),
      fullWidth: box.right - box.left,
    );
  }

  List<Rect> _findBoxesUpstream(
    MongolParagraph paragraph,
    int offset,
    int plainTextLength,
    bool needsSearch, {
    required bool stopAtNewline,
  }) {
    int graphemeLength = needsSearch ? 2 : 1;

    while (true) {
      final int rangeStart = max(0, offset - graphemeLength);
      final List<Rect> boxes = paragraph.getBoxesForRange(rangeStart, offset);
      if (boxes.isNotEmpty) {
        return boxes;
      }

      if (!needsSearch || stopAtNewline || rangeStart == 0) {
        return const <Rect>[];
      }

      final int nextLength = min(plainTextLength, graphemeLength * 2);
      if (nextLength == graphemeLength) {
        return const <Rect>[];
      }
      graphemeLength = nextLength;
    }
  }

  List<Rect> _findBoxesDownstream(
    MongolParagraph paragraph,
    int offset,
    int plainTextLength,
    bool needsSearch,
  ) {
    int graphemeLength = needsSearch ? 2 : 1;
    final int maxSearchEnd = plainTextLength << 1;

    while (true) {
      final int rangeEnd = offset + graphemeLength;
      final List<Rect> boxes = paragraph.getBoxesForRange(offset, rangeEnd);
      if (boxes.isNotEmpty) {
        return boxes;
      }

      if (!needsSearch || rangeEnd >= maxSearchEnd) {
        return const <Rect>[];
      }

      final int nextLength = graphemeLength * 2;
      if (nextLength == graphemeLength) {
        return const <Rect>[];
      }
      graphemeLength = nextLength;
    }
  }

  bool _needsGraphemeExtendedSearch(int codeUnit, int? codeUnitAfter) {
    return MongolTextTools.isHighSurrogate(codeUnit) ||
        MongolTextTools.isLowSurrogate(codeUnit) ||
        codeUnitAfter == _zeroWidthJoinerCodeUnit ||
        MongolTextTools.isUnicodeDirectionality(codeUnit);
  }
}
