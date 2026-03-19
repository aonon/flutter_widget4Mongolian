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
@immutable
sealed class CaretMetrics {}

/// 光标位于非空行的中的度量信息
///
/// 此类表示光标位于文本行中字形旁的情况，存储光标和字形的位置及大小信息。
final class LineCaretMetrics implements CaretMetrics {
  /// 创建一个光标度量信息实例
  const LineCaretMetrics({required this.offset, required this.fullWidth});

  /// 光标左上角相对于段落左上角的位置（段落内部坐标系）
  final Offset offset;

  /// 光标所在位置字形的完整宽度
  final double fullWidth;
}

/// 光标位于空行或换行符处的度量信息
///
/// 此类表示光标位于空行中的情况（如文本为空、行首、或两个换行符之间），
/// 此时光标不关联任何字形，仅需提供水平位置信息。
final class EmptyLineCaretMetrics implements CaretMetrics {
  const EmptyLineCaretMetrics({required this.lineHorizontalOffset});

  /// 空行的水平位置（该行的 x 坐标）
  final double lineHorizontalOffset;
}

/// 光标度量计算器
///
/// 此类封装了所有光标度量的计算逻辑，包括字形查找、坐标转换等。
/// 负责处理 UTF-16 代理对、零宽度字符等复杂情况。
class CaretMetricsCalculator {
  /// 零宽度连接符字符的 Unicode 值
  static const int _zwjUtf16 = 0x200d;

  /// 首次缓存的光标位置和度量结果
  late CaretMetrics _cachedCaretMetrics;

  /// 关键字段：上一次计算光标度量时的文本位置
  ///
  /// 用于缓存光标度量结果。当查询相同位置时，无需重新计算，
  /// 直接返回缓存的度量结果。当位置变化时，缓存自动失效。
  TextPosition? _previousCaretPosition;

  /// 计算给定光标位置的度量信息
  ///
  /// 此方法是光标度量计算的核心，实现了以下逻辑：
  /// 1. 使用位置和亲和力（affinity）确定查询方向
  /// 2. 首选方向查询失败时，回退到另一个方向
  /// 3. 缓存结果，避免重复计算
  CaretMetrics compute(
    TextPosition position,
    String plainText,
    MongolParagraph paragraph,
    InlineSpan text,
  ) {
    // 缓存检查：若位置未变，直接返回缓存结果
    if (position == _previousCaretPosition) {
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

    // 更新缓存位置和度量
    _previousCaretPosition = position;
    return _cachedCaretMetrics =
        metrics ?? EmptyLineCaretMetrics(lineHorizontalOffset: 0);
  }

  /// 基于上游字符（当前位置之前的字符）的近边缘获取光标度量
  CaretMetrics? _getMetricsFromUpstream(
    int offset,
    String plainText,
    MongolParagraph paragraph,
    InlineSpan text,
  ) {
    final int plainTextLength = plainText.length;
    if (plainTextLength == 0 || offset > plainTextLength) return null;

    final int prevCodeUnit =
        plainText.codeUnitAt(max(0, offset - 1));
    const int newlineCodeUnit = 10;

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
        if (!needsSearch && prevCodeUnit == newlineCodeUnit) break;
        if (searchOffset < -plainTextLength) break;
        graphemeLength *= 2;
      }
    }

    if (boxes.isEmpty) return null;
    final box = boxes.last;
    return prevCodeUnit == newlineCodeUnit
        ? EmptyLineCaretMetrics(lineHorizontalOffset: box.right)
        : LineCaretMetrics(
            offset: Offset(box.left, box.bottom),
            fullWidth: box.right - box.left,
          );
  }

  /// 基于下游字符（当前位置之后的字符）的近边缘获取光标度量
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

  /// 检查给定代码单元是否需要扩展搜索
  bool _needsGraphemeExtendedSearch(int codeUnit, int? codeUnitAfter) {
    return MongolTextTools.isHighSurrogate(codeUnit) ||
        MongolTextTools.isLowSurrogate(codeUnit) ||
        codeUnitAfter == _zwjUtf16 ||
        MongolTextTools.isUnicodeDirectionality(codeUnit);
  }
}
