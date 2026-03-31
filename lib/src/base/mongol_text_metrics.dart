// Copyright 2014 The Flutter Authors.
// Copyright 2020 Suragch.
// All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' show max, min;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/services.dart' show TextAffinity, TextPosition;
import 'package:flutter/widgets.dart'
    show InlineSpan, Offset, Rect;
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

  CaretMetrics _cachedCaretMetrics =
      const EmptyLineCaretMetrics(lineHorizontalOffset: 0);

  TextPosition? _lastQueriedCaretPosition;

  CaretMetrics compute(
    TextPosition position,
    String plainText,
    MongolParagraph paragraph,
    InlineSpan text,
  ) {
    if (position == _lastQueriedCaretPosition) {
      return _cachedCaretMetrics;
    }

    final int offset = position.offset;
    final CaretMetrics? metrics = switch (position.affinity) {
      TextAffinity.upstream =>
        _getMetricsFromUpstream(offset, plainText, paragraph, text) ??
            _getMetricsFromDownstream(offset, plainText, paragraph, text),
      TextAffinity.downstream =>
        _getMetricsFromDownstream(offset, plainText, paragraph, text) ??
            _getMetricsFromUpstream(offset, plainText, paragraph, text),
    };

    _lastQueriedCaretPosition = position;
    return _cachedCaretMetrics =
        metrics ?? EmptyLineCaretMetrics(lineHorizontalOffset: 0);
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
    if (plainTextLength == 0 || offset > plainTextLength) return null;

    final int prevCodeUnit = plainText.codeUnitAt(max(0, offset - 1));
    const int newlineCharCode = 0x0A;

    final bool needsSearch = _needsGraphemeExtendedSearch(
      prevCodeUnit,
      text.codeUnitAt(offset),
    );
    int graphemeLength = needsSearch ? 2 : 1;
    List<Rect> boxes = <Rect>[];

    while (boxes.isEmpty) {
      final int searchOffset = offset - graphemeLength;
      boxes = paragraph.getBoxesForRange(
        max(0, searchOffset),
        offset,
      );

      if (boxes.isEmpty) {
        if (!needsSearch && prevCodeUnit == newlineCharCode) break;
        if (searchOffset < -plainTextLength) break;
        graphemeLength *= 2;
      }
    }

    if (boxes.isEmpty) return null;
    final box = boxes.last;
    return prevCodeUnit == newlineCharCode
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
    if (plainTextLength == 0) return null;

    final int nextCodeUnit =
        plainText.codeUnitAt(min(offset, plainTextLength - 1));

    final bool needsSearch = _needsGraphemeExtendedSearch(nextCodeUnit, null);
    int graphemeLength = needsSearch ? 2 : 1;
    List<Rect> boxes = <Rect>[];

    while (boxes.isEmpty) {
      final int searchOffset = offset + graphemeLength;
      boxes = paragraph.getBoxesForRange(offset, searchOffset);

      if (boxes.isEmpty) {
        if (!needsSearch) break;
        if (searchOffset >= plainTextLength << 1) break;
        graphemeLength *= 2;
      }
    }

    if (boxes.isEmpty) return null;
    final box = boxes.first;
    return LineCaretMetrics(
      offset: Offset(box.left, box.top),
      fullWidth: box.right - box.left,
    );
  }

  bool _needsGraphemeExtendedSearch(int codeUnit, int? codeUnitAfter) {
    return MongolTextTools.isHighSurrogate(codeUnit) ||
        MongolTextTools.isLowSurrogate(codeUnit) ||
        codeUnitAfter == _zeroWidthJoinerCodeUnit ||
        MongolTextTools.isUnicodeDirectionality(codeUnit);
  }
}
